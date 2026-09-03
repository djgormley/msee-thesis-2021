function [statistic, coefficients] = streaming_sca_statistic( ...
    signal, sample_rate_hz, cycle_frequencies_hz, ...
    center_frequencies_hz, filter_taps, carrier_chunk_size)
%STREAMING_SCA_STATISTIC Evaluate selected SCA points in bounded memory.
%
% Carrier candidates are processed in chunks, so memory use scales with
% N-by-carrier_chunk_size instead of N-by-number_of_carriers.  The returned
% statistic is otherwise identical to processing every carrier at once.

arguments
    signal (:,1) double
    sample_rate_hz (1,1) double {mustBePositive}
    cycle_frequencies_hz (:,1) double {mustBePositive}
    center_frequencies_hz (:,1) double {mustBeFinite}
    filter_taps (1,:) double
    carrier_chunk_size (1,1) double {mustBeInteger,mustBePositive} = 8
end

num_samples = numel(signal);
goertzel_bins = round(cycle_frequencies_hz/sample_rate_hz*num_samples)+1;
assert(all(goertzel_bins >= 1 & goertzel_bins <= num_samples), ...
    'thesis:streaming_sca_statistic:CycleFrequencyOutOfRange', ...
    'Each cycle frequency must map to a valid Goertzel bin.');

sample_index = (0:num_samples-1).';
num_carriers = numel(center_frequencies_hz);
coefficients = complex(zeros(numel(cycle_frequencies_hz),num_carriers));

for first_carrier = 1:carrier_chunk_size:num_carriers
    carriers = first_carrier:min(first_carrier+carrier_chunk_size-1, ...
        num_carriers);
    local_oscillators = exp(-1j*2*pi/sample_rate_hz*sample_index* ...
        center_frequencies_hz(carriers).');
    channelized = filter(filter_taps,1,signal.*local_oscillators);
    instantaneous_power = abs(channelized).^2;
    coefficients(:,carriers) = goertzel(instantaneous_power, ...
        goertzel_bins)/num_samples;
end

statistic = abs(coefficients).^2;
end
