%% WSS Gaussian sample path with its theoretical parameters

clear;
rng(0,'twister');

N = 100;
mu = 0.1;
sigma = 0.25;
t = (0:N-1)';           % Sample interval is 1 us
x = sigma*randn(N,1)+mu;

[fig, colors] = thesis_figure();
hold on;
band = fill([t;flipud(t)], ...
    [(mu-sigma)*ones(N,1);(mu+sigma)*ones(N,1)], ...
    colors.sky,'FaceAlpha',0.18,'EdgeColor','none', ...
    'DisplayName','$\mu\pm\sigma$');
signal_line = plot(t,x,'Color',colors.blue,'LineWidth',1.25, ...
    'DisplayName','$x(t)$');
mean_line = yline(mu,'--','Color',colors.orange,'LineWidth',1.5, ...
    'DisplayName','$\mu=0.1$');

xlabel('$t\ (\mu\mathrm{s})$');
ylabel('$x(t)$');
xlim([t(1),t(end)]);
ylim([-1,1]);
legend([signal_line,mean_line,band],'Location','southwest');
thesis_export(fig,'X_mean_std');
