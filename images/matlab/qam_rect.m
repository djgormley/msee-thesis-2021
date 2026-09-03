%% Spectral and cyclostationary estimates for rectangular-pulse 2-QAM

clear;
rng(7,'twister');

Nsymbols = 400;
Rs = 0.1;               % Symbol rate (MBd)
fc = 0.05;              % Positive center frequency (MHz)
Fs = 1;                 % Sample rate (samples/us, numerically MHz)
M = 2;
Nlags = 15;
Nfreqs = 128;
smoothing_length = 8;   % Rectangular frequency-smoothing window (bins)
SPS = Fs/Rs;
assert(abs(SPS-round(SPS)) < eps(Fs));
SPS = round(SPS);

alpha = 0:Rs:Fs/2;      % Cycle frequencies in MHz
Na = numel(alpha);

% Unit-average-power symbols and a rectangular pulse shape.
d = randi([0 M-1],Nsymbols,1);
syms_bb = qammod(d,M,'UnitAveragePower',true);
syms_rect = rectpulse(syms_bb,SPS);

% A positive complex exponential places the analytic signal at +fc.
n = (0:numel(syms_rect)-1)';
time_us = n/Fs;
syms_pb = syms_rect.*exp(1j*2*pi*(fc/Fs)*n);

%% Time series
[fig, colors] = thesis_figure();
plot(time_us(1:200),real(syms_pb(1:200)), ...
    'Color',colors.blue,'LineWidth',1.25);
xlabel('$t\ (\mu\mathrm{s})$');
ylabel('$\mathrm{Re}\{x(t)\}$');
xlim([time_us(1),time_us(200)]);
ylim([-1.15,1.15]);
thesis_export(fig,'2qam_time');

%% Biased autocorrelation estimate
[R,lags] = xcorr(syms_pb,Nlags,'biased');
tau_us = lags/Fs;

[fig, colors] = thesis_figure();
plot(tau_us,abs(R),'Color',colors.blue,'LineWidth',1.8);
xlabel('$\tau\ (\mu\mathrm{s})$');
ylabel('$|\widehat{R}_{x}(\tau)|$');
xlim([tau_us(1),tau_us(end)]);
thesis_export(fig,'autocorrelogram');

%% Correctly scaled squared-magnitude periodogram
x_segment = syms_pb(1:Nfreqs);
X = fftshift(fft(x_segment,Nfreqs));
P = abs(X).^2/(Fs*Nfreqs);
f = (-Nfreqs/2:Nfreqs/2-1)'*(Fs/Nfreqs);

% The integral of the periodogram equals the segment's average power.
assert(abs(sum(P)*(Fs/Nfreqs)-mean(abs(x_segment).^2)) < 1e-12);

[fig, colors] = thesis_figure();
plot(f,P,'Color',colors.blue,'LineWidth',1.5);
xlabel('$f\ (\mathrm{MHz})$');
ylabel('$\widehat{P}_{x}(f)$');
xlim([f(1),f(end)]);
thesis_export(fig,'periodogram');

%% Frequency-smoothed periodogram
% Smooth eight adjacent frequency bins with a unit-area rectangular window,
% as described in the thesis, rather than applying an eight-sample Welch
% time-domain window.
S = circular_movmean(P,smoothing_length,1);

[fig, colors] = thesis_figure();
plot(f,S,'Color',colors.blue,'LineWidth',1.8);
xlabel('$f\ (\mathrm{MHz})$');
ylabel('$\widehat{S}_{x}(f)$');
xlim([f(1),f(end)]);
thesis_export(fig,'psd');

%% Symmetric cyclic autocorrelation estimate
Ra = zeros(Na,2*Nlags+1);
for k = 1:Na
    % Multiplying by opposite half-cycle-frequency shifts implements the
    % symmetric CAF: x(t+tau/2)x*(t-tau/2)exp(-j2*pi*alpha*t).
    half_shift = exp(-1j*pi*(alpha(k)/Fs)*n);
    Ra(k,:) = xcorr(syms_pb.*half_shift, ...
        syms_pb.*conj(half_shift),Nlags,'biased').';
end

[fig, colors] = thesis_figure();
surface_handle = waterfall(tau_us,alpha,abs(Ra));
set(surface_handle,'EdgeColor',colors.blue,'FaceColor','none','LineWidth',0.9);
view(225,20);
xlabel('$\tau\ (\mu\mathrm{s})$');
ylabel('$\alpha\ (\mathrm{MHz})$');
zlabel('$|\widehat{R}_{x}^{\alpha}(\tau)|$');
xlim([tau_us(1),tau_us(end)]);
thesis_export(fig,'cyclic_autocorrelogram');

%% Frequency-smoothed spectral correlation function estimate
% Embed the contiguous -Nlags:Nlags sequence in its proper circular-lag
% positions before zero-padding.  This keeps lag zero at DFT index zero,
% positive lags at the beginning, and negative lags at the end.  Merely
% applying ifftshift before a longer FFT would strand the negative lags in
% the middle of the padded record; leaving the sequence contiguous would
% introduce a linear phase that corrupts the subsequent complex smoother.
Ra_padded = complex(zeros(Na,Nfreqs));
Ra_padded(:,1:Nlags+1) = Ra(:,Nlags+1:end);
Ra_padded(:,end-Nlags+1:end) = Ra(:,1:Nlags);
SCF_raw = fftshift(fft(Ra_padded,[],2),2)/Fs;
SCF = circular_movmean(SCF_raw,smoothing_length,2);

% The nontrivial alpha=Rs slice should identify the injected carrier to
% within one DFT bin.
[~,symbol_rate_index] = min(abs(alpha-Rs));
[~,carrier_index] = max(abs(SCF(symbol_rate_index,:)));
assert(abs(f(carrier_index)-fc) <= Fs/Nfreqs);

[fig, colors] = thesis_figure();
surface_handle = waterfall(f,alpha,abs(SCF));
set(surface_handle,'EdgeColor',colors.blue,'FaceColor','none','LineWidth',0.9);
view(225,20);
xlabel('$f\ (\mathrm{MHz})$');
ylabel('$\alpha\ (\mathrm{MHz})$');
zlabel('$|\widehat{S}_{x}^{\alpha}(f)|$');
xlim([f(1),f(end)]);
thesis_export(fig,'scf');
