classdef test_PopulationAnalysis < matlab.unittest.TestCase
    %test_PopulationAnalysis  populationAnalysis, populationSummary, renderPopulation, writePopulation.
    %   Over the analysis fixture (two synthetic datasets run through the
    %   pipeline): P.units holds selectUnits' units of every dataset with
    %   their rates; P.psth is spikePSTH's per dataset, pooled over the
    %   selection's groups; P.tuning is responseStats' per-level rates on
    %   the union of levels; the summary's counts add up and its means are
    %   the means of its units; the correction runs over every unit or over
    %   each dataset (Family); the files are written; the errors. Only the
    %   correction test calls the toolbox's tests (skipped without the
    %   Statistics and Machine Learning Toolbox).
    %
    %   Usage:  runtests("test_PopulationAnalysis")

    properties (SetAccess = private)
        Fixture = []
        Config = []
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
            cfg.Defaults.EventRef.line = "Stim";
            cfg.Defaults.Window = struct('mode', "fixed", 'pre', -0.2, 'post', 0.5, 'stop', []);
            cfg.Defaults.Selection.groupBy = "Depth";    % not used: one PSTH per unit over every epoch
            tc.Config = cfg;
        end
    end

    methods (Test)
        function unitsPsthAndTuning(tc)
            [P, S] = populationAnalysis(tc.Config, Tests=false, Param="Depth", LogFcn=[]);
            r = EphysAnalysisRunner(tc.Config, LogFcn=[]);
            tc.verifyEqual(P.datasets.status, repmat("done", numel(r.Outputs), 1));
            ref = eventRef(line="Stim");
            sel = trialSelection();
            nAll = 0;
            for k = 1:numel(r.Outputs)
                src = r.source(k);
                [st, meta] = selectUnits(src, struct());
                E = epochTable(src, ref, Window=epochWindow(pre=-0.2, post=0.5), Selection=sel);
                R = spikePSTH(st, E, Window=[-0.2 0.5], BinSec=0.01, Raster=false);
                rows = P.units.datasetKey == r.Keys(k);
                tc.verifyEqual(P.units.unitId(rows), meta.unitId, sprintf('%s: selectUnits'' units', r.Names(k)));
                tc.verifyEqual(P.units.rateHz(rows), meta.nSpikes / src.durationSec, 'RelTol', 1e-12);
                tc.verifyEqual(P.psth.rate(:, rows), R.rate(:, :, 1), sprintf('%s: spikePSTH over every epoch', r.Names(k)));
                tc.verifyEqual(P.datasets.nEpochs(k), height(E));
                Er = responseEpochs(src, ref, sel, Param="Depth");
                [T, info] = responseStats(st, Er, Param="Depth", Tests=false);
                tc.verifyEqual(P.units.responseRate(rows), T.responseRate);
                [~, loc] = ismember(info.levels, P.tuning.levels);
                tc.verifyEqual(P.tuning.rate(loc, rows), info.levelRate, sprintf('%s: per-level rates', r.Names(k)));
                tc.verifyEqual(P.tuning.n(loc, rows), info.levelN);
                nAll = nAll + height(meta);
            end
            tc.verifyEqual(height(P.units), nAll);
            tc.verifyEqual(P.psth.t, R.t(:));
            tc.verifyTrue(all(isnan(P.units.pEvoked)) && ~any(P.units.responsive), 'Tests=false: no p');
            % the summary adds up
            G = S.groups;
            tc.verifyEqual(sum(G.nUnits), height(P.units));
            for g = 1:height(G)
                rows = S.unitGroup == g;
                tc.verifyEqual(G.nUnits(g), nnz(rows));
                tc.verifyEqual(S.psth.mean(:, g), mean(P.psth.rate(:, rows), 2, 'omitnan'), 'AbsTol', 1e-12);
                tc.verifyEqual(G.meanRateHz(g), mean(P.units.rateHz(rows), 'omitnan'), 'AbsTol', 1e-12);
            end
        end

        function groupings(tc)
            P = populationAnalysis(tc.Config, Tests=false, LogFcn=[]);
            S = populationSummary(P, GroupBy=string.empty(1, 0));
            tc.verifyEqual(S.groups.group, "all");
            tc.verifyEqual(S.groups.nUnits, height(P.units));
            S = populationSummary(P, GroupBy=["dataset" "shank"]);
            tc.verifyEqual(sum(S.groups.nUnits), height(P.units));
            tc.verifyTrue(all(ismember(["dataset" "shank"], string(S.groups.Properties.VariableNames))));
            S = populationSummary(P, GroupBy="depth", DepthBinUm=50);
            lo = floor(P.units.y / 50) * 50;
            lo(isnan(lo)) = Inf;                  % "y unknown": one group
            for g = 1:height(S.groups)
                rows = S.unitGroup == g;
                tc.verifyEqual(numel(unique(lo(rows))), 1, 'a depth group holds one 50 um bin');
            end
            tc.verifyError(@() populationSummary(P, GroupBy="colour"), 'populationSummary:BadGroupBy');
            tc.verifyError(@() populationSummary(P, GroupBy="tuned"), 'populationSummary:BadGroupBy');
        end

        function correctionFamily(tc)
            tc.assumeTrue(license('test', 'Statistics_Toolbox') && exist('signrank', 'file') > 0 ...
                && exist('kruskalwallis', 'file') > 0, "needs the Statistics and Machine Learning Toolbox");
            P = populationAnalysis(tc.Config, Param="Depth", Correction="holm", LogFcn=[]);
            tc.verifyEqual(P.units.qEvoked, pAdjust(P.units.pEvoked, "holm"), 'Family "all": one Holm over every unit');
            tc.verifyEqual(P.units.responsive, P.units.qEvoked <= 0.05);
            tc.verifyEqual(P.units.qTuning, pAdjust(P.units.pTuning, "holm"));
            Pd = populationAnalysis(tc.Config, Param="Depth", Correction="holm", Family="dataset", LogFcn=[]);
            tc.verifyEqual(Pd.units.pEvoked, P.units.pEvoked, 'the same tests');
            for key = unique(Pd.units.datasetKey).'
                rows = Pd.units.datasetKey == key;
                tc.verifyEqual(Pd.units.qEvoked(rows), pAdjust(Pd.units.pEvoked(rows), "holm"), 'Family "dataset"');
            end
            S = populationSummary(P, GroupBy="dataset");
            for g = 1:height(S.groups)
                rows = S.unitGroup == g;
                tc.verifyEqual(S.groups.nResponsive(g), nnz(rows & P.units.responsive));
                tc.verifyEqual(S.groups.nExcited(g) + S.groups.nSuppressed(g), S.groups.nResponsive(g) ...
                    - nnz(rows & P.units.responsive & P.units.direction == "none"));
            end
        end

        function writesFiles(tc)
            tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            out = fullfile(tmp.Folder, "pop");
            [P, S, files] = populationAnalysis(tc.Config, Tests=false, Param="Depth", Folder=out, LogFcn=[]);
            names = ["population_units.csv" "population_groups.csv" "population_psth.csv" "population_tuning.csv" ...
                "population_psth.png" "population_tuning.png" "population_depth.png" "population.json"];
            for f = names
                tc.verifyTrue(isfile(fullfile(out, f)), f + " is written");
            end
            tc.verifyFalse(isfile(fullfile(out, "population_fractions.png")), 'no fractions figure without the tests');
            tc.verifyEqual(numel(files), numel(names));
            T = readtable(fullfile(out, "population_units.csv"), 'TextType', 'string');
            tc.verifyEqual(height(T), height(P.units));
            tc.verifyEqual(T.unitId, P.units.unitId);
            G = readtable(fullfile(out, "population_groups.csv"), 'TextType', 'string');
            tc.verifyEqual(G.nUnits, S.groups.nUnits);
            J = readJsonFile(fullfile(out, "population.json"));
            tc.verifyEqual(string(J.params.param), "Depth");
            tc.verifyTrue(isfield(J, 'provenance') && isfield(J, 'datasets'));
        end

        function errors(tc)
            tc.verifyError(@() populationAnalysis(tc.Config, Units=struct('response', struct('enabled', true)), LogFcn=[]), ...
                'populationAnalysis:ResponseSelection');
            between = struct('mode', "between", 'pre', 0, 'post', 0, 'stop', struct('line', "Stim", 'edge', "offset"));
            tc.verifyError(@() populationAnalysis(tc.Config, Window=between, LogFcn=[]), 'populationAnalysis:BadWindow');
            tc.verifyError(@() populationAnalysis(tc.Config, Family="subject", LogFcn=[]), 'populationAnalysis:BadOption');
            tc.verifyError(@() populationAnalysis(tc.Config, Datasets="Nope", LogFcn=[]), 'populationAnalysis:BadOption');
            tc.verifyError(@() populationAnalysis(tc.Config, Ref=struct('line', "Nope"), Tests=false, LogFcn=[]), ...
                'populationAnalysis:NoUnits');
            tc.verifyError(@() populationAnalysis(42), 'populationAnalysis:BadSource');
            if ~(license('test', 'Statistics_Toolbox') && exist('signrank', 'file') > 0)
                tc.verifyError(@() populationAnalysis(tc.Config, LogFcn=[]), 'responseStats:NoToolbox');
            end
        end
    end
end
