%% 
% Generate Input Signal x[n]

x = [zeros(50+1,1); ones(50,1); zeros(50,1)]/2;
%% 
% Generate X[k]

N = length(x);
X = fftshift(fft(x));
%% 
% Plot X(f)

f  = (-N/2:N/2-1)';
plot(f/N,abs(X)/N,'k')
xlabel('$f \: (MHz)$','interpreter','latex')
ylabel('$\bar{S}_{\Pi}(f)$','interpreter','latex')
set(gca,'TickLabelInterpreter','latex')
grid on
print('../plots/esd', '-dpng')