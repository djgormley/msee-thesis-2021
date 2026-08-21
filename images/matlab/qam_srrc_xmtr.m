function [syms_noisy, syms_pb] = qam_srrc_xmtr(Nmessages, Fs, Rs, fc, M, Rolloff, EbN0)

% generate integer messages
messages = randi([0 M-1],Nmessages,1);

% modulate messages
syms = qammod(messages,M);

% pulse shape filter
span      = 6;     % filter length - aka symbol span
SPS       = Fs/Rs; % integer upsample factor
hrrc      = rcosdesign(Rolloff,span,SPS)'; % filter taps
syms_srrc = upfirdn(syms,hrrc,SPS,1);      % upsample and filter syms
%% 
% TX RF Frontend

% upconvert to passband
% This project uses a negative-frequency upconversion convention. The
% receiver/channelizer therefore uses the opposite sign for downconversion.
n       = (0:length(syms_srrc)-1)';
lo      = exp(-1j*2*pi*fc/Fs*n); % local oscillator
syms_up = syms_srrc.*lo;         % upconvert syms to passband

% normalize such that the peak tx power is mag 1
norm_factor = modnorm(syms_up,'peakpow',1);
syms_pb     = syms_up*norm_factor;
%% 
% Noisy Channel

% noisy channel
EsN0       = EbN0 + 10*log10(log2(M)); % energy per symbol over noise density in dB
CNR        = EsN0 - 10*log10(Fs/Rs);   % carrier to noise density ratio in dB
syms_noisy = awgn(syms_pb, CNR);       % noise added to our passband signal