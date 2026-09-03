clear;
rng(2021, 'twister');

% Reproducible BPSK/SRRC waveform and observation parameters.
num_symbols = 16384;
M = 2;
Rs = 100e3;
Fs = 1e6;
fc = 50e3;
samples_per_symbol = Fs / Rs;
rolloff = 1.0;
span = 6;
EbN0_dB = 14;

assert(samples_per_symbol == round(samples_per_symbol), ...
    'Fs/Rs must be an integer for SRRC pulse shaping.');

h = rcosdesign(rolloff, span, samples_per_symbol, 'sqrt').';
data = randi([0, M - 1], num_symbols, 1);
symbols = qammod(data, M, 'UnitAveragePower', true);
baseband = upfirdn(symbols, h, samples_per_symbol);
n = (0:numel(baseband) - 1).';

% A positive complex exponential places the waveform at +fc.
clean_signal = baseband .* exp(1j*2*pi*fc/Fs*n);
clean_signal = clean_signal / sqrt(mean(abs(clean_signal).^2));

% Convert Eb/N0 to sample SNR and measure the actual waveform power when
% adding noise. This avoids AWGN's two-argument 0-dBW power assumption.
sample_SNR_dB = EbN0_dB + 10*log10(log2(M)) ...
    - 10*log10(samples_per_symbol);
received_signal = awgn(clean_signal, sample_SNR_dB, 'measured');

% Evaluate candidate cycle frequencies in physical units (Hz).
alpha = 0:Rs:Fs/2;
num_alpha = numel(alpha);
num_lags = 50;
num_freqs = 200; % 5-kHz bins place fc exactly on the frequency grid.
frequency = (-num_freqs/2:num_freqs/2 - 1) * (Fs/num_freqs);
S_y = complex(zeros(num_alpha, num_freqs));

for idx = 1:num_alpha
    % Symmetric half-alpha shifts produce an estimate of R_y^alpha(tau).
    half_shift = exp(-1j*pi*alpha(idx)/Fs*n);
    cyclic_autocorrelation = xcorr( ...
        received_signal .* half_shift, ...
        received_signal .* conj(half_shift), ...
        num_lags, 'biased');
    S_y(idx, :) = fftshift(fft(cyclic_autocorrelation, num_freqs));
end

% The statistic and threshold now both have units of power squared.
T_y = abs(S_y).^2;
beta = 1e-2;
P_y_hat = mean(abs(received_signal).^2);
gamma = beta * P_y_hat^2;

% alpha = 0 is the ordinary PSD and is not a symbol-rate detection.
slice_peaks = max(T_y, [], 2);
detected_rows = find((alpha(:) > 0) & (slice_peaks > gamma));
[~, peak_columns] = max(T_y(detected_rows, :), [], 2);
detected_alpha = alpha(detected_rows);
detected_frequency = frequency(peak_columns);
detected_peaks = slice_peaks(detected_rows);

[fig, colors] = thesis_figure();
ax = axes(fig);
hold(ax, 'on');

display_rows = alpha > 0;
mesh_handle = mesh(ax, frequency/1e3, alpha(display_rows)/1e3, ...
    T_y(display_rows, :), ...
    'FaceColor', 'none', 'EdgeColor', colors.blue, ...
    'EdgeAlpha', 0.70, 'LineWidth', 0.7);
threshold_handle = surf(ax, frequency/1e3, alpha(display_rows)/1e3, ...
    gamma*ones(nnz(display_rows), num_freqs), ...
    'FaceColor', colors.orange, 'FaceAlpha', 0.30, ...
    'EdgeColor', colors.orange, 'EdgeAlpha', 0.15);
peak_handle = scatter3(ax, detected_frequency/1e3, detected_alpha/1e3, ...
    detected_peaks, 55, colors.green, 'filled', ...
    'MarkerEdgeColor', 'white', 'LineWidth', 0.8);

view(ax, 225, 20);
xlabel(ax, 'Spectral frequency, $f$ (kHz)');
ylabel(ax, 'Cycle frequency, $\alpha$ (kHz)');
zlabel(ax, '$T_y^{\alpha}(f)=|S_y^{\alpha}(f)|^2$');
title(ax, 'Received BPSK cyclic-spectrum detection');
xlim(ax, [-Fs, Fs]/(2e3));
ylim(ax, [Rs, Fs/2]/1e3);
set(ax, 'ZScale', 'log');
zlim(ax, [gamma/10, 1.2*max(T_y(display_rows, :), [], 'all')]);
legend(ax, [mesh_handle, threshold_handle, peak_handle], ...
    {'$T_y^{\alpha}(f)$', '$\gamma=\beta\widehat{P}_y^2$', ...
     'Detected $(\widehat{R}_s,\widehat{f}_c)$'}, ...
    'Location', 'northeast');

noise = received_signal - clean_signal;
measured_sample_SNR_dB = 10*log10( ...
    mean(abs(clean_signal).^2) / mean(abs(noise).^2));
assert(abs(measured_sample_SNR_dB-sample_SNR_dB) < 0.1, ...
    'The realized sample SNR differs from its request by at least 0.1 dB.');
fprintf('Requested sample SNR = %.3f dB; measured = %.3f dB\n', ...
    sample_SNR_dB, measured_sample_SNR_dB);
fprintf('beta = %.3g; gamma = %.6g\n', beta, gamma);
for idx = 1:numel(detected_rows)
    fprintf('Detected alpha = %.1f kHz at f = %.1f kHz (peak/gamma = %.2f)\n', ...
        detected_alpha(idx)/1e3, detected_frequency(idx)/1e3, ...
        slice_peaks(detected_rows(idx))/gamma);
end
non_target_rows = (alpha > 0) & (alpha ~= Rs);
fprintf('Largest non-target peak/gamma = %.3f\n', ...
    max(slice_peaks(non_target_rows))/gamma);

assert(any(detected_alpha == Rs), ...
    'The known symbol-rate slice was not detected.');
assert(isscalar(detected_alpha), ...
    'At least one non-symbol-rate slice exceeded the threshold.');
known_row = find(alpha == Rs, 1);
[~, known_peak_column] = max(T_y(known_row, :));
assert(abs(frequency(known_peak_column) - fc) <= Fs/num_freqs, ...
    'The detected carrier peak is farther than one DFT bin from fc.');

thesis_export(fig, 'threshold_3d');
