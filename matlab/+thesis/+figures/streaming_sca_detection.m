function output_path = streaming_sca_detection(output_directory,stream)
%STREAMING_SCA_DETECTION Detect two QAM-SRRC signals with streaming SCA.
% Dylan J. Gormley (NASA GRC/LCI), 2020
%
% This reader-facing example follows the receiver dataflow described in
% the thesis: downconversion, channel filtering, instantaneous power, a
% selected-frequency Fourier sum, and constant-threshold decisions.

arguments
    output_directory (1,1) string
    stream (1,1) RandStream
end

%% Transmitter: two M-QAM-SRRC components
num_symbols = 2^16;
sample_rate_hz = 1.0e6;
symbol_rates_hz = [0.10,0.20]*1e6;
center_frequencies_hz = [0.05,0.10]*1e6;
modulation_orders = [4,16];
rolloffs = [1.00,0.35];
ebn0_db = [14.0,9.0];

clean_component_1 = thesis.signal.qam_srrc_waveform(num_symbols, ...
    sample_rate_hz,symbol_rates_hz(1),center_frequencies_hz(1), ...
    modulation_orders(1),rolloffs(1),stream,'PeakNormalize',true);
clean_component_2 = thesis.signal.qam_srrc_waveform(num_symbols, ...
    sample_rate_hz,symbol_rates_hz(2),center_frequencies_hz(2), ...
    modulation_orders(2),rolloffs(2),stream,'PeakNormalize',true);

%% Receiver RF front end
num_capture_samples = 2^16;
components = [clean_component_1(1:num_capture_samples), ...
    clean_component_2(1:num_capture_samples)];

% Realize both requested Eb/N0 values against one physical noise floor.
% Component 1 keeps its generated level; component 2 is scaled to produce
% its requested ratio against the same receiver noise realization.
samples_per_symbol = sample_rate_hz./symbol_rates_hz;
sample_snr_db = ebn0_db + 10*log10(log2(modulation_orders)) - ...
    10*log10(samples_per_symbol);
component_power = mean(abs(components).^2,1);
noise_power = component_power(1)/10^(sample_snr_db(1)/10);
target_component_power = noise_power*10.^(sample_snr_db/10);
components = components.*sqrt(target_component_power./component_power);

unit_noise = (randn(stream,num_capture_samples,1) + ...
    1j*randn(stream,num_capture_samples,1))/sqrt(2);
noise = unit_noise*sqrt(noise_power/mean(abs(unit_noise).^2));
received_signal = sum(components,2)+noise;

% A common AGC scale preserves both component-to-noise ratios.
agc_scale = modnorm(received_signal,'peakpow',1);
agc_signal = received_signal*agc_scale;
measured_sample_snr_db = 10*log10( ...
    mean(abs(components).^2,1)/mean(abs(noise).^2));
measured_ebn0_db = measured_sample_snr_db - ...
    10*log10(log2(modulation_orders)) + ...
    10*log10(samples_per_symbol);
assert(all(abs(measured_ebn0_db-ebn0_db) < 0.05), ...
    'thesis:streaming_sca_detection:IncorrectNoisePower', ...
    'A realized Eb/N0 differs from its request by at least 0.05 dB.');
fprintf('Measured Eb/N0: %.2f dB, %.2f dB\n',measured_ebn0_db);

%% Streaming spectral-correlation analyzer
cycle_frequency_step_hz = min(symbol_rates_hz);
candidate_cycle_frequencies_hz = ...
    (cycle_frequency_step_hz: ...
    cycle_frequency_step_hz:sample_rate_hz/2).';
center_frequency_step_hz = 0.010e6;
candidate_center_frequencies_hz = ...
    (-sample_rate_hz/2:center_frequency_step_hz: ...
    sample_rate_hz/2-center_frequency_step_hz).';
channel_filter = [0.5,0.5];

% Process eight carrier candidates at a time.  The result equals the fully
% vectorized formulation, while the largest temporary array is N-by-8
% rather than N-by-100 and therefore reflects a streaming implementation.
carrier_chunk_size = 8;
test_statistic = thesis.signal.streaming_sca_statistic( ...
    agc_signal,sample_rate_hz, ...
    candidate_cycle_frequencies_hz, ...
    candidate_center_frequencies_hz, ...
    channel_filter,carrier_chunk_size);

threshold_scale = 1e-3;
estimated_power = sum(abs(agc_signal).^2)/num_capture_samples;
detection_threshold = threshold_scale*estimated_power^2;
threshold_surface = detection_threshold*ones(size(test_statistic));

peak_statistic = zeros(size(symbol_rates_hz));
estimated_center_frequencies_hz = zeros(size(center_frequencies_hz));
is_detected = false(size(symbol_rates_hz));
for signal_index = 1:numel(symbol_rates_hz)
    cycle_row = find(candidate_cycle_frequencies_hz == ...
        symbol_rates_hz(signal_index),1);
    [peak_statistic(signal_index),carrier_column] = ...
        max(test_statistic(cycle_row,:));
    estimated_center_frequencies_hz(signal_index) = ...
        candidate_center_frequencies_hz(carrier_column);
    is_detected(signal_index) = ...
        peak_statistic(signal_index) > detection_threshold;
    fprintf(['Signal %d: symbol rate = %.0f kBd, estimated center ' ...
        'frequency = %.0f kHz, T/gamma_CFD = %.2f, detected = %s\n'], ...
        signal_index,symbol_rates_hz(signal_index)/1e3, ...
        estimated_center_frequencies_hz(signal_index)/1e3, ...
        peak_statistic(signal_index)/detection_threshold, ...
        string(is_detected(signal_index)));
end
assert(all(is_detected), ...
    'thesis:streaming_sca_detection:MissedSignal', ...
    'At least one transmitted signal was not detected.');
assert(all(estimated_center_frequencies_hz == center_frequencies_hz), ...
    'thesis:streaming_sca_detection:IncorrectCenterFrequency', ...
    'A detected center frequency does not match its transmitted value.');

%% Detection surface
[fig, colors] = thesis.plot.new_figure();
ax = axes(fig);
statistic_plot = waterfall(ax,candidate_center_frequencies_hz/1e6, ...
    candidate_cycle_frequencies_hz/1e6,test_statistic);
statistic_plot.EdgeColor = colors.blue;
statistic_plot.FaceColor = 'none';
hold(ax,'on');
threshold_plot = waterfall(ax,candidate_center_frequencies_hz/1e6, ...
    candidate_cycle_frequencies_hz/1e6,threshold_surface);
threshold_plot.EdgeColor = colors.orange;
threshold_plot.FaceColor = 'none';
for signal_index = 1:numel(symbol_rates_hz)
    estimated_center_frequency_mhz = ...
        estimated_center_frequencies_hz(signal_index)/1e6;
    symbol_rate_mbd = symbol_rates_hz(signal_index)/1e6;
    scatter3(ax,estimated_center_frequency_mhz, ...
        symbol_rate_mbd,peak_statistic(signal_index), ...
        50,colors.green,'filled','MarkerEdgeColor',colors.gray, ...
        'HandleVisibility','off');
end
view(ax,225,20);
title(ax,'Streaming SCA Detection of Two M-QAM-SRRC Signals');
xlabel(ax,'$f_c$ (MHz)');
ylabel(ax,'$R_s$ (MBd)');
zlabel(ax,'$T_y(v,k)=|\widehat{C}_y(\alpha_v,f_k)|^2$');
legend(ax,[statistic_plot,threshold_plot], ...
    {'$T_y(v,k)$','$\gamma_{\mathrm{CFD}}=\beta\widehat{P}_y^2$'}, ...
    'Location','northeast');
output_path = thesis.plot.export_png(fig,output_directory,'qam_srrc_rs');
end
