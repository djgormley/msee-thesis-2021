clear;

m = 50;
N = 500;
s = 10;
x = linspace(m-5*s,m+5*s,N);
%%
% pdf 1
y = 1/(s*sqrt(2*pi))*exp(-(x-m).^2/(2*s^2));
%y = y/max(y);

plot(x/10,y,'k')
hold on
grid on;

% threshold
g = zeros(1,length(x));
g(length(x)/2) = max(y);
%g = g/max(g);
plot(x/10,g,'k')
hold on

ax = [0.3 0.5];
ay = [0.3 0.25];
annotation('textarrow',ax,ay,'String','$\mu_{p} \:$','interpreter','latex')
hold on

ax = [0.55 0.59];
ay = [0.6 0.6];
annotation('textarrow',ax,ay,'String','$\sigma_{p} \:$','interpreter','latex')
hold on

ax = [0.48 0.45];
ay = [0.6 0.6];
annotation('textarrow',ax,ay,'String','$\sigma_{p} \:$','interpreter','latex')
hold on

set(gca,'TickLabelInterpreter','latex')
%%
print('../plots/gaussian_pdf', '-dpng')