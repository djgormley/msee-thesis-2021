function [passband_signal, symbols] = qam_srrc_waveform( ...
    num_symbols, sample_rate_hz, symbol_rate_hz, center_frequency_hz, ...
    modulation_order, rolloff, stream, options)
%QAM_SRRC_WAVEFORM Generate a clean, positive-frequency M-QAM-SRRC waveform.
%
% Noise is deliberately not added here.  Keeping waveform generation and
% the channel model separate lets an experiment define one physical noise
% floor for several components and makes random-number ownership explicit.

arguments
    num_symbols (1,1) double {mustBeInteger,mustBePositive}
    sample_rate_hz (1,1) double {mustBePositive}
    symbol_rate_hz (1,1) double {mustBePositive}
    center_frequency_hz (1,1) double {mustBeFinite}
    modulation_order (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(modulation_order,2)}
    rolloff (1,1) double {mustBeGreaterThanOrEqual(rolloff,0),mustBeLessThanOrEqual(rolloff,1)}
    stream (1,1) RandStream
    options.UnitAveragePower (1,1) logical = false
    options.PeakNormalize (1,1) logical = false
    options.FilterSpanSymbols (1,1) double {mustBeInteger,mustBePositive} = 6
end

assert(2^round(log2(modulation_order)) == modulation_order, ...
    'thesis:qam_srrc_waveform:InvalidModulationOrder', ...
    'The modulation order must be a power of two.');

samples_per_symbol = sample_rate_hz/symbol_rate_hz;
assert(abs(samples_per_symbol-round(samples_per_symbol)) < ...
    10*eps(samples_per_symbol), ...
    'thesis:qam_srrc_waveform:NonintegerSamplesPerSymbol', ...
    'The sample-rate to symbol-rate ratio must be an integer.');
samples_per_symbol = round(samples_per_symbol);

messages = randi(stream, [0, modulation_order-1], num_symbols, 1);
symbols = qammod(messages, modulation_order, ...
    'UnitAveragePower', options.UnitAveragePower);

filter_taps = rcosdesign(rolloff, options.FilterSpanSymbols, ...
    samples_per_symbol, 'sqrt').';
shaped_signal = upfirdn(symbols, filter_taps, samples_per_symbol);
sample_index = (0:numel(shaped_signal)-1).';
passband_signal = shaped_signal .* exp(1j*2*pi*center_frequency_hz/ ...
    sample_rate_hz*sample_index);

if options.PeakNormalize
    normalization = modnorm(passband_signal, 'peakpow', 1);
    passband_signal = passband_signal*normalization;
end
end
