function output_path = gaussian_pdf(output_directory)
%GAUSSIAN_PDF Plot the Gaussian density used in the thesis example.

arguments
    output_directory (1,1) string
end

mean_value = 5;
standard_deviation = 1;
num_points = 500;
observation = linspace(mean_value-5*standard_deviation, ...
    mean_value+5*standard_deviation,num_points);
probability_density = exp(-0.5*((observation-mean_value)/ ...
    standard_deviation).^2)/(standard_deviation*sqrt(2*pi));

assert(abs(trapz(observation,probability_density)-1) < 1e-5);

[fig, colors] = thesis.plot.new_figure();
ax = axes(fig);
pdf_line = plot(ax,observation,probability_density, ...
    'Color',colors.blue,'LineWidth',1.8,'DisplayName','$p(d)$');
hold(ax,'on');
mean_line = xline(ax,mean_value,'--','Color',colors.orange, ...
    'LineWidth',1.5,'DisplayName','$\mu=5$');
sigma_line = xline(ax,mean_value-standard_deviation,':', ...
    'Color',colors.gray,'LineWidth',1.4, ...
    'DisplayName','$\mu\pm\sigma$');
xline(ax,mean_value+standard_deviation,':','Color',colors.gray, ...
    'LineWidth',1.4,'HandleVisibility','off');

xlabel(ax,'$d$');
ylabel(ax,'$p(d)$');
xlim(ax,[observation(1),observation(end)]);
ylim(ax,[0,1.08*max(probability_density)]);
legend(ax,[pdf_line,mean_line,sigma_line],'Location','northwest');
output_path = thesis.plot.export_png(fig,output_directory,'gaussian_pdf');
end
