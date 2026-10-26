classdef test_PopulationAnalysis < matlab.unittest.TestCase
    %test_PopulationAnalysis  populationAnalysis, populationSummary, renderPopulation, writePopulation.
    %   Over the analysis fixture (two synthetic datasets run through the
    %   pipeline): P.units holds selectUnits' units of every dataset with
    %   their rates; P.psth is spikePSTH's per dataset, pooled over the
    %   selection's groups; P.tuning is responseStats' per-level rates on
    %   the union of levels; the summary's counts add up and its means are
    %   the means of its units; the correction runs over every unit or over
    %   each dataset (Family); each unit's auROC is aurocCurves' over its
    %   dataset, and the 95% CI cutoff is pooled over the family (every
    %   unit: the formula over all of them; each dataset: its own cutoff;
    %   with AurocGroupBy every unit x group curve, a row each),
    %   the calls, peaks and summary counts follow, and a test cutoff's p
    %   are corrected over the family; the files are written; the errors;
    %   the stars beside the data (DatasetFavorites) in P.units and
    %   P.datasets, GroupBy "starred", unitSummary, sessionTable, the
    %   report's summary tables and the HTML and PDF reports.
    %   Only the correction and auROC tests call the toolbox (skipped
    %   without the Statistics and Machine Learning Toolbox).
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
            tc.verifyTrue(isempty(P.auroc) && all(P.units.aurocDirection == "") && all(isnan(P.units.aurocMean)) ...
                && isempty(S.auroc) && all(S.groups.nAurocCalled == 0), 'Tests=false: no auROC');
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
            tc.verifyError(@() populationSummary(P, GroupBy="color"), 'populationSummary:BadGroupBy');
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

        function aurocOverTheFamily(tc)
            tc.assumeTrue(license('test', 'Statistics_Toolbox') && exist('signrank', 'file') > 0 ...
                && exist('tiedrank', 'file') > 0, "needs the Statistics and Machine Learning Toolbox");
            tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            out = fullfile(tmp.Folder, "pop");
            [P, S] = populationAnalysis(tc.Config, Folder=out, LogFcn=[]);
            r = EphysAnalysisRunner(tc.Config, LogFcn=[]);
            ref = eventRef(line="Stim");
            mw = EphysAnalysisConfig.defaults("Auroc").modulationWindow;
            cuts = NaN(1, numel(r.Outputs));
            for k = 1:numel(r.Outputs)
                src = r.source(k);
                [st, meta] = selectUnits(src, struct());
                E = epochTable(src, ref, Window=epochWindow(pre=-0.2, post=0.5), Selection=trialSelection(), Baseline=[-0.2 0]);
                args = {'Window', [-0.2 0.5], 'Baseline', [-0.2 0], 'BinSec', 0.01, 'ModulationWindow', mw};
                A = aurocCurves(st, E, args{:}, Call=false);
                rows = P.units.datasetKey == r.Keys(k);
                tc.verifyEqual(nnz(rows), height(meta));
                tc.verifyEqual(P.units.aurocMean(rows), A.mean, 'AbsTol', 1e-12, sprintf('%s: each unit''s mean auROC', r.Names(k)));
                tc.verifyEqual(P.units.aurocPhasic(rows), A.phasic, 'AbsTol', 1e-12);
                tc.verifyEqual(P.auroc.auroc(:, rows), A.auroc(:, :, 1), 'AbsTol', 1e-12, 'each unit''s curve');
                ws = warning('off', 'aurocCall:WideCutoff');
                Ak = aurocCurves(st, E, args{:});   % the cutoff over this dataset alone
                warning(ws);
                cuts(k) = Ak.cutoffValue;
            end
            tc.verifyEqual(P.auroc.t, A.t);
            tc.verifyEqual(height(P.auroc.calls), height(P.units), 'without AurocGroupBy a row per unit');
            tc.verifyEqual(P.auroc.calls.mean, P.units.aurocMean);
            v = P.units.aurocPhasic(isfinite(P.units.aurocPhasic));
            c = mean(v) + tinv(0.975, numel(v) - 1) * std(v) / sqrt(numel(v));
            F = P.auroc.families;
            tc.verifyEqual(F.family, "all");
            tc.verifyEqual([F.nUnits F.nCurves], [height(P.units) numel(v)]);
            tc.verifyEqual(F.cutoffValue, c, 'AbsTol', 1e-12, 'Family "all": the 95% CI cutoff over every dataset''s units');
            C = aurocCall(struct('mean', P.units.aurocMean, 'phasic', P.units.aurocPhasic, 'p', P.units.aurocP));
            tc.verifyEqual(F.cutoffValue, C.cutoffValue, 'AbsTol', 1e-12, 'one aurocCall over the units stacked');
            tc.verifyEqual(P.units.aurocDirection == "increase", P.units.aurocMean > 0.5 + c, 'called up above 0.5 + c');
            tc.verifyEqual(P.units.aurocDirection == "decrease", P.units.aurocMean < 0.5 - c, 'called down below 0.5 - c');
            tc.verifyEqual(P.units.aurocModulated, ismember(P.units.aurocDirection, ["increase" "decrease"]));
            tc.verifyEqual(F.nModulated, nnz(P.units.aurocModulated));
            in = P.auroc.inModulation;
            a = P.auroc.auroc(in, :);
            tt = P.auroc.t(in);
            for u = find(isfinite(P.units.aurocPeak)).'
                [~, i] = max(abs(a(:, u) - 0.5));
                tc.verifyEqual([P.units.aurocPeak(u) P.units.aurocPeakTime(u)], [a(i, u) tt(i)], ...
                    'the peak: the window in the call window farthest from 0.5');
            end
            tc.verifyEqual(sum(S.groups.nAurocCalled), nnz(P.units.aurocDirection ~= ""), 'the summary counts every unit called');
            tc.verifyEqual(sum(S.groups.nAurocModulated), nnz(P.units.aurocModulated));
            tc.verifyEqual(S.auroc.families, F, 'the summary carries the pooled cutoff');
            J = readJsonFile(fullfile(out, "population.json"));
            tc.verifyEqual(J.auroc.families.cutoffValue, c, 'AbsTol', 1e-9, 'population.json records the pooled cutoff');
            T = readtable(fullfile(out, "population_units.csv"), 'TextType', 'string');
            tc.verifyEqual(T.aurocMean, P.units.aurocMean, 'AbsTol', 1e-9, 'population_units.csv holds the auROC columns');
            T = readtable(fullfile(out, "population_auroc.csv"), 'TextType', 'string');
            tc.verifyEqual(height(T), height(P.auroc.calls), 'population_auroc.csv: a row per unit and group');
            tc.verifyTrue(isfile(fullfile(out, "population_fractions.png")));
            % AurocGroupBy: a curve per unit and group, every one pooled for the cutoff
            Pg = populationAnalysis(tc.Config, AurocGroupBy="Depth", LogFcn=[]);
            K = Pg.auroc.calls;
            selD = trialSelection();
            selD.groupBy = "Depth";
            nRows = 0;
            for k = 1:numel(r.Outputs)
                src = r.source(k);
                st = selectUnits(src, struct());
                [Eg, Gg] = epochTable(src, ref, Window=epochWindow(pre=-0.2, post=0.5), Selection=selD, Baseline=[-0.2 0]);
                A = aurocCurves(st, Eg, args{:}, Groups=Gg, Call=false);
                rows = K.datasetKey == r.Keys(k);
                tc.verifyEqual(K.mean(rows), reshape(A.mean.', [], 1), 'AbsTol', 1e-12, ...
                    sprintf('%s: a row per unit and group, a unit''s groups together', r.Names(k)));
                tc.verifyEqual(K.group(rows), repmat(string(Gg.label), numel(st), 1));
                nRows = nRows + numel(A.mean);
            end
            tc.verifyEqual(height(K), nRows);
            v = K.phasic(isfinite(K.phasic));
            cg = Pg.auroc.families.cutoffValue;
            tc.verifyEqual(Pg.auroc.families.nCurves, numel(v));
            tc.verifyEqual(cg, mean(v) + tinv(0.975, numel(v) - 1) * std(v) / sqrt(numel(v)), 'AbsTol', 1e-12, ...
                'the cutoff pools every unit x group curve of every dataset');
            tc.verifyEqual(K.direction == "increase", K.mean > 0.5 + cg);
            tc.verifyEqual(K.direction == "decrease", K.mean < 0.5 - cg);
            tc.verifyEqual(Pg.units.aurocModulated, arrayfun(@(u) any(K.modulated(K.unit == u)), (1:height(Pg.units)).'), ...
                'a unit is modulated when any of its groups is');
            % Family "dataset": each dataset's own cutoff, as aurocCurves gives it over that dataset
            ws = warning('off', 'aurocCall:WideCutoff');
            Pd = populationAnalysis(tc.Config, Family="dataset", LogFcn=[]);
            warning(ws);
            tc.verifyEqual(Pd.auroc.families.family, r.Keys(:));
            tc.verifyEqual(Pd.auroc.families.cutoffValue, cuts(:), 'AbsTol', 1e-12, 'Family "dataset": a cutoff per dataset');
            % a test per unit: no pooling, the correction over the family
            Pt = populationAnalysis(tc.Config, Auroc=struct('cutoff', "test", 'test', "ranksum"), Correction="holm", LogFcn=[]);
            tc.verifyTrue(all(isfinite(Pt.units.aurocP)) && isnan(Pt.auroc.families.cutoffValue));
            tc.verifyEqual(Pt.units.aurocQ, pAdjust(Pt.units.aurocP, "holm"), 'the test: Holm over every unit');
            sig = Pt.units.aurocQ <= 0.05;
            tc.verifyEqual(Pt.units.aurocDirection == "increase", sig & Pt.units.aurocMean > 0.5);
            tc.verifyEqual(Pt.units.aurocDirection == "decrease", sig & Pt.units.aurocMean < 0.5);
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

        function starsInExports(tc)
            r = EphysAnalysisRunner(tc.Config, LogFcn=[]);
            src = r.source(1);
            [~, meta] = selectUnits(src, struct());
            u = meta.unitId(end);
            ch = meta.channel(1);
            fav = DatasetFavorites(r.Outputs(1));
            tc.addTeardown(@() deleteIfThere(fav.File));
            fav.star("dataset");
            fav.star("unit", u);
            fav.star("channel", ch);
            P = populationAnalysis(tc.Config, Tests=false, LogFcn=[]);
            tc.verifyEqual(P.datasets.starred, P.datasets.datasetKey == r.Keys(1), 'P.datasets.starred: each dataset''s star');
            rows = P.units.datasetKey == r.Keys(1);
            tc.verifyEqual(P.units.starred(rows), meta.unitId == u, 'P.units.starred: the unit''s star on the sort in use');
            tc.verifyFalse(any(P.units.starred(~rows)), 'no unit of the other dataset is starred');
            S = populationSummary(P, GroupBy="starred");
            tc.verifyEqual(S.groups.group, ["not starred"; "starred"]);
            tc.verifyEqual(S.groups.nUnits(2), 1, 'GroupBy "starred": the starred units on their own');
            U = unitSummary(src, Source="units");
            tc.verifyEqual(U.starred, meta.unitId == u, 'unitSummary: each unit''s star');
            if src.hasDetected
                Ud = unitSummary(src, Source="detected");
                tc.verifyEqual(Ud.starred, Ud.channel == ch, 'unitSummary of the detections: each channel''s star');
            end
            T = reportSummaryTables(src);
            rec = T.recording;
            tc.verifyEqual(rec.Value(rec.Field == "Starred"), "yes");
            tc.verifyEqual(rec.Value(rec.Field == "Starred units"), string(u));
            tc.verifyEqual(rec.Value(rec.Field == "Starred channels"), string(ch));
            tc.verifyTrue(all(ismember(T.topRates.Starred, ["yes" ""])), 'the highest rates table has a Starred column');
            T2 = reportSummaryTables(r.source(2));
            tc.verifyEqual(T2.recording.Value(T2.recording.Field == "Starred"), "no");
            tc.verifyFalse(any(ismember(["Starred units" "Starred channels"], T2.recording.Field)), 'no starred units or channels listed');
            sessions = r.sessionTable();
            tc.verifyEqual(sessions.starred, sessions.index == 1, 'sessionTable: each dataset''s star');
            report = newAnalysisReport(Options=struct('Format', "both"));
            report = addReportDataset(report, src);
            report = addReportDataset(report, r.source(2));
            report = addReportSection(report, "Across sessions");
            tc.verifyEqual([report.datasets.starred], [true false false], 'the report keeps each dataset''s star');
            tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            html = writeHtmlReport(report, fullfile(string(tmp.Folder), "report.html"));
            txt = string(fileread(html));
            tc.verifyEqual(count(txt, "class=""star"""), 2, 'the HTML report marks the starred dataset in the contents and over its section');
            tc.verifyTrue(contains(txt, "<h2>" + src.name + " <span class=""star"""));
            pdf = writePdfReport(report, fullfile(string(tmp.Folder), "report.pdf"));
            tc.verifyTrue(isfile(pdf), 'the PDF report is written with the starred dataset named so');
        end

        function tagsInExports(tc)
            % a dataset's tags (the manifest's) reach the source, the tables, the session table and the reports
            r0 = EphysAnalysisRunner(tc.Config, LogFcn=[]);
            f1 = r0.Outputs(1).ManifestFile;
            f2 = r0.Outputs(2).ManifestFile;
            for f = [f1 f2]
                tc.addTeardown(@restoreText, f, string(fileread(f)));
            end
            m1 = readJsonFile(f1);
            m1.tags = {'zeta', 'Pilot', 'pilot'};   % written as the manifest holds them; read sorted, unique, lowercase
            writeJsonFile(f1, m1);
            m2 = readJsonFile(f2);
            if isfield(m2, 'tags'); m2 = rmfield(m2, 'tags'); end
            writeJsonFile(f2, m2);
            r = EphysAnalysisRunner(tc.Config, LogFcn=[]);
            src = r.source(1);
            src2 = r.source(2);
            tc.verifyEqual(src.tags, {'pilot', 'zeta'}, 'loadAnalysisSource: the manifest''s tags, sorted and lowercase');
            tc.verifyEqual(src2.tags, {}, 'a manifest without a tags key: {}');
            m2.tags = {};   % jsonencode writes []
            writeJsonFile(f2, m2);
            tc.verifyEqual(loadAnalysisSource(r.Outputs(2).Folder).tags, {}, 'an empty tags array: {}');
            tc.verifyEqual(outputTags(r.Outputs(1)), {'pilot', 'zeta'}, 'outputTags: the same, without loading a source');
            % the session table, directly and through the runner
            S = sessionTable(["a"; "b"], ["a"; "b"], Tags=["x;y"; ""]);
            tc.verifyEqual(S.tags, ["x;y"; ""], 'sessionTable: Tags= is the tags column');
            tc.verifyEqual(sessionTable(["a"; "b"], ["a"; "b"]).tags, ["";  ""], 'sessionTable: no Tags= gives ""');
            sessions = r.sessionTable();
            tc.verifyEqual(sessions.tags(sessions.index == 1), "pilot;zeta", 'EphysAnalysisRunner.sessionTable: the ";"-joined tags');
            tc.verifyEqual(sessions.tags(sessions.index == 2), "", 'no tags: ""');
            % the population tables and files
            tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            out = fullfile(tmp.Folder, "pop");
            P = populationAnalysis(tc.Config, Tests=false, Folder=out, LogFcn=[]);
            tc.verifyEqual(P.datasets.tags(P.datasets.datasetKey == r.Keys(1)), "pilot;zeta", 'P.datasets.tags');
            rows = P.units.datasetKey == r.Keys(1);
            tc.verifyTrue(all(P.units.tags(rows) == "pilot;zeta") && all(P.units.tags(~rows) == ""), 'P.units.tags: the dataset''s, on each of its units');
            tc.verifyEqual(TagSet.fromText(P.units.tags(find(rows, 1)), TagSet.ExportDelimiter), {'pilot', 'zeta'}, 'the text reads back as the tag set');
            T = readtable(fullfile(out, "population_units.csv"), 'TextType', 'string');
            tc.verifyEqual(fillmissing(T.tags, 'constant', ""), P.units.tags, 'population_units.csv holds the tags column');
            J = readJsonFile(fullfile(out, "population.json"));
            tc.verifyTrue(isfield(J.datasets, 'tags'), 'population.json: the datasets carry tags');
            % the report: the model, the Recording table, the HTML and the PDF
            T1 = reportSummaryTables(src);
            tc.verifyEqual(T1.recording.Value(T1.recording.Field == "Tags"), "pilot, zeta", 'the Recording table: Tags, ", "-joined');
            T2 = reportSummaryTables(src2);
            tc.verifyEqual(T2.recording.Value(T2.recording.Field == "Tags"), "(none)", 'the Recording table: (none) without tags');
            report = newAnalysisReport(Options=struct('Format', "both"));
            report = addReportDataset(report, src);
            report = addReportDataset(report, src2);
            report = addReportSection(report, "Across sessions");
            tc.verifyEqual(report.datasets(1).tags, {'pilot', 'zeta'}, 'the report keeps the dataset''s tags');
            tc.verifyTrue(isempty(report.datasets(2).tags) && isempty(report.datasets(3).tags), 'no tags on a dataset without and on a section');
            html = writeHtmlReport(report, fullfile(string(tmp.Folder), "report.html"));
            txt = string(fileread(html));
            tc.verifyEqual(count(txt, "class=""tags"""), 1, 'the HTML report shows the tags once, over the tagged dataset''s section');
            tc.verifyTrue(contains(txt, "<h2>" + src.name + " <span class=""tags"" title=""tags"">pilot, zeta</span></h2>"), ...
                'the section header carries the tags');
            tc.verifyTrue(contains(txt, "<td>Tags</td><td>pilot, zeta</td>") && contains(txt, "<td>Tags</td><td>(none)</td>"), 'the Recording tables have the Tags row');
            pdf = writePdfReport(report, fullfile(string(tmp.Folder), "report.pdf"));
            pages = pdfPageTexts(pdf);
            tc.verifyTrue(contains(pages(1), "1. " + src.name) && contains(pages(1), "figure(s)) [pilot, zeta]"), 'the PDF title page: the dataset line gains [pilot, zeta]');
            tc.verifyFalse(contains(pages(1), "2. " + src2.name + " (0 figure(s)) ["), 'no bracket without tags');
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


function deleteIfThere(f)
if isfile(f); delete(f); end
end


function restoreText(file, txt)
%restoreText  Put a file's text back as it was.
fid = fopen(file, 'w');
c = onCleanup(@() fclose(fid));
fwrite(fid, txt);
end


function T = pdfPageTexts(file)
%pdfPageTexts  Each page's text, whitespace collapsed (PDFBox, as writePdfReport joins the pages).
doc = org.apache.pdfbox.pdmodel.PDDocument.load(java.io.File(char(file)));
closer = onCleanup(@() doc.close());
strip = org.apache.pdfbox.text.PDFTextStripper();
n = doc.getNumberOfPages();
T = strings(n, 1);
for p = 1:n
    strip.setStartPage(p);
    strip.setEndPage(p);
    T(p) = strtrim(regexprep(string(strip.getText(doc)), '\s+', ' '));
end
end
