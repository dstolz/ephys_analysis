classdef test_EpochMatrix < matlab.unittest.TestCase
    %test_EpochMatrix  epochMatrix and epochMatrixSettings.
    %   Settings: the defaults (every unit class, auROC cutoff "none"), the
    %   OFC script's settings as an overlay, every error, a JSON round trip
    %   with the same id text, and an ID that holds only what applies to
    %   the data; several kinds of data (each once, every kind's fields
    %   checked, the ID per kind through Kind=, AUX's columns and magnitude
    %   among other kinds, a file round trip). Over the analysis fixture (two synthetic datasets run
    %   through the pipeline): spike rates and counts equal the script's
    %   loop written out here, the auROC equals spikePSTH's; an LFP equals
    %   evokedPotential by hand, with the shank and channel picks, and AUX's
    %   magnitude is one row; a dataset without the signal is skipped. With
    %   hand-made parts: the group labels' union and order, NaN, text and
    %   mixed labels, the rows' union of columns, Session, and the time-base
    %   check. A cancel keeps the finished part in Runs, which a second call
    %   reuses, and a signal option leaves the spike parts cached. The
    %   script's own spike settings (detected, merged, some shanks) equal
    %   its loop; Subject, Date and Session follow subjectAndDate and the
    %   script's session rule; a changed outputs stamp recomputes that
    %   dataset only. Assembly: numeric and text labels of one parameter
    %   line up, two parameters order by value (Depth 9 before 10), and an
    %   integer column some datasets lack becomes double. Normalization:
    %   every method by hand, per row and per group, normalized again from
    %   the raw values (no stacking, "none" gives them back), a flat
    %   baseline NaN and marked, a missing group left unmarked, no baseline
    %   time an error, auROC left alone, and the labels; normalize is not
    %   in the id. keepEpochs: in the id only when on, its parts under their
    %   own name; the kept spike times, binned per epoch, average to the
    %   counts, and the kept LFP epochs to the means; normalization leaves
    %   them alone; a part without epochs assembles with empty ones.
    %
    %   Usage:  runtests("test_EpochMatrix")

    properties (SetAccess = private)
        Fixture = []
        Config = []
        Runner = []
    end

    methods (TestClassSetup)
        function makeFixture(tc)
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(here);
            addpath(fullfile(repo, 'pipeline'));
            addpath(repo);
            addpath(genpath(fullfile(repo, 'vendor')));
            tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            tc.Fixture = makeAnalysisFixture(string(tmp.Folder), Scenarios=["clean" "late-start"], NumTrials=12);
            cfg = EphysAnalysisConfig();
            cfg.Source.Root = tc.Fixture.proj;
            tc.Config = cfg;
            tc.Runner = EphysAnalysisRunner(cfg, LogFcn=[]);
        end
    end

    methods
        function [S, ID] = spikeSettings(~, varargin)
            %spikeSettings  Stim onsets, [-0.2 0.5] s, grouped by Depth, descending (the script's order).
            [S, ID] = epochMatrixSettings([], 'ref', eventRef(line="Stim"), 'window', epochWindow(pre=-0.2, post=0.5), ...
                'selection', trialSelection(groupBy="Depth", groupOrder="descending"), varargin{:});
        end
    end

    methods (Test)
        % --- settings -----------------------------------------------------------------------
        function settingsDefaults(tc)
            [S, ID] = epochMatrixSettings();
            tc.verifyEqual(string(fieldnames(S)).', ["data" "ref" "window" "selection" "units" "measure" "binSec" ...
                "baseline" "auroc" "signal" "normalize" "keepEpochs"]);
            tc.verifyEqual(S.normalize, struct('method', "none", 'baseline', [-0.5 0], 'scope', "row"));
            tc.verifyFalse(S.keepEpochs);
            tc.verifyEqual(S.data, "units");
            tc.verifyEmpty(S.units.classes, 'Every class by default, as the script''s [].');
            tc.verifyEqual(S.units.source, "units");
            tc.verifyEqual(S.auroc.cutoff, "none");
            tc.verifyEqual(S.measure, "rate");
            tc.verifyEqual(S.binSec, 0.01);
            tc.verifyEqual(S.window.mode, "fixed");
            tc.verifyEqual(S.signal, struct('channels', [], 'shanks', [], 'baseline', [], 'detrend', false, ...
                'rectify', false, 'magnitude', false, 'statistic', "mean"));
            tc.verifyEqual(string(fieldnames(ID)).', ["data" "ref" "window" "selection" "units" "measure" "binSec" ...
                "baseline" "auroc" "version"]);
            [~, IDs] = epochMatrixSettings([], data="lfp");
            tc.verifyEqual(string(fieldnames(IDs)).', ["data" "ref" "window" "selection" "signal" "version"]);
            tc.verifyEqual(IDs.data, "LFP");
        end

        function settingsScriptOverlay(tc)
            ref = eventRef(line="Stim", edge="onset", which="first", sequence=struct('line', "Platform", 'edge', "offset"));
            S = epochMatrixSettings([], ref=ref, window=epochWindow(pre=-1, post=1), ...
                selection=trialSelection(response="Hit", groupBy="Depth", groupOrder="descending"), ...
                data="detected", units=struct('classes', [], 'shanks', 1:4, 'merge', struct('enabled', true)), ...
                measure="rate", binSec=0.01, baseline=[-1 -0.5]);
            tc.verifyEqual(S.ref, ref);
            tc.verifyEqual(S.units.source, "detected", 'The source follows data.');
            tc.verifyEqual(S.units.shanks, 1:4);
            tc.verifyTrue(S.units.merge.enabled);
            tc.verifyEqual(S.units.merge.radiusUm, 50, 'Merge''s other fields keep their defaults.');
            tc.verifyEmpty(S.units.classes);
            tc.verifyEqual(S.selection.groupOrder, "descending");
            tc.verifyEqual(S.baseline, [-1 -0.5]);
            % a struct option merges into the field; S0 as the base
            S2 = epochMatrixSettings(S, units=struct('shanks', [1 2]), signal=struct('detrend', true));
            tc.verifyEqual(S2.units.shanks, [1 2]);
            tc.verifyTrue(S2.units.merge.enabled);
            tc.verifyTrue(S2.signal.detrend);
            tc.verifyEqual(S2.signal.statistic, "mean");
        end

        function settingsErrors(tc)
            bad = 'epochMatrixSettings:BadValue';
            unk = 'epochMatrixSettings:UnknownField';
            tc.verifyError(@() epochMatrixSettings(struct('nope', 1)), unk);
            tc.verifyError(@() epochMatrixSettings([], units=struct('nope', 1)), unk);
            tc.verifyError(@() epochMatrixSettings([], signal=struct('nope', 1)), unk);
            tc.verifyError(@() epochMatrixSettings([], auroc=struct('nope', 1)), unk);
            tc.verifyError(@() epochMatrixSettings([], ref=struct('nope', 1)), unk);
            tc.verifyError(@() epochMatrixSettings([], data="spikes"), bad);
            tc.verifyError(@() epochMatrixSettings([], measure="zscore"), bad);
            tc.verifyError(@() epochMatrixSettings([], ref=struct('edge', "middle")), bad);
            tc.verifyError(@() epochMatrixSettings([], window=struct('mode', "between", 'stop', "Stim")), bad);
            tc.verifyError(@() epochMatrixSettings([], window=struct('pre', 1, 'post', 0)), bad);
            tc.verifyError(@() epochMatrixSettings([], selection=struct('groupOrder', "random")), bad);
            tc.verifyError(@() epochMatrixSettings([], binSec=0), bad);
            tc.verifyError(@() epochMatrixSettings([], binSec=-0.01), bad);
            tc.verifyError(@() epochMatrixSettings([], window=struct('pre', -0.004, 'post', 0.004), binSec=0.01), bad);
            tc.verifyError(@() epochMatrixSettings([], measure="auroc", baseline=[0 0]), bad);
            tc.verifyError(@() epochMatrixSettings([], measure="auroc", baseline=[]), bad);
            tc.verifyError(@() epochMatrixSettings([], baseline=[0 1 2]), bad);
            tc.verifyError(@() epochMatrixSettings([], units=struct('source', "nope"), data="LFP"), bad);
            tc.verifyError(@() epochMatrixSettings([], signal=struct('statistic', "max")), bad);
            tc.verifyError(@() epochMatrixSettings([], signal=struct('channels', 0)), bad);
            tc.verifyError(@() epochMatrixSettings([], signal=struct('baseline', [1 0])), bad);
            tc.verifyError(@() epochMatrixSettings([], signal=struct('detrend', "maybe")), bad);
            tc.verifyError(@() epochMatrixSettings([], data="LFP", signal=struct('baseline', [2 3])), bad);
            tc.verifyError(@() epochMatrixSettings(42), bad);
            tc.verifyError(@() epochMatrixSettings([], normalize=struct('nope', 1)), unk);
            tc.verifyError(@() epochMatrixSettings([], normalize=struct('method', "log")), bad);
            tc.verifyError(@() epochMatrixSettings([], normalize=struct('scope', "unit")), bad);
            tc.verifyError(@() epochMatrixSettings([], normalize=struct('baseline', [0 0])), bad);
            tc.verifyError(@() epochMatrixSettings([], normalize=struct('baseline', [])), bad);
            tc.verifyError(@() epochMatrixSettings([], normalize="zscore"), bad);
            tc.verifyError(@() epochMatrixSettings([], normalize=struct('method', "zscore", 'baseline', [2 3])), bad);
            tc.verifyError(@() epochMatrixSettings([], keepEpochs="maybe"), bad);
            tc.verifyError(@() epochMatrixSettings([], keepEpochs=[true false]), bad);
            % a baseline outside the window only matters where it is used
            S = epochMatrixSettings([], normalize=struct('method', "minmax", 'baseline', [2 3]));
            tc.verifyEqual(S.normalize.baseline, [2 3]);
            epochMatrixSettings([], measure="auroc", normalize=struct('method', "zscore", 'baseline', [2 3]));
            % the auROC baseline and the bins only matter for spikes
            S = epochMatrixSettings([], data="LFP", measure="auroc", baseline=[]);
            tc.verifyEqual(S.data, "LFP");
            % a file that is not a settings file
            tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            f = fullfile(tmp.Folder, 'other.json');
            writeJsonFile(f, struct('schema', "something-else", 'version', 1, 'settings', struct()));
            tc.verifyError(@() epochMatrixSettings(f), bad);
            tc.verifyError(@() epochMatrixSettings(fullfile(tmp.Folder, 'missing.json')), bad);
        end

        function settingsJsonRoundTrip(tc)
            tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            f = string(fullfile(tmp.Folder, 'ofc.json'));
            ref = eventRef(line="Stim", sequence=struct('line', "Platform", 'edge', "offset"), timeRange=[-Inf 5]);
            [S, ID] = epochMatrixSettings([], ref=ref, data="detected", selection=trialSelection(groupBy="Depth"), ...
                units=struct('shanks', 1:4, 'merge', struct('enabled', true)), measure="auroc", baseline=[-1 -0.5], ...
                signal=struct('channels', [1 3], 'baseline', [-0.1 0]), SaveAs=f);
            raw = readJsonFile(f);
            tc.verifyEqual(string(raw.schema), "epoch-matrix-settings");
            tc.verifyEqual(raw.version, 1);
            [S2, ID2] = epochMatrixSettings(f);
            tc.verifyEqual(S2, S);
            tc.verifyEqual(DatasetRuns.idText(ID2), DatasetRuns.idText(ID));
            tc.verifyTrue(contains(DatasetRuns.idText(ID), '"-Inf"'));
            % options overlay a file too
            S3 = epochMatrixSettings(f, binSec=0.02);
            tc.verifyEqual(S3.binSec, 0.02);
            tc.verifyEqual(S3.units.shanks, 1:4);
        end

        function idHoldsWhatApplies(tc)
            [S, ID] = epochMatrixSettings();
            [~, ID2] = epochMatrixSettings(S, signal=struct('detrend', true));
            tc.verifyEqual(DatasetRuns.idText(ID2), DatasetRuns.idText(ID), 'A signal option leaves the spike id.');
            [~, ID3] = epochMatrixSettings(S, binSec=0.02);
            tc.verifyNotEqual(DatasetRuns.idText(ID3), DatasetRuns.idText(ID));
            [L, IL] = epochMatrixSettings(S, data="LFP");
            [~, IL2] = epochMatrixSettings(L, binSec=0.02, units=struct('shanks', 2));
            tc.verifyEqual(DatasetRuns.idText(IL2), DatasetRuns.idText(IL), 'Spike options leave the signal id.');
            [~, IL3] = epochMatrixSettings(L, signal=struct('rectify', true));
            tc.verifyNotEqual(DatasetRuns.idText(IL3), DatasetRuns.idText(IL));
            [~, IN] = epochMatrixSettings(S, normalize=struct('method', "zscore", 'baseline', [-1 0], 'scope', "group"));
            tc.verifyEqual(DatasetRuns.idText(IN), DatasetRuns.idText(ID), 'normalize is applied after assembly: not in the id.');
            % keepEpochs: in the id only when on, and its parts under their own name
            [~, ~, name] = epochMatrixSettings(S);
            tc.verifyEqual(name, "epochMatrix/units");
            [~, IK, nameK] = epochMatrixSettings(S, keepEpochs=true);
            tc.verifyTrue(IK.keepEpochs);
            tc.verifyNotEqual(DatasetRuns.idText(IK), DatasetRuns.idText(ID));
            tc.verifyEqual(nameK, "epochMatrix/units/epochs");
            [~, ~, nameL] = epochMatrixSettings(L, keepEpochs=true);
            tc.verifyEqual(nameL, "epochMatrix/LFP/epochs");
        end

        function settingsSeveralKinds(tc)
            bad = 'epochMatrixSettings:BadValue';
            % data: a row of kinds, each once, in the order given
            S = epochMatrixSettings([], data=["lfp" "units" "LFP" "AUX"], units=struct('shanks', 1:2), ...
                signal=struct('channels', 1:4, 'shanks', 1, 'magnitude', true));
            tc.verifyEqual(S.data, ["LFP" "units" "AUX"]);
            tc.verifyEqual(S.units.source, "units");
            tc.verifyEqual(epochMatrixSettings([], data={'detected', 'LFP'}).data, ["detected" "LFP"], 'A JSON list (cell).');
            tc.verifyError(@() epochMatrixSettings([], data=string.empty(1, 0)), bad);
            tc.verifyError(@() epochMatrixSettings([], data=["units" "spikes"]), bad);
            % every kind's fields are checked
            tc.verifyError(@() epochMatrixSettings([], data=["LFP" "units"], window=struct('pre', -0.004, 'post', 0.004), ...
                binSec=0.01), bad);
            tc.verifyError(@() epochMatrixSettings([], data=["units" "LFP"], signal=struct('baseline', [2 3])), bad);
            tc.verifyError(@() epochMatrixSettings([], data=["units" "LFP"], measure="auroc", ...
                normalize=struct('method', "zscore", 'baseline', [2 3])), bad, 'The signal is normalized, the auROC not.');
            % the cache identity is per kind: Kind=; epochMatrix computes one kind
            tc.verifyError(@() secondOutput(S), 'epochMatrixSettings:SeveralData');
            tc.verifyError(@() epochMatrix(tc.Runner, S, LogFcn=[]), 'epochMatrixSettings:SeveralData');
            [U, IU, nU] = epochMatrixSettings(S, Kind="units");
            [U1, IU1, nU1] = epochMatrixSettings(S, data="units");
            tc.verifyEqual(U, U1, 'Kind gives that kind alone.');
            tc.verifyEqual(DatasetRuns.idText(IU), DatasetRuns.idText(IU1));
            tc.verifyEqual([nU nU1], ["epochMatrix/units" "epochMatrix/units"]);
            L = epochMatrixSettings(S, Kind="lfp");
            tc.verifyEqual(L.data, "LFP");
            tc.verifyEqual(L.signal.channels, 1:4, 'A probe signal keeps the probe pick.');
            tc.verifyFalse(L.signal.magnitude, 'Magnitude is AUX''s when AUX is in data.');
            A = epochMatrixSettings(S, Kind="AUX");
            tc.verifyEmpty(A.signal.channels, 'Among other kinds AUX takes all its columns.');
            tc.verifyEmpty(A.signal.shanks);
            tc.verifyTrue(A.signal.magnitude);
            tc.verifyEqual(epochMatrixSettings(S, data="AUX", Kind="AUX").signal.channels, 1:4, 'Alone, AUX keeps its columns.');
            tc.verifyError(@() epochMatrixSettings(S, Kind="MUA"), bad);
            tc.verifyEqual(epochMatrixSettings([], data=["units" "detected"], Kind="detected").units.source, "detected");
            % a settings file keeps the row
            tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            f = string(fullfile(tmp.Folder, 'several.json'));
            epochMatrixSettings(S, SaveAs=f);
            tc.verifyEqual(epochMatrixSettings(f), S);
        end

        % --- spikes ---------------------------------------------------------------------------
        function spikesEqualScriptLoop(tc)
            r = tc.Runner;
            for data = ["units" "detected"]
                for measure = ["rate" "count"]
                    S = tc.spikeSettings(data=data, measure=measure);
                    [R, T] = epochMatrix(r, S, LogFcn=[]);
                    tc.verifyEqual(T.status, repmat("done", numel(r.Keys), 1));
                    [data0, units0, labels0, t0] = scriptLoop(r, S);
                    what = data + " " + measure;
                    tc.verifyEqual(R.data, data0, what);
                    tc.verifyEqual(R.groupLabels, labels0, what);
                    tc.verifyEqual(R.t, t0, what);
                    tc.verifyEqual(R.rows.unitId, units0.unitId, what);
                    tc.verifyEqual(R.rows.label, units0.label, what);
                    tc.verifyEqual(R.rowKind, "unit");
                    tc.verifyEqual(R.valueUnits, ternary(measure == "rate", "spikes/s", "spikes/bin"));
                end
            end
            % the result's fields, and its datasets table
            tc.verifyEqual(string(fieldnames(R)).', ["data" "rows" "t" "groupLabels" "rowKind" "valueUnits" ...
                "settings" "datasets" "keys" "created" "raw" "normalization" "labels" "epochs"]);
            tc.verifyEmpty(R.epochs, 'No epochs without keepEpochs.');
            tc.verifyEqual(R.labels, epochMatrixLabels(R));
            tc.verifyEqual(R.settings, S);
            tc.verifyEqual(R.datasets.Properties.VariableNames, {'key', 'name', 'subject', 'date', 'status', ...
                'message', 'nRows', 'nEpochs', 'nGroups', 'seconds'});
            tc.verifyEqual(R.datasets.key, reshape(r.Keys, [], 1));
            tc.verifyEqual(sum(R.datasets.nRows), height(R.rows));
            tc.verifyEqual(R.keys, reshape(r.Keys, [], 1));
            tc.verifyClass(R.created, 'datetime');
            for c = ["Dataset" "Subject" "Date" "Tags" "Session"]
                tc.verifyTrue(ismember(c, string(R.rows.Properties.VariableNames)), c);
            end
            tc.verifyEqual(unique(R.rows.Dataset, 'stable'), reshape(r.Keys, [], 1));
            tc.verifyEqual(size(R.data), [height(R.rows), numel(R.t), numel(R.groupLabels)]);
        end

        function scriptSpikeSettingsEqualScriptLoop(tc)
            % the script's section 3: detected spikes, neighboring channels merged, some shanks
            r = tc.Runner;
            [~, u] = selectUnits(r.source(1), struct('source', "detected", 'classes', [], 'shanks', [], ...
                'merge', struct('enabled', false)));
            sh = unique(u.shank(isfinite(u.shank)));
            tc.assumeNotEmpty(sh, 'The fixture''s detection channels have no shanks.');
            shanks = reshape(sh, 1, []);
            if numel(shanks) > 1; shanks = shanks(1:end-1); end   % so the shank filter leaves some out
            S = tc.spikeSettings(data="detected", units=struct('shanks', shanks, 'merge', struct('enabled', true)));
            [R, T] = epochMatrix(r, S, LogFcn=[]);
            tc.verifyEqual(T.status, repmat("done", numel(r.Keys), 1));
            [data0, units0, labels0, t0] = scriptLoop(r, S);
            tc.verifyEqual(R.data, data0);
            tc.verifyEqual(R.groupLabels, labels0);
            tc.verifyEqual(R.t, t0);
            tc.verifyEqual(R.rows.unitId, units0.unitId);
            tc.verifyEqual(R.rows.label, units0.label);
            tc.verifyTrue(all(ismember(R.rows.shank, shanks)));
            tc.verifyTrue(ismember("nSites", string(R.rows.Properties.VariableNames)), 'Merged units carry nSites.');
            tc.verifyEqual(R.rows.nSites, units0.nSites);
        end

        function subjectDateAndSession(tc)
            r = tc.Runner;
            R = epochMatrix(r, tc.spikeSettings(), LogFcn=[]);
            keys = reshape(r.Keys, [], 1);
            n = numel(keys);
            acq = NaT(n, 1);
            if ~isempty(r.Project)
                pk = r.Project.findByKey(keys.');
                for j = reshape(find(pk > 0), 1, [])
                    acq(j) = r.Project.Datasets(pk(j)).AcqDate;
                end
            end
            [subj, day] = subjectAndDate(reshape(r.Names, [], 1), string(r.Config.Source.NamePattern), acq);
            tc.verifyTrue(all(subj ~= "") && all(day ~= ""), 'The fixture''s names give subjects and dates.');
            date = datetime(day, 'InputFormat', 'yyyy-MM-dd');
            for j = 1:n
                m = R.rows.Dataset == keys(j);
                tc.verifyTrue(all(R.rows.Subject(m) == subj(j)), keys(j));
                tc.verifyTrue(all(R.rows.Date(m) == date(j)), keys(j));
            end
            tc.verifyEqual(R.datasets.subject, subj);
            tc.verifyEqual(R.datasets.date, date);
            % Session: per subject, the rank of the date among the datasets that give rows (the script's rule)
            gives = ismember(keys, R.keys);
            want = NaN(height(R.rows), 1);
            for s = unique(subj(gives)).'
                ds = find(gives & subj == s);
                [~, ~, rk] = unique(date(ds));
                for i = 1:numel(ds)
                    want(R.rows.Dataset == keys(ds(i))) = rk(i);
                end
            end
            tc.verifyEqual(R.rows.Session, want);
        end

        function outputsChangeRecomputes(tc)
            r = tc.Runner;
            runs = DatasetRuns();
            [S, ID] = tc.spikeSettings();
            epochMatrix(r, S, Runs=runs, LogFcn=[]);
            [~, T] = epochMatrix(r, S, Runs=runs, LogFcn=[]);
            tc.verifyEqual(T.status, repmat("cached", numel(r.Keys), 1), 'The default stamps hold.');
            stamps = string(arrayfun(@(k) outputsStamp(r.Outputs(r.index(k))), r.Keys, 'UniformOutput', false));
            tc.verifyEqual(runs.status("epochMatrix/units", r.Keys, ID, Stamps=stamps), repmat("current", numel(r.Keys), 1));
            changed = @(k) outputsStamp(r.Outputs(r.index(k))) + ternary(k == r.Keys(2), " re-sorted", "");
            tc.verifyEqual(runs.status("epochMatrix/units", r.Keys, ID, ...
                Stamps=string(arrayfun(changed, r.Keys, 'UniformOutput', false))), ["current"; "old"]);
            [~, T] = epochMatrix(r, S, Runs=runs, LogFcn=[], StampFcn=changed);
            tc.verifyEqual(T.status, ["cached"; "done"], 'Only the dataset whose outputs changed is computed.');
        end

        function aurocEqualsSpikePSTH(tc)
            tc.assumeTrue(license('test', 'Statistics_Toolbox') && exist('tiedrank', 'file') == 2, ...
                'The auROC needs the Statistics and Machine Learning Toolbox.');
            r = tc.Runner;
            S = tc.spikeSettings(measure="auroc", baseline=[-0.2 0]);
            R = epochMatrix(r, S, LogFcn=[]);
            tc.verifyEqual(R.valueUnits, "auROC");
            row = 0;
            for k = 1:numel(r.Keys)
                src = r.source(k);
                [st, u] = selectUnits(src, S.units);
                [E, G] = epochTable(src, S.ref, Window=S.window, Selection=S.selection);
                P = spikePSTH(st, E, Window=[-0.2 0.5], BinSec=0.01, Raster=false, Meta=u, Groups=G, ...
                    BaselineMode="auroc", Baseline=[-0.2 0], Auroc=struct('cutoff', "none"));
                tc.verifyEqual(R.t, P.t);
                [~, col] = ismember(G.Depth, R.groupLabels);
                n = size(P.rate, 2);
                tc.verifyEqual(R.data(row + (1:n), :, col), permute(P.rate, [2 1 3]), r.Names(k));
                row = row + n;
            end
        end

        % --- signals ----------------------------------------------------------------------------
        function lfpEqualsEvokedPotential(tc)
            r = tc.Runner;
            S = tc.spikeSettings(data="LFP", signal=struct('baseline', [-0.2 0], 'detrend', true));
            [R, T] = epochMatrix(r, S, LogFcn=[]);
            tc.verifyEqual(T.status, repmat("done", numel(r.Keys), 1));
            tc.verifyEqual(R.rowKind, "channel");
            tc.verifyEqual(R.valueUnits, "uV");
            row = 0;
            for k = 1:numel(r.Keys)
                src = r.source(k);
                [Y, fs, meta] = selectChannels(src, "LFP");
                [E, G] = epochTable(src, S.ref, Window=S.window, Selection=S.selection);
                P = evokedPotential(Y, fs, E, Window=[-0.2 0.5], Groups=G, Meta=meta, Baseline=[-0.2 0], Detrend=true);
                tc.verifyEqual(R.t, P.t);
                [~, col] = ismember(G.Depth, R.groupLabels);
                n = height(meta);
                tc.verifyEqual(R.data(row + (1:n), :, col), permute(P.mean, [2 1 3]), r.Names(k));
                tc.verifyEqual(R.rows.channel(row + (1:n)), meta.channel);
                row = row + n;
            end
            tc.verifyEqual(row, height(R.rows));
        end

        % --- keepEpochs -------------------------------------------------------------------------
        function spikeEpochsCountToTheMatrix(tc)
            r = tc.Runner;
            runs = DatasetRuns();
            [S, ID] = tc.spikeSettings(data="units", measure="count");
            R0 = epochMatrix(r, S, LogFcn=[], Runs=runs);
            R = epochMatrix(r, epochMatrixSettings(S, keepEpochs=true), LogFcn=[], Runs=runs);
            tc.verifyEqual(R.data, R0.data, 'Keeping the epochs changes no value.');
            tc.verifyEqual(runs.status("epochMatrix/units", r.Keys, ID), repmat("current", numel(r.Keys), 1), ...
                'The parts without epochs stay, under their own name.');
            tc.verifyEqual(numel(R.epochs), numel(R.keys));
            edges = [R.t - S.binSec / 2; R.t(end) + S.binSec / 2];
            for k = 1:numel(R.epochs)
                e = R.epochs(k);
                tc.verifyEqual(e.key, R.keys(k));
                tc.verifyEqual(e.rows, find(R.rows.Dataset == e.key));
                tc.verifyEmpty(e.data);
                src = r.source(e.key);
                E = epochTable(src, S.ref, Window=S.window, Selection=S.selection);
                tc.verifyEqual(removevars(e.E, 'resultGroup'), E);
                tc.verifyEqual(R.groupLabels(e.E.resultGroup), e.E.Depth, 'resultGroup names the group of R.groupLabels.');
                tc.verifyEqual(numel(e.spikes), numel(e.rows));
                % every row's spikes, binned per epoch and averaged per group, give R.data
                for i = 1:numel(e.rows)
                    sp = e.spikes(i);
                    tc.verifyTrue(all(sp.times >= edges(1) & sp.times < edges(end)));
                    for g = reshape(unique(e.E.resultGroup), 1, [])
                        ep = find(e.E.resultGroup == g);
                        c = zeros(numel(R.t), numel(ep));
                        for j = 1:numel(ep)
                            c(:, j) = histcounts(sp.times(sp.epoch == ep(j)), edges).';
                        end
                        tc.verifyEqual(R.data(e.rows(i), :, g), mean(c, 2).', 'AbsTol', 1e-12, ...
                            sprintf('%s row %d group %d', e.key, i, g));
                    end
                end
            end
        end

        function lfpEpochsAverageToTheMatrix(tc)
            r = tc.Runner;
            S = tc.spikeSettings(data="LFP", signal=struct('baseline', [-0.2 0], 'detrend', true, 'rectify', true));
            R0 = epochMatrix(r, S, LogFcn=[]);
            R = epochMatrix(r, epochMatrixSettings(S, keepEpochs=true), LogFcn=[]);
            tc.verifyEqual(R.data, R0.data);
            for k = 1:numel(R.epochs)
                e = R.epochs(k);
                tc.verifyEmpty(e.spikes);
                tc.verifyClass(e.data, 'single');
                tc.verifyEqual(size(e.data), [numel(e.rows), numel(R.t), height(e.E)]);
                tc.verifyEqual(R.datasets.nEpochs(R.datasets.key == e.key), height(e.E));
                for g = reshape(unique(e.E.resultGroup), 1, [])
                    m = mean(double(e.data(:, :, e.E.resultGroup == g)), 3);
                    tc.verifyEqual(m, R.data(e.rows, :, g), 'RelTol', 1e-5, 'AbsTol', 1e-4);
                end
            end
            % normalization leaves the epochs as they are
            Rz = epochMatrixNormalize(R, struct('method', "zscore", 'baseline', [-0.2 0]));
            tc.verifyEqual(Rz.epochs, R.epochs);
        end

        function assemblyKeepsPartsWithoutEpochs(tc)
            S = epochMatrixSettings([], keepEpochs=true);
            R = epochMatrix({makePart("a", [1; 2], 2)}, S);
            tc.verifyEqual(R.epochs.key, "a");
            tc.verifyEqual(R.epochs.rows, [1; 2]);
            tc.verifyEmpty(R.epochs.E);
        end

        function channelAndShankPicks(tc)
            r = tc.Runner;
            R = epochMatrix(r, tc.spikeSettings(data="LFP", signal=struct('channels', [1 3])), LogFcn=[]);
            tc.verifyEqual(R.rows.recordingChannel, repmat([1; 3], numel(r.Keys), 1), 'signal.channels are recording channels.');
            tc.verifyEqual(R.rows.channel, repmat([1; 3], numel(r.Keys), 1), 'The fixture''s columns are its recording channels.');
            try   % no channel picked: the dataset is skipped, saying why, so nothing is left to assemble
                epochMatrix(r, tc.spikeSettings(data="LFP", signal=struct('channels', 999)), LogFcn=[], Datasets=r.Keys(1));
                tc.verifyFail('A recording channel the dataset lacks leaves no rows.');
            catch ME
                tc.verifyEqual(string(ME.identifier), "epochMatrix:NoData");
                tc.verifySubstring(ME.message, 'recording channel(s) 999');
            end
            [~, ~, meta] = selectChannels(r.source(1), "LFP");
            sh = unique(meta.shank(isfinite(meta.shank)));
            tc.assumeNotEmpty(sh, 'The fixture''s LFP channels have no shanks.');
            pick = sh(end);
            S = tc.spikeSettings(data="LFP", signal=struct('shanks', pick));
            R = epochMatrix(r, S, LogFcn=[]);
            first = R.rows.Dataset == r.Keys(1);
            tc.verifyEqual(R.rows.channel(first), meta.channel(meta.shank == pick));
            tc.verifyTrue(all(R.rows.shank == pick));
            % the picked channels are the full run's rows on that shank
            Rall = epochMatrix(r, tc.spikeSettings(data="LFP"), LogFcn=[]);
            tc.verifyEqual(R.data, Rall.data(Rall.rows.shank == pick, :, :));
        end

        function auxMagnitudeIsOneRow(tc)
            r = tc.Runner;
            src = r.source(1);
            tc.assumeTrue(src.signals.AUX, 'The fixture has no AUX extract.');
            R = epochMatrix(r, tc.spikeSettings(data="AUX", signal=struct('magnitude', true)), LogFcn=[]);
            tc.verifyEqual(height(R.rows), nnz(R.datasets.status == "done"));
            tc.verifyTrue(all(startsWith(R.rows.label, "|")));
            tc.verifyEqual(R.valueUnits, "V");
            [Y, fs, meta] = selectChannels(src, "AUX");
            [E, G] = epochTable(src, eventRef(line="Stim"), Window=epochWindow(pre=-0.2, post=0.5), ...
                Selection=trialSelection(groupBy="Depth", groupOrder="descending"));
            P = evokedPotential(Y, fs, E, Window=[-0.2 0.5], Groups=G, Meta=meta, Magnitude=true, Units="V");
            [~, col] = ismember(G.Depth, R.groupLabels);
            tc.verifyEqual(R.data(1, :, col), permute(P.mean, [2 1 3]));
        end

        function missingSignalIsSkipped(tc)
            r = tc.Runner;
            src = r.source(1);
            tc.assumeFalse(src.signals.SPIKE, 'The fixture has a SPIKE extract.');
            runs = DatasetRuns();
            [S, ID] = tc.spikeSettings(data="SPIKE");
            tc.verifyError(@() epochMatrix(r, S, Runs=runs, LogFcn=[]), 'epochMatrix:NoData');
            tc.verifyEqual(runs.Last.status, repmat("skipped", numel(r.Keys), 1));
            tc.verifyEqual(runs.status("epochMatrix/SPIKE", r.Keys, ID), repmat("skipped", numel(r.Keys), 1));
        end

        % --- cache, cancel ---------------------------------------------------------------------
        function cancelKeepsFinishedParts(tc)
            r = tc.Runner;
            tc.assumeGreaterThanOrEqual(numel(r.Keys), 2);
            runs = DatasetRuns();
            [S, ID] = tc.spikeSettings();
            stop = @(f, msg) cancelWhen(f > 0);   % the second dataset's progress call
            tc.verifyError(@() epochMatrix(r, S, Runs=runs, ProgressFcn=stop, LogFcn=[]), 'epochMatrix:Canceled');
            st = runs.status("epochMatrix/units", r.Keys, ID);
            tc.verifyEqual(st(1), "current");
            tc.verifyEqual(st(2), "");
            [R, T] = epochMatrix(r, S, Runs=runs, LogFcn=[]);
            tc.verifyEqual(T.status(1:2), ["cached"; "done"]);
            Rfresh = epochMatrix(r, S, LogFcn=[]);
            tc.verifyEqual(R.data, Rfresh.data);
            tc.verifyEqual(R.rows, Rfresh.rows);
            % a cancel from CheckFcn too
            runs2 = DatasetRuns();
            tc.verifyError(@() epochMatrix(r, S, Runs=runs2, CheckFcn=@() cancelWhen(true), LogFcn=[]), ...
                'epochMatrix:Canceled');
            tc.verifyEqual(runs2.Last.status, repmat("canceled", numel(r.Keys), 1));
            tc.verifyEmpty(runs2.Entries);
        end

        function signalOptionKeepsSpikeParts(tc)
            r = tc.Runner;
            runs = DatasetRuns();
            S = tc.spikeSettings();
            R1 = epochMatrix(r, S, Runs=runs, LogFcn=[]);
            S2 = epochMatrixSettings(S, signal=struct('detrend', true, 'channels', 2));
            [R2, T] = epochMatrix(r, S2, Runs=runs, LogFcn=[]);
            tc.verifyEqual(T.status, repmat("cached", numel(r.Keys), 1));
            tc.verifyEqual(R2.data, R1.data);
            % a signal run keeps its own parts beside them
            L = epochMatrixSettings(S, data="LFP");
            epochMatrix(r, L, Runs=runs, LogFcn=[]);
            [~, T] = epochMatrix(r, S, Runs=runs, LogFcn=[]);
            tc.verifyEqual(T.status, repmat("cached", numel(r.Keys), 1));
            [~, T] = epochMatrix(r, L, Runs=runs, LogFcn=[]);
            tc.verifyEqual(T.status, repmat("cached", numel(r.Keys), 1));
            % a spike option recomputes; Recompute does too
            [~, T] = epochMatrix(r, epochMatrixSettings(S, binSec=0.02), Runs=runs, LogFcn=[]);
            tc.verifyEqual(T.status, repmat("done", numel(r.Keys), 1));
            [~, T] = epochMatrix(r, S, Runs=runs, Recompute=true, LogFcn=[]);
            tc.verifyEqual(T.status, repmat("done", numel(r.Keys), 1));
            % Datasets= picks some
            [R, T] = epochMatrix(r, S, Runs=runs, Datasets=r.Keys(2), LogFcn=[]);
            tc.verifyEqual(T.key, r.Keys(2));
            tc.verifyEqual(R.keys, r.Keys(2));
            tc.verifyError(@() epochMatrix(r, S, Datasets="nope", LogFcn=[]), 'epochMatrix:UnknownDataset');
        end

        function configIsScanned(tc)
            [R, T] = epochMatrix(tc.Config, tc.spikeSettings(), LogFcn=[]);
            tc.verifyEqual(T.key, reshape(tc.Runner.Keys, [], 1));
            tc.verifyEqual(R.keys, reshape(tc.Runner.Keys, [], 1));
        end

        % --- labels -------------------------------------------------------------------------------
        function labelsInWords(tc)
            parts = makePart("A", [3; 1], 2);
            S = epochMatrixSettings([], ref=eventRef(line="Stim", sequence=struct('line', "Platform", 'edge', "offset"), alignStep=0), ...
                window=epochWindow(pre=-1, post=1), selection=trialSelection(response="Hit", groupBy="Depth", groupOrder="descending"));
            L = epochMatrix(parts, S).labels;
            tc.verifyEqual(L.value, "Firing rate (spikes/s)");
            tc.verifyEqual(L.measure, "Firing rate");
            tc.verifyEqual(L.time, "Time from Stim onset (s)", 'The aligned event, not the last step.');
            tc.verifyEqual(L.event, "Stim onset then Platform offset (aligned to Stim onset)");
            tc.verifyEqual(L.group, "Depth");
            tc.verifyEqual(L.groups, ["Depth 3"; "Depth 1"]);
            tc.verifyEqual(L.rows, "units");
            tc.verifyEqual(L.trials, "Hit trials");
            tc.verifyEqual(L.window, "-1 to 1 s");
            tc.verifyEqual(L.bins, "10 ms bins");
            tc.verifyEqual(L.baseline, "");
            tc.verifyEqual(L.description, "Firing rate of units in 10 ms bins, -1 to 1 s from Stim onset then Platform offset " + ...
                "(aligned to Stim onset); Hit trials by Depth (descending)");

            % auROC: its baseline; no groupBy: one "All trials" group
            p = makePart("A", "all", 1); p.valueUnits = "auROC";
            S = epochMatrixSettings([], ref=eventRef(line="Stim"), measure="auroc", baseline=[-0.5 0], ...
                selection=trialSelection(response=["Hit" "Miss"], filter="Depth > 0"));
            L = epochMatrix(p, S).labels;
            tc.verifyEqual([L.value L.baseline L.trials L.group], ["auROC vs. baseline" "baseline -0.5 to 0 s" ...
                "Hit or Miss trials where Depth > 0" ""]);
            tc.verifyEqual(L.groups, "All trials");

            % a signal: rectified, the median, a subtracted baseline, no bins
            p = makePart("A", [1; 2], 1); p.valueUnits = "uV";
            S = epochMatrixSettings([], data="MUA", ref=eventRef(line="Stim"), ...
                signal=struct('rectify', true, 'statistic', "median", 'baseline', [-0.2 0]));
            L = epochMatrix(p, S).labels;
            tc.verifyEqual([L.value L.measure L.rows L.bins L.baseline], ["Rectified MUA, median over epochs (uV)" ...
                "Rectified MUA median" "MUA channels" "" "baseline -0.2 to 0 s subtracted"]);
        end

        % --- normalization ------------------------------------------------------------------------
        function normalizeMethods(tc)
            % each method by hand, per row (the groups pooled) and per group
            A = makePart("A", [1; 2], 2);
            A.values(:, 2, :) = A.values(:, 2, :) .^ 1.5;   % rows that differ in their spread
            R0 = epochMatrix(A, []);
            raw = R0.data;
            tc.verifyEmpty(R0.raw);
            tc.verifyEqual(R0.normalization.method, "none");
            inB = R0.t >= 0 & R0.t <= 0.1;   % t 0 and 0.1
            for scope = ["row" "group"]
                if scope == "row"
                    Xb = reshape(raw(:, inB, :), 2, []);
                    X = reshape(raw, 2, []);
                else
                    Xb = raw(:, inB, :);
                    X = raw;
                end
                mu = mean(Xb, 2);
                sd = std(Xb, 0, 2);
                want = struct('subtract', raw - mu, 'ratio', raw ./ mu, 'percent', 100 * (raw - mu) ./ abs(mu), ...
                    'zscore', (raw - mu) ./ sd, 'minmax', (raw - min(X, [], 2)) ./ (max(X, [], 2) - min(X, [], 2)));
                units = struct('subtract', "spikes/s", 'ratio', "x baseline", 'percent', "%", 'zscore', "z", 'minmax', "0-1");
                for m = string(fieldnames(want)).'
                    S = epochMatrixSettings([], normalize=struct('method', m, 'baseline', [0 0.1], 'scope', scope));
                    R = epochMatrix(A, S);
                    tc.verifyEqual(R.data, want.(m), 'AbsTol', 1e-9, m + " " + scope);
                    tc.verifyEqual(R.raw, raw);
                    tc.verifyEqual(R.data, (R.raw - R.normalization.center) ./ R.normalization.scale, 'AbsTol', 1e-12);
                    tc.verifyEqual(R.valueUnits, units.(m));
                    tc.verifyEqual(R.normalization.rawUnits, "spikes/s");
                    tc.verifyEqual([R.normalization.method R.normalization.scope], [m scope]);
                    tc.verifyFalse(any(R.normalization.undefined(:)));
                    if m == "minmax"
                        tc.verifyEmpty(R.normalization.baseline);
                    else
                        tc.verifyEqual([R.normalization.baseline R.normalization.nBaseline], [0 0.1 2]);
                    end
                end
            end
            % normalized again from the raw values: no stacking; "none" gives them back
            Rs = epochMatrix(A, epochMatrixSettings([], normalize=struct('method', "subtract", 'baseline', [0 0.1])));
            Rz = epochMatrixNormalize(Rs, struct('method', "zscore"));
            tc.verifyEqual(Rz.data, epochMatrix(A, epochMatrixSettings([], normalize=struct('method', "zscore", ...
                'baseline', [0 0.1]))).data, 'AbsTol', 1e-12);
            tc.verifyEqual(Rz.settings.normalize.baseline, [0 0.1], 'The other fields are kept.');
            Rn = epochMatrixNormalize(Rz, struct('method', "none"));
            tc.verifyEqual(Rn.data, raw);
            tc.verifyEmpty(Rn.raw);
            tc.verifyEqual(Rn.valueUnits, "spikes/s");
            tc.verifyEqual(epochMatrixNormalize(Rz).data, Rz.data, 'Its own settings again: the same.');
        end

        function normalizeUndefinedAndMissing(tc)
            % a flat baseline gives NaN and is marked; a group a dataset lacks stays NaN, unmarked
            A = makePart("A", [1; 2], 2);
            A.values(1:2, 1, 1) = 5;   % row 1, group 1: the same value at both baseline times
            B = makePart("B", 1, 1);   % no group 2
            S = epochMatrixSettings([], normalize=struct('method', "zscore", 'baseline', [0 0.1], 'scope', "group"));
            R = epochMatrix([A B], S);
            tc.verifyTrue(all(isnan(R.data(1, :, 1))));
            tc.verifyTrue(all(isfinite(R.data(1, :, 2))));
            tc.verifyTrue(all(isfinite(R.data(2, :, :)), 'all'));
            tc.verifyTrue(all(isnan(R.data(3, :, 2))));
            tc.verifyEqual(R.normalization.undefined, logical([1 0; 0 0; 0 0]));
            % per row the groups are pooled: row 1's baseline varies across them
            R = epochMatrix([A B], epochMatrixSettings(S, normalize=struct('scope', "row")));
            tc.verifyTrue(all(isfinite(R.data(1, :, :)), 'all'));
            tc.verifyFalse(any(R.normalization.undefined(:)));
            % no time of R.t in the baseline
            tc.verifyError(@() epochMatrix(A, epochMatrixSettings(S, normalize=struct('baseline', [0.35 0.5]))), ...
                'epochMatrixNormalize:NoBaseline');
            tc.verifyError(@() epochMatrixNormalize(struct('data', 1)), 'epochMatrixNormalize:BadResult');
            % auROC is not normalized
            p = makePart("A", [1; 2], 1); p.valueUnits = "auROC";
            R = epochMatrix(p, epochMatrixSettings([], measure="auroc", normalize=struct('method', "zscore")));
            tc.verifyEqual(R.normalization.method, "none");
            tc.verifyEqual(R.settings.normalize.method, "zscore");
            tc.verifyEqual(R.valueUnits, "auROC");
            tc.verifyEmpty(R.raw);
        end

        function normalizeLabels(tc)
            A = makePart("A", [3; 1], 2);
            S = epochMatrixSettings([], ref=eventRef(line="Stim"), normalize=struct('method', "zscore", 'baseline', [0 0.1]));
            L = epochMatrix(A, S).labels;
            tc.verifyEqual([L.value L.normalization], ["Firing rate (z-score vs. baseline)" ...
                "z-scored against the baseline 0 to 0.1 s"]);
            tc.verifyEqual(L.description, "Firing rate of units in 10 ms bins, -1 to 1 s from Stim onset, " + ...
                "z-scored against the baseline 0 to 0.1 s; all trials");
            L = epochMatrix(A, epochMatrixSettings(S, normalize=struct('method', "subtract", 'scope', "group"))).labels;
            tc.verifyEqual([L.value L.normalization], ["Firing rate - baseline (spikes/s)" ...
                "the baseline 0 to 0.1 s subtracted, per group"]);
            L = epochMatrix(A, epochMatrixSettings(S, normalize=struct('method', "minmax"))).labels;
            tc.verifyEqual([L.value L.normalization], ["Firing rate (min-max normalized)" "scaled 0 to 1 over the window"]);
            L = epochMatrix(A, epochMatrixSettings(S, normalize=struct('method', "percent"))).labels;
            tc.verifyEqual(L.value, "Firing rate (% change from baseline)");
            L = epochMatrix(A, epochMatrixSettings(S, normalize=struct('method', "none"))).labels;
            tc.verifyEqual([L.value L.normalization], ["Firing rate (spikes/s)" ""]);
            p = makePart("A", [1; 2], 1); p.valueUnits = "uV";
            L = epochMatrix(p, epochMatrixSettings([], data="LFP", normalize=struct('method', "ratio", 'baseline', [0 0.1]))).labels;
            tc.verifyEqual(L.value, "LFP, mean over epochs / baseline");
        end

        % --- assembly -----------------------------------------------------------------------------
        function labelOrders(tc)
            cases = { ...
                {[3; 2; 1], [2; 1; 0]}, [0; 1; 2; 3], [3; 2; 1; 0], [3; 2; 1; 0]; ...
                {[1; NaN], [NaN; 2]},   [1; 2; NaN],   [NaN; 2; 1],   [1; NaN; 2]; ...
                {["b"; "a"], ["c"; "a"]}, ["a"; "b"; "c"], ["c"; "b"; "a"], ["b"; "a"; "c"]; ...
                {[2; 1], "x"},          ["1"; "2"; "x"], ["x"; "2"; "1"], ["2"; "1"; "x"]};
            orders = ["ascending" "descending" "appearance"];
            for i = 1:size(cases, 1)
                labs = cases{i, 1};
                parts = [makePart("A", labs{1}, 2), makePart("B", labs{2}, 3)];
                for o = 1:3
                    S = epochMatrixSettings([], selection=struct('groupOrder', orders(o)));
                    R = epochMatrix(parts, S);
                    want = cases{i, 1 + o};
                    what = sprintf('case %d, %s', i, orders(o));
                    tc.verifyEqual(R.groupLabels, want, what);
                    % every part's group lands in its label's column
                    for p = 1:2
                        rows = find(R.rows.Dataset == parts(p).key);
                        for g = 1:numel(parts(p).labels)
                            c = labelColumn(R.groupLabels, parts(p).labels(g));
                            tc.verifyEqual(R.data(rows, :, c), parts(p).values(:, :, g).', what);
                        end
                        others = setdiff(1:numel(R.groupLabels), arrayfun(@(x) labelColumn(R.groupLabels, x), parts(p).labels));
                        tc.verifyTrue(all(isnan(R.data(rows, :, others)), 'all'), what + ": NaN where a dataset has no group");
                    end
                end
            end
        end

        function rowsUnionAndSession(tc)
            A = makePart("A", [1; 2], 2);
            B = makePart("B", [1; 2], 1);
            C = makePart("C", [1; 2], 1);
            D = makePart("D", [1; 2], 1);
            B.rows.nSites = 3;
            B.rows.sites = "1,2,3";
            info = table(["A"; "B"; "C"; "D"], ["a"; "b"; "c"; "d"], ["s1"; "s1"; "s2"; "s1"], ...
                [datetime(2026, 1, 5); datetime(2026, 1, 2); datetime(2026, 1, 9); NaT], ["x;y"; ""; "y"; ""], ...
                'VariableNames', {'key', 'name', 'subject', 'date', 'tags'});
            R = epochMatrix([A B C D], [], Info=info);
            tc.verifyEqual(R.rows.Dataset, ["A"; "A"; "B"; "C"; "D"]);
            tc.verifyEqual(R.rows.Subject, ["s1"; "s1"; "s1"; "s2"; "s1"]);
            tc.verifyEqual(R.rows.Session, [2; 2; 1; 1; NaN]);
            tc.verifyEqual(R.rows.Tags, ["x;y"; "x;y"; ""; "y"; ""]);
            tc.verifyEqual(R.rows.nSites, [NaN; NaN; 3; NaN; NaN]);
            tc.verifyEqual(ismissing(R.rows.sites), [true; true; false; true; true]);
            tc.verifyEqual(R.datasets.name, ["a"; "b"; "c"; "d"]);
            tc.verifyEqual(R.datasets.nRows, [2; 1; 1; 1]);
            tc.verifyEqual(R.datasets.status, repmat("done", 4, 1));
            tc.verifyEqual(R.keys, ["A"; "B"; "C"; "D"]);
            % a part without rows contributes nothing
            E = makePart("E", [1; 2], 0);
            R = epochMatrix([A E], []);
            tc.verifyEqual(R.keys, "A");
            tc.verifyError(@() epochMatrix(E, []), 'epochMatrix:NoData');
        end

        function mixedLabelsLineUp(tc)
            % one parameter, numeric in one dataset and text in another: the text of the value
            A = makePart("A", [3; 0.5; 10], 2);
            B = makePart("B", ["10"; "3"; "deep"], 1);
            for o = ["ascending" "descending" "appearance"]
                R = epochMatrix([A B], epochMatrixSettings([], selection=struct('groupOrder', o)));
                switch o
                    case "ascending";  want = ["0.5"; "3"; "10"; "deep"];
                    case "descending"; want = ["deep"; "10"; "3"; "0.5"];
                    otherwise;         want = ["3"; "0.5"; "10"; "deep"];
                end
                tc.verifyEqual(R.groupLabels, want, o);
                a = R.rows.Dataset == "A";
                b = R.rows.Dataset == "B";
                c3 = find(R.groupLabels == "3");
                tc.verifyEqual(R.data(a, :, c3), A.values(:, :, 1).', o);
                tc.verifyEqual(R.data(b, :, c3), B.values(:, :, 2).', o + ': Depth 3 and "3" are one group');
                c10 = find(R.groupLabels == "10");
                tc.verifyEqual(R.data(b, :, c10), B.values(:, :, 1).', o);
            end
            % text only: alphabetical, as selectTrials sorts a text parameter
            C = makePart("C", ["low"; "high"], 1);
            R = epochMatrix(C, []);
            tc.verifyEqual(R.groupLabels, ["high"; "low"]);
        end

        function twoParametersOrderByValue(tc)
            A = makePart("A", ["Depth = 10, Level = b"; "Depth = 9, Level = a"], 2);
            A.groupValues = table([10; 9], ["b"; "a"], 'VariableNames', {'Depth', 'Level'});
            B = makePart("B", ["Depth = 9, Level = a"; "Depth = 9, Level = c"], 1);
            B.groupValues = table([9; 9], ["a"; "c"], 'VariableNames', {'Depth', 'Level'});
            asc = ["Depth = 9, Level = a"; "Depth = 9, Level = c"; "Depth = 10, Level = b"];
            orders = ["ascending" "descending" "appearance"];
            wants = {asc, flipud(asc), ["Depth = 10, Level = b"; "Depth = 9, Level = a"; "Depth = 9, Level = c"]};
            for o = 1:3
                R = epochMatrix([A B], epochMatrixSettings([], selection=struct('groupOrder', orders(o))));
                tc.verifyEqual(R.groupLabels, wants{o}, orders(o));
                a = R.rows.Dataset == "A";
                b = R.rows.Dataset == "B";
                g9a = find(R.groupLabels == "Depth = 9, Level = a");
                tc.verifyEqual(R.data(a, :, g9a), A.values(:, :, 2).', orders(o));
                tc.verifyEqual(R.data(b, :, g9a), B.values(:, :, 1).', orders(o) + ': matched by value');
                g10 = find(R.groupLabels == "Depth = 10, Level = b");
                tc.verifyTrue(all(isnan(R.data(b, :, g10)), 'all'), orders(o));
            end
            % Depth as text in one dataset: matched as text, ordered by value still
            B.groupValues.Depth = ["9"; "9"];
            R = epochMatrix([A B], epochMatrixSettings([], selection=struct('groupOrder', "ascending")));
            tc.verifyEqual(R.groupLabels, asc);
            tc.verifyEqual(R.data(R.rows.Dataset == "B", :, 1), B.values(:, :, 1).');
            % parts grouped by different parameters cannot be matched
            C = B;
            C.groupValues.Properties.VariableNames = {'Depth', 'Side'};
            tc.verifyError(@() epochMatrix([A C], []), 'epochMatrix:BadPart');
        end

        function integerColumnsBecomeDouble(tc)
            A = makePart("A", [1; 2], 2);
            B = makePart("B", [1; 2], 1);
            C = makePart("C", [1; 2], 1);
            A.rows.x = [1.5; 2];       % the first holder is double ...
            B.rows.x = int32(3);       % ... a later one integer, and C lacks it
            A.rows.y = int16([1; 2]);  % every table holds y, of two classes
            B.rows.y = 2.5;
            C.rows.y = int16(4);
            R = epochMatrix([A B C], []);
            tc.verifyClass(R.rows.x, 'double');
            tc.verifyEqual(R.rows.x, [1.5; 2; 3; NaN]);
            tc.verifyClass(R.rows.y, 'double');
            tc.verifyEqual(R.rows.y, [1; 2; 2.5; 4]);
            % one integer class everywhere stays integer
            A.rows.z = uint8([1; 2]); B.rows.z = uint8(3); C.rows.z = uint8(4);
            R = epochMatrix([A B C], []);
            tc.verifyClass(R.rows.z, 'uint8');
        end

        function timeBaseMustMatch(tc)
            A = makePart("A", [1; 2], 2);
            B = makePart("B", [1; 2], 2);
            B.t = B.t * 2;   % e.g. another signal rate
            try
                epochMatrix([A B], []);
                tc.verifyFail('Different time bases must raise epochMatrix:TimeBase.');
            catch ME
                tc.verifyEqual(ME.identifier, 'epochMatrix:TimeBase');
                tc.verifyTrue(contains(ME.message, "B"), 'The message names the dataset.');
            end
            C = makePart("C", [1; 2], 2);
            C.values = C.values(:, 1, :);   % does not fit its rows
            tc.verifyError(@() epochMatrix([A C], []), 'epochMatrix:BadPart');
        end
    end
end


function [data, units, groupLabels, binCenters] = scriptLoop(r, S)
%scriptLoop  S_OFCEPhys_Analysis.m's section 4, written out (lines 135-190), for S's settings.
%   spikeSource, shanks and mergeChannels are S.data, S.units.shanks and
%   S.units.merge.enabled, as the script's section 3 sets them.
win = S.window;
spikeSource = S.data;
shanks = S.units.shanks;
mergeChannels = S.units.merge.enabled;
nD = numel(r.Keys);
unitsD = cell(nD, 1);
dataD = cell(nD, 1);
labelsD = cell(nD, 1);
tD = cell(nD, 1);
for d = 1:nD
    src = r.source(d);
    [spikes, u] = selectUnits(src, struct('source', spikeSource, 'classes', [], 'shanks', shanks, ...
        'merge', struct('enabled', mergeChannels)));
    [E, G] = epochTable(src, S.ref, Window=win, Selection=S.selection);
    psthArgs = {'Window', [win.pre win.post], 'BinSec', S.binSec, 'Raster', false, 'Meta', u, 'Groups', G};
    R = spikePSTH(spikes, E, psthArgs{:}, 'Measure', S.measure);
    dataD{d} = R.rate;
    tD{d} = R.t;
    labelsD{d} = G.Depth;
    unitsD{d} = u;
end
ok = ~cellfun(@isempty, unitsD);
units = vertcat(unitsD{ok});
groupLabels = sort(unique(vertcat(labelsD{ok})), 'descend');
binCenters = tD{find(ok, 1)};
data = nan(height(units), numel(binCenters), numel(groupLabels));
row = 0;
for d = find(ok).'
    v = permute(dataD{d}, [2 1 3]);
    [~, col] = ismember(labelsD{d}, groupLabels);
    data(row + (1:size(v, 1)), :, col) = v;
    row = row + size(v, 1);
end
end


function p = makePart(key, labels, nRows)
%makePart  A hand-made part: 4 times, NROWS rows, a group per label; values that tell the cells apart.
nT = 4;
nG = numel(labels);
v = reshape(1:nT * nRows * nG, nT, nRows, nG) + 1000 * double(key{1}(1));
p = struct('key', key, 'values', v, 't', (0:nT - 1).' * 0.1, 'labels', labels, ...
    'rows', table(key + "_r" + (1:nRows).', 'VariableNames', {'label'}), 'nEpochs', ones(nG, 1), ...
    'valueUnits', "spikes/s");
end


function c = labelColumn(groupLabels, x)
if isnumeric(groupLabels) && isnan(x)
    c = find(isnan(groupLabels), 1);
elseif isstring(groupLabels) && isnumeric(x)
    c = find(groupLabels == string(x), 1);
else
    c = find(groupLabels == x, 1);
end
end


function secondOutput(S)
%secondOutput  epochMatrixSettings asked for the cache identity (verifyError calls with no output).
[~, ~] = epochMatrixSettings(S);
end


function cancelWhen(tf)
if tf
    error('Test:Canceled', 'Canceled by the test.');
end
end


function v = ternary(tf, a, b)
if tf; v = a; else; v = b; end
end
