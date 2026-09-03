function output_path = random_signal_parameters(output_directory,stream)
%RANDOM_SIGNAL_PARAMETERS Plot a WSS Gaussian path and its parameters.

arguments
    output_directory (1,1) string
    stream (1,1) RandStream
end

num_samples = 100;
mean_value = 0.1;
standard_deviation = 0.25;
time_us = (0:num_samples-1).';
signal = standard_deviation*randn(stream,num_samples,1)+mean_value;

[fig, colors] = thesis.plot.new_figure();
ax = axes(fig);
hold(ax,'on');
band = fill(ax,[time_us;flipud(time_us)], ...
    [(mean_value-standard_deviation)*ones(num_samples,1); ...
    (mean_value+standard_deviation)*ones(num_samples,1)], ...
    colors.sky,'FaceAlpha',0.18,'EdgeColor','none', ...
    'DisplayName','$\mu\pm\sigma$');
signal_line = plot(ax,time_us,signal,'Color',colors.blue, ...
    'LineWidth',1.25,'DisplayName','$x(t)$');
mean_line = yline(ax,mean_value,'--','Color',colors.orange, ...
    'LineWidth',1.5,'DisplayName','$\mu=0.1$');

xlabel(ax,'$t\ (\mu\mathrm{s})$');
ylabel(ax,'$x(t)$');
xlim(ax,[time_us(1),time_us(end)]);
ylim(ax,[-1,1]);
legend(ax,[signal_line,mean_line,band],'Location','southwest');
output_path = thesis.plot.export_png(fig,output_directory,'X_mean_std');
end
