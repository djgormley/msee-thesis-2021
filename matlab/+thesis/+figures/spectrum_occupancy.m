function output_path = spectrum_occupancy(output_directory)
%SPECTRUM_OCCUPANCY Plot a conceptual time-frequency occupancy map.

arguments
    output_directory (1,1) string
end

time_s = 0:0.5:50;
frequency_ghz = 2.40:0.001:2.50;
power_map = zeros(numel(frequency_ghz),numel(time_s));
power_map(frequency_ghz >= 2.404 & frequency_ghz <= 2.414, ...
    time_s >= 1 & time_s <= 35) = 0.50;
power_map(frequency_ghz >= 2.426 & frequency_ghz <= 2.436, ...
    (time_s >= 3 & time_s <= 6) | (time_s >= 30 & time_s <= 45)) = 0.75;
power_map(frequency_ghz >= 2.446 & frequency_ghz <= 2.456,:) = 0.60;
power_map(frequency_ghz >= 2.462 & frequency_ghz <= 2.472, ...
    (time_s >= 2 & time_s <= 20) | (time_s >= 44 & time_s <= 50)) = 0.40;
power_map(frequency_ghz >= 2.484 & frequency_ghz <= 2.494, ...
    time_s >= 14) = 0.90;

[fig, colors] = thesis.plot.new_figure();
ax = axes(fig);
imagesc(ax,time_s,frequency_ghz,power_map);
axis(ax,'xy');
num_colors = 256;
color_map = [linspace(1,colors.blue(1),num_colors).', ...
    linspace(1,colors.blue(2),num_colors).', ...
    linspace(1,colors.blue(3),num_colors).'];
colormap(ax,color_map);
clim(ax,[0,1]);

xlabel(ax,'Time, $t$ (s)');
ylabel(ax,'Frequency, $f$ (GHz)');
title(ax,'Primary-user occupancy and spectral holes');
xlim(ax,[time_s(1),time_s(end)]);
ylim(ax,[frequency_ghz(1),frequency_ghz(end)]);
xticks(ax,0:10:50);
yticks(ax,2.40:0.02:2.50);
color_bar = colorbar(ax);
color_bar.Label.String = 'Normalized power spectral density';
color_bar.Label.Interpreter = 'latex';
color_bar.TickLabelInterpreter = 'latex';
output_path = thesis.plot.export_png(fig,output_directory,'spectrum_sensing');
end
