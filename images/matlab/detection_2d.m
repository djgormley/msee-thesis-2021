clear;

m1 = 40;
m2 = 60;

N = 500;
s = 10;
x = linspace(m1-4*s,m2+4*s,N);

% Gaussian PDFs for H0 and H1 with equal variance.
y1 = 1/(s*sqrt(2*pi))*exp(-(x-m1).^2/(2*s^2));
y2 = 1/(s*sqrt(2*pi))*exp(-(x-m2).^2/(2*s^2));

% For the equal-prior, equal-variance illustration, the likelihood-ratio
% threshold occurs midway between the means.
gamma = (m1+m2)/2;
[~, threshold_idx] = min(abs(x-gamma));

hold on
grid on

% Probability regions.
area(x(1:threshold_idx), y1(1:threshold_idx), 'FaceAlpha', 0.1, 'LineStyle', 'none') % Pcr
area(x(threshold_idx:end), y1(threshold_idx:end), 'FaceAlpha', 0.1, 'LineStyle', 'none') % Pfa
area(x(1:threshold_idx), y2(1:threshold_idx), 'FaceAlpha', 0.1, 'LineStyle', 'none') % Pm
area(x(threshold_idx:end), y2(threshold_idx:end), 'FaceAlpha', 0.1, 'LineStyle', 'none') % Pd

% PDFs and decision threshold.
plot(x,y1);
plot(x,y2);
plot([gamma gamma], [0 max([y1 y2])]);

legend('$P_{CR}$','$P_{FA}$','$P_{M}$','$P_{D}$', ...
    '$H_{0}$','$H_{1}$','$\gamma$', ...
    'interpreter', 'latex')

set(gca,'TickLabelInterpreter','latex')
print('../plots/error_probabilities', '-dpng')
