classdef test_SpikeCoincidence < matlab.unittest.TestCase
    %test_SpikeCoincidence  One spike seen on neighboring sites (detectSpikes Coincidence).
    %   Events on sites within CoincidenceRadiusUm of each other whose
    %   troughs lie within CoincidenceJitterMs are copies of one spike:
    %   "remove" keeps the deepest, "tag" keeps them all and numbers them.
    %   Covered: the jitter and radius edges, the deepest copy wins whatever
    %   its channel, ties go to the earlier event and then the lower channel,
    %   a site off the probe is never a neighbor, waveforms follow the events
    %   kept, whole-recording mode gives the block's result across chunk
    %   joins, spikesToMat takes the sites from the probe (and, with a
    %   warning, keeps every copy without one), the tags survive artifact
    %   rejection, the config section and its validation, siteNeighbors and
    %   SpikeNeighborsDialog.
    %
    %   The fixture is 1 s at 30 kHz without noise, four channels with sites
    %   at (0,0), (0,20) and (0,200) um and one off the probe. Troughs
    %   (samples, uV):
    %     3000   ch1 -300; ch2 -150 at +5; ch3 -200 (200 um away); ch4 -250 (off the probe)
    %     9000   ch2 -300; ch1 -100 at -3 (the deeper copy is on ch2)
    %     15000  ch1 -300; ch2 -150 at +15 (exactly the 0.5 ms jitter)
    %     21000  ch1 -300; ch2 -150 at +16 (just beyond it), across a 7000-sample chunk join
    %
    %   Usage:  runtests("test_SpikeCoincidence")

    properties (SetAccess = private)
        X = []                         % the fixture, microvolts [n x 4]
        Fs = 30000
        Pos = [0 0; 0 20; 0 200; NaN NaN]
        Folder (1,1) string = ""       % the fixture as a recording (one file per signal)
        ProbeFile (1,1) string = ""    % its probe (channel 4 placed 300 um away)
        Radii = []                     % OnChange calls of the dialog
    end

    methods (TestClassSetup)
        function makeFixture(tc)
            n = tc.Fs;
            X = zeros(n, 4);
            tw = (-10:20).';
            tmpl = -exp(-0.5 * (tw / 1.5).^2) + 0.2 * exp(-0.5 * ((tw - 8) / 4).^2);   % trough -1 at tw = 0
            X = injectSpikes(X, [3000; 15000; 21000], 1, 300 * tmpl, 11);
            X = injectSpikes(X, 8997, 1, 100 * tmpl, 11);
            X = injectSpikes(X, 9000, 2, 300 * tmpl, 11);
            X = injectSpikes(X, [3005; 15015; 21016], 2, 150 * tmpl, 11);
            X = injectSpikes(X, 3000, 3, 200 * tmpl, 11);
            X = injectSpikes(X, 3000, 4, 250 * tmpl, 11);
            tc.X = X;

            root = string(tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
            tc.Folder = writeSplit(fullfile(root, "C1_260101_120000"), X, tc.Fs);
            tc.ProbeFile = fullfile(root, "probe4.json");
            writeProbeMap(tc.ProbeFile, struct('chanMap', 0:3, 'xc', [0 0 0 300], ...
                'yc', [0 20 200 0], 'kcoords', zeros(1, 4), 'n_chan', 4));
        end
    end

    methods (Test)
        function removeKeepsTheDeepest(tc)
            [ts, ~, info] = tc.detect(Coincidence="remove");
            tc.verifyEqual(info.index, {[3000; 15000; 21000], [9000; 21016], 3000, 3000}, ...
                "each spike once, on its deepest site; 21016 is 16 samples off, a spike of its own");
            tc.verifyEqual(ts{2}, ([9000; 21016] - 1) / tc.Fs, "times follow");
            tc.verifyEqual(info.count, [3 2 1 1]);
            tc.verifyEqual(info.rate, info.count / info.durationSec);
            C = info.coincidence;
            tc.verifyEqual(C.mode, "remove");
            tc.verifyEqual(C.nCopies, [1 2 0 0], "ch1 gave up 8997, ch2 3005 and 15015");
            tc.verifyEqual(C.neighbors, {2, 1, zeros(1, 0), zeros(1, 0)}, ...
                "200 um is beyond 50; off the probe is no one's neighbor");
            tc.verifyEqual([C.jitterSamples C.jitterMs C.radiusUm], [15 0.5 50]);
            tc.verifyEqual(C.positions, tc.Pos);
            tc.verifyFalse(isfield(info, 'eventId') || isfield(info, 'primary'), "no tags when they are removed");
        end

        function tagNumbersTheCopies(tc)
            [~, ~, info] = tc.detect(Coincidence="tag");
            tc.verifyEqual(info.index, {[3000; 8997; 15000; 21000], [3005; 9000; 15015; 21016], 3000, 3000}, ...
                "every event kept");
            tc.verifyEqual(info.primary, {logical([1; 0; 1; 1]), logical([0; 1; 0; 1]), true, true});
            tc.verifyEqual(info.eventId, {[1; 4; 5; 6], [1; 4; 5; 7], 2, 3}, ...
                "a copy has its primary's number; primaries numbered in time order (then channel)");
            tc.verifyEqual(info.coincidence.nCopies, [1 2 0 0]);
            [~, ~, rem] = tc.detect(Coincidence="remove");
            kept = cellfun(@(i, p) i(p), info.index, info.primary, 'UniformOutput', false);
            tc.verifyEqual(kept, rem.index, "the primaries are what remove keeps");
        end

        function noneLeavesEveryChannelOnItsOwn(tc)
            [~, ~, info] = tc.detect();
            tc.verifyEqual(info.coincidence.mode, "none", "the detector's default");
            tc.verifyEqual(info.count, [4 4 1 1]);
            tc.verifyEqual(info.coincidence.nCopies, zeros(1, 4));
            tc.verifyTrue(isnan(info.coincidence.jitterMs));
        end

        function jitterAndRadiusEdges(tc)
            [~, ~, j0] = tc.detect(Coincidence="remove", CoincidenceJitterMs=0);
            tc.verifyEqual(j0.coincidence.nCopies, zeros(1, 4), "jitter 0: only the same sample");
            [~, ~, r] = tc.detect(Coincidence="remove", CoincidenceRadiusUm=19.99);
            tc.verifyEqual(r.coincidence.nCopies, zeros(1, 4), "20 um apart is beyond 19.99 um");
            [~, ~, r20] = tc.detect(Coincidence="remove", CoincidenceRadiusUm=20);
            tc.verifyEqual(r20.coincidence.nCopies, [1 2 0 0], "and within 20 um");
            [~, ~, far] = tc.detect(Coincidence="remove", CoincidenceRadiusUm=200);
            tc.verifyEmpty(far.index{3}, "at 200 um ch3's smaller copy at 3000 goes too");
            tc.verifyEqual(far.index{4}, 3000, "but a site off the probe never has a neighbor");
            [~, ~, w] = tc.detect(Coincidence="remove", CoincidenceJitterMs=16 / 30);
            tc.verifyEqual(w.index{2}, 9000, "16 samples of jitter take 21016 too");
        end

        function tiesGoEarlierThenLowerChannel(tc)
            X = zeros(3000, 2);
            tw = (-10:20).';
            tmpl = -200 * exp(-0.5 * (tw / 1.5).^2);
            X = injectSpikes(X, 1000, 1, tmpl, 11);
            X = injectSpikes(X, 1000, 2, tmpl, 11);
            X = injectSpikes(X, 2000, 2, tmpl, 11);
            X = injectSpikes(X, 2003, 1, tmpl, 11);
            [~, ~, info] = EphysDataset().detectSpikes(X, Fs=tc.Fs, Filter=false, ThresholdMethod="absolute", ...
                Threshold=50, Coincidence="remove", SitePositions=[0 0; 0 20]);
            tc.verifyEqual(info.index, {1000, 2000}, "equal troughs: the earlier, then the lower channel");
        end

        function waveformsFollowTheEvents(tc)
            [ts, wf, info] = tc.detect(Coincidence="remove", Waveforms=true, WindowMs=[-0.5 1]);
            [~, wfT, tag] = tc.detect(Coincidence="tag", Waveforms=true, WindowMs=[-0.5 1]);
            for c = 1:4
                tc.verifyEqual(size(wf{c}, 1), numel(ts{c}));
                tc.verifyEqual(wf{c}, wfT{c}(tag.primary{c}, :), sprintf("channel %d: the kept events' rows", c));
            end
            tc.verifyEqual(info.nEdgeWindows, zeros(1, 4));
            t0 = find(info.waveformTimeMs == 0);
            tc.verifyEqual(wf{1}(:, t0), tc.X([3000; 15000; 21000], 1), "each window centered on its trough");
            tc.verifyEqual(wf{1}(:, t0), min(wf{1}, [], 2));
        end

        function sitePositionsAreRequired(tc)
            ds = EphysDataset();
            tc.verifyError(@() ds.detectSpikes(tc.X, Fs=tc.Fs, Coincidence="remove"), ...
                'EphysDataset:detectSpikes:NoSitePositions');
            tc.verifyError(@() ds.detectSpikes(tc.X, Fs=tc.Fs, Coincidence="tag", SitePositions=[0 0; 0 20]), ...
                'EphysDataset:detectSpikes:SitePositions');
            tc.verifyError(@() EphysDataset(tc.Folder).detectSpikes(Coincidence="remove", ...
                SitePositions=[0 0; 0 20]), 'EphysDataset:detectSpikes:SitePositions', ...
                "whole-recording mode checks before reading");
            ts = ds.detectSpikes(tc.X, Fs=tc.Fs, Filter=false, ThresholdMethod="absolute", Threshold=50, ...
                SitePositions=[0 0; 0 20]);
            tc.verifyEqual(cellfun(@numel, ts), [4 4 1 1], "Coincidence none ignores them");
        end

        function wholeRecordingMatchesTheBlock(tc)
            ds = EphysDataset(tc.Folder);
            dat = ds.readData();
            opts = {'Filter', false, 'ThresholdMethod', "absolute", 'Threshold', 50, ...
                'Coincidence', "remove", 'SitePositions', tc.Pos, 'Waveforms', true};
            [tsW, wfW, w] = ds.detectSpikes(opts{:}, 'MaxChunkSamples', 7000);
            [tsB, wfB, b] = ds.detectSpikes(dat.amplifier, opts{:});
            tc.verifyGreaterThan(numel(w.chunks), 3, "the recording was read in chunks");
            tc.verifyEqual(w.index, b.index, "21000 / 21016 straddle a join: the same events as one block");
            tc.verifyEqual(tsW, tsB);
            tc.verifyEqual(wfW, wfB);
            tc.verifyEqual(w.coincidence.nCopies, [1 2 0 0]);
            tc.verifyEqual(w.options.Coincidence, "remove", "info.options says how it ran");
            [~, ~, wc] = ds.detectSpikes(opts{:}, 'Coincidence', "tag", 'ChannelOrder', [2 1], ...
                'SitePositions', tc.Pos([2 1], :));
            tc.verifyEqual(wc.eventId, {[1; 2; 3; 5], [1; 2; 3; 4]}, ...
                "ChannelOrder: one site per channel detected on, the spikes numbered over those two");
        end

        function spikesToMatTakesTheSitesFromTheProbe(tc)
            ds = EphysDataset(tc.Folder);
            out = string(tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
            file = fullfile(out, "C1_spikes.mat");
            r = ds.spikesToMat(File=file, ArtifactMode="none", ProbeFile=tc.ProbeFile, ...
                DetectOptions=tc.fileOptions("remove"));
            S = load(file);
            tc.verifyEqual(S.detected.info.coincidence.mode, "remove");
            tc.verifyEqual(S.detected.info.coincidence.positions, [0 0; 0 20; 0 200; 300 0], "the probe's xc / yc");
            tc.verifyEqual(cellfun(@numel, S.detected.ts), [3 2 1 1]);
            tc.verifyEqual(S.detected.detection.coincidence, ...
                struct('requested', "remove", 'probeFile', tc.ProbeFile, 'note', ""));
            tc.verifyEqual([r.coincidence r.coincidenceNote], ["remove" ""]);
            tc.verifyEqual(r.nCoincident, [1 2 0 0]);
            rec = ds.Processing.spikes;
            tc.verifyEqual(rec.coincidence.copies, 3);
            tc.verifyEqual(rec.coincidence.probe, tc.ProbeFile);
            tc.verifyFalse(isfield(rec.options, 'SitePositions'), "the manifest names the probe, not the sites");
            tc.verifyError(@() ds.spikesToMat(File=fullfile(out, "x.mat"), ...
                DetectOptions=struct('SitePositions', tc.Pos)), 'EphysDataset:spikesToMat:DetectOption');
        end

        function spikesToMatWithoutAProbeKeepsEveryCopy(tc)
            ds = EphysDataset(tc.Folder);
            out = string(tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
            file = fullfile(out, "C1_spikes.mat");
            r = tc.verifyWarning(@() ds.spikesToMat(File=file, ArtifactMode="none", ...
                DetectOptions=tc.fileOptions("remove")), 'EphysDataset:spikesToMat:NoProbe');
            S = load(file);
            tc.verifyEqual(S.detected.info.coincidence.mode, "none");
            tc.verifyEqual(S.detected.detection.coincidence.requested, "remove");
            tc.verifyEqual(S.detected.detection.coincidence.note, "no probe");
            tc.verifyEqual(cellfun(@numel, S.detected.ts), [4 4 1 1]);
            tc.verifyEqual(r.coincidenceNote, "no probe");
            missing = fullfile(out, "nowhere.json");
            r2 = tc.verifyWarning(@() ds.spikesToMat(File=file, Overwrite=true, ArtifactMode="none", ...
                ProbeFile=missing, DetectOptions=tc.fileOptions("tag")), 'EphysDataset:spikesToMat:NoProbe');
            tc.verifyTrue(contains(r2.coincidenceNote, "missing"));
        end

        function tagsSurviveArtifactRejection(tc)
            ds = EphysDataset(tc.Folder);
            out = string(tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
            file = fullfile(out, "C1_spikes.mat");
            ds.spikesToMat(File=file, ArtifactMode="reject", ArtifactIntervals=[0.0995 0.1005], ...
                ProbeFile=tc.ProbeFile, DetectOptions=tc.fileOptions("tag"));
            info = load(file).detected.info;
            tc.verifyEqual(info.index(1:2), {[8997; 15000; 21000], [9000; 15015; 21016]}, ...
                "the events at 3000 / 3005 lie in the period");
            tc.verifyEqual(info.eventId(1:2), {[4; 5; 6], [4; 5; 7]});
            tc.verifyEqual(info.primary(1:2), {logical([0; 1; 1]), logical([1; 0; 1])});
            tc.verifyTrue(all(cellfun(@isempty, [info.index(3:4) info.eventId(3:4) info.primary(3:4)])));
            tc.verifyEqual(info.coincidence.nCopies, [1 1 0 0], "the copies still in the file");
        end

        function configSection(tc)
            K = EphysPipelineConfig.defaults("Spikes");
            tc.verifyEqual(K.Coincidence, "remove", "on in the pipeline");
            tc.verifyEqual([K.CoincidenceRadiusUm K.CoincidenceJitterMs], [50 0.5]);
            d = EphysPipelineConfig.detectOptions(K);
            tc.verifyEqual(d.Coincidence, "remove");
            tc.verifyEqual([d.CoincidenceRadiusUm d.CoincidenceJitterMs], [50 0.5]);
            cfg = EphysPipelineConfig();
            cfg.Spikes.Enabled = true;
            cfg.Spikes.Coincidence = "dedupe";
            iss = cfg.validate();
            tc.verifyTrue(any(iss.Field == "Coincidence" & iss.Severity == "error"));
            cfg.Spikes.Coincidence = "tag";
            cfg.Spikes.CoincidenceRadiusUm = 0;
            cfg.Spikes.CoincidenceJitterMs = -1;
            cfg.Spikes.Align = "none";
            iss = cfg.validate();
            tc.verifyTrue(any(iss.Field == "CoincidenceRadiusUm" & iss.Severity == "error"));
            tc.verifyTrue(any(iss.Field == "CoincidenceJitterMs" & iss.Severity == "error"));
            tc.verifyTrue(any(iss.Field == "Coincidence" & iss.Severity == "warning"), ...
                "Align none compares the crossings, not the troughs");
        end

        function siteNeighborsIsTheTrueDistance(tc)
            pos = [0 0; 0 50; 0 100; NaN NaN; 30 40];
            [nb, M] = siteNeighbors(pos, 50);
            tc.verifyEqual(nb, {[2 5], [1 3 5], 2, zeros(1, 0), [1 2]}, "(30,40) is 50 um from (0,0)");
            tc.verifyEqual(M, M.', "symmetric");
            tc.verifyFalse(any(diag(M)), "a site is not its own neighbor");
            tc.verifyEqual(siteNeighbors(pos, 49.9), {zeros(1, 0), 5, zeros(1, 0), zeros(1, 0), 2});
        end

        function neighborsDialog(tc)
            dlg = SpikeNeighborsDialog(tc.Pos, Channels=[5 6 7 8], RadiusUm=50, Title="C1", ...
                OnChange=@(r) tc.addRadius(r), Visible=false);
            tc.addTeardown(@delete, dlg);
            tc.verifyEqual(dlg.Neighbors, {2, 1, zeros(1, 0), zeros(1, 0)});
            tc.verifyTrue(contains(dlg.Summary, "3 site(s)") && contains(dlg.Summary, "1 channel(s) off the probe") ...
                && contains(dlg.Summary, "1 with none"), dlg.Summary);
            tc.verifyEqual(string(dlg.Fig.Name), "Spike neighbors: C1");
            dlg.select(2);
            tc.verifyEqual(dlg.Selected, 2);
            ax = findall(dlg.Fig, 'Type', 'axes');
            tc.verifyTrue(contains(string(ax.Title.String), "Channel 6: 1 neighbor(s)"));
            tc.verifyEqual(numel(findall(ax, 'Type', 'rectangle')), 1, "the radius circled around it");
            dlg.select(4);
            tc.verifyEqual(dlg.Selected, 0, "a site off the probe cannot be picked");
            dlg.setRadius(200);
            tc.verifyEqual(dlg.Neighbors, {[2 3], [1 3], [1 2], zeros(1, 0)});
            tc.verifyEmpty(tc.Radii, "setRadius (from the tab) does not call OnChange");
            T = findall(dlg.Fig, 'Type', 'uitable');
            tc.verifyEqual(T.Data(:, 5), {2; 2; 2; 0});
            tc.verifyEqual(T.Data{4, 6}, 'off the probe');
            dlg.setSites([0 0; 0 10], Channels=[1 2]);
            tc.verifyEqual(dlg.Neighbors, {2, 1});
        end
    end

    methods (Access = private)
        function [ts, wf, info] = detect(tc, varargin)
            [ts, wf, info] = EphysDataset().detectSpikes(tc.X, 'Fs', tc.Fs, 'Filter', false, ...
                'ThresholdMethod', "absolute", 'Threshold', 50, 'SitePositions', tc.Pos, varargin{:});
        end

        function s = fileOptions(~, mode)
            s = struct('Filter', false, 'ThresholdMethod', "absolute", 'Threshold', 50, 'Coincidence', mode);
        end

        function addRadius(tc, r)
            tc.Radii(end+1) = r;
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
