function output_path = qam_srrc(output_directory,stream)
%QAM_SRRC Compare SCF estimates for four M-QAM-SRRC waveforms.

arguments
    output_directory (1,1) string
    stream (1,1) RandStream
end

num_symbols = 4000;
symbol_rate_mbd = 0.1;
sample_rate_mhz = 1;
center_frequency_mhz = 0.05;
max_lag = 15;
num_frequencies = 128;
smoothing_length = 8;
cycle_frequencies_mhz = (0:symbol_rate_mbd:sample_rate_mhz/2).';
rolloff = 1;
filter_span_symbols = 6;
samples_per_symbol = sample_rate_mhz/symbol_rate_mbd;
assert(abs(samples_per_symbol-round(samples_per_symbol)) < ...
    eps(sample_rate_mhz));
samples_per_symbol = round(samples_per_symbol);
filter_taps = rcosdesign(rolloff,filter_span_symbols, ...
    samples_per_symbol,'sqrt').';
frequency_mhz = (-num_frequencies/2:num_frequencies/2-1) * ...
    (sample_rate_mhz/num_frequencies);

[fig, colors] = thesis.plot.new_figure();
layout = tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
plot_colors = [colors.blue;colors.orange;colors.green;colors.purple];
modulation_orders = 2.^(1:4);
expected_symbol_variances = [1,2,6,10];
symbol_variances = zeros(size(modulation_orders));
scf_peaks = zeros(size(modulation_orders));
axes_handles = gobjects(size(modulation_orders));

for modulation_index = 1:numel(modulation_orders)
    modulation_order = modulation_orders(modulation_index);

    % Use each constellation point equally often.  This fixes the finite
    % record's symbol variance at its analytical value and makes the
    % amplitude comparison independent of draw-to-draw count imbalance.
    messages = repmat((0:modulation_order-1).', ...
        num_symbols/modulation_order,1);
    messages = messages(randperm(stream,num_symbols));
    baseband_symbols = qammod(messages,modulation_order, ...
        'UnitAveragePower',false);
    reference_constellation = qammod((0:modulation_order-1).', ...
        modulation_order,'UnitAveragePower',false);
    symbol_variances(modulation_index) = ...
        mean(abs(reference_constellation).^2);
    assert(abs(symbol_variances(modulation_index) - ...
        expected_symbol_variances(modulation_index)) < ...
        100*eps(expected_symbol_variances(modulation_index)));
    assert(abs(mean(abs(baseband_symbols).^2) - ...
        symbol_variances(modulation_index)) < ...
        100*eps(symbol_variances(modulation_index)));

    shaped_signal = upfirdn(baseband_symbols,filter_taps,samples_per_symbol);
    sample_index = (0:numel(shaped_signal)-1).';
    passband_signal = shaped_signal .* exp(1j*2*pi* ...
        center_frequency_mhz/sample_rate_mhz*sample_index);
    cyclic_autocorrelation = thesis.signal.symmetric_caf(passband_signal, ...
        cycle_frequencies_mhz,sample_rate_mhz,max_lag);
    spectral_correlation = thesis.signal.caf_to_scf( ...
        cyclic_autocorrelation,sample_rate_mhz,num_frequencies, ...
        smoothing_length);
    scf_peaks(modulation_index) = max(abs(spectral_correlation),[],'all');

    [~,symbol_rate_index] = min(abs(cycle_frequencies_mhz-symbol_rate_mbd));
    [~,carrier_index] = max(abs(spectral_correlation(symbol_rate_index,:)));
    assert(abs(frequency_mhz(carrier_index)-center_frequency_mhz) <= ...
        sample_rate_mhz/num_frequencies);

    ax = nexttile(layout);
    axes_handles(modulation_index) = ax;
    surface_handle = waterfall(ax,frequency_mhz,cycle_frequencies_mhz, ...
        abs(spectral_correlation));
    set(surface_handle,'EdgeColor',plot_colors(modulation_index,:), ...
        'EdgeAlpha',0.82, ...
        'FaceColor',plot_colors(modulation_index,:), ...
        'FaceAlpha',0.12,'LineWidth',0.75);
    view(ax,225,20);
    title(ax,sprintf('%d-QAM-SRRC',modulation_order));
    xlabel(ax,'$f\ (\mathrm{MHz})$');
    ylabel(ax,'$\alpha\ (\mathrm{MHz})$');
    zlabel(ax,'$|\widehat{S}_{x}^{\alpha}(f)|$');
    xlim(ax,[frequency_mhz(1),frequency_mhz(end)]);
end

shared_zmax = 1.05*max(scf_peaks);
for axes_index = 1:numel(axes_handles)
    zlim(axes_handles(axes_index),[0,shared_zmax]);
end

normalized_peaks = scf_peaks./symbol_variances;
assert(max(abs(normalized_peaks/mean(normalized_peaks)-1)) < 0.08, ...
    'thesis:qam_srrc:UnexpectedAmplitudeScaling', ...
    'The SCF shapes do not exhibit the expected symbol-variance scaling.');
fprintf('Symbol variances:');
fprintf(' %.6f',symbol_variances);
fprintf('\nSCF peaks:');
fprintf(' %.6f',scf_peaks);
fprintf('\nSCF peak / symbol variance:');
fprintf(' %.6f',normalized_peaks);
fprintf('\n');

output_path = thesis.plot.export_png(fig,output_directory,'qam_srrc');
end
