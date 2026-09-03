function [scf, raw_scf] = caf_to_scf( ...
    caf, sample_rate, num_frequencies, smoothing_length)
%CAF_TO_SCF Transform a contiguous symmetric CAF into a smoothed SCF.
%
% The CAF columns must be ordered from negative to positive lag.  Before
% zero-padding, lag zero and the positive lags are placed at the beginning
% of the circular record and the negative lags at its end.  This preserves
% phase when the zero-padded DFT is frequency-smoothed.

arguments
    caf (:,:) double
    sample_rate (1,1) double {mustBePositive}
    num_frequencies (1,1) double {mustBeInteger,mustBePositive}
    smoothing_length (1,1) double {mustBeInteger,mustBePositive}
end

num_lag_samples = size(caf,2);
assert(mod(num_lag_samples,2) == 1, ...
    'thesis:caf_to_scf:EvenLagCount', ...
    'The CAF must contain an odd number of symmetric lag samples.');
max_lag = (num_lag_samples-1)/2;
assert(num_frequencies >= num_lag_samples, ...
    'thesis:caf_to_scf:InsufficientFrequencyBins', ...
    'The frequency grid cannot be shorter than the CAF lag record.');

padded_caf = complex(zeros(size(caf,1),num_frequencies));
padded_caf(:,1:max_lag+1) = caf(:,max_lag+1:end);
padded_caf(:,end-max_lag+1:end) = caf(:,1:max_lag);
raw_scf = fftshift(fft(padded_caf,[],2),2)/sample_rate;
scf = thesis.signal.circular_movmean(raw_scf,smoothing_length,2);
end
