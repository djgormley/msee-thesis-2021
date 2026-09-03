%% Gaussian probability density used in the thesis example

clear;

mu = 5;
sigma = 1;
N = 500;
d = linspace(mu-5*sigma,mu+5*sigma,N);
p = exp(-0.5*((d-mu)/sigma).^2)/(sigma*sqrt(2*pi));

% Five standard deviations on either side contain essentially all mass.
assert(abs(trapz(d,p)-1) < 1e-5);

[fig, colors] = thesis_figure();
pdf_line = plot(d,p,'Color',colors.blue,'LineWidth',1.8, ...
    'DisplayName','$p(d)$');
hold on;
mean_line = xline(mu,'--','Color',colors.orange,'LineWidth',1.5, ...
    'DisplayName','$\mu=5$');
sigma_line = xline(mu-sigma,':','Color',colors.gray,'LineWidth',1.4, ...
    'DisplayName','$\mu\pm\sigma$');
xline(mu+sigma,':','Color',colors.gray,'LineWidth',1.4, ...
    'HandleVisibility','off');

xlabel('$d$');
ylabel('$p(d)$');
xlim([d(1),d(end)]);
ylim([0,1.08*max(p)]);
legend([pdf_line,mean_line,sigma_line],'Location','northwest');
thesis_export(fig,'gaussian_pdf');
