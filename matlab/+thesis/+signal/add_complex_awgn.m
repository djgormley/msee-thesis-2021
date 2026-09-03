function [received_signal, noise] = add_complex_awgn(signal, snr_db, stream)
%ADD_COMPLEX_AWGN Add deterministic complex AWGN at a measured sample SNR.

arguments
    signal (:,1) double
    snr_db (1,1) double {mustBeFinite}
    stream (1,1) RandStream
end

signal_power = mean(abs(signal).^2);
assert(signal_power > 0, ...
    'thesis:add_complex_awgn:ZeroSignalPower', ...
    'The input signal must have nonzero mean power.');

unit_noise = (randn(stream,size(signal)) + ...
    1j*randn(stream,size(signal)))/sqrt(2);
unit_noise = unit_noise/sqrt(mean(abs(unit_noise).^2));
noise_power = signal_power/10^(snr_db/10);
noise = sqrt(noise_power)*unit_noise;
received_signal = signal + noise;
end
