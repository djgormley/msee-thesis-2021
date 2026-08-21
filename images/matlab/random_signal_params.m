% first, initialize the random number generator to make the results in this example repeatable.
rng(0,'twister');

% create a vector of 1000 random values drawn from a normal distribution with a mean of mu and a standard deviation of sigma.
N     = 100;
mu    = 0.1;
sigma = 0.25;
y     = sigma.*randn(N,1) + mu;
%%
% plot random signal
plot(y,'k')
hold on

% plot mean
plot(ones(N,1)*mu, "*")
hold on

% plot std centered at mean
errorbar(ones(N,1)*mu, ones(N,1)*std(y), ' ','LineWidth',1/1e12)

% configure environment
ylim([-1,1])
xlabel('$t \: (\mu s)$','interpreter','latex')
ylabel('$P_{x} (t)$','interpreter','latex')
set(gca,'TickLabelInterpreter','latex')
legend('$x(t)$','$\mu_{x(t)}$','$2 \sigma_{x(t)}$','interpreter', 'latex')
grid on

print('../plots/X_mean_std', '-dpng')