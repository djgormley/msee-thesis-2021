%% Energy spectral density of a finite-duration rectangular pulse

clear;

Fs = 50;                % Sample rate (samples/us, numerically MHz)
N = 150;                % Number of time samples used in the thesis example
Nfft = 4096;            % Zero-padded grid for a smooth DTFT approximation
% Fifty samples at 50 samples/us represent the unit-width pulse Pi(t)
% over a three-microsecond observation record.
x = [zeros(50,1); ones(50,1); zeros(50,1)];

% The sampled continuous-time Fourier-transform approximation includes the
% sample interval. Its squared magnitude is the energy spectral density.
dt = 1/Fs;
X = dt*fftshift(fft(x,Nfft));
Psi = abs(X).^2;
f = (-Nfft/2:Nfft/2-1)'*(Fs/Nfft);

% Discrete Parseval check: integral |x(t)|^2 dt = integral Psi(f) df.
time_energy = sum(abs(x).^2)*dt;
frequency_energy = sum(Psi)*(Fs/Nfft);
assert(abs(time_energy-frequency_energy) < 100*eps(time_energy));

[fig, colors] = thesis_figure();
plot(f,Psi,'Color',colors.blue,'LineWidth',1.8);
xlabel('$f\ (\mathrm{MHz})$');
ylabel('$\Psi_{\Pi}(f)$');
% Show the main lobe and several sidelobes rather than the mostly empty
% full Nyquist interval of this oversampled pulse.
xlim([-5,5]);
thesis_export(fig,'esd');
