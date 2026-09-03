%% 
% Dylan J. Gormley (NASA GRC/LCI) - 2020

clear
close all
rng(20210901,'twister')
%% 
% Transmitter:  M-QAM-SRRC

Nmessages = 2^16;   % number of transmitted symbols per component
Fs        = 1.0e6;  % sample rate

Rs        = [0.10  0.20]*1e6; % symbol rate
fc        = [0.05  0.10]*1e6; % carrier frequency
M         = [4       16];      % modulation order
Rolloff   = [1.00  0.35];      % excess bandwidth
EbN0      = [14.0   9.0];     % energy per bit over noise density in dB

% Extract clean signals.  A single shared receiver noise floor is added
% below; independent transmitter noise realizations must not be stacked.
[~, syms_pb1_clean] = qam_srrc_xmtr(Nmessages, Fs, Rs(1), fc(1), M(1), Rolloff(1), EbN0(1));
[~, syms_pb2_clean] = qam_srrc_xmtr(Nmessages, Fs, Rs(2), fc(2), M(2), Rolloff(2), EbN0(2));

%% 
% RX RF front end

% Sample size used to compute one point.
Ncapture = 2^16;
components = [syms_pb1_clean(1:Ncapture), syms_pb2_clean(1:Ncapture)];

% Realize both requested Eb/N0 values against one physical noise floor.
% Keep signal 1 at its generated level and scale signal 2 accordingly.
SPS        = Fs./Rs;
CNR_target = EbN0 + 10*log10(log2(M)) - 10*log10(SPS);
component_pwr = mean(abs(components).^2,1);
noise_pwr     = component_pwr(1)/10^(CNR_target(1)/10);
target_pwr    = noise_pwr*10.^(CNR_target/10);
components    = components.*sqrt(target_pwr./component_pwr);

unit_noise = (randn(Ncapture,1) + 1j*randn(Ncapture,1))/sqrt(2);
noise      = unit_noise*sqrt(noise_pwr/mean(abs(unit_noise).^2));
syms_rx    = sum(components,2) + noise;

% Simulate receiver AGC.  Its common scale factor preserves both CNRs.
norm_factor = modnorm(syms_rx,'peakpow',1);
agc         = syms_rx*norm_factor;

measured_CNR  = 10*log10(mean(abs(components).^2,1)/mean(abs(noise).^2));
measured_EbN0 = measured_CNR - 10*log10(log2(M)) + 10*log10(SPS);
assert(all(abs(measured_EbN0-EbN0) < 0.05), ...
    'A realized Eb/N0 differs from its request by at least 0.05 dB.');
fprintf('Measured Eb/N0: %.2f dB, %.2f dB\n',measured_EbN0);

%% 
% Receiver:  streaming SCA (fully vectorized)

% Valid symbol-rate range is (0, Fs/2].
a_step  = min(Rs);
a_array = (a_step:a_step:Fs/2)';

% The half-open 10 kHz grid includes both transmitted carrier frequencies
% exactly without duplicating the equivalent -Fs/2 and +Fs/2 Nyquist LOs.
fc_step  = 0.010e6;
fc_array = (-Fs/2:fc_step:Fs/2-fc_step)';

% Two-tap low-pass filter
hlpf = [0.5,0.5];

n = (0:Ncapture-1)';

% 1. Calculate frequency bins once
vbin = round(a_array/Fs*Ncapture) + 1;

% 2. Generate downconverting local oscillators.  The transmitter uses the
% positive-frequency convention exp(+j*2*pi*fc*n/Fs).
LO_matrix = exp(-1j*2*pi*n*(fc_array')/Fs);

% 3. Apply the local oscillators using implicit expansion
mixed_signal = agc(1:Ncapture) .* LO_matrix;

% 4. Channelize
channelized = filter(hlpf, 1, mixed_signal);

% 5. Symbol rate estimation
R = abs(channelized).^2;

% 6. Vectorized Goertzel algorithm
S = goertzel(R, vbin) / Ncapture;    

% Test statistic and constant threshold.
T = abs(S).^2; % test statistic
beta        = 1e-3; % user-selected threshold scale
P_y_hat     = sum(abs(agc).^2)/Ncapture;
gamma_CFD   = beta*P_y_hat^2;
threshold   = gamma_CFD*ones(size(T));

% Report the strongest carrier candidate at each transmitted symbol rate.
peak_T      = zeros(size(Rs));
peak_fc     = zeros(size(fc));
is_detected = false(size(Rs));
for idx = 1:numel(Rs)
    row = find(a_array == Rs(idx),1);
    [peak_T(idx),column] = max(T(row,:));
    peak_fc(idx) = fc_array(column);
    is_detected(idx) = peak_T(idx) > gamma_CFD;
    fprintf(['Signal %d: Rs = %.0f kBd, estimated fc = %.0f kHz, ' ...
        'T/gamma_CFD = %.2f, detected = %s\n'], idx, Rs(idx)/1e3, ...
        peak_fc(idx)/1e3, peak_T(idx)/gamma_CFD, ...
        string(is_detected(idx)));
end
assert(all(is_detected), 'At least one transmitted signal was not detected.');
assert(all(peak_fc == fc), ...
    'At least one detected carrier does not match its transmitted carrier.');

% Plot the statistic, threshold, and the decisions using shared thesis style.
[fig, colors] = thesis_figure();
statistic_plot = waterfall(fc_array/1e6,a_array/1e6,T);
statistic_plot.EdgeColor = colors.blue;
statistic_plot.FaceColor = 'none';
hold on
threshold_plot = waterfall(fc_array/1e6,a_array/1e6,threshold);
threshold_plot.EdgeColor = colors.orange;
threshold_plot.FaceColor = 'none';
for idx = 1:numel(Rs)
    if is_detected(idx)
        marker_color = colors.green;
    else
        marker_color = colors.orange;
    end
    scatter3(peak_fc(idx)/1e6,Rs(idx)/1e6,peak_T(idx),50, ...
        marker_color,'filled','MarkerEdgeColor',colors.gray, ...
        'HandleVisibility','off');
end
view(225,20)
title('Streaming SCA Detection of Two M-QAM-SRRC Signals')
xlabel('$f_c$ (MHz)')
ylabel('$R_s$ (MBd)')
zlabel('$T_y(v,k)=|\widehat{C}_y(\alpha_v,f_k)|^2$')
legend([statistic_plot,threshold_plot], ...
    {'$T_y(v,k)$','$\gamma_{\mathrm{CFD}}=\beta\widehat{P}_y^2$'}, ...
    'Location','northeast')
thesis_export(fig,'qam_srrc_rs');
