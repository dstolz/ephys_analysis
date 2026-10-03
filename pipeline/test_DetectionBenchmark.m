classdef test_DetectionBenchmark < matlab.unittest.TestCase
    %test_DetectionBenchmark  Spike and artifact detection meet their accuracy floors on synthetic truth.
    %   benchmarkDetection writes one synthetic recording (8 channels, about
    %   55 s, units of 40 / 60 / 90 / 140 / 200 uV on channels 1 / 3 / 5 / 7 /
    %   8, at 10 Hz, over the generator's default background and its two
    %   artifacts), detects with
    %   the pipeline's default settings and scores the result against the
    %   truth. The floors are regression floors, set below what a model of
    %   the same signal and detectors gave over six seeds:
    %
    %     measure (default settings)            model     floor
    %     recall, units with SNR >= 6           >= 0.985  >= 0.95
    %     recall, the 40 uV unit (SNR ~4.3)     0.82-0.88 >= 0.6
    %     precision, all detections             ~0.82     >= 0.7
    %     duplicates per visible spike (max)    <= 0.51   <= 0.8
    %     isolated noise crossings (max/chan)   <= 0.56   <= 1.0 Hz
    %     artifacts found / coverage            all / 1   all / >= 0.99
    %     artifact edges                        <= 0.5 ms <= 2 ms
    %     false artifact intervals              0         0
    %
    %   The duplicates are second crossings of large spikes (the band-passed
    %   waveform's later lobe, past MinPeriodMs): their ceiling guards
    %   against more of them, it does not say they are wanted. Raise a floor
    %   when the detector improves; report R (benchmarkDetection) when one
    %   fails.
    %
    %   Usage:  runtests("test_DetectionBenchmark")
    %           run_all_tests(Tag="Benchmark")

    properties (SetAccess = private)
        R = []
        ReportFile (1,1) string = ""
    end

    methods (TestClassSetup)
        function runBenchmark(tc)
            folder = string(tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
            tc.ReportFile = fullfile(folder, "benchmark.json");
            tc.R = benchmarkDetection(Folder=fullfile(folder, "recordings"), Seeds=1, ...
                AmplitudesUV=[40 60 90 140 200], Channels=[1 3 5 7 8], ReportFile=tc.ReportFile);
        end
    end

    methods (Test, TestTags = {'Benchmark'})
        function spikeRecall(tc)
            U = tc.R.units;
            high = U.snr >= 6;
            tc.assertGreaterThanOrEqual(nnz(high), 3, "at least three units at SNR >= 6");
            tc.verifyGreaterThanOrEqual(min(U.recall(high)), 0.95, ...
                "units well above threshold: nearly every spike found within 0.5 ms");
            low = U(U.amplitudeUV == 40, :);
            tc.verifyLessThan(low.snr, 6, "the 40 uV unit is the one near threshold");
            tc.verifyGreaterThanOrEqual(low.recall, 0.6, "near threshold, most spikes are still found");
            tc.verifyEqual(U.recall(U.snr == min(U.snr)), min(U.recall), ...
                "the lowest SNR has the lowest recall");
        end

        function spikePrecision(tc)
            s = tc.R.summary;
            tc.verifyGreaterThanOrEqual(s.precision, 0.7);
            tc.verifyLessThanOrEqual(s.maxIsolatedHz, 1.0, "noise crossings at 4 x MAD: under 1 Hz per channel");
            tc.verifyLessThanOrEqual(s.maxDuplicatesPerSpike, 0.8, "second crossings of large spikes do not grow");
            C = tc.R.channels;
            tc.verifyEqual(C.matched + C.duplicates + C.isolated, C.detections, "every detection is classified once");
        end

        function artifacts(tc)
            A = tc.R.artifacts;
            tc.verifyEqual(height(A), 2, "the generator's burst and saturating step");
            tc.verifyTrue(all(A.found), "every artifact period is found");
            tc.verifyGreaterThanOrEqual(min(A.coverage), 0.99);
            tc.verifyLessThanOrEqual(tc.R.summary.artifactMaxEdgeMs, 2);
            tc.verifyEqual(height(tc.R.falseArtifacts), 0, "no artifact where there is none");
        end

        function reportIsWritten(tc)
            tc.assertTrue(isfile(tc.ReportFile));
            rep = readJsonFile(tc.ReportFile);
            tc.verifyEqual(rep.summary.precision, tc.R.summary.precision, 'AbsTol', 1e-12);
            tc.verifyEqual(numel(rep.units), height(tc.R.units));
            tc.verifyTrue(isfield(rep, 'provenance') && isfield(rep.provenance, 'commit'), "the code that was scored");
        end
    end
end
