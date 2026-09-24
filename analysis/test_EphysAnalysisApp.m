function test_EphysAnalysisApp()
%test_EphysAnalysisApp  Headless checks of the analysis GUI over a synthetic project.
%   Builds the app on a small synthetic project run through the pipeline
%   and drives it through its own methods: the tabs; Scan filling the
%   datasets table; the active dataset's lines and parameters; grouping by
%   Depth from the Alignment controls (the epoch count reports the groups);
%   adding a PSTH and previewing it into the preview panel; editing the plot
%   (bins; an edit in a "Use default" section giving the plot its own event
%   reference or window, ticking it again going back); the editor showing
%   only the rows and sections a plot uses (y limits, heat colours, the
%   alignment sections), greying out the ones its options switch off, and
%   collapsing a section;
%   the gather / apply round trip, keeping the fields without a control
%   (stop-event offset, length and time range, trial rows); save
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
cleanup = onCleanup(@() restorePrefsAndRoot(g, savedPrefs, root));
if ispref(g, 'LastConfigFile'); setpref(g, 'LastConfigFile', ''); end
if ispref(g, 'PlotSectionsCollapsed'); rmpref(g, 'PlotSectionsCollapsed'); end

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
appCleanup = onCleanup(@() closeApp(app));
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
key1 = app.Runner.Keys(k);
app1 = EphysAnalysisApp(F.proj, Datasets=key1);
[~, leaf1] = fileparts(key1);
check(app1.Config.Source.Selection == "list" && isequal(app1.Config.Source.Datasets, key1) ...
    && height(app1.DatasetsTable.Data) == 2 && isequal(app1.Ticked, app1.Runner.Keys == key1) ...
    && app1.ActiveIdx >= 1 && app1.Runner.Names(app1.ActiveIdx) == F.names(1) ...
    && app1.Config.Name == string(leaf1) + " quick look" && ~startsWith(app1.Fig.Name, "*"), ...
    ['Datasets= (the preprocessing app''s Tools panel) ticks only those datasets of the project to run, ' ...
    'the first one active, and names the config after the one']);
closeApp(app1);

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
check(isscalar(app.Config.Plots) && app.SelectedPlot == 1 && app.Config.Plots(1).id == "psth_1" ...
    && string(app.PlotEditor.kind.Text) == "PSTH" && string(app.PlotsListBox.Items{1}) == "psth_1  (psth)", ...
    'Add psth makes psth_1 and opens it in the editor');
app.refreshPreview(Force=true);
axs = findall(app.PreviewPanel, 'Type', 'axes');
check(~isempty(axs) && ~isempty(app.PreviewResult) && app.PreviewResult.kind == "psth" && isfinite(app.PreviewSeconds), ...
    sprintf('the preview draws %d axes into the preview panel', numel(axs)));
E = app.PlotEditor;
A = app.PlotAlignControls;
check(E.defaultRef.Value && E.defaultWindow.Value && A.Line.Enable == "on" && A.Pre.Enable == "on" ...
    && A.Filter.Enable == "on" && shown(A.Line) && shown(A.Pre) && shown(A.Filter), ...
    'the event, window and selection sections are shown and editable while they use the defaults');
E.binMs.Value = 20;
app.onConfigChanged("plot");
A.Line.Value = 'Trial';
app.onPlotAlignEdited("ref");
p = app.Config.Plots(1);
check(p.bins.BinSec == 0.02 && isstruct(p.ref) && p.ref.line == "Trial" && ~E.defaultRef.Value ...
    && isequal(p.window, "default") && E.defaultWindow.Value && app.Config.Defaults.EventRef.line == "Stim", ...
    'editing the bins; editing the event line gives the plot its own event reference; the window stays default');
A.Pre.Value = -0.35;
app.onPlotAlignEdited("window");
p = app.Config.Plots(1);
check(isstruct(p.window) && p.window.pre == -0.35 && ~E.defaultWindow.Value && app.Config.Defaults.Window.pre ~= -0.35, ...
    'editing the window''s pre gives the plot its own window; the Alignment tab''s is unchanged');
E.defaultWindow.Value = true;
app.onPlotDefaultToggled();
p = app.Config.Plots(1);
check(isequal(p.window, "default") && A.Pre.Value == app.Config.Defaults.Window.pre && isstruct(p.ref), ...
    'ticking Use default again goes back to (and shows) the default window');
check(shown(E.stack) && shown(E.normalize) && shown(E.fill) && shown(E.fillAlpha) && shown(E.colormap) ...
    && E.fillAlpha.Enable == "on" && E.stackSpacing.Enable == "off" && ~shown(E.heatColormap) && ~shown(E.param) ...
    && ~shown(E.value) && ~shown(E.metric) && string(A.Mode.ItemsData) == "fixed", ...
    ['a PSTH shows stack, normalize, fill, opacity and group colours (spacing waits for Stack), not heat colours ' ...
    'or other kinds'' rows; its window is fixed']);
E.stack.Value = true; E.normalize.Value = 'groupPeak'; E.fill.Value = false; E.stackSpacing.Value = 0.8;
E.colormap.Value = 'black'; E.lineWidth.Value = 2;
app.onConfigChanged("plot");
p = app.Config.Plots(1);
check(p.stack && p.normalize == "groupPeak" && ~p.fill && isnan(p.fillAlpha) && p.stackSpacing == 0.8 ...
    && p.style.Colormap == "black" && p.style.LineWidth == 2 && E.stackSpacing.Enable == "on" && E.fillAlpha.Enable == "off" ...
    && E.ylim.Enable == "off" && E.legend.Enable == "off", ...
    'stack, group-peak normalization, unfilled, spacing 0.8, black, width 2 reach the plot; spacing on, opacity / y limits / legend off');
app.refreshPreview(Force=true);
axs = findall(app.PreviewPanel, 'Type', 'axes');
check(any(arrayfun(@(a) numel(a.YAxis) == 2, axs)) == (nG > 1), 'the preview draws the stack (value and peak axes)');
app.onAddPlot("evoked");
check(app.SelectedPlot == 2 && string(E.source.Value) == "LFP" && ~any(string(E.source.Items) == "units") ...
    && ~shown(E.binMs) && ~shown(E.withRaster) && ~shown(E.stack) && ~shown(E.fill) && ~shown(E.classes.su) && ~shown(E.ids) ...
    && shown(E.channels) && shown(E.baselineMode) && shown(E.lineWidth), ...
    'an evoked plot reads LFP and shows its channels and baseline, not the unit, bin or PSTH rows');
app.PlotEditor.source.Value = 'LFP';
app.onConfigChanged("plot");
app.refreshPreview(Force=true);
check(~isempty(app.PreviewResult) && app.PreviewResult.kind == "evoked" && ~isempty(findall(app.PreviewPanel, 'Type', 'axes')), ...
    'the LFP evoked potential previews');
ylStack = shown(E.ylim);
E.layout.Value = 'grid'; app.syncPlotEditor();
ylGrid = shown(E.ylim);
E.layout.Value = 'stack'; app.syncPlotEditor();
app.onAddPlot("raster");
ylRaster = shown(E.ylim);
app.onRemovePlot();
check(~ylStack && ylGrid && ~ylRaster && numel(app.Config.Plots) == 2 && app.SelectedPlot == 2, ...
    'y limits are hidden where they would hide rows (an evoked stack, a raster), shown for an evoked grid');
app.onAddPlot("probemap");
sec = app.PlotSections;
check(~shown(E.defaultRef) && ~shown(A.Line) && ~shown(A.Pre) && ~shown(A.Filter) && ~shown(E.baselineMode) ...
    && shown(E.value) && shown(E.heatColormap) && ~shown(E.colormap) && ~shown(E.maxTiles), ...
    'a probe map hides the event, window, selection and baseline; it shows its value and heat colours');
app.onRemovePlot();
app.onPlotSelected(1);
app.onPlotSectionToggled("style");
collapsed = ~shown(E.fontSize) && shown(sec([sec.Name] == "style").Toggle);
app.onPlotSectionToggled("style");
check(collapsed && shown(E.fontSize), 'the Appearance section collapses to its header and expands again');
app.onPlotSectionToggled("bins");
app.onPlotSelected(1);
check(app.SelectedPlot == 1 && app.PlotEditor.binMs.Value == 20 && app.PlotEditor.stack.Value ...
    && string(app.PlotEditor.normalize.Value) == "groupPeak" && isempty(app.PlotEditor.fillAlpha.Value) ...
    && string(app.PlotEditor.colormap.Value) == "black", 'selecting plot 1 shows its edits');

fprintf('\n== 4. gather / apply, save / reopen, script ==\n');
c1 = app.gatherConfig();
app.applyConfig(c1);
c2 = app.gatherConfig();
check(c1.isequalConfig(c2), 'gatherConfig -> applyConfig -> gatherConfig is the same config');
c3 = c1;
c3.Defaults.Window.stop = struct('line', "Stim", 'edge', "offset", 'which', "nth", 'n', 2, 'scope', "trial", ...
    'offsetSec', 0.05, 'minDurationSec', 0.01, 'maxDurationSec', 5, 'timeRange', [0 60]);
c3.Defaults.Selection.trials = [1 3 5];
c3.Plots(1).window = c3.Defaults.Window;
c3.Plots(1).selection = c3.Defaults.Selection;
app.applyConfig(c3);
app.onConfigChanged("defaults");   % an edit re-gathers the config from the controls
c4 = app.gatherConfig();
check(c4.isequalConfig(c3) && app.AlignControls.StopN.Value == 2 && app.PlotAlignControls.StopN.Value == 2, ...
    'a re-gather keeps what has no control (the stop event''s offset, length and time range; trial rows) and the stop''s n');
app.applyConfig(c1);
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
check(strcmp(getpref(g, 'LastConfigFile'), cfgFile) && isequal(string(getpref(g, 'PlotSectionsCollapsed')), "bins"), ...
    'the last config and the collapsed plot-editor section are remembered');
app.onClose();
check(~isvalid(app.Fig), 'Close (clean config) closes the window');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysAnalysisApp:Failures', '%d checks failed.', nFail);
end
end


function tf = shown(h)
%shown  H and every container above it are visible (hidden row, section or collapsed).
tf = true;
while ~isempty(h) && ~isa(h, 'matlab.ui.Figure')
    if isprop(h, 'Visible') && h.Visible == "off"
        tf = false;
        return
    end
    h = h.Parent;
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
