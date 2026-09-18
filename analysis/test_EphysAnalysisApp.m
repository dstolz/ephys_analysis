function test_EphysAnalysisApp()
%test_EphysAnalysisApp  Headless checks of the analysis GUI over a synthetic project.
%   Builds the app on a small synthetic project run through the pipeline
%   and drives it through its own methods: the tabs; Scan filling the
%   datasets table; the active dataset's lines and parameters; grouping by
%   Depth from the Alignment controls (the epoch count reports the groups);
%   adding a PSTH and previewing it into the preview panel; editing the plot
%   (bins, its own event reference); the gather / apply round trip; save
%   and reopen; a standalone script from the app's config; a run of one
%   plot writing its figures and report; closing. The user's preferences
%   (group EphysAnalysisApp) are restored afterwards.
%
%   Usage:  test_EphysAnalysisApp

here = fileparts(mfilename('fullpath'));
repo = fileparts(here);
addpath(here);
addpath(fullfile(repo, 'pipeline'));
addpath(repo);
addpath(genpath(fullfile(repo, 'vendor')));

root = fullfile(tempdir, sprintf('AnaApp_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
g = EphysAnalysisApp.PrefGroup;
savedPrefs = [];
if ispref(g); savedPrefs = getpref(g); end
cleanup = onCleanup(@() restorePrefsAndRoot(g, savedPrefs, root)); %#ok<NASGU>
if ispref(g, 'LastConfigFile'); setpref(g, 'LastConfigFile', ''); end

nPass = 0; nFail = 0;
    function check(cond, msg)
        if cond
            nPass = nPass + 1;
            fprintf('  PASS: %s\n', msg);
        else
            nFail = nFail + 1;
            fprintf(2, '  FAIL: %s\n', msg);
        end
    end

fprintf('\n== 0. fixture ==\n');
F = makeAnalysisFixture(string(root), Scenarios=["clean" "late-start"], NumTrials=12);
check(numel(F.names) == 2, 'two datasets run through the pipeline');

fprintf('\n== 1. build, open the project, scan ==\n');
app = EphysAnalysisApp(F.proj);
appCleanup = onCleanup(@() closeApp(app)); %#ok<NASGU>
check(isvalid(app.Fig) && numel(app.Tabs.Children) == 5 && app.Tabs.Children(1) == app.TabData ...
    && app.Tabs.Children(5) == app.TabLog, 'the app has the Data, Alignment, Plots, Export and Log tabs');
T = app.DatasetsTable.Data;
check(~isempty(app.Runner) && height(T) == 2 && all(T.Run) && isequal(sort(T.Name), sort(F.names(:))) ...
    && all(T.LFP == "✓") && all(T.Behavior == "✓"), 'the project root was scanned: both datasets, ticked, with LFP and behavior');
check(app.Config.Source.Mode == "project" && app.Config.Source.Root == F.proj && ~startsWith(app.Fig.Name, "*"), ...
    'a new config for the project, clean');
k = find(app.Runner.Names == F.names(1));
app.selectDataset(k);
check(app.ActiveIdx == k && any(app.LinesTable.Data.Line == "Stim") && any(app.ParamsTable.Data.Parameter == "Depth") ...
    && contains(app.BehaviorLabel.Text, "12 trials") && height(app.UnitsTable.Data) > 0, ...
    'the active dataset shows its lines (Stim), parameters (Depth), trials and units');
check(any(string(app.AlignControls.Line.Items) == "Stim") && any(string(app.AlignControls.Group1.Items) == "Depth"), ...
    'the Alignment boxes list the lines and parameters');

fprintf('\n== 2. Alignment: group by Depth ==\n');
app.selectTab(app.TabAlign);
app.AlignControls.Line.Value = 'Stim';
app.AlignControls.Group1.Value = 'Depth';
app.onConfigChanged("defaults");
[trials, ~] = readEpsychSession(F.truth(1).behaviorFile);
nG = numel(unique(trials.Depth));
check(app.Config.Defaults.Selection.groupBy == "Depth" && startsWith(app.AlignSummaryLabel.Text, "12 epochs from 12 of 12 trials") ...
    && count(app.AlignSummaryLabel.Text, "Depth = ") == nG, sprintf('the epoch count reports %d Depth groups', nG));
check(height(app.AlignTrialsTable.Data) == 12 && ismember("Group", string(app.AlignTrialsTable.Data.Properties.VariableNames)), ...
    'the kept trials are listed with their group');
check(startsWith(app.Fig.Name, "*"), 'the edit marks the config unsaved');

fprintf('\n== 3. Plots: add, edit, preview ==\n');
app.selectTab(app.TabPlots);
app.onAddPlot("psth");
check(numel(app.Config.Plots) == 1 && app.SelectedPlot == 1 && app.Config.Plots(1).id == "psth_1" ...
    && string(app.PlotEditor.kind.Text) == "PSTH" && string(app.PlotsListBox.Items{1}) == "psth_1  (psth)", ...
    'Add psth makes psth_1 and opens it in the editor');
app.refreshPreview(Force=true);
axs = findall(app.PreviewPanel, 'Type', 'axes');
check(~isempty(axs) && ~isempty(app.PreviewResult) && app.PreviewResult.kind == "psth" && isfinite(app.PreviewSeconds), ...
    sprintf('the preview draws %d axes into the preview panel', numel(axs)));
app.PlotEditor.binMs.Value = 20;
app.PlotEditor.defaultRef.Value = false;
app.onConfigChanged("plot");
app.PlotAlignControls.Line.Value = 'Trial';
app.onConfigChanged("plot");
p = app.Config.Plots(1);
check(p.bins.BinSec == 0.02 && isstruct(p.ref) && p.ref.line == "Trial" && isequal(p.window, "default") ...
    && app.PlotAlignControls.Line.Enable == "on" && app.PlotAlignControls.Pre.Enable == "off", ...
    'editing the bins and the plot''s own event reference; the default window stays default');
app.onAddPlot("evoked");
check(app.SelectedPlot == 2 && any(string(app.PlotEditor.source.Items) == "LFP") && app.PlotEditor.binMs.Enable == "off" ...
    && app.PlotEditor.withRaster.Enable == "off", 'an evoked plot offers signals and disables the spike rows');
app.PlotEditor.source.Value = 'LFP';
app.onConfigChanged("plot");
app.refreshPreview(Force=true);
check(~isempty(app.PreviewResult) && app.PreviewResult.kind == "evoked" && ~isempty(findall(app.PreviewPanel, 'Type', 'axes')), ...
    'the LFP evoked potential previews');
app.onPlotSelected(1);
check(app.SelectedPlot == 1 && app.PlotEditor.binMs.Value == 20, 'selecting plot 1 shows its edits');

fprintf('\n== 4. gather / apply, save / reopen, script ==\n');
c1 = app.gatherConfig();
app.applyConfig(c1);
c2 = app.gatherConfig();
check(c1.isequalConfig(c2), 'gatherConfig -> applyConfig -> gatherConfig is the same config');
outRoot = fullfile(root, 'out');
app.ExportControls.Folder.Value = fullfile(outRoot, '{Name}');
app.ExportControls.svg.Value = false;
app.ExportControls.png.Value = true;
app.ExportControls.Dpi.Value = 60;
app.ReportControls.Folder.Value = outRoot;
app.ReportControls.Dpi.Value = 50;
app.onConfigChanged("export");
cfgFile = fullfile(root, 'app_analysis.json');
ok = app.onSaveConfigAs(string(cfgFile));
check(ok && isfile(cfgFile) && ~startsWith(app.Fig.Name, "*") && app.Config.File == string(cfgFile), 'Save As writes the config and clears the marker');
app.onNewConfig();
check(isempty(app.Config.Plots) && app.Config.File == "", 'New config resets to the defaults');
ok = app.openConfigFile(cfgFile);
check(ok && numel(app.Config.Plots) == 2 && app.Config.Plots(1).bins.BinSec == 0.02 && ~isempty(app.Runner) ...
    && height(app.DatasetsTable.Data) == 2 && any(app.RecentConfigs == string(cfgFile)), 'reopening restores the plots and rescans');
txt = EphysAnalysisScript.standalone(app.gatherConfig());
check(contains(txt, "spikePSTH(") && contains(txt, "evokedPotential(") && contains(txt, "spec1.ref.line = ""Trial"";"), ...
    'a standalone script from the app''s config');
scriptFile = fullfile(root, 'run_app_compact.m');
app.onGenerateScript("compact", string(scriptFile));
check(isfile(scriptFile) && contains(fileread(scriptFile), "EphysAnalysisConfig.load("), 'Generate script (compact) writes the file');

fprintf('\n== 5. run one plot ==\n');
app.selectTab(app.TabExport);
I = app.onValidate();
check(~any(I.Severity == "error"), 'the config validates');
P = app.onPlan();
check(height(P) == 4 && all(P.Enabled), 'Plan: both plots on both datasets');
R = app.onRunExport(Plots="psth_1");
files = dir(fullfile(outRoot, '**', '*psth_1*.png'));
check(height(R) == 2 && all(R.Status == "done") && numel(files) >= 2 && isfile(fullfile(outRoot, 'analysis_report.html')) ...
    && app.OpenReportButton.Enable == "on" && contains(app.RunLabel.Text, "2 done"), ...
    'Run (psth_1): figures for both datasets and the report');
check(any(contains(string(app.LogArea.Value), "psth_1 done")), 'the Log tab has the runner''s lines');

fprintf('\n== 6. close ==\n');
app.savePreferences();
check(strcmp(getpref(g, 'LastConfigFile'), cfgFile), 'the last config is remembered');
app.onClose();
check(~isvalid(app.Fig), 'Close (clean config) closes the window');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysAnalysisApp:Failures', '%d checks failed.', nFail);
end
end


function closeApp(app)
try
    if isvalid(app) && isvalid(app.Fig)
        delete(app.Fig);
    end
catch
end
end


function restorePrefsAndRoot(g, savedPrefs, root)
try
    if ispref(g); rmpref(g); end
    if isstruct(savedPrefs)
        for f = string(fieldnames(savedPrefs)).'
            setpref(g, char(f), savedPrefs.(f));
        end
    end
catch
end
if isfolder(root)
    try
        rmdir(root, 's');
    catch
    end
end
end
