%% 
% Dylan J. Gormley (NASA GRC/LCI) - 2020

clear
%% 
% Transmitter:  M-QAM-SRRC

Nmessages = 2^16;   % sample size 
Fs        = 1.0e6;  % samp rate

Rs        = [0.10  0.20]*1e6; % sym rate
fc        = [0.05  0.10]*1e6; % carrier freq
M         = [4       16];     % 12^(randi(16)); % randomize M
Rolloff   = [1.00  0.35];     % aka excess bandwidth
EbN0      = [14.0   9.0];     % energy per bit over noise density in dB

% Extract clean signals to avoid stacking independent noise floors
[~, syms_pb1_clean] = qam_srrc_xmtr(Nmessages, Fs, Rs(1), fc(1), M(1), Rolloff(1), EbN0(1));
[~, syms_pb2_clean] = qam_srrc_xmtr(Nmessages, Fs, Rs(2), fc(2), M(2), Rolloff(2), EbN0(2));

%% 
% RX RF Frontend

% sample size used to compute one point
Ncapture = 2^16;
syms_combined_clean = syms_pb1_clean(1:Ncapture) + syms_pb2_clean(1:Ncapture);

% Apply unified noise floor based on Signal 1's target EbN0 as the reference
EsN0_ref = EbN0(1) + 10*log10(log2(M(1))); 
CNR_ref  = EsN0_ref - 10*log10(Fs/Rs(1));
syms_pb  = awgn(syms_combined_clean, CNR_ref);

% due to noise, signal is no longer at mag one
% simulate an agc to renormalize received signal
norm_factor = modnorm(syms_pb,'peakpow',1);

agc = syms_pb(1:Ncapture)*norm_factor;

%% 
% Receiver:  Koch-SCA (Fully Vectorized)

% valid alpha range is [0 Fs/2]
a_step  = min(Rs);
a_array = (a_step:a_step:Fs/2)';

% valid fc range is [-Fs/2 Fs/2]
fc_step  = 0.011e6;
fc_array = (-Fs/2:fc_step:Fs/2)';

% two tap low-pass filter
hlpf = [0.5,0.5];

n = (0:Ncapture-1)';
rx_mixer_sign = +1; % transmitter uses exp(-j2*pi*fc*n/Fs)

% 1. Calculate frequency bins once
vbin = round(a_array/Fs*Ncapture) + 1;

% 2. Generate a matrix of Local Oscillators (LO)
LO_matrix = exp(rx_mixer_sign * 1j * 2 * pi * n * (fc_array') / Fs);

% 3. Apply the Local Oscillators using implicit expansion
mixed_signal = agc(1:Ncapture) .* LO_matrix;

% 4. Channelize
channelized = filter(hlpf, 1, mixed_signal);

% 5. Symbol rate estimation
R = abs(channelized).^2;

% 6. Vectorized Goertzel algorithm
S = goertzel(R, vbin) / Ncapture;    

% plot T
T = abs(S).^2; % test statistic
waterfall(fc_array/1e6,a_array/1e6,T)
colormap([0 0 0])
view(225,15)
title('2-QAM-SRRC','interpreter','latex')
xlabel('$k$','interpreter','latex')
ylabel('$v$','interpreter','latex')
zlabel('$S_{x}^{v}[k]$','interpreter','latex')
set(gca,'TickLabelInterpreter','latex')

% plot threshold
hold on
beta        = 1e-3; % user-selected threshold scale
P_hat       = sum(abs(agc).^2)/Ncapture;
gamma       = beta*P_hat^2;
threshold   = ones(length(a_array),length(fc_array))*gamma+T/Fs; % create 3D threshold
p           = waterfall(fc_array/1e6,a_array/1e6,threshold);
p.EdgeColor = 'r';
legend('$S_{x}^{R_{s}}(f_{c})$','$\gamma$','interpreter', 'latex')

print('../plots/qam_srrc_rs', '-dpng')