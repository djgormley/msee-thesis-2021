function output_path = energy_spectral_density(output_directory)
%ENERGY_SPECTRAL_DENSITY Plot the ESD of a rectangular pulse.

arguments
    output_directory (1,1) string
end

sample_rate_mhz = 50;
num_frequencies = 4096;
pulse = [zeros(50,1);ones(50,1);zeros(50,1)];
sample_interval_us = 1/sample_rate_mhz;
spectrum = sample_interval_us*fftshift(fft(pulse,num_frequencies));
energy_density = abs(spectrum).^2;
frequency_mhz = (-num_frequencies/2:num_frequencies/2-1).' * ...
    (sample_rate_mhz/num_frequencies);

time_energy = sum(abs(pulse).^2)*sample_interval_us;
frequency_energy = sum(energy_density)*(sample_rate_mhz/num_frequencies);
assert(abs(time_energy-frequency_energy) < 100*eps(time_energy));

[fig, colors] = thesis.plot.new_figure();
ax = axes(fig);
plot(ax,frequency_mhz,energy_density,'Color',colors.blue, ...
    'LineWidth',1.8);
xlabel(ax,'$f\ (\mathrm{MHz})$');
ylabel(ax,'$\Psi_{\Pi}(f)$');
xlim(ax,[-5,5]);
output_path = thesis.plot.export_png(fig,output_directory,'esd');
end
