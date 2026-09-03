function [syms_noisy, syms_pb] = qam_srrc_xmtr(Nmessages, Fs, Rs, fc, M, Rolloff, EbN0)

%QAM_SRRC_XMTR Generate a positive-frequency, SRRC-shaped M-QAM signal.

% generate integer messages
messages = randi([0 M-1],Nmessages,1);

% modulate messages
syms = qammod(messages,M);

% pulse shape filter
span      = 6;     % filter length - aka symbol span
SPS       = Fs/Rs; % integer upsample factor
assert(abs(SPS-round(SPS)) < 10*eps(SPS), ...
    'qam_srrc_xmtr:NonintegerSPS', ...
    'Fs/Rs must be an integer for SRRC pulse shaping.');
SPS       = round(SPS);
hrrc      = rcosdesign(Rolloff,span,SPS)'; % filter taps
syms_srrc = upfirdn(syms,hrrc,SPS,1);      % upsample and filter syms
%% 
% TX RF Frontend

% upconvert to passband
n       = (0:length(syms_srrc)-1)';
lo      = exp(1j*2*pi*fc/Fs*n);  % positive-frequency local oscillator
syms_up = syms_srrc.*lo;         % upconvert syms to passband

% normalize such that the peak tx power is mag 1
norm_factor = modnorm(syms_up,'peakpow',1);
syms_pb     = syms_up*norm_factor;
%% 
% Noisy Channel

% Noisy channel.  Compute the noise from the measured waveform power;
% awgn(x,snr) without the measured-power option instead assumes 0 dBW.
EsN0       = EbN0 + 10*log10(log2(M)); % energy per symbol over noise density in dB
CNR        = EsN0 - 10*log10(SPS);     % sample SNR required for the target Eb/N0
signal_pwr = mean(abs(syms_pb).^2);
noise_pwr  = signal_pwr/10^(CNR/10);
noise      = sqrt(noise_pwr/2) * ...
    (randn(size(syms_pb)) + 1j*randn(size(syms_pb)));
syms_noisy = syms_pb + noise;
