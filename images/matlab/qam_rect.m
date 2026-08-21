%% 
% Dylan J. Gormley (NASA GRC/LCI) - 2020

clear

% Initialize parameters
Nbits  = 400;
Rs     = 0.1;
Ts     = 1/Rs;
fc     = 0.05;
M      = 2;
Nlags  = 15;
Nfreqs = 128;
Fs     = 1.0;
T      = 1/Fs;
alpha  = (0:Rs:Fs/2)/Fs;
Na     = length(alpha);

% Create binary data sequence
d = randi([0 M-1],Nbits,1);

% Modulate Data
syms_bb = qammod(d,M);
norm_factor = modnorm(syms_bb,'peakpow',1);
syms_bb = syms_bb*norm_factor;

% Upsample and Rectangular Filter
SPS = Fs/Rs;
syms_rect = rectpulse(syms_bb, SPS);
norm_factor = modnorm(syms_rect,'peakpow',1);
syms_rect = syms_rect*norm_factor;

% Upconvert to passband
Nsyms = length(syms_rect);
n = (0:Nsyms-1)';
lo = exp(-1j*2*pi*fc/Fs*n);
syms_pb = syms_rect.*lo;
norm_factor = modnorm(syms_pb,'peakpow',1);
syms_pb = syms_pb*norm_factor;

% Time series
plot(0:199,imag(syms_pb(1:200)),'k')
xlabel('$t \: (\mu s)$','interpreter','latex')
ylabel('$x(t)$','interpreter','latex')
set(gca,'TickLabelInterpreter','latex')
grid on
print('../plots/2qam_time','-dpng')
%% 
% acf - autocorrelogram

[R,Rtau] = xcorr(syms_pb,Nlags,'biased');
Rtau = Rtau';

plot(Rtau,abs(R),'k')
xlabel('$\tau \: (\mu s)$','interpreter','latex')
ylabel('$R_{x}(\tau)$','interpreter','latex')
set(gca,'TickLabelInterpreter','latex')
grid on
print('../plots/autocorrelogram','-dpng')
%% 
% psd - periodogram

P = fftshift(fft(syms_pb,Nfreqs))/Nfreqs;
Pf = (-Nfreqs/2:Nfreqs/2-1)'*(Fs/Nfreqs);

plot(Pf,abs(P),'k');
xlabel('$f (MHz)$','interpreter','latex')
ylabel('$P_{x}(f)$','interpreter','latex')
set(gca,'TickLabelInterpreter','latex')
grid on
print('../plots/periodogram', '-dpng')
%% 
% psd - smoothed periodogram

[S, Sf] = pwelch(syms_pb,8,[],Nfreqs,Fs,"centered");

plot(Sf, abs(S),'k');
xlabel('$f \: (MHz)$','interpreter','latex')
ylabel('$S_{x}(f)$','interpreter','latex')
set(gca,'TickLabelInterpreter','latex')
grid on
print('../plots/psd','-dpng')
%%
% caf - cyclic autocorrelogram
Ra = zeros(Na,2*Nlags+1);
for k = 1:Na
    % Apply +/- half-alpha shifts to get symmetric cyclic autocorrelation (Optimized)
    kernel_A = exp(-1j * pi * alpha(k) / Fs * n);
    [Ra(k,:),Ratau] = xcorr(syms_pb .* kernel_A, syms_pb .* conj(kernel_A), Nlags, "biased");   
end
Ratau = Ratau';

waterfall(Ratau,alpha,abs(Ra));
colormap([0 0 0])
view(225,15)
xlim([-15 15])
xlabel('$\tau \: (\mu s)$','interpreter','latex')
ylabel('$\alpha \: (MHz)$','interpreter','latex')
zlabel('$R_{x}^{\alpha}(\tau)$','interpreter','latex')
set(gca,'TickLabelInterpreter','latex')
grid on
print('../plots/cyclic_autocorrelogram','-dpng')
%% 
% scf - smoothed cyclic periodogram

Sa = zeros(Na,Nfreqs);
Saf = (-Nfreqs/2:Nfreqs/2-1)'*(Fs/Nfreqs);

for k = 1:Na
    Sa(k,:) = fftshift(fft(Ra(k,:),Nfreqs));
end

waterfall(Saf,alpha,abs(Sa));

colormap([0 0 0])
view(225,15)
xlabel('$f \: (MHz)$','interpreter','latex')
ylabel('$\alpha \: (MHz)$','interpreter','latex')
zlabel('$S_{x}^{\alpha}(f)$','interpreter','latex')
set(gca,'TickLabelInterpreter','latex')
grid on
print('../plots/csd', '-dpng')