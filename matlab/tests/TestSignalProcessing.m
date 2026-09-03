classdef TestSignalProcessing < matlab.unittest.TestCase
    %TESTSIGNALPROCESSING Numerical invariants for shared thesis kernels.

    methods (TestClassSetup)
        function addMatlabDirectory(test_case)
            tests_directory = fileparts(mfilename('fullpath'));
            matlab_directory = fileparts(tests_directory);
            test_case.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(matlab_directory));
        end
    end

    methods (Test)
        function circularMeanPreservesConstantsAndMean(test_case)
            values = reshape(1:24,6,4);
            smoothed = thesis.signal.circular_movmean(values,4,1);
            test_case.verifySize(smoothed,size(values));
            test_case.verifyEqual(mean(smoothed,1),mean(values,1), ...
                'AbsTol',10*eps(max(values,[],'all')));
            constants = 3.25*ones(9,2);
            test_case.verifyEqual( ...
                thesis.signal.circular_movmean(constants,5,1),constants);
        end

        function zeroCycleCafMatchesAutocorrelation(test_case)
            signal = complex((1:12).',flipud((1:12).'));
            max_lag = 4;
            caf = thesis.signal.symmetric_caf(signal,0,1,max_lag);
            reference = xcorr(signal,max_lag,'biased').';
            test_case.verifyEqual(caf,reference,'AbsTol',1e-12);
        end

        function lagImpulseProducesFlatScf(test_case)
            caf = zeros(1,5);
            caf(3) = 2;
            [scf,raw_scf] = thesis.signal.caf_to_scf(caf,4,16,4);
            expected = 0.5*ones(1,16);
            test_case.verifyEqual(raw_scf,expected,'AbsTol',1e-14);
            test_case.verifyEqual(scf,expected,'AbsTol',1e-14);
        end

        function complexNoiseHasRequestedPower(test_case)
            signal = exp(1j*2*pi*(0:2047).'/17);
            stream = RandStream('mt19937ar','Seed',41);
            [received,noise] = thesis.signal.add_complex_awgn(signal,7,stream);
            measured_snr_db = 10*log10( ...
                mean(abs(signal).^2)/mean(abs(noise).^2));
            test_case.verifyEqual(measured_snr_db,7,'AbsTol',1e-12);
            test_case.verifyEqual(received,signal+noise);
        end

        function waveformGenerationIsDeterministic(test_case)
            first_stream = RandStream('mt19937ar','Seed',123);
            second_stream = RandStream('mt19937ar','Seed',123);
            first = thesis.signal.qam_srrc_waveform(128,1e6,100e3, ...
                50e3,4,0.35,first_stream,'UnitAveragePower',true);
            second = thesis.signal.qam_srrc_waveform(128,1e6,100e3, ...
                50e3,4,0.35,second_stream,'UnitAveragePower',true);
            test_case.verifyEqual(first,second);
        end

        function streamingStatisticIsIndependentOfChunkSize(test_case)
            sample_rate_hz = 1024;
            sample_index = (0:1023).';
            signal = exp(1j*2*pi*96/sample_rate_hz*sample_index) + ...
                0.4*exp(1j*2*pi*208/sample_rate_hz*sample_index);
            cycle_frequencies_hz = [64;128];
            center_frequencies_hz = (-256:32:224).';
            filter_taps = [0.5,0.5];
            one_at_a_time = thesis.signal.streaming_sca_statistic(signal, ...
                sample_rate_hz,cycle_frequencies_hz, ...
                center_frequencies_hz,filter_taps,1);
            all_at_once = thesis.signal.streaming_sca_statistic(signal, ...
                sample_rate_hz,cycle_frequencies_hz, ...
                center_frequencies_hz,filter_taps, ...
                numel(center_frequencies_hz));
            test_case.verifyEqual(one_at_a_time,all_at_once, ...
                'RelTol',1e-12,'AbsTol',1e-20);
        end
    end
end
