function [caf, lags] = symmetric_caf( ...
    signal, cycle_frequencies, sample_rate, max_lag)
%SYMMETRIC_CAF Estimate the symmetric cyclic autocorrelation function.

arguments
    signal (:,1) double
    cycle_frequencies (:,1) double {mustBeNonnegative}
    sample_rate (1,1) double {mustBePositive}
    max_lag (1,1) double {mustBeInteger,mustBeNonnegative}
end

sample_index = (0:numel(signal)-1).';
lags = (-max_lag:max_lag).';
caf = complex(zeros(numel(cycle_frequencies),numel(lags)));

for cycle_index = 1:numel(cycle_frequencies)
    half_shift = exp(-1j*pi*cycle_frequencies(cycle_index)/ ...
        sample_rate*sample_index);
    caf(cycle_index,:) = xcorr(signal.*half_shift, ...
        signal.*conj(half_shift), max_lag, 'biased').';
end
end
