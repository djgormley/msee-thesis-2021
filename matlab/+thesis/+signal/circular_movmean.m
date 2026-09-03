function smoothed = circular_movmean(values, window_length, dimension)
%CIRCULAR_MOVMEAN Uniform moving mean along a periodic DFT dimension.

arguments
    values
    window_length (1,1) double {mustBeInteger,mustBePositive}
    dimension (1,1) double {mustBeInteger,mustBePositive}
end

assert(window_length <= size(values,dimension), ...
    'circular_movmean:WindowTooLong', ...
    'The smoothing window cannot exceed the selected dimension.');

% Match MATLAB's placement for an even moving window: four samples before
% and three after the current sample for a length-eight window.  Circular
% shifts keep the DFT's two Nyquist edges adjacent and maintain a uniform
% number of averaged bins everywhere.
backward_bins = floor(window_length/2);
forward_bins = window_length-1-backward_bins;
smoothed = zeros(size(values),'like',values);

for offset = -backward_bins:forward_bins
    smoothed = smoothed + circshift(values,-offset,dimension);
end

smoothed = smoothed/window_length;
end
