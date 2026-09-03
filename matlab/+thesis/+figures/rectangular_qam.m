function output_paths = rectangular_qam(output_directory,stream)
%RECTANGULAR_QAM Generate related 2-QAM time and spectral figures.
%
% All six figures derive from one waveform realization so that time,
% autocorrelation, periodogram, ACF, and SCF views remain mutually
% consistent without repeating the simulation.

arguments
    output_directory (1,1) string
    stream (1,1) RandStream
end

num_symbols = 400;
symbol_rate_mbd = 0.1;
center_frequency_mhz = 0.05;
sample_rate_mhz = 1;
modulation_order = 2;
max_lag = 15;
num_frequencies = 128;
smoothing_length = 8;
samples_per_symbol = sample_rate_mhz/symbol_rate_mbd;
assert(abs(samples_per_symbol-round(samples_per_symbol)) < ...
    eps(sample_rate_mhz));
samples_per_symbol = round(samples_per_symbol);

cycle_frequencies_mhz = (0:symbol_rate_mbd:sample_rate_mhz/2).';
messages = randi(stream,[0,modulation_order-1],num_symbols,1);
baseband_symbols = qammod(messages,modulation_order, ...
    'UnitAveragePower',true);
rectangular_signal = rectpulse(baseband_symbols,samples_per_symbol);
sample_index = (0:numel(rectangular_signal)-1).';
time_us = sample_index/sample_rate_mhz;
passband_signal = rectangular_signal .* exp(1j*2*pi* ...
    center_frequency_mhz/sample_rate_mhz*sample_index);

output_paths = strings(1,6);

[fig, colors] = thesis.plot.new_figure();
ax = axes(fig);
plot(ax,time_us(1:200),real(passband_signal(1:200)), ...
    'Color',colors.blue,'LineWidth',1.25);
xlabel(ax,'$t\ (\mu\mathrm{s})$');
ylabel(ax,'$\mathrm{Re}\{x(t)\}$');
xlim(ax,[time_us(1),time_us(200)]);
ylim(ax,[-1.15,1.15]);
output_paths(1) = thesis.plot.export_png(fig,output_directory,'2qam_time');

[autocorrelation,lags] = xcorr(passband_signal,max_lag,'biased');
lag_us = lags/sample_rate_mhz;
[fig, colors] = thesis.plot.new_figure();
ax = axes(fig);
plot(ax,lag_us,abs(autocorrelation),'Color',colors.blue,'LineWidth',1.8);
xlabel(ax,'$\tau\ (\mu\mathrm{s})$');
ylabel(ax,'$|\widehat{R}_{x}(\tau)|$');
xlim(ax,[lag_us(1),lag_us(end)]);
output_paths(2) = thesis.plot.export_png(fig,output_directory, ...
    'autocorrelogram');

signal_segment = passband_signal(1:num_frequencies);
spectrum = fftshift(fft(signal_segment,num_frequencies));
periodogram_estimate = abs(spectrum).^2/(sample_rate_mhz*num_frequencies);
frequency_mhz = (-num_frequencies/2:num_frequencies/2-1).' * ...
    (sample_rate_mhz/num_frequencies);
assert(abs(sum(periodogram_estimate)*(sample_rate_mhz/num_frequencies) - ...
    mean(abs(signal_segment).^2)) < 1e-12);

[fig, colors] = thesis.plot.new_figure();
ax = axes(fig);
plot(ax,frequency_mhz,periodogram_estimate,'Color',colors.blue, ...
    'LineWidth',1.5);
xlabel(ax,'$f\ (\mathrm{MHz})$');
ylabel(ax,'$\widehat{P}_{x}(f)$');
xlim(ax,[frequency_mhz(1),frequency_mhz(end)]);
output_paths(3) = thesis.plot.export_png(fig,output_directory,'periodogram');

power_spectral_density = thesis.signal.circular_movmean( ...
    periodogram_estimate,smoothing_length,1);
[fig, colors] = thesis.plot.new_figure();
ax = axes(fig);
plot(ax,frequency_mhz,power_spectral_density,'Color',colors.blue, ...
    'LineWidth',1.8);
xlabel(ax,'$f\ (\mathrm{MHz})$');
ylabel(ax,'$\widehat{S}_{x}(f)$');
xlim(ax,[frequency_mhz(1),frequency_mhz(end)]);
output_paths(4) = thesis.plot.export_png(fig,output_directory,'psd');

[cyclic_autocorrelation,lags] = thesis.signal.symmetric_caf( ...
    passband_signal,cycle_frequencies_mhz,sample_rate_mhz,max_lag);
lag_us = lags/sample_rate_mhz;
[fig, colors] = thesis.plot.new_figure();
ax = axes(fig);
surface_handle = waterfall(ax,lag_us,cycle_frequencies_mhz, ...
    abs(cyclic_autocorrelation));
set(surface_handle,'EdgeColor',colors.blue,'EdgeAlpha',0.82, ...
    'FaceColor',colors.sky,'FaceAlpha',0.14,'LineWidth',0.9);
view(ax,225,20);
xlabel(ax,'$\tau\ (\mu\mathrm{s})$');
ylabel(ax,'$\alpha\ (\mathrm{MHz})$');
zlabel(ax,'$|\widehat{R}_{x}^{\alpha}(\tau)|$');
xlim(ax,[lag_us(1),lag_us(end)]);
output_paths(5) = thesis.plot.export_png(fig,output_directory, ...
    'cyclic_autocorrelogram');

spectral_correlation = thesis.signal.caf_to_scf( ...
    cyclic_autocorrelation,sample_rate_mhz,num_frequencies,smoothing_length);
[~,symbol_rate_index] = min(abs(cycle_frequencies_mhz-symbol_rate_mbd));
[~,carrier_index] = max(abs(spectral_correlation(symbol_rate_index,:)));
assert(abs(frequency_mhz(carrier_index)-center_frequency_mhz) <= ...
    sample_rate_mhz/num_frequencies);

[fig, colors] = thesis.plot.new_figure();
ax = axes(fig);
surface_handle = waterfall(ax,frequency_mhz,cycle_frequencies_mhz, ...
    abs(spectral_correlation));
set(surface_handle,'EdgeColor',colors.blue,'EdgeAlpha',0.82, ...
    'FaceColor',colors.sky,'FaceAlpha',0.14,'LineWidth',0.9);
view(ax,225,20);
xlabel(ax,'$f\ (\mathrm{MHz})$');
ylabel(ax,'$\alpha\ (\mathrm{MHz})$');
zlabel(ax,'$|\widehat{S}_{x}^{\alpha}(f)|$');
xlim(ax,[frequency_mhz(1),frequency_mhz(end)]);
output_paths(6) = thesis.plot.export_png(fig,output_directory,'scf');
end
