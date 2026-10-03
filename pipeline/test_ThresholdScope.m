classdef test_ThresholdScope < matlab.unittest.TestCase
    %test_ThresholdScope  Recording-wide detection thresholds (detectSpikes ThresholdScope).
    %   "recording" gives each channel one threshold from its noise over the
    %   whole recording: std / rms exactly; mad within 0.02 uV of the exact
    %   whole-recording value band-passed, 0.2 uV unfiltered (samples on
    %   0.195 uV steps); a percentile within one 0.05 uV bin of the sample it
    %   estimates. The thresholds do not change with the chunk size;
    %   detection applies them; "absolute" is the
    %   same either way; a flat channel, or one whose noise lies beyond the
    %   histogram, is degenerate with a warning; progress covers both passes;
    %   the spikes file records the scope; the config passes it on.
    %
    %   The fixture is a one-file-per-signal Intan recording (2 s at 30 kHz,
    %   stored at 0.195 uV per code) whose first channel is four times as
    %   noisy in its second half, so per-chunk thresholds differ from chunk
    %   to chunk while the recording-wide one is one value.
    %
    %   Usage:  runtests("test_ThresholdScope")

    properties (SetAccess = private)
        Folder (1,1) string = ""       % the main recording
        OddFolder (1,1) string = ""    % a flat channel and one beyond the histogram
        X = []                         % its microvolts, as the reader returns them
        Fs = 30000
        Ticks = struct('i', {}, 'n', {}, 'name', {})   % ProgressFcn calls (tick)
    end

    methods (TestClassSetup)
        function makeRecordings(tc)
            root = string(tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
            rng(21);
            Fs = tc.Fs; n = 2 * Fs;
            X = [5 * randn(n, 1), 8 * randn(n, 1)];
            X(n/2+1:end, 1) = 4 * X(n/2+1:end, 1);          % channel 1: 5 uV, then 20 uV
            tw = (-10:20).';
            tmpl = -300 * exp(-0.5 * (tw / 1.5).^2) + 60 * exp(-0.5 * ((tw - 8) / 4).^2);
            idx = (700:3000:n-700).';
            X = injectSpikes(X, idx, 1, tmpl, 11);
            X = injectSpikes(X, idx(1:2:end), 2, tmpl, 11);
            tc.Folder = writeSplit(fullfile(root, "R1_260101_120000"), X, Fs);
            dat = EphysDataset(tc.Folder).readData();
            tc.X = dat.amplifier;

            Y = [zeros(n, 1), 4000 * randn(n, 1)];          % flat; MAD ~2700 uV (beyond 2000)
            tc.OddFolder = writeSplit(fullfile(root, "R2_260101_120000"), Y, Fs);
        end
    end

    methods (Test)
        function madMatchesWholeRecording(tc)
            [~, ~, info] = tc.detect(ThresholdScope="recording", MaxChunkSamples=7000);
            tc.verifyEqual(info.thresholdScope, "recording");
            tc.verifyEqual(size(info.threshold), [1 2], "one threshold per channel");
            % Unfiltered, the samples sit on 0.195 uV steps, so the exact
            % median and MAD are themselves quantized; the histogram's are
            % within about two 0.05 uV bins of them (simulated: <= 0.14 uV
            % on the noise level over 300 such recordings).
            tc.verifyEqual(info.noise, madNoise(tc.X), 'AbsTol', 0.2, ...
                "the whole recording's MAD/0.6745");
            tc.verifyEqual(info.threshold, 4 * info.noise, 'RelTol', 1e-12, "the default 4 x noise");
            e = info.noiseEstimate;
            tc.verifyEqual([e.method e.estimator], ["mad" "histogram"]);
            tc.verifyEqual([e.binUV e.rangeUV], [0.05 2000]);
            tc.verifyEqual(e.nSamples, [1 1] * size(tc.X, 1), "every sample counted once");
            tc.verifyEqual(e.nOutOfRange, [0 0]);
            tc.verifyFalse(any(info.degenerate | e.beyondRange | e.belowResolution));
        end

        function madBandPassed(tc)
            ds = EphysDataset(tc.Folder);
            [~, ~, info] = ds.detectSpikes(ThresholdScope="recording", MaxChunkSamples=7000);
            Xf = ds.filterContinuous(tc.X, Type="bandpass", Cutoff=[500 5000], Order=4, Fs=tc.Fs);
            % Band-passed, the trace is continuous: within ~0.1% (simulated:
            % <= 0.003 uV here); the streamed band-pass meets the one-block
            % one within ~0.01 uV at the chunk joins.
            tc.verifyEqual(info.noise, madNoise(Xf), 'AbsTol', 0.02, ...
                "the MAD/0.6745 of the whole band-passed recording");
        end

        function chunkSizeDoesNotMatter(tc)
            [~, ~, a] = tc.detect(ThresholdScope="recording", MaxChunkSamples=7000);
            [~, ~, b] = tc.detect(ThresholdScope="recording", MaxChunkSamples=25000);
            [~, ~, w] = tc.detect(ThresholdScope="recording");
            tc.verifyGreaterThan(numel(a.chunks), numel(b.chunks));
            tc.verifyEqual(b.threshold, a.threshold, "the same thresholds whatever the chunks");
            tc.verifyEqual(w.threshold, a.threshold);
            tc.verifyEqual(b.index, a.index, "and the same events");
            [~, ~, k] = tc.detect(MaxChunkSamples=7000);
            tc.verifyEqual(k.thresholdScope, "chunk");
            tc.verifyEqual(size(k.threshold), [numel(k.chunks) 2], "per chunk by default");
            tc.verifyGreaterThan(max(k.threshold(:, 1)) / min(k.threshold(:, 1)), 3, ...
                "per-chunk thresholds follow the noise of each chunk");
        end

        function detectionUsesTheThresholds(tc)
            [~, ~, info] = tc.detect(ThresholdScope="recording", MaxChunkSamples=7000);
            ds = EphysDataset(tc.Folder);
            for c = 1:2
                [~, ~, blk] = ds.detectSpikes(tc.X(:, c), Filter=false, ThresholdMethod="absolute", ...
                    Threshold=info.threshold(c));
                tc.verifyEqual(info.index{c}, blk.index{1}, ...
                    sprintf("channel %d: the events a single block gives at that threshold", c));
            end
        end

        function stdRmsExactPercentileWithinABin(tc)
            [~, ~, s] = tc.detect(ThresholdScope="recording", ThresholdMethod="std", MaxChunkSamples=7000);
            tc.verifyEqual(s.noise, std(tc.X, 0, 1), 'RelTol', 1e-10, "std: exact");
            tc.verifyEqual(s.noiseEstimate.estimator, "exact");
            tc.verifyTrue(all(isnan([s.noiseEstimate.binUV s.noiseEstimate.rangeUV])));
            [~, ~, r] = tc.detect(ThresholdScope="recording", ThresholdMethod="rms", MaxChunkSamples=7000);
            tc.verifyEqual(r.noise, sqrt(mean(tc.X.^2, 1)), 'RelTol', 1e-10, "rms: exact");
            [~, ~, p] = tc.detect(ThresholdScope="recording", ThresholdMethod="percentile", ...
                Threshold=99, MaxChunkSamples=7000);
            n = size(tc.X, 1);
            A = sort(abs(tc.X), 1);
            tc.verifyEqual(p.threshold, A(ceil(0.99 * n), :), 'AbsTol', 0.05 + 1e-9, ...
                "percentile: within one 0.05 uV bin of the sample it estimates (the ceil(p*n)-th |x|)");
            tc.verifyTrue(all(isnan(p.noise)), "percentile measures no noise level");
        end

        function absoluteIsTheSameEitherWay(tc)
            [~, ~, k] = tc.detect(ThresholdMethod="absolute", Threshold=100, MaxChunkSamples=7000);
            [~, ~, r] = tc.detect(ThresholdMethod="absolute", Threshold=100, MaxChunkSamples=7000, ...
                ThresholdScope="recording");
            tc.verifyEqual(r.index, k.index);
            tc.verifyEqual(r.threshold, [100 100]);
            tc.verifyEmpty(r.noiseEstimate, "nothing is measured");
        end

        function flatAndOutOfRangeChannels(tc)
            ds = EphysDataset(tc.OddFolder);
            f = @() ds.detectSpikes(Filter=false, ThresholdScope="recording", MaxChunkSamples=7000);
            tc.verifyWarning(f, 'EphysDataset:detectSpikes:DegenerateThreshold');
            tc.verifyWarning(f, 'EphysDataset:detectSpikes:NoiseBeyondRange');
            warning('off', 'EphysDataset:detectSpikes:DegenerateThreshold');
            warning('off', 'EphysDataset:detectSpikes:NoiseBeyondRange');
            tc.addTeardown(@() warning('on', 'EphysDataset:detectSpikes:DegenerateThreshold'));
            tc.addTeardown(@() warning('on', 'EphysDataset:detectSpikes:NoiseBeyondRange'));
            [ts, ~, info] = f();
            e = info.noiseEstimate;
            tc.verifyEqual(info.degenerate, [true true]);
            tc.verifyEqual(info.threshold, [Inf Inf], "detect nothing rather than everything");
            tc.verifyEqual(cellfun(@numel, ts), [0 0]);
            tc.verifyEqual([e.belowResolution(1) e.beyondRange(1)], [true false], ...
                "the flat channel's noise is below one bin");
            tc.verifyTrue(isnan(info.noise(1)), "not resolved: NaN, not 0");
            tc.verifyEqual([e.belowResolution(2) e.beyondRange(2)], [false true], ...
                "the other's MAD lies beyond +/-2000 uV");
            tc.verifyGreaterThan(e.nOutOfRange(2), 0);
            [~, ~, s] = ds.detectSpikes(Filter=false, ThresholdScope="recording", ThresholdMethod="std");
            tc.verifyEqual(s.degenerate, [true false], "std has no range limit");
        end

        function progressCoversBothPasses(tc)
            tc.Ticks = struct('i', {}, 'n', {}, 'name', {});
            [~, ~, info] = tc.detect(ThresholdScope="recording", MaxChunkSamples=7000, ...
                ProgressFcn=@(i, n, name) tc.tick(i, n, name));
            n = numel(info.chunks);
            tc.verifyEqual([[tc.Ticks.i].' [tc.Ticks.n].'], [(1:2*n).' repmat(2*n, 2*n, 1)], ...
                "one call per chunk and pass, out of 2n");
            names = string({tc.Ticks.name});
            tc.verifyTrue(all(startsWith(names(1:n), "noise level: ")) && ~any(startsWith(names(n+1:end), "noise level")), ...
                "the first pass says so");
        end

        function blockModeRefusesIt(tc)
            ds = EphysDataset(tc.Folder);
            tc.verifyError(@() ds.detectSpikes(tc.X, ThresholdScope="recording"), ...
                'EphysDataset:detectSpikes:BlockOption');
        end

        function spikesFileRecordsTheScope(tc)
            ds = EphysDataset(tc.Folder);
            out = string(tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
            file = fullfile(out, "R1_spikes.mat");
            ds.spikesToMat(File=file, ArtifactMode="none", DetectOptions=struct('Filter', false, ...
                'ThresholdScope', "recording", 'MaxChunkSamples', 7000));
            S = load(file);
            tc.verifyEqual(S.detected.info.thresholdScope, "recording");
            tc.verifyEqual(S.detected.detection.options.ThresholdScope, "recording");
            tc.verifyEqual(size(S.detected.info.threshold), [1 2]);
        end

        function configPassesItOn(tc)
            K = EphysPipelineConfig.defaults("Spikes");
            tc.verifyEqual(K.ThresholdScope, "chunk");
            tc.verifyFalse(isfield(EphysPipelineConfig.detectOptions(K), 'ThresholdScope'), ...
                "the default is left to detectSpikes");
            K.ThresholdScope = "recording";
            tc.verifyEqual(EphysPipelineConfig.detectOptions(K).ThresholdScope, "recording");
            cfg = EphysPipelineConfig();
            cfg.Spikes.Enabled = true;
            cfg.Spikes.ThresholdScope = "whole";
            iss = cfg.validate();
            tc.verifyTrue(any(iss.Field == "ThresholdScope" & iss.Severity == "error"));
        end
    end

    methods (Access = private)
        function tick(tc, i, n, name)
            tc.Ticks(end+1) = struct('i', i, 'n', n, 'name', string(name));
        end

        function [ts, wf, info] = detect(tc, varargin)
            ds = EphysDataset(tc.Folder);
            [ts, wf, info] = ds.detectSpikes('Filter', false, varargin{:});
        end
    end
end


function folder = writeSplit(folder, X, Fs)
%writeSplit  A one-file-per-signal Intan recording of X (microvolts, [n x nChan]).
mkdir(folder);
n = size(X, 1);
writeInfoRHD(fullfile(folder, 'info.rhd'), size(X, 2), Fs);
writeDat(fullfile(folder, 'amplifier.dat'), int16(round(X.' / 0.195)), 'int16');
writeDat(fullfile(folder, 'time.dat'), int32(0:n-1), 'int32');
writeDat(fullfile(folder, 'digitalin.dat'), uint16(zeros(1, n)), 'uint16');
folder = string(folder);
end


function v = madNoise(X)
%madNoise  Exact MAD/0.6745 of each column, as detectSpikes measures one block.
v = zeros(1, size(X, 2));
for c = 1:size(X, 2)
    x = X(:, c);
    v(c) = median(abs(x - median(x))) / 0.6745;
end
end
