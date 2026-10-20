function test_PipelineAnalysisStep()
%test_PipelineAnalysisStep  Verification suite for the pipeline's Analysis step.
%   Over a small synthetic project run through the pipeline
%   (makeAnalysisFixture), with an analysis config saved from
%   EphysAnalysisConfig: the Analysis section's validation (the analysis
%   config's own issues, its Source ignored, a missing file, nothing
%   written, background sorting feeding unit figures); plan rows per dataset
%   and figure, a session figure's row and the report row; a dry run writing nothing; a run writing
%   every dataset's figures, the report over every dataset and the
%   analysis run record, with progress that only grows; cancel; a "list"
%   selection with one report per dataset; the compact script's step call;
%   and the standalone script, which carries the analysis config and writes
%   the report again.
%
%   Usage:  test_PipelineAnalysisStep

here = fileparts(mfilename('fullpath'));
repo = fileparts(here);
addpath(here);
addpath(fullfile(repo, 'pipeline'));
addpath(repo);
addpath(genpath(fullfile(repo, 'vendor')));

root = fullfile(tempdir, sprintf('AnaStep_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
cleanup = onCleanup(@() rmdirQuiet(root));

nPass = 0; nFail = 0;
    function check(cond, msg)
        if cond
            nPass = nPass + 1;
            fprintf('  PASS: %s\n', msg);
        else
            nFail = nFail + 1;
            fprintf(2, '  FAIL: %s\n', msg);
            LegacySuiteTest.checkFailed(msg);   % one failure per check in run_all_tests' report
        end
    end

fprintf('\n== 0. fixture ==\n');
F = makeAnalysisFixture(string(root), Scenarios=["clean" "late-start"], NumTrials=12);
check(numel(F.names) == 2, 'two datasets run through the pipeline');

acfg = EphysAnalysisConfig();
acfg.Name = "step test";
acfg.Source.Root = fullfile(root, 'no_such_root');   % the step runs over the pipeline's datasets instead
acfg.Defaults.EventRef.line = "Stim";
acfg.Defaults.Window = struct('mode', "fixed", 'pre', -0.2, 'post', 0.6, 'stop', []);
acfg = acfg.addFigure("rasterPsth", Id="psth_stim");   % a page per observed unit
acfg.Figures(1).observe.units.maxUnits = 2;
acfg = acfg.addFigure("continuous", Id="lfp_stim");   % a page per observed LFP channel
acfg.Figures(2).observe.channels = [1 2];
acfg.Figures(2).window = struct('mode', "fixed", 'pre', -0.1, 'post', 0.4, 'stop', []);
acfg = acfg.addFigure("raster", Id="raster_det");   % detected spikes, a channel each
acfg.Figures(3).observe.data = "detected";
acfg.Figures(3).observe.units.maxUnits = 2;
acfg.Figures(3).panels(1).layers(1).source = "detected";
acfg = acfg.addFigure("probemap", Id="map_fig");   % one page per dataset
acfg.Export.Formats = "png";
acfg.Report.Format = "html";
anaFile = fullfile(root, 'step_test_analysis.json');
acfg = acfg.save(anaFile);

cfg = EphysPipelineConfig.load(F.configFile);
cfg.Behavior.Enabled = false; cfg.Artifacts.Enabled = false; cfg.Sorting.Enabled = false;
cfg.Signals.Enabled = false; cfg.Spikes.Enabled = false; cfg.Export.Enabled = false;
cfg.Analysis.Enabled = true;
cfg.Analysis.ConfigFile = anaFile;
check(isequal(cfg.enabledSteps(), ["probe" "analysis"]) && cfg.stepSection("analysis").ConfigFile == anaFile, ...
    'the analysis step comes last and is enabled by its section');

fprintf('\n== 1. validation ==\n');
iss = cfg.validate();
ai = iss(iss.Step == "analysis", :);
check(~any(ai.Severity == "error") && any(contains(ai.Message, "The Signals step is off")), ...
    'a good analysis config validates (its own Source, which does not exist, is ignored); Signals off is a warning');
bad = acfg;
bad = bad.addFigure("tuning", Id="tune_x");
bad.Figures(end).panels(1).options.param = "1x";   % not a trial parameter's name
badFile = fullfile(root, 'bad_analysis.json');
bad.save(badFile);
c2 = cfg; c2.Analysis.ConfigFile = badFile;
iss = c2.validate();
check(any(iss.Step == "analysis" & iss.Field == "Figures.tune_x.tuning_1.options.param" & iss.Severity == "error"), ...
    'the analysis config''s own errors are the step''s, under Figures.<id>.<panel>.<field>');
v1 = struct('schema', "ephys-analysis-config", 'version', 1, 'Defaults', struct('EventRef', struct('line', "Stim")));
v1.Plots = {struct('kind', "psth", 'id', "old_psth", 'style', struct('MaxTiles', 9), 'bogus', 1), struct('kind', "behavior", 'id', "beh")};
v1File = fullfile(root, 'v1_analysis.json');
writeJsonFile(v1File, v1);
c2.Analysis.ConfigFile = v1File;
iss = c2.validate();
lw = iss(iss.Step == "analysis" & iss.Field == "ConfigFile" & iss.Severity == "warning", :);
check(nnz(contains(lw.Message, "is version 1: open and save it in the analysis app to migrate it once")) == 1 ...
    && contains(lw.Message(contains(lw.Message, "is version 1")), string(v1File)) ...
    && ~any(contains(lw.Message, "The analysis config: plot ")) && ~any(contains(lw.Message, "config version 1")) ...
    && ~any(contains(lw.Message, "Plots: dropped")), ...
    'a version-1 analysis config: one warning to open and save it in the analysis app, not each migration note');
c2.Analysis.ConfigFile = fullfile(root, 'nope.json');
iss = c2.validate();
check(any(iss.Step == "analysis" & iss.Severity == "error" & contains(iss.Message, "not found")), 'a missing analysis config is an error');
iss = c2.validate(CheckPaths=false);
check(~any(iss.Step == "analysis" & iss.Severity == "error"), 'without CheckPaths the file is not read');
c2.Analysis.ConfigFile = "";
iss = c2.validate(CheckPaths=false);
check(any(iss.Step == "analysis" & iss.Field == "ConfigFile" & iss.Severity == "error"), 'no analysis config chosen is an error');
c2 = cfg; c2.Analysis.Figures = false; c2.Analysis.Report = false;
iss = c2.validate();
check(any(iss.Step == "analysis" & iss.Field == "Figures" & iss.Severity == "warning"), 'writing neither figures nor report is a warning');
c2 = cfg; c2.Sorting.Enabled = true; c2.Sorting.PythonExe = "python"; c2.Sorting.Execution = "background";
iss = c2.validate();
check(any(iss.Step == "sorting" & iss.Field == "Execution" & iss.Severity == "error"), ...
    'background sorting cannot feed the analysis''s unit figures in the same run');

fprintf('\n== 2. plan ==\n');
pipe = EphysPipeline(cfg);
pipe.LogFcn = [];
T = pipe.plan(Steps="analysis");
d1 = pipe.Project.dataset(F.names(1));
rep = EphysAnalysisRunner.reportFiles(acfg, pipe.analysisTokens(d1));
plotRows = T(T.Step ~= "analysis:report", :);
check(height(plotRows) == 8 && all(plotRows.Status == "ready") ...
    && isequal(sort(unique(plotRows.Step)).', sort("analysis:" + ["psth_stim" "lfp_stim" "raster_det" "map_fig"])) ...
    && all(plotRows.Output(plotRows.Dataset == F.names(1)) == fullfile(F.folders(1), "analysis")) ...
    && all(startsWith(plotRows.Note(plotRows.Step == "analysis:map_fig"), "figure of dataset")), ...
    'plan: a row per dataset and figure (a probe map: "figure of dataset"), each with its figure folder');
check(nnz(T.Step == "analysis:report") == 1 && T.Dataset(T.Step == "analysis:report") == "" ...
    && T.Output(T.Step == "analysis:report") == rep && contains(T.Note(T.Step == "analysis:report"), "over 2 dataset"), ...
    'plan: one report over every dataset');
T2 = pipe.plan();
check(height(T2(startsWith(T2.Step, "analysis"), :)) == 9 && ~any(startsWith(T2.Status, "duplicate")), ...
    'the shared report and folders are no duplicate outputs');

fprintf('\n== 3. dry run ==\n');
R = pipe.run(Steps="analysis", DryRun=true);
A = R(startsWith(R.Step, "analysis"), :);
check(height(A) == 9 && all(A.Status == "dry run") && ~isfile(rep) && ~isfolder(fullfile(F.folders(1), "analysis")), ...
    'a dry run says what it would write and writes nothing');
sfa = acfg.addFigure("rasterPsth", Id="card_days");   % a session figure: one row across the datasets, its sessions folder
sfa.Figures(end).sessions.enabled = true;
sfFile = fullfile(root, 'session_figure_analysis.json');
sfa.save(sfFile);
cs = cfg; cs.Analysis.ConfigFile = sfFile;
ps = EphysPipeline(cs);
ps.LogFcn = [];
Ts = ps.plan(Steps="analysis");
rs = Ts(Ts.Step == "analysis:card_days", :);
sfFolder = figureFileName(sfa.Export.SessionsFolder, ps.analysisTokens(ps.Project.dataset(F.names(1))), Kind="folder");
check(height(rs) == 1 && rs.Dataset == "" && rs.Status == "ready" && rs.Output == sfFolder && contains(rs.Note, "across 2 dataset") ...
    && height(Ts(Ts.Step ~= "analysis:report", :)) == height(plotRows) + 1, ...
    'plan (and the dry run): a session figure is one row across the datasets, its sessions folder, beside the per-dataset rows');
iss = cs.validate(CheckPaths=false);
check(~any(iss.Step == "analysis" & iss.Severity == "error"), 'an analysis config with a session figure validates in the pipeline');

fprintf('\n== 4. run ==\n');
events = struct('step', {}, 'dataset', {}, 'index', {}, 'count', {}, 'done', {}, 'total', {}, 'message', {});
    function onEvent(evt)
        events(end+1) = evt;
    end
pipe.ProgressFcn = @onEvent;
R = pipe.run(Steps="analysis");
A = R(startsWith(R.Step, "analysis:") & R.Step ~= "analysis:report", :);
pngs = dir(fullfile(F.folders(1), "analysis", F.names(1) + "_*.png"));
check(height(A) == 8 && all(A.Status == "done") && all(A.Output ~= "") && numel(pngs) >= 4, ...
    sprintf('each dataset''s figures are drawn and their files written (%d done, %d png of the first)', nnz(A.Status == "done"), numel(pngs)));
fa = A(A.Step == "analysis:map_fig", :);
fu = A(A.Step == "analysis:psth_stim" & A.Dataset == F.names(1), :);
check(height(fa) == 2 && all(fa.Status == "done") && isequal(sort(fa.Dataset).', sort(F.names)) ...
    && isfile(fullfile(F.folders(1), "analysis", F.names(1) + "_map_fig.png")) && height(fu) == 1 && numel(split(fu.Output, "; ")) == 2, ...
    'a row per dataset and figure ("analysis:map_fig", done), its pages written: one for the dataset''s probe map, one per observed unit');
r = R(R.Step == "analysis:report", :);
check(height(r) == 1 && r.Status == "done" && r.Output == rep && isfile(rep) && contains(fileread(rep), F.names(2)), ...
    'the report over every dataset is written where the plan said');
check(~isempty(dir(fullfile(fileparts(rep), "analysis_runs", "*_step_test.json"))) && isfile(pipe.RunRecordFile), ...
    'the analysis run record and the pipeline run record are written');
ev = events([events.step] == "analysis" & [events.dataset] ~= "");
frac = arrayfun(@(e) (max(e.index, 1) - 1 + e.done / max(e.total, 1)) / max(e.count, 1), ev);
check(numel(ev) > 6 && all(diff(frac) >= -1e-9) && abs(frac(end) - 1) < 1e-9 ...
    && all(ismember(unique([ev.dataset]), F.names)) && any(startsWith([ev.message], "figure ")), ...
    'progress goes out as the analysis step, dataset by dataset, and only grows to 1');

fprintf('\n== 5. cancel ==\n');
nPlotEvents = 0;
    function onCancelEvent(evt)
        if evt.step == "analysis" && startsWith(evt.message, "figure ")
            nPlotEvents = nPlotEvents + 1;
            if nPlotEvents == 4; pipe.cancel(); end   % psth_stim, its 2 observations, then lfp_stim's start
        end
    end
pipe.ProgressFcn = @onCancelEvent;
delete(rep);
R = pipe.run(Steps="analysis");
A = R(startsWith(R.Step, "analysis:"), :);
check(any(A.Status == "canceled") && any(A.Status == "done") && A.Status(A.Step == "analysis:report") == "canceled" ...
    && ~isfile(rep), 'cancel stops before the next figure observation; the rest and the report are "canceled"');

fprintf('\n== 6. a list selection, one report per dataset ==\n');
per = acfg; per.Report.PerDataset = true;
per.save(anaFile);
c3 = cfg; c3.Project.Selection = "list"; c3.Project.Datasets = F.keys(2);
pipe3 = EphysPipeline(c3);
pipe3.LogFcn = [];
R = pipe3.run(Steps="analysis");
A = R(startsWith(R.Step, "analysis:"), :);
d2 = pipe3.Project.dataset(F.names(2));
rep2 = EphysAnalysisRunner.reportFiles(per, pipe3.analysisTokens(d2));
check(all(A.Dataset == F.names(2)) && height(A) == 5 && A.Output(A.Step == "analysis:report") == rep2 && isfile(rep2) ...
    && endsWith(rep2, "_" + F.names(2) + ".html"), 'only the selected dataset runs; its own report is named after it');
acfg.save(anaFile);   % back to one report over every dataset

fprintf('\n== 7. scripts ==\n');
cfgFile = fullfile(root, 'step_test_pipeline.json');
cfg = cfg.save(cfgFile);
txtC = EphysPipelineScript.compact(cfg);
check(contains(txtC, "pipe.runAnalysis();   % analysis"), 'the compact script calls the step');
scriptFile = fullfile(root, 'scripts', 'standalone_analysis.m');
txtS = EphysPipelineScript.standalone(cfg, File=scriptFile);
check(contains(txtS, "%% Analysis: figures and report") && contains(txtS, "analysisJson = [") ...
    && contains(txtS, "EphysAnalysisRunner(acfg, SearchDirs=") && contains(txtS, "ephys-analysis-config") ...
    && contains(txtS, "raster_det") ...
    && contains(txtS, "Export=true, Report=true"), 'the standalone script carries the analysis config as JSON and runs it');
lines = splitlines(string(fileread(scriptFile)));
at = find(startsWith(lines, "%% Analysis"), 1);
info = checkcode(scriptFile);
check(~isempty(at) && all([info.line] < at), 'the standalone script''s Analysis section passes checkcode');
if isfile(rep); delete(rep); end
out = runScript(scriptFile);
check(isfile(rep) && contains(out, "Report: "), 'the standalone script writes the report again');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_PipelineAnalysisStep:Failures', '%d checks failed.', nFail);
end
end


function out = runScript(file) %#ok<INUSD> used inside evalc
%runScript  Run a script in its own workspace and capture what it prints.
out = evalc('run(file)');
end


function rmdirQuiet(root)
if isfolder(root)
    try
        rmdir(root, 's');
    catch
    end
end
end
