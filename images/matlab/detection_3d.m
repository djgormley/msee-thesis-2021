clear

% Initialize Parameters
Nbits  = 400;
Rs     = 0.1;
Ts     = 1/Rs;
Fs     = 1.0;
fc     = 0.05;
Nlags  = 15;
Nfreqs = 128;
alpha  = (0:Rs:Fs/2)/Fs;
Nas    = length(alpha);

Rolloff = 1.0;
span    = 6;
SPS     = Fs/Rs;
h       = rcosdesign(Rolloff,span,SPS)';

Nsyms = Nbits*SPS+length(h)-SPS;
n     = (0:Nsyms-1)';
lo    = exp(-1j*2*pi*fc/Fs*n);
%% 
% M-QAM

M = 2;

% generate mod syms
d = randi([0 M-1],Nbits,1);
syms_bb = qammod(d,M);
syms_srrc = upfirdn(syms_bb,h,SPS);
syms_pb = syms_srrc.*lo;

% calc scf
Sa = zeros(Nas,Nfreqs);
Saf = (-Nfreqs/2:Nfreqs/2-1)'*(Fs/Nfreqs);

for k = 1:Nas
    % Symmetric half-alpha shifts (Optimized using conj)
    kernel_A = exp(-1j * pi * alpha(k) / Fs * n);
    Ra = xcorr(syms_pb .* kernel_A, syms_pb .* conj(kernel_A), Nlags, 'normalized');    
    
    % Calculate complex spectrum (abs removed)
    Sa(k,:) = fftshift(fft(Ra, Nfreqs)) / length(Ra);
end

waterfall(Saf,alpha,abs(Sa).^2);
colormap([0 0 0])
view(225,15)
title('2-QAM-SRRC','interpreter','latex')
xlabel('$k$','interpreter','latex')
ylabel('$v$','interpreter','latex')
zlabel('$S_{x}^{v}[k]$','interpreter','latex')
set(gca,'TickLabelInterpreter','latex')

% plot threshold
hold on
beta        = 1; % user-selected threshold scale for illustration
P_hat       = sum(abs(syms_pb).^2)/length(syms_pb);
gamma       = beta*P_hat^2;
threshold   = ones(Nas,Nfreqs)*gamma+abs(Sa).^2/1000000000000; % create 3D threshold
p           = waterfall(Saf,alpha,threshold);
p.EdgeColor = 'r';
legend('$S_{x}^{v}[k]$','$\gamma$','interpreter', 'latex')

print('../plots/threshold_3d', '-dpng')