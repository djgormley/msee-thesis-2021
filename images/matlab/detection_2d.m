clear;

% Equal-prior binary detection with equal-variance Gaussian observations.
mu0 = 40;
mu1 = 60;
sigma = 10;
y_threshold = (mu0 + mu1) / 2;
gamma_lr = 1; % equal priors and equal decision costs

% An odd number of samples puts the analytical threshold exactly on the
% observation grid (x(threshold_idx) == y_threshold).
num_points = 501;
x = linspace(mu0 - 4*sigma, mu1 + 4*sigma, num_points);
threshold_idx = find(x == y_threshold, 1);

p_y_h0 = exp(-0.5*((x - mu0)/sigma).^2) / (sigma*sqrt(2*pi));
p_y_h1 = exp(-0.5*((x - mu1)/sigma).^2) / (sigma*sqrt(2*pi));

% Analytical operating probabilities for the rule H1 when y > y_threshold.
p_fa = 0.5 * erfc((y_threshold - mu0)/(sigma*sqrt(2)));
p_d  = 0.5 * erfc((y_threshold - mu1)/(sigma*sqrt(2)));
assert(abs(p_fa-0.158655253931457) < 1e-12);
assert(abs(p_d-0.841344746068543) < 1e-12);

[fig, colors] = thesis_figure();
ax = axes(fig);
hold(ax, 'on');

left = 1:threshold_idx;
right = threshold_idx:num_points;

% Fill the four mutually interpreted areas under the two conditional PDFs.
h_cr = fill(ax, [x(left), fliplr(x(left))], ...
    [p_y_h0(left), zeros(size(left))], colors.sky, ...
    'FaceAlpha', 0.28, 'EdgeColor', 'none');
h_fa = fill(ax, [x(right), fliplr(x(right))], ...
    [p_y_h0(right), zeros(size(right))], colors.red, ...
    'FaceAlpha', 0.28, 'EdgeColor', 'none');
h_m = fill(ax, [x(left), fliplr(x(left))], ...
    [p_y_h1(left), zeros(size(left))], colors.purple, ...
    'FaceAlpha', 0.24, 'EdgeColor', 'none');
h_d = fill(ax, [x(right), fliplr(x(right))], ...
    [p_y_h1(right), zeros(size(right))], colors.green, ...
    'FaceAlpha', 0.24, 'EdgeColor', 'none');

h_h0 = plot(ax, x, p_y_h0, 'Color', colors.blue, 'LineWidth', 2.0);
h_h1 = plot(ax, x, p_y_h1, 'Color', colors.orange, 'LineWidth', 2.0);
h_threshold = xline(ax, y_threshold, '--', '$y_{\mathrm{th}}$', ...
    'Color', colors.gray, 'LineWidth', 1.6, ...
    'LabelVerticalAlignment', 'middle', ...
    'LabelHorizontalAlignment', 'left', ...
    'Interpreter', 'latex');

xlabel(ax, 'Observation, $y$');
ylabel(ax, 'Conditional density, $p_{Y\mid H_i}(y)$');
title(ax, 'Binary hypothesis decision regions');
xlim(ax, [x(1), x(end)]);
ylim(ax, [0, 1.08*max([p_y_h0, p_y_h1])]);

legend(ax, [h_cr, h_fa, h_m, h_d, h_h0, h_h1, h_threshold], ...
    {'$P_{CR}$', '$P_{FA}$', '$P_M$', '$P_D$', ...
     '$p_{Y\mid H_0}$', '$p_{Y\mid H_1}$', '$y_{\mathrm{th}}$'}, ...
    'Location', 'northoutside', 'NumColumns', 4);

fprintf(['Observation threshold y_th = %.1f (grid sample %d) corresponds ' ...
    'to gamma_LR = %.1f; P_FA = %.6f; P_D = %.6f\n'], ...
    y_threshold, threshold_idx, gamma_lr, p_fa, p_d);
thesis_export(fig, 'error_probabilities');
