function test_EphysPreprocessingApp()
%test_EphysPreprocessingApp  Headless checks of the GUI's config model.
%   Builds the app in the current session (uifigure; no display interaction),
%   opens a config over a synthetic project, and checks: config -> controls ->
%   config round trip, the unsaved-changes marker, scan + selection ticks,
%   plan, the Sorting tab's Optimize for probe / Reset to defaults, running
%   one step through EphysPipeline, save, a config for another project
%   root, a rescan that keeps the active dataset, the Visualize bins and
%   overlay, the Kilosort4 monitor and queue, the phy launch, a figure
%   deleted without Close, and that the app's
%   preferences are restored afterwards. Dialogs that would block (uiconfirm)
%   are never triggered because the config is kept clean before New / Close.
%
%   Usage:  test_EphysPreprocessingApp

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));
addpath(genpath(fullfile(fileparts(here), 'vendor')));

root = fullfile(tempdir, sprintf('App_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);

% Preserve the user's preferences (the app writes LastConfigFile / recents).
g = EphysPreprocessingApp.PrefGroup;
savedPrefs = [];
if ispref(g); savedPrefs = getpref(g); end
cleanup = onCleanup(@() restorePrefsAndRoot(g, savedPrefs, root)); %#ok<NASGU>
if ispref(g, 'LastConfigFile'); setpref(g, 'LastConfigFile', ''); end
if ispref(g, 'DatasetsColumnOrder'); rmpref(g, 'DatasetsColumnOrder'); end
if ispref(g, 'TrialsParamColumns'); rmpref(g, 'TrialsParamColumns'); end
if ispref(g, 'TrialsColumnOrder'); rmpref(g, 'TrialsColumnOrder'); end
if ispref(g, 'TrialsLabelParams'); rmpref(g, 'TrialsLabelParams'); end
if ispref(g, 'MonitorResources'); rmpref(g, 'MonitorResources'); end
if ispref(g, 'ShowRunDiagram'); rmpref(g, 'ShowRunDiagram'); end
if ispref(g, 'CleanupOptions'); rmpref(g, 'CleanupOptions'); end

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

% ---- fixture ---------------------------------------------------------------
Fs = 30000; numAmp = 4; spb = 128; nSamp = 4 * spb;
rng(5);
ampRaw = uint16(randi([0 65535], numAmp, nSamp));
digRaw = zeros(1, nSamp); digRaw(50:70) = 1;
proj = fullfile(root, 'proj');
f1 = fullfile(proj, 'recA_260101_120000'); mkdir(f1);   % <SubjectID>_<yyMMdd>_<HHmmss>
writeSyntheticRHD(fullfile(f1, 'recA.rhd'), ampRaw, digRaw, Fs, spb);
phyDir = fullfile(root, 'phy');
makePhyFixture(phyDir, Fs, ChannelMap=[0 1 2 3], SettingsJson=true);
d = EphysDataset(f1);
d.SortingDir = phyDir;
d.ManualArtifacts = [0.001 0.002];
behFile = fullfile(root, 'recA_session.mat');
Data = struct('ToneLevel', {60}, 'TrialIndex', {1}, 'computerTimestamp', {datetime(2026,1,1,12,0,1)}, ...
    'isTest', {false}); %#ok<NASGU>
Info = struct('Subject', "mouseA", 'StartTime', datetime(2026,1,1,12,0,0), 'FormatVersion', 2); %#ok<NASGU>
save(behFile, 'Data', 'Info');
d.BehaviorFile = behFile;
d.writeManifest();
outRoot = fullfile(root, 'out');
cfg = EphysPipelineConfig();
cfg.Name = "gui test";
cfg.Project.Root = proj;
cfg.Project.OutputRoot = outRoot;
cfg.Spikes.Enabled = true; cfg.Spikes.Filter = false; cfg.Spikes.ThresholdMethod = "absolute"; cfg.Spikes.Threshold = 2000;
cfg.Spikes.Source = "both";
cfg.Export.Formats = "chronux";
cfg.Sorting.KS4.nblocks = 3; cfg.Sorting.KS4.dmin = 12;
cfg.Parallel.Enabled = true; cfg.Parallel.MaxWorkers = 3;
cfgFile = fullfile(root, 'gui_test.json');
cfg = cfg.save(cfgFile);

fprintf('\n== 1. build + open ==\n');
app = EphysPreprocessingApp;
appCleanup = onCleanup(@() closeApp(app));
check(isvalid(app.Fig) && numel(app.Tabs.Children) == 14 && app.Tabs.Children(1) == app.TabCopy ...
    && app.Tabs.Children(3) == app.TabTrials && app.Tabs.Children(end) == app.TabCleanup && app.Tabs.SelectedTab == app.TabProject, ...
    'app builds with 14 tabs (Copy first, Trials third, Clean up last) and opens on Project');
check(startsWith(app.Fig.Name, "Ephys preprocessing") && ~startsWith(app.Fig.Name, "*"), 'fresh app is clean');
ok = app.openConfigFile(cfgFile);
check(ok && app.Config.Name == "gui test" && app.Config.File == string(cfgFile), 'openConfigFile loads the config');
check(strcmp(app.RootPathField.Value, proj) && app.SpkEnableCheckBox.Value && strcmp(app.SpkThresholdField.Value, '2000') ...
    && app.ExpChronuxCheckBox.Value && ~app.ExpFieldTripCheckBox.Value && app.ParamControls.nblocks.Value == 3 ...
    && strcmp(app.ParamControls.dmin.Value, '12'), 'controls reflect the config');
check(app.RunParallelCheckBox.Value && strcmp(app.RunMaxWorkersField.Value, '3') && strcmp(app.RunMaxWorkersField.Enable, 'on') ...
    && ~isprop(app, 'SpkParallelCheckBox'), 'the Run tab shows the Parallel section; the Spikes tab has no parallel box');
check(tabTip(app, app.TabSpikes) ~= "Step disabled." && tabTip(app, app.TabSignals) == "Step disabled." && app.RunSpikesCheckBox.Value, ...
    'tab strip states and the Run checklist follow the enabled steps');
app.selectTab(app.TabFlow);
html = string(app.FlowHTML.HTMLSource);
check(contains(html, "Preprocessing diagram: gui test") ...
    && contains(html, "thr = 2000 &micro;V") && contains(html, "Bandpass filter</div><div class=""d"">off (raw trace)") ...
    && contains(html, "nblocks 3") && contains(html, "Chronux file") && ~contains(html, "FieldTrip file") ...
    && contains(html, "+ sorted units (see downstream)") && startsWith(app.FlowSummaryLabel.Text, "1 of 4"), ...
    'the Diagram tab charts the loaded config (spike threshold, filter off, KS4 drift, export formats)');
app.SpkThresholdField.Value = '2500';
app.onSpikesControlsChanged();
check(contains(string(app.FlowHTML.HTMLSource), "thr = 2500 &micro;V"), 'the Diagram follows config edits while shown');
app.SpkThresholdField.Value = '2000';
app.onSpikesControlsChanged();

fprintf('\n== 1a. Diagram: boxes open their settings ==\n');
loaded = app.Config;                       % put back after the every-branch chart below
allOn = loaded;
allOn.Artifacts.Enabled = true; allOn.Sorting.Enabled = true; allOn.Signals.Enabled = true;
allOn.Signals.LFP = true; allOn.Signals.MUA = true; allOn.Signals.SPIKE = true; allOn.Signals.AUX = true;
allOn.Export.Enabled = true; allOn.Export.Formats = ["chronux" "fieldtrip" "epochs"];
app.applyConfig(allOn);
full = string(app.FlowHTML.HTMLSource);
targets = unique(strip(split(join(string(regexp(full, '(?<=data-nav=")[^"]+', 'match')), ","), ",")));
missing = targets(arrayfun(@(t) isempty(app.flowNavControls(t)), targets));
msg = sprintf('every one of the %d controls the Diagram boxes point at exists', numel(targets));
if ~isempty(missing); msg = msg + " (missing: " + join(missing, ", ") + ")"; end
check(numel(targets) > 50 && isempty(missing) && contains(full, "sendEventToMATLAB('navigate'") ...
    && ~isempty(app.FlowHTML.HTMLEventReceivedFcn), msg);
check(isempty(regexp(full, '<div class="n k-[a-z]+">', 'once')) && count(full, "<header data-nav=") == 6, ...
    'no box is left without a target, and each of the 6 step headers has one too');
app.applyConfig(loaded);
drift = struct('nav', 'ks4.nblocks,ks4.sig_interp,ks4.binning_depth,ks4.dmin,ks4.dminx', 'title', 'Drift correction');
app.onFlowNavigate(struct('HTMLEventName', 'navigate', 'HTMLEventData', drift));
check(app.Tabs.SelectedTab == app.TabSorting && numel(app.FlowHighlight) == 5 ...
    && isequal(app.ParamControls.nblocks.FontColor, [0.15 0.45 0.80]) && app.ParamControls.dmin.FontWeight == "bold" ...
    && contains(app.StatusBar.Text, "Drift correction is set on the Sorting tab"), ...
    'a click in the Diagram opens the first control''s tab, marks every control of the box and says where it went');
app.selectTab(app.TabFlow);
check(isempty(app.FlowHighlight) && app.ParamControls.nblocks.FontWeight == "normal" ...
    && isequal(app.ParamControls.nblocks.FontColor, app.ParamControls.nt.FontColor), ...
    'the marks come off when the tab changes');
app.onFlowNavigate(struct('HTMLEventName', 'navigate', ...
    'HTMLEventData', struct('nav', 'NoSuchField', 'title', 'Gone')));
check(app.Tabs.SelectedTab == app.TabFlow && contains(app.StatusBar.Text, "no setting to open"), ...
    'a box pointing at a control that no longer exists says so instead of navigating');
app.selectTab(app.TabProject);
g2 = app.gatherConfig();
check(g2.isequalConfig(app.Config) && isequaln(g2.toStruct(), cfg.toStruct()), 'gatherConfig reproduces the loaded config exactly');
check(~startsWith(app.Fig.Name, "*") && contains(app.Fig.Name, "gui_test.json"), 'title shows the file and no unsaved marker');

% the Export tab's event-epoch settings, both ways
app.ExpEpochsCheckBox.Value = true;
app.ExpEpochSourceDropDown.Value = 'behavior';
app.ExpEpochPreField.Value = -0.35;
app.ExpEpochPostField.Value = 0.8;
app.ExpEpochSpikeBaseDropDown.Value = 'window';
app.ExpEpochIncompleteDropDown.Value = 'drop';
gE = app.gatherExportSection();
check(any(gE.Formats == "epochs") && gE.EpochSource == "behavior" && isequal(gE.EpochWindow, [-0.35 0.8]) ...
    && gE.EpochSpikeTimeBase == "window" && gE.EpochIncomplete == "drop", ...
    'the Export tab''s epoch settings reach the Export section');
app.applyExportSection(app.Config.Export);
check(~app.ExpEpochsCheckBox.Value && strcmp(app.ExpEpochSourceDropDown.Value, 'line') ...
    && app.ExpEpochPreField.Value == -0.2 && strcmp(app.ExpEpochIncompleteDropDown.Value, 'nan'), ...
    'applyExportSection puts the epoch settings back');

fprintf('\n== 1b. Help menu: wiki pages ==\n');
items = flip(string({app.HelpMenu.Children.Text}));
check(isequal(items(1:2), ["Help for this tab" "Documentation home"]) && numel(items) == 12 ...
    && isequal(items(10:12), ["Report an issue on GitHub..." "Request a feature on GitHub..." "About EphysPreprocessingApp"]) ...
    && app.helpURL("") == app.WikiURL && app.helpURL("Quick-Start") == app.WikiURL + "/Quick-Start", ...
    'the Help menu opens the tab''s page, the wiki home, the guides, the two GitHub issue items and About');
v = ephysVersion();
check(~isempty(regexp(v.Version, '^\d+\.\d+\.\d+$', 'once')) && startsWith(v.Text, v.Version) ...
    && (v.Commit == "" || contains(v.Text, "commit " + v.Commit)) && isfolder(v.Folder + "/pipeline"), ...
    'ephysVersion gives the release number, the git commit and the repository folder');
tabPages = strings(1, numel(app.TabList));
for k = 1:numel(app.TabList)
    app.Tabs.SelectedTab = app.TabList(k);   % helpURL reads only the selection; no tab-change refresh needed
    tabPages(k) = app.helpURL("tab");
end
app.Tabs.SelectedTab = app.TabProject;
check(numel(tabPages) == 14 && numel(unique(tabPages)) == 14 && all(startsWith(tabPages, app.WikiURL + "/")) ...
    && ~any(endsWith(tabPages, "/App-Overview")), 'every tab has its own wiki page');

fprintf('\n== 1c. Help menu: GitHub issue and feature request ==\n');
bug = app.issueReport("bug", Description="the Spikes step stops here");
check(contains(bug, "### What happened") && contains(bug, "the Spikes step stops here") ...
    && contains(bug, "### Steps to reproduce") && contains(bug, "<summary>System</summary>") ...
    && contains(bug, "MATLAB") && contains(bug, "<summary>Pipeline options</summary>") ...
    && contains(bug, "gui test") && contains(bug, "<summary>Config JSON</summary>") ...
    && contains(bug, """schema""") && contains(bug, "<summary>Logs</summary>"), ...
    'a bug report carries the description, the system, the config and the logs');
feat = app.issueReport("feature", Description="a button that stitches", System=false, Config=false, Logs=false);
check(contains(feat, "### What would you like to be able to do") && contains(feat, "a button that stitches") ...
    && ~contains(feat, "<details>") && ~contains(feat, "### What happened") ...
    && ~contains(feat, string(proj)), 'a feature request keeps only what is ticked: no system, config or logs');
app.LastError = MException("EphysPreprocessingApp:test", "synthetic failure");
app.LastErrorTime = datetime('now');
err = app.issueReport("bug", System=false, Config=false);
check(contains(err, "**Last run error**") && contains(err, "synthetic failure") ...
    && ~contains(app.issueReport("bug", System=false, Config=false, Logs=false), "synthetic failure"), ...
    'the last run error and its stack go with the report, unless the logs are unticked');
app.LastError = MException.empty(0, 1);
app.LastErrorTime = NaT;
[url, cut] = app.issueURL("bug", "a title", "line one" + newline + "line two");
check(startsWith(url, app.RepoURL + "/issues/new?") && contains(url, "title=a%20title") ...
    && contains(url, "body=line%20one%0Aline%20two") && contains(url, "labels=bug") ...
    && ~cut && ~contains(url, " ") && ~contains(url, newline), ...
    'the issue address is the prefilled form, percent-encoded');
check(contains(app.issueURL("feature", "t", "b"), "labels=enhancement"), ...
    'a feature request is filed as an enhancement');
[long, cut] = app.issueURL("bug", "t", join(repmat("0123456789", 1, 2000), newline));
check(cut && strlength(long) <= 7000 && contains(long, "was%20too%20long%20for%20the%20address"), ...
    'a report too long for the address is cut and says so in the body');

fprintf('\n== 1d. a config with values the controls cannot show ==\n');
bad = cfg;
bad.Name = "cannot show";
bad.Artifacts.Threshold = NaN;            % detection is off: validate lets it pass
bad.Behavior.MaxStartOffsetMin = 0;       % Behavior is off; the field wants more than 0
bad.Spikes.Source = "nonsense";
badFile = fullfile(root, 'cannot_show.json');
bad.save(badFile);
ok = app.openConfigFile(badFile);
check(ok && app.Config.Name == "cannot show" && numel(app.ApplyRejected) == 3 ...
    && contains(join(app.ApplyRejected), "Artifacts.Threshold = NaN") && contains(join(app.ApplyRejected), "Behavior.MaxStartOffsetMin = 0") ...
    && contains(join(app.ApplyRejected), "Spikes.Source") && app.Config.Artifacts.Threshold == app.ArtThresholdField.Value ...
    && app.Config.Behavior.MaxStartOffsetMin == app.BehMaxOffsetField.Value && startsWith(app.Fig.Name, "*"), ...
    'a config with values its fields cannot show opens: those are listed, the config holds what the fields show and is marked unsaved');
ok = app.openConfigFile(cfgFile);
check(ok && isempty(app.ApplyRejected) && ~startsWith(app.Fig.Name, "*") && app.Config.Spikes.Source == "both", ...
    'the good config opens clean again');

fprintf('\n== 2. edits and the unsaved marker ==\n');
app.SpkThresholdField.Value = '1500';
app.onSpikesControlsChanged();
check(app.Config.Spikes.Threshold == 1500 && startsWith(app.Fig.Name, "*"), 'a control edit updates the config and marks it unsaved');
app.RunSignalsCheckBox.Value = true;
app.RunSignalsCheckBox.ValueChangedFcn(app.RunSignalsCheckBox, []);   % as a click would
check(app.Config.Signals.Enabled && app.SigEnableCheckBox.Value && tabTip(app, app.TabSignals) ~= "Step disabled.", ...
    'the Run checklist and the step tab stay in sync');
app.SigEnableCheckBox.Value = false;
app.onConvertControlsChanged();
check(~app.Config.Signals.Enabled && ~app.RunSignalsCheckBox.Value, 'and back');
app.SortEnableCheckBox.Value = true;
app.SortSkipExistingCheckBox.Value = true;
app.SortEnableCheckBox.ValueChangedFcn(app.SortEnableCheckBox, []);   % as a click would
check(app.Config.Sorting.Enabled && app.Config.Sorting.SkipExisting && app.SortEnableCheckBox.Value ...
    && app.RunSortingCheckBox.Value, 'ticking Enable on the Sorting tab sticks');
app.SortEnableCheckBox.Value = false;
app.SortSkipExistingCheckBox.Value = false;
app.SortEnableCheckBox.ValueChangedFcn(app.SortEnableCheckBox, []);
app.RunMaxWorkersField.Value = '';
app.onParallelControlsChanged();
check(isnan(app.Config.Parallel.MaxWorkers) && app.Config.Parallel.Enabled, 'a blank worker cap means automatic');
app.RunParallelCheckBox.Value = false;
app.onParallelControlsChanged();
check(~app.Config.Parallel.Enabled && strcmp(app.RunMaxWorkersField.Enable, 'off'), 'unticking Parallel disables the worker cap');
app.RunParallelCheckBox.Value = true;
app.onParallelControlsChanged();
[html, ~] = app.flowChartHTML();
check(contains(html, "Write .bin") && contains(html, "run_kilosort") && ~contains(html, "SpikeInterface"), ...
    'the Sorting diagram shows Kilosort4 on a .bin');
app.ParamControls.tmax.Value = 'abc';
[~, msg] = app.gatherSortingSection();
check(msg ~= "", 'an unparseable KS4 field is reported');
app.ParamControls.tmax.Value = 'Infinity';
app.ParamControls.drift_smoothing.Value = '1, 2, 3';
app.onConfigChanged();
app.ParamControls.drift_smoothing.Value = 'x, 2, 3';
app.onConfigChanged();
[S, msg] = app.gatherSortingSection();
check(isequal(app.Config.Sorting.KS4.drift_smoothing, [1 2 3]) && isequal(S.KS4.drift_smoothing, [1 2 3]) ...
    && contains(msg, "drift_smoothing") && contains(app.StatusBar.Text, "drift_smoothing") && ~app.onSaveConfig(), ...
    'a Kilosort4 field that does not parse keeps the value in force (not the default), is reported, and Save refuses');
app.ParamControls.drift_smoothing.Value = '0.5, 0.5, 0.5';
app.onConfigChanged();
K0 = app.Config.Spikes;
K = K0; K.Threshold = 0.1953125; K.MaxAmplitudeUV = 123.456789; K.EdgePadMs = 0.1;
app.applySpikesSection(K);
gK = app.gatherSpikesSection();
check(strcmp(app.SpkThresholdField.Value, '0.1953125') && gK.Threshold == 0.1953125 ...
    && gK.MaxAmplitudeUV == 123.456789 && gK.EdgePadMs == 0.1, ...
    'numbers in the Spikes text fields are written in full and read back unchanged (0.1953125, not 0.19531)');
app.applySpikesSection(K0);
app.ArtMethodDropDown.Value = 'microvolts';
app.onArtifactControlsChanged();
check(app.ArtThresholdField.Value == 1500 && app.Config.Artifacts.Threshold == 1500, ...
    'switching Method to Absolute microvolts takes its own default threshold (1500 uV), not the running-RMS 9');
app.ArtThresholdField.Value = 800;
app.onArtifactControlsChanged();
app.ArtMethodDropDown.Value = 'commonmode';
app.onArtifactControlsChanged();
check(app.ArtThresholdField.Value == 800, 'a threshold typed for the previous method is kept');
app.ArtMethodDropDown.Value = 'rms';
app.ArtThresholdField.Value = 1500;
app.onArtifactControlsChanged();
check(app.ArtThresholdField.Value == 9 && app.Config.Artifacts.Method == "rms", ...
    'back to running RMS from the common-mode default: 9 robust SDs again');
A0 = app.Config.Artifacts;
A2 = A0; A2.Filter = true; A2.FilterType = "bandpass"; A2.FilterCutoff = [300 3000]; A2.FilterOrder = 2;
app.applyArtifactsSection(A2);
app.Config.Artifacts = A2;   % as applyConfig leaves it
app.ArtHighpassField.Value = 400;
app.onArtifactControlsChanged();
gA = app.Config.Artifacts;
check(gA.FilterType == "bandpass" && gA.FilterOrder == 2 && isequal(gA.FilterCutoff, [400 3000]), ...
    'the filter type, order and upper band edge (no control) are kept; the High-pass field sets the band''s lower edge');
A3 = A0; A3.Filter = true; A3.FilterType = "lowpass"; A3.FilterCutoff = 250;
app.applyArtifactsSection(A3);
app.Config.Artifacts = A3;
app.onArtifactControlsChanged();
check(app.Config.Artifacts.FilterType == "lowpass" && app.Config.Artifacts.FilterCutoff == 250 ...
    && strcmp(app.ArtHighpassField.Enable, 'off'), 'a low-pass filter keeps its cut-off, and the High-pass field is off');
app.applyArtifactsSection(A0);
app.Config.Artifacts = A0;
app.onArtifactControlsChanged();

fprintf('\n== 3. scan, selection, plan ==\n');
app.onScan();
T = app.DatasetsTable.Data;
check(~isempty(app.Project) && app.Project.NumDatasets == 1 && height(T) == 1 && T.Key(1) == "recA_260101_120000" ...
    && contains(T.Sorting(1), "manual"), 'scan fills the table with keys and the sorting association');
check(~T.Select(1) && app.Config.Project.Selection == "all", 'no ticks = every dataset');
check(numel(app.DatasetTickedItems) == 1 && string(app.DatasetTickedItems.Text) == "(no datasets ticked)" ...
    && numel(app.DatasetMenuItems) == 1 && isequal(app.DatasetMenu.Children(1:2), [app.DatasetManifestItem; app.DatasetAllMenu]), ...
    'the Dataset menu lists no datasets while none is ticked; All datasets lists every one; View manifest at the bottom');
app.onSelectDatasets("all");
check(app.Config.Project.Selection == "list" && isequal(app.Config.Project.Datasets, "recA_260101_120000"), 'ticking rows selects by key');
check(numel(app.DatasetTickedItems) == 1 && isequal(app.DatasetTickedItems.UserData, 1) && app.DatasetTickedItems.Checked ...
    && isequal(app.DatasetMenu.Children(1:2), [app.DatasetManifestItem; app.DatasetAllMenu]), ...
    'a ticked dataset is listed above All datasets, checked when active');
check(all(arrayfun(@(dd) isequal(dd.ItemsData, {1}) && isequal(dd.Value, 1), app.DatasetPickers)), ...
    'every tab''s Dataset box lists the ticked datasets');
app.onSelectDatasets("none");
check(app.SelectedDatasetIdx == 1 && app.DatasetMenuItems(1).Checked && numel(app.DatasetPickers) == 7 ...
    && all(arrayfun(@(dd) isequal(dd.Value, 1), app.DatasetPickers)) && height(app.DatasetsTable.StyleConfigurations) == 1, ...
    'the scan makes the dataset active: menu item checked, every tab''s Dataset box set, table row highlighted');
app.onDatasetCellSelection(struct('Indices', [1 1]));
check(contains(app.SortResultsLabel.Text, "manual") && size(app.ArtManualTable.Data, 1) == 1, ...
    'selecting a row shows its sorting association and manual periods');
app.onViewManifest();
mv = findall(groot, 'Type', 'figure', 'Name', "Manifest - recA_260101_120000_manifest.json");
mvT = findall(mv, 'Type', 'uitable');
check(isscalar(mv) && isscalar(mvT) && any(mvT.Data.Field == "Periods" & mvT.Data.Value == "1") ...
    && contains(app.StatusBar.Text, "Opened the manifest of recA_260101_120000"), ...
    'Dataset > View manifest opens the active dataset''s manifest in a viewer');
close(mv);
check(~any(isvalid(mv)), 'closing the viewer window closes it');
check(~isempty(app.EpsychMetaCache) && isKey(app.EpsychMetaCache, char(behFile)) ...
    && contains(app.DatasetsTable.Data.Behavior(1), "(1 trials)"), ...
    'the Behavior column reads the session summary once and keeps it until the file changes');
app.ExcludeChannelsField.Value = '1,5,32-40,4O';
app.onApplyExclude("selected");
app.ArtRefExcludeField.Value = '2,x';
app.onReferenceExcludeEdited();
check(isempty(app.currentDataset().ExcludeChannels) && strcmp(app.ExcludeChannelsField.Value, '') ...
    && isempty(app.currentDataset().ReferenceExclude) && app.ArtRefExcludeField.Value == "", ...
    'a channel list that does not parse ("4O", "x") changes nothing and the fields show the lists in force');
app.onPlan();
P = app.RunResultsTable.Data;
check(istable(P) && any(P.Step == "spikes" & P.Status == "ready"), 'plan lists the spikes step as ready');
app.onValidate();
check(iscell(app.RunIssuesTable.Data) || istable(app.RunIssuesTable.Data), 'validate fills the issues table');

fprintf('\n== 3a0. Artifacts tab: the artifact viewer ==\n');
art0 = app.Config.Artifacts;
ax = app.ArtViewAxes;
check(~app.ArtView.previewed && strcmp(app.ArtViewSpinner.Enable, 'off') && app.ArtViewCountLabel.Text == "of 0" ...
    && contains(string(get(findobj(ax, 'Type', 'text'), 'String')), "Detect / Preview"), ...
    'the viewer asks for a preview until one has run');
app.ArtMethodDropDown.Value = 'microvolts';
app.ArtThresholdField.Value = 6300;
app.ArtMinChannelsField.Value = 1;
app.onArtifactControlsChanged();
app.onDetectArtifacts();
dA = app.Project.Datasets(1);
sm = dA.analyzeArtifacts();
nArt = size(app.ArtView.intervals, 1);
check(nArt > 1 && isequal(app.ArtView.intervals, sm.intervals) && app.ArtViewCountLabel.Text == "of " + nArt ...
    && isequal(app.ArtViewSpinner.Limits, [1 nArt]) && strcmp(app.ArtViewPrevButton.Enable, 'off') ...
    && strcmp(app.ArtViewNextButton.Enable, 'on') && startsWith(ax.Title.String, "Artifact 1 of " + nArt), ...
    'a preview loads the detected artifacts into the viewer and shows the first');
% Auto context (25 ms) spans the whole 512-sample recording; all 4 channels drawn.
nPts  = @(name) sum(arrayfun(@(h) nnz(~isnan(h.YData)), findobj(ax, 'Type', 'line', 'DisplayName', name)));
nKept = @() nPts('Kept');                 % one line per lane
nRem  = @() nPts('Removed (replaced)');
manMask = dA.manualArtifactMask(nSamp, 0, Fs);
allMask = manMask | dA.manualArtifactMask(nSamp, 0, Fs, sm.intervals);
check(numel(ax.YTick) == numAmp && nKept() == numAmp * (nSamp - nnz(manMask)) && nRem() > 0 ...
    && startsWith(app.ArtViewNoteLabel.Text, "Automatic detection is off") ...
    && numel(findobj(ax, 'Type', 'constantregion')) == nArt + 1, ...
    'detection off: only the manual period is removed (red), the detected artifacts shaded but kept');
app.ArtEnableCheckBox.Value = true;
app.onArtifactControlsChanged();
check(nKept() == numAmp * (nSamp - nnz(allMask)) && startsWith(app.ArtViewNoteLabel.Text, "Red is what a run removes: replaced"), ...
    'detection on: the detected artifacts are removed too');
app.ArtApplySortingCheckBox.Value = false; app.ArtApplySpikesCheckBox.Value = false;
app.onArtifactControlsChanged();
check(nKept() == numAmp * (nSamp - nnz(manMask)) && contains(app.ArtViewNoteLabel.Text, "both off"), ...
    'with neither use ticked a run keeps the detected artifacts');
app.ArtApplySortingCheckBox.Value = true; app.ArtApplySpikesCheckBox.Value = true;
app.ArtThresholdField.Value = 6000;
app.onArtifactControlsChanged();
check(startsWith(app.ArtViewNoteLabel.Text, "Detection settings changed"), 'a changed detection setting marks the preview stale');
app.ArtThresholdField.Value = 6300;
app.onArtifactControlsChanged();
check(startsWith(app.ArtViewNoteLabel.Text, "Red is what"), 'setting it back clears the mark');
app.ArtViewNextButton.ButtonPushedFcn(app.ArtViewNextButton, []);
check(app.ArtViewSpinner.Value == 2 && startsWith(ax.Title.String, "Artifact 2 of") ...
    && strcmp(app.ArtViewPrevButton.Enable, 'on'), 'Next steps to the second artifact');
app.ArtViewContextField.Value = 1;
app.ArtViewContextField.ValueChangedFcn(app.ArtViewContextField, []);
iv2 = sm.intervals(2, :);
check(diff(ax.XLim) <= 1e3 * diff(iv2) + 2 + 2e3 / Fs, 'Context sets the signal shown around it (ms)');
app.ArtViewChannelsField.Value = 2;
app.drawArtifactView();
fitAll = diff(ax.YLim);
check(numel(ax.YTick) == 2 && isequal(string(ax.Subtitle.String), ["the 2 of 4 channels it is largest on"; "broadband, as detected"]) ...
    && ~contains(ax.YLabel.String, "clipped"), ...
    'Channels picks the channels it is largest on (a long subtitle on two lines); fitting the artifact never clips');
app.ArtViewScaleDropDown.Value = 'kept';
app.drawArtifactView();
check(diff(ax.YLim) <= fitAll && numel(ax.YTick) == 2, 'fitting the kept signal gives lanes no wider');
check(abs(app.ArtViewLanesField.Value - diff(ax.YLim) / 2) < 1e-6 * diff(ax.YLim), 'Lanes shows the spacing drawn');
app.ArtViewLanesField.Value = 123;
app.ArtViewLanesField.ValueChangedFcn(app.ArtViewLanesField, []);
check(app.ArtViewScaleDropDown.Value == "manual" && abs(ax.YTick(2) - ax.YTick(1) - 123) < 1e-9 ...
    && contains(ax.YLabel.String, "123 uV"), 'typing a lane spacing sets the scale by hand');
app.drawArtifactView();
check(abs(ax.YTick(2) - ax.YTick(1) - 123) < 1e-9, 'a manual spacing survives a redraw');
app.ArtViewLanesField.Value = 0;
app.ArtViewLanesField.ValueChangedFcn(app.ArtViewLanesField, []);
check(app.ArtViewScaleDropDown.Value == "artifact" && abs(diff(ax.YLim) - fitAll) < 1e-6 * fitAll, ...
    'a spacing of 0 goes back to fitting the artifact');
app.ArtViewContextField.Value = 0; app.ArtViewChannelsField.Value = 8; app.ArtViewScaleDropDown.Value = 'artifact';
app.ArtThresholdField.Value = 1e6;
app.onArtifactControlsChanged();
app.onDetectArtifacts();
check(app.ArtView.previewed && isempty(app.ArtView.intervals) && strcmp(app.ArtViewNextButton.Enable, 'off') ...
    && contains(string(get(findobj(ax, 'Type', 'text'), 'String')), "No artifacts detected"), ...
    'a preview that detects nothing says so');
app.applyArtifactsSection(art0);
app.onArtifactControlsChanged();
app.selectDataset(1, Reset=true);
check(~app.ArtView.previewed && isempty(app.ArtView.win) && isequaln(app.Config.Artifacts, art0), ...
    'a dataset change clears the viewer; the settings are back as loaded');

fprintf('\n== 3a0b. Artifacts tab: probe layout, shanks, voltage and time scale ==\n');
check(~app.ArtProbeOrderCheckBox.Value && strcmp(app.ArtProbeOrderCheckBox.Enable, 'off') ...
    && isequal(app.ArtViewShankDropDown.ItemsData, {'all'}) && app.ArtViewShankColorCheckBox.Value ...
    && numel(app.ArtChannelTable.ColumnName) == 4, ...
    'without a probe: no probe order or shanks to pick, colour by shank on by default, no Shank column');
% Two shanks, the recording's channels crossing between them: 1 and 3 on
% shank 2, 2 and 4 on shank 1; 3 and 4 above 1 and 2.
probe2 = fullfile(root, 'twoShank.json');
writeJsonFile(probe2, struct('chanMap', (0:3).', 'xc', zeros(4, 1), 'yc', [0; 0; 20; 20], 'kcoords', [2; 1; 2; 1]));
dA = app.Project.Datasets(1);
dA.ProbeFile = probe2;
L = dA.channelLayout();
check(L.hasProbe && isequal(L.order, [4 2 3 1]) && isequal(L.shank, [2 1 2 1]) && isequal(L.shanks, [1 2]), ...
    'channelLayout places the channels: by shank, the top of each shank first');
app.syncArtProbeControls();
check(app.ArtProbeOrderCheckBox.Value && strcmp(app.ArtProbeOrderCheckBox.Enable, 'on') ...
    && isequal(app.ArtViewShankDropDown.ItemsData, {'all', '1', '2'}), ...
    'with a probe: probe order is on by default and its shanks are offered');
app.ArtMethodDropDown.Value = 'microvolts';
app.ArtThresholdField.Value = 6300;
app.ArtMinChannelsField.Value = 1;
app.onArtifactControlsChanged();
app.onDetectArtifacts();
w = app.ArtView.win;
lanes = @() string(ax.YTickLabel(:)).';   % bottom lane first
artT = app.ArtChannelTable.Data;
check(isequal(lanes(), w.names([1 3 2 4])) && numel(findall(ax, 'Type', 'constantline')) == 1 ...
    && isequal(cell2mat(artT(:, 1)).', [4 2 3 1]) && isequal(cell2mat(artT(:, 3)).', [1 1 2 2]), ...
    'the lanes and the table follow the probe (a dotted line between the shanks, a Shank column)');
k1 = findobj(ax, 'Type', 'line', 'DisplayName', 'Shank 1');
k2 = findobj(ax, 'Type', 'line', 'DisplayName', 'Shank 2');
check(~isempty(k1) && ~isempty(k2) && ~isequal(k1(1).Color, k2(1).Color) ...
    && isempty(findobj(ax, 'Type', 'line', 'DisplayName', 'Kept')), 'colour by shank: each shank in its own colour');
app.ArtProbeOrderCheckBox.Value = false;
app.ArtProbeOrderCheckBox.ValueChangedFcn(app.ArtProbeOrderCheckBox, []);
check(isequal(lanes(), w.names(4:-1:1)) && isempty(findall(ax, 'Type', 'constantline')) ...
    && isequal(cell2mat(app.ArtChannelTable.Data(:, 1)).', 1:4), 'unticked: recording order again, plot and table');
app.ArtViewShankDropDown.Value = '2';
app.drawArtifactView();
check(numel(ax.YTick) == 2 && all(ismember(lanes(), w.names([1 3]))) && contains(join(string(ax.Subtitle.String)), "on shank 2"), ...
    'Shank draws that shank''s channels only');
app.ArtViewShankColorCheckBox.Value = false;
app.drawArtifactView();
check(~isempty(findobj(ax, 'Type', 'line', 'DisplayName', 'Kept')), 'colour by shank off: the kept signal is black again');
app.ArtViewShankDropDown.Value = 'all';
app.ArtViewShankColorCheckBox.Value = true;
app.drawArtifactView();

% Scale: the plot's keys and wheel, with the pointer over it.
pp = getpixelposition(ax, true);
app.Fig.CurrentPoint = pp(1:2) + pp(3:4) / 2;
keyEvt = @(k, mods) struct('Key', k, 'Modifier', {mods});
xFull = ax.XLim; yFull = diff(ax.YLim);
check(app.onArtViewInput("key", keyEvt('uparrow', {})) && app.ArtView.gain > 1 && diff(ax.YLim) < yFull ...
    && contains(ax.YLabel.String, "clipped"), 'up arrow scales the voltage up (the lanes fewer microvolts apart)');
check(app.onArtViewInput("key", keyEvt('rightarrow', {'shift'})) && diff(ax.XLim) < diff(xFull), 'Shift+right zooms time in');
xz = ax.XLim;
app.onArtViewInput("key", keyEvt('rightarrow', {}));
check(ax.XLim(1) > xz(1) && abs(diff(ax.XLim) - diff(xz)) < 1e-9, 'right arrow pans later in time');
xz = ax.XLim;
app.drawArtifactView();
check(max(abs(ax.XLim - xz)) < 1e-9, 'a redraw of the same artifact keeps the time zoom');
app.ArtView.mods = strings(1, 0);
app.onArtViewInput("scroll", struct('VerticalScrollCount', -1));
check(diff(ax.XLim) < diff(xz), 'the wheel zooms time');
g0 = app.ArtView.gain;
app.ArtView.mods = "control";
app.onArtViewInput("scroll", struct('VerticalScrollCount', 1));
app.ArtView.mods = strings(1, 0);
check(app.ArtView.gain < g0, 'Ctrl+wheel scales the voltage');
app.Fig.CurrentPoint = [1 1];
check(~app.onArtViewInput("key", keyEvt('uparrow', {})) && app.ArtView.gain < g0, ...
    'with the pointer off the plot the keys are left alone');
app.Fig.CurrentPoint = pp(1:2) + pp(3:4) / 2;
app.ArtViewResetButton.ButtonPushedFcn(app.ArtViewResetButton, []);
check(app.ArtView.gain == 1 && max(abs(ax.XLim - xFull)) < 1e-9 && abs(diff(ax.YLim) - yFull) < 1e-9, ...
    'Reset view: the whole window at the Scale fit');
app.onArtViewInput("key", keyEvt('equal', {}));
app.onArtViewInput("key", keyEvt('rightarrow', {'shift'}));
app.ArtViewNextButton.ButtonPushedFcn(app.ArtViewNextButton, []);
check(app.ArtView.gain > 1 && max(abs(ax.XLim - app.ArtView.drawn.span)) < 1e-9, ...
    'the next artifact keeps the voltage scale but shows its whole window');
app.ArtViewScaleDropDown.Value = 'manual';
app.ArtViewLanesField.Value = 200;
g0 = app.ArtView.gain;
app.onArtViewInput("key", keyEvt('uparrow', {}));
check(abs(app.ArtViewLanesField.Value - 160) < 1e-9 && app.ArtView.gain == g0 ...
    && abs(ax.YTick(2) - ax.YTick(1) - 160) < 1e-9, 'with Scale: Manual the voltage keys change Lanes');
app.ArtViewScaleDropDown.Value = 'artifact';
app.selectTab(app.TabArtifacts);
g0 = app.ArtView.gain;
app.Fig.WindowKeyPressFcn(app.Fig, keyEvt('uparrow', {}));
check(app.ArtView.gain > g0, 'on the Artifacts tab the figure''s keys reach the plot');
app.selectTab(app.TabProject);
g0 = app.ArtView.gain;
app.Fig.WindowKeyPressFcn(app.Fig, keyEvt('uparrow', {}));
check(app.ArtView.gain == g0, 'on another tab they do not');
dA.ProbeFile = "";
app.applyArtifactsSection(art0);
app.onArtifactControlsChanged();
app.selectDataset(1, Reset=true);
check(~app.ArtProbeOrderCheckBox.Value && isequal(app.ArtViewShankDropDown.ItemsData, {'all'}), ...
    'without the probe again the probe controls go back off');
app.ProbeDefaultField.Value = char(probe2);
app.onConfigChanged();
check(app.ArtProbeOrderCheckBox.Value && isequal(app.ArtViewShankDropDown.ItemsData, {'all', '1', '2'}), ...
    'a dataset without a probe of its own is laid out on the default probe (as the pipeline uses it)');
app.ProbeDefaultField.Value = '';
app.onConfigChanged();
check(~app.ArtProbeOrderCheckBox.Value && isequal(app.ArtViewShankDropDown.ItemsData, {'all'}), ...
    'and without a default probe the probe controls go back off');

fprintf('\n== 3a. name tokens ==\n');
check(isequal(string({app.NameTokenChecks.Text}), ["SubjectID" "Date" "Time"]) && isequal([app.NameTokenChecks.Value], [true false false]) ...
    && T.Token_SubjectID(1) == "recA" && string(app.DatasetsTable.ColumnName{3}) == "SubjectID" ...
    && app.NameTokenStatusLabel.Text == "1 of 1 names match", ...
    'default pattern: one checkbox per token, SubjectID shown, the name matches');
app.NamePatternField.Value = '{Stem}{Letter:[A-Z]}_*';
app.onNameTokensChanged();
check(isequal(string({app.NameTokenChecks.Text}), ["Stem" "Letter"]) && ~any([app.NameTokenChecks.Value]) ...
    && ~any(startsWith(app.DatasetsTable.Data.Properties.VariableNames, 'Token_')) ...
    && app.NameTokenStatusLabel.Text == "1 of 1 names match", 'a new pattern rebuilds the checkboxes');
app.NameTokenChecks(2).Value = true; app.NameTokenChecks(1).Value = true;
app.onNameTokensChanged();
T = app.DatasetsTable.Data;
check(T.Token_Stem(1) == "rec" && T.Token_Letter(1) == "A" && isequal(reshape(string(app.DatasetsTable.ColumnName(3:4)), 1, []), ["Stem" "Letter"]) ...
    && app.Config.Project.NamePattern == "{Stem}{Letter:[A-Z]}_*" && app.Config.Project.TokenColumns == "Stem, Letter" ...
    && numel(app.DatasetsTable.ColumnWidth) == width(T) && startsWith(app.Fig.Name, "*"), ...
    'ticked tokens become columns in pattern order and are saved in the config');
check(numel(app.NameTokenFilters) == 2 && isequal(string(app.NameTokenFilters(2).Items), ["(any)" "A"]), ...
    'one filter dropdown per token, listing the parsed values');
app.onSelectDatasets("all");
app.NameTokenFilters(2).Value = 'B';
app.refreshDatasetsTable();
app.onConfigChanged();
check(height(app.DatasetsTable.Data) == 0 && app.HiddenSelectedKeys == "recA_260101_120000" && isequal(app.selectedDatasetIndices(), 1) ...
    && isequal(app.Config.Project.Datasets, "recA_260101_120000") && contains(app.NameTokenStatusLabel.Text, "showing 0 of 1 (1 ticked hidden)"), ...
    'a filter hides non-matching rows and keeps their ticks in the selection');
check(app.SelectedDatasetIdx == 1 && isempty(app.DatasetsTable.StyleConfigurations), ...
    'a hidden active dataset stays active, with no row highlighted');
app.NameTokenFilters(2).Value = 'b, a*';
app.refreshDatasetsTable();
check(height(app.DatasetsTable.Data) == 1 && app.DatasetsTable.Data.Select(1) && isempty(app.HiddenSelectedKeys) ...
    && height(app.DatasetsTable.StyleConfigurations) == 1, ...
    'wildcard / comma alternatives match case-insensitively; the tick and the highlight return');
app.NameTokenFilters(2).Value = '(any)';
app.onSelectDatasets("none");
nCol = width(app.DatasetsTable.Data);
app.DatasetsTable.DisplayColumnOrder = [5, 1:4, 6:nCol];   % as if Key were dragged to the front
app.refreshDatasetsTable();
T = app.DatasetsTable.Data;
check(string(T.Properties.VariableNames{1}) == "Key" && string(app.DatasetsTable.ColumnName{1}) == "Key" ...
    && isempty(app.DatasetsTable.DisplayColumnOrder) && ~app.DatasetsTable.ColumnSortable(end), ...
    'a rearranged column order is baked into the table on refresh');
app.NameTokenChecks(1).Value = false;
app.onNameTokensChanged();
T = app.DatasetsTable.Data;
check(isequal(string(T.Properties.VariableNames(1:4)), ["Key" "Select" "Name" "Token_Letter"]) ...
    && string(T.Properties.VariableNames{end}) == "DatasetIdx" && numel(app.DatasetsTable.ColumnWidth) == width(T), ...
    'the order survives a change of the token columns');
app.DatasetsColumnOrder = string.empty(1, 0);
app.NameTokenChecks(1).Value = true;
app.onNameTokensChanged();
app.NamePatternField.Value = '{Stem';
app.onNameTokensChanged();
check(numel(app.NameTokenChecks) == 2 && ~any(startsWith(app.DatasetsTable.Data.Properties.VariableNames, 'Token_')) ...
    && contains(app.NameTokenStatusLabel.Text, "unclosed"), 'an invalid pattern keeps the checkboxes and hides token columns');
app.applyProjectSection(cfg.Project);
app.onConfigChanged();
check(app.NameTokenChecks(1).Value && app.Config.Project.TokenColumns == "SubjectID" ...
    && app.Config.Project.NamePattern == cfg.Project.NamePattern, 'applying the section restores pattern and columns');

fprintf('\n== 3a2. recursive scan ==\n');
check(app.RecursiveCheckBox.Value && app.Project.Recursive, 'scans are recursive by default');
app.RecursiveCheckBox.Value = false;
app.onConfigChanged();
app.onScan();
check(~app.Config.Project.Recursive && ~app.Project.Recursive && app.Project.NumDatasets == 1, ...
    'unticking Recursive is saved in the config and scans only the root and the folders directly in it');
app.applyProjectSection(cfg.Project);
app.onConfigChanged();
app.onScan();
check(app.RecursiveCheckBox.Value && app.Config.Project.Recursive && app.Project.Recursive, ...
    'applying the section restores Recursive');

fprintf('\n== 3b1. Project tab: Open Ephys reader options ==\n');
check(app.Config.Acquisition.OpenEphys.Recordings == "concatenate" && string(app.OERecordingsDropDown.Value) == "concatenate", ...
    'Open Ephys sessions are joined by default');
app.OERecordingsDropDown.Value = 'separate';
app.OERecordNodeField.Value = '104';
app.OEStreamField.Value = 'Rhythm Data';
app.onAcquisitionChanged();
A = app.Config.Acquisition.OpenEphys;
check(A.Recordings == "separate" && A.RecordNode == "104" && A.Stream == "Rhythm Data" ...
    && isequal(app.Project.ReaderOptions, app.Config.Acquisition) && isequal(app.Project.Datasets(1).ReaderOptions, app.Config.Acquisition), ...
    'the Open Ephys options are saved in Acquisition and a rescan pushes them to the project and datasets');
app.applyAcquisitionSection(cfg.Acquisition);
app.onAcquisitionChanged();
check(app.Config.Acquisition.OpenEphys.Recordings == "concatenate" && app.OERecordNodeField.Value == "" ...
    && isequal(app.Project.ReaderOptions, cfg.Acquisition), 'applying the section restores the defaults');
app.Config.Acquisition.OpenEphys.RecordNode = "node";
app.syncTabStrip();
check(contains(tabTip(app, app.TabProject), "RecordNode"), 'an invalid Open Ephys option shows on the Project tab''s button');
app.Config.Acquisition = cfg.Acquisition;
app.syncTabStrip();

fprintf('\n== 3b. Trials tab: load, cut, approve, polarity ==\n');
app.selectDataset(1);
app.setTrialsLineItems("din0", "din0");
app.onTrialsSettingsChanged();
check(app.Config.Behavior.TrialLine == "din0" && startsWith(app.Fig.Name, "*"), 'the trial line is a config setting');
app.onTrialsLoad("recorded");
dT = app.currentDataset();
TT = app.TrialsTable.Data;
check(~isempty(app.TrialsPairing) && height(TT) == 1 && TT{1, 3} == 1 && TT{1, 6} == 50 ...
    && height(app.TrialsLinesTable.Data) == 1 && strcmp(app.TrialsApproveButton.Enable, 'on'), ...
    'Load pairs the single trial with the din0 interval (onset row 50)');
check(isequal(app.TrialsCutSpinners(1, 1).Limits, [0 1]) && strcmp(app.TrialsCutSpinners(2, 2).Enable, 'on') ...
    && app.TrialsCutIntervalsLabel.Text == "din0 intervals", 'the cut spinners are limited to the trial / interval counts');
check(app.TrialsAxes.InteractionOptions.LimitsDimensions == "x", 'the lines plot zooms and pans horizontally only');
check(all(app.TrialsTable.ColumnSortable) && app.TrialsTable.ColumnRearrangeable == "on", 'the trials table sorts and rearranges');
cm = app.TrialsTable.ContextMenu;
app.onTrialsTableMenu(cm, struct('InteractionInformation', struct('Column', [])));
sub = findobj(cm.Children, 'flat', 'Text', 'Parameter columns');
check(isscalar(sub) && isequal(flip(string({sub.Children.Text})), ["computerTimestamp" "isTest" "ToneLevel"]) ...
    && ~any(logical([sub.Children.Checked])) && isscalar(findobj(cm.Children, 'flat', 'Text', 'Reset column order')), ...
    'the table menu lists the session parameters (not TrialIndex) alphabetically, ignoring case, unticked');
for p = ["ToneLevel" "isTest"]
    item = findobj(sub, 'Text', p);
    item.MenuSelectedFcn(item, []);
    app.onTrialsTableMenu(cm, struct('InteractionInformation', struct('Column', [])));   % as the next right-click would
    sub = findobj(cm.Children, 'flat', 'Text', 'Parameter columns');
end
TT = app.TrialsTable.Data;
vars = string(TT.Properties.VariableNames);
check(isequal(app.TrialsParamColumns, ["ToneLevel" "isTest"]) && isequal(vars(8:11), ["Flag" "Param_ToneLevel" "Param_isTest" "OtherLines"]) ...
    && isequal(reshape(string(app.TrialsTable.ColumnName(9:10)), 1, []), ["ToneLevel" "isTest"]) && TT.Param_ToneLevel == 60 && TT.Param_isTest == false ...
    && all(logical(findobj(sub, 'Text', 'ToneLevel').Checked)), 'ticked parameters become columns after Flag, in the order added');
app.TrialsTable.DisplayColumnOrder = [10, 1:9, 11];   % as if isTest were dragged to the front
check(isequal(app.trialsColumnOrder(), vars([10, 1:9, 11])), 'the dragged order is read back before a refresh');
kTone = find(vars == "Param_ToneLevel");
app.onTrialsTableMenu(cm, struct('InteractionInformation', struct('Column', kTone)));
item = findobj(cm.Children, 'flat', 'Text', 'Remove "ToneLevel"');
check(isscalar(item), 'right-clicking a parameter column offers to remove it');
item.MenuSelectedFcn(item, []);
TT = app.TrialsTable.Data;
check(isequal(app.TrialsParamColumns, "isTest") && string(TT.Properties.VariableNames{1}) == "Param_isTest" ...
    && ~ismember("Param_ToneLevel", TT.Properties.VariableNames) && isempty(app.TrialsTable.DisplayColumnOrder) ...
    && isequal(app.TrialsColumnOrder, ["Param_isTest", vars(1:8), "Param_ToneLevel", "OtherLines"]), ...
    'removing a column keeps the dragged order and remembers where the removed column was');
app.TrialsParamColumns = ["isTest" "ToneLevel" "Response"];   % Response: chosen for another dataset
app.refreshTrialsTable();
TT = app.TrialsTable.Data;
app.onTrialsTableMenu(cm, struct('InteractionInformation', struct('Column', [])));
sub = findobj(cm.Children, 'flat', 'Text', 'Parameter columns');
item = findobj(sub, 'Text', 'Response (not in this session)');
check(isequal(string(TT.Properties.VariableNames), ["Param_isTest", vars(1:8), "Param_ToneLevel", "OtherLines"]) ...
    && isscalar(item) && logical(item.Checked), 'a re-added column returns to its place; a parameter the session lacks is listed, not shown');
item.MenuSelectedFcn(item, []);
check(isequal(app.TrialsParamColumns, ["isTest" "ToneLevel"]), 'and can be unticked');
app.TrialsSession.Pos = [1 2];
app.TrialsSession.Note = {'abc'};
app.TrialsSession.Maybe = {[]};
app.TrialsParamColumns = ["Pos" "Note" "Maybe"];
app.refreshTrialsTable();
TT = app.TrialsTable.Data;
check(TT.Param_Pos == "1 2" && TT.Param_Note == "abc" && isnan(TT.Param_Maybe), ...
    'multi-column and cell parameters are shown as text, empty numbers as NaN');
app.savePreferences();
check(isequal(string(getpref(g, 'TrialsParamColumns')), ["Pos" "Note" "Maybe"]) ...
    && isequal(string(getpref(g, 'TrialsColumnOrder')), app.TrialsColumnOrder), 'the columns and their order are preferences');
app.TrialsTable.DisplayColumnOrder = [2 1 3:width(TT)];
app.onTrialsTableMenu(cm, struct('InteractionInformation', struct('Column', [])));
item = findobj(cm.Children, 'flat', 'Text', 'Reset column order');
item.MenuSelectedFcn(item, []);
TT = app.TrialsTable.Data;
check(string(TT.Properties.VariableNames{1}) == "Trial" && isempty(app.TrialsTable.DisplayColumnOrder) ...
    && isequal(app.TrialsColumnOrder, string(TT.Properties.VariableNames)), 'Reset column order restores the natural order');
app.TrialsParamColumns = string.empty(1, 0);
app.refreshTrialsTable();
app.TrialsCutSpinners(1, 1).Value = 1;
app.onTrialsCutsChanged();
check(isequal(app.TrialsPairing.cutTrials, [1 0]) && isnan(app.TrialsPairing.interval(1)) && app.TrialsPairing.countMismatch ...
    && contains(app.TrialsSummaryLabel.Text, "WARNING"), 'cutting the only trial leaves the interval unpaired and warns about the mismatch');
app.TrialsCutSpinners(1, 2).Value = 1;
app.onTrialsCutsChanged();
check(isequal(app.TrialsPairing.cutTrials, [1 0]) && app.TrialsCutSpinners(1, 2).Value == 0, ...
    'cuts beyond the trial count are refused and the spinners put back');
app.onTrialsLoad("none");
check(isequal(app.TrialsPairing.cutTrials, [0 0]) && app.TrialsCutSpinners(1, 1).Value == 0 && ~app.TrialsPairing.countMismatch, ...
    'Reset cuts pairs everything in order again');
app.onTrialsApprove("approved");
mT = readJsonFile(dT.manifestFile());
check(strcmp(mT.behavior.pairing.status, 'approved') && contains(app.DatasetsTable.Data.Behavior(1), "pairing approved"), ...
    'Approve saves the pairing in the manifest and the table shows it');
app.TrialsLinesTable.Data.Inverted(1) = true;
app.onTrialsSettingsChanged();
check(isequal(app.Config.Signals.InvertedLines, "din0") && app.TrialsPairing.stale ...
    && app.TrialsPairing.status == "unreviewed" && app.TrialsPairing.onsetSample(1) == 1, ...
    'inverting the line makes the approved pairing stale (onset = falling edge)');
FsT = app.TrialsEvents.Fs;
hBars = findall(app.TrialsAxes, "Tag", "events:din0");
xBars = [hBars.XData];
barRows = sortrows(round(reshape(xBars(~isnan(xBars)), 2, []).' * FsT));
hiRows = round(app.namedTrialsEvents().events.din0 * FsT);
check(isequal(barRows, round(app.TrialsPairing.events.din0 * FsT)) && all(ismember(hiRows(:, 2) + 1, barRows(:, 1))) ...
    && all(ismember(hiRows(:, 1) - 1, barRows(:, 2))) && all(strcmp({hBars.Marker}, 'none')) ...
    && any(contains(string(app.TrialsAxes.YTickLabel), "din0 (inverted)")), ...
    'inverted, the plot draws din0 as unmarked bars from each falling edge to the next rising edge');
hEdges = findall(app.TrialsAxes, "Tag", "trialEdges");
check(isscalar(hEdges) && hEdges.Visible == "on" && isequal(unique(round(hEdges.XData(~isnan(hEdges.XData)) * FsT)), ...
    unique(round(app.TrialsPairing.intervals(:) * FsT)).'), ...
    'dotted lines mark every trial-line onset and offset, and a refresh replaces the previous plot (hidden objects too)');
app.TrialsEdgesMenu.MenuSelectedFcn(app.TrialsEdgesMenu, []);
app.onTrialsSettingsChanged();
hEdges = findall(app.TrialsAxes, "Tag", "trialEdges");
check(isscalar(hEdges) && hEdges.Visible == "off" && app.TrialsEdgesMenu.Checked == "off", ...
    'the plot''s context menu hides the onset / offset lines, and they stay hidden when the plot is redrawn');
app.TrialsEdgesMenu.MenuSelectedFcn(app.TrialsEdgesMenu, []);
check(app.TrialsAxes.XGrid == "off", 'no grid lines by default');
app.TrialsGridMenu.MenuSelectedFcn(app.TrialsGridMenu, []);
check(hEdges.Visible == "on" && app.TrialsAxes.XGrid == "on" && app.TrialsAxes.YGrid == "on" && app.TrialsGridMenu.Checked == "on", ...
    'the context menu shows the onset / offset lines again and toggles the grid lines');
app.TrialsGridMenu.MenuSelectedFcn(app.TrialsGridMenu, []);
app.onTrialsPlotMenu();
labelItems = flip(string({app.TrialsLabelsMenu.Children.Text}));
sessionVars = string(app.TrialsSession.Properties.VariableNames);
[~, iAlpha] = sort(lower(sessionVars));
check(isequal(labelItems, sessionVars(iAlpha)) && ismember("TrialIndex", labelItems) ...
    && ~any(logical([app.TrialsLabelsMenu.Children.Checked])) && isempty(findall(app.TrialsAxes, "Tag", "trialLabels")), ...
    'the plot menu lists every session parameter for trial labels (TrialIndex too), none shown by default');
item = findobj(app.TrialsLabelsMenu, 'Text', 'ToneLevel');
item.MenuSelectedFcn(item, []);
hLab = findall(app.TrialsAxes, "Tag", "trialLabels");
check(isequal(app.TrialsLabelParams, "ToneLevel") && isscalar(hLab) && string(hLab.String) == "60" ...
    && hLab.Position(1) == app.TrialsPairing.onset(1) && hLab.Position(2) > 1 && app.TrialsAxes.YLim(2) > hLab.Position(2) ...
    && isscalar(findall(app.TrialsAxes, "Tag", "trialEdges")), ...
    'ticking a parameter writes each paired trial''s value above the trial line at its onset');
app.onTrialsPlotMenu();
item = findobj(app.TrialsLabelsMenu, 'Text', 'isTest');
item.MenuSelectedFcn(item, []);
hLab = findall(app.TrialsAxes, "Tag", "trialLabels");
check(isscalar(hLab) && string(hLab.String) == "ToneLevel=60, isTest=false" && contains(string(app.TrialsAxes.Title.String), "labels: ToneLevel, isTest"), ...
    'several parameters are written name=value in the order ticked, and the title names them');
app.TrialsLabelParams = ["ToneLevel" "Response"];   % Response: chosen for another dataset
app.refreshTrialsPlot();
app.onTrialsPlotMenu();
item = findobj(app.TrialsLabelsMenu, 'Text', 'Response (not in this session)');
hLab = findall(app.TrialsAxes, "Tag", "trialLabels");
check(isscalar(item) && logical(item.Checked) && string(hLab.String) == "60", ...
    'a label parameter the session lacks is listed, not written');
app.savePreferences();
check(isequal(string(getpref(g, 'TrialsLabelParams')), ["ToneLevel" "Response"]), 'the label parameters are a preference');
item = findobj(app.TrialsLabelsMenu, 'Text', 'No labels');
item.MenuSelectedFcn(item, []);
check(isempty(app.TrialsLabelParams) && isempty(findall(app.TrialsAxes, "Tag", "trialLabels")) && app.TrialsAxes.YLim(2) == 1.6, ...
    'No labels removes them and the head room');
g3 = app.gatherConfig();
check(isequal(g3.Signals.InvertedLines, "din0") && isequal(EphysPipelineConfig.signalOptions(g3.Signals).invertedLines, "din0"), ...
    'the polarity reaches the Signals options');
app.TrialsLinesTable.Data.Inverted(1) = false;
app.onTrialsSettingsChanged();
check(isempty(app.Config.Signals.InvertedLines) && app.TrialsPairing.recorded && app.TrialsPairing.status == "approved", ...
    'restoring the polarity brings the approved pairing back');
L0 = app.TrialsLinesTable.Data;
E0 = app.TrialsEvents;
check(isequal(string(L0.Properties.VariableNames), ["Native" "Name" "Intervals" "Inverted"]) && L0.Native(1) == "DIN-00" ...
    && L0.Name(1) == "din0", 'the lines table shows each line''s native name and its name');
app.TrialsLinesTable.Data.Name(1) = "Trial";
app.onTrialsLinesEdited(struct('Indices', [1 2], 'PreviousData', "din0", 'NewData', "Trial"));
check(isequal(app.Config.Signals.LineNames, "DIN-00=Trial") && app.Config.Behavior.TrialLine == "Trial" ...
    && string(app.TrialsLineDropDown.Value) == "Trial" && ~isempty(app.TrialsPairing) && app.TrialsPairing.nPaired == 1 ...
    && isequal(app.TrialsEvents, E0) && isfield(app.TrialsPairing.events, 'Trial'), ...
    'renaming a line writes Signals.LineNames, the trial line follows, and it re-pairs without reading the recording');
app.TrialsLinesTable.Data.Name(1) = "1bad";
app.onTrialsLinesEdited(struct('Indices', [1 2], 'PreviousData', "Trial", 'NewData', "1bad"));
check(app.TrialsLinesTable.Data.Name(1) == "Trial" && isequal(app.Config.Signals.LineNames, "DIN-00=Trial"), ...
    'an invalid name is refused and put back');
app.TrialsLinesTable.Data.Name(1) = "";
app.onTrialsLinesEdited(struct('Indices', [1 2], 'PreviousData', "Trial", 'NewData', ""));
check(isempty(app.Config.Signals.LineNames) && app.Config.Behavior.TrialLine == "din0" ...
    && app.TrialsLinesTable.Data.Name(1) == "din0", 'a blank name goes back to the default name and drops the entry');
app.ConvLabelFieldDropDown.Value = 'native';
app.onConvertControlsChanged();
check(isempty(app.Config.Signals.LineNames) && app.TrialsLinesTable.Data.Name(1) == "DIN-00", ...
    'switching Label field to native renames no line (no LineNames entry) and the lines table shows the native names');
app.ConvLabelFieldDropDown.Value = 'custom';
app.onConvertControlsChanged();
check(isempty(app.Config.Signals.LineNames) && app.TrialsLinesTable.Data.Name(1) == "din0", 'and back to the custom names');

vE = matlab.lang.makeValidName("epsych_" + dT.Name);
vB = matlab.lang.makeValidName("behavior_" + dT.Name);
evalin('base', "clear " + vE + " " + vB);
behT = fullfile(dT.outputFolder(), dT.Name + "_behavior.mat");
if ~isfile(behT)
    app.onTrialsToWorkspace("behavior");
    check(~evalin('base', "exist('" + vB + "', 'var')"), 'Behavior to workspace assigns nothing before <name>_behavior.mat exists');
end
app.onTrialsWriteBehavior();
BT = load(behT);
check(BT.behavior.trials.TrialOnsetSample(1) == 50 && BT.behavior.pairing.status == "approved", 'Write behavior .mat carries the pairing');
app.onTrialsToWorkspace("epsych");
E = evalin('base', vE);
check(isequal(E, load(dT.BehaviorFile)) && contains(app.StatusBar.Text, vE), ...
    'Epsych2 to workspace puts the session file as saved in the base workspace and names the variable');
app.onTrialsToWorkspace("behavior");
BW = evalin('base', vB);
check(isequal(BW, BT.behavior) && contains(app.StatusBar.Text, vB), ...
    'Behavior to workspace puts the behavior struct of <name>_behavior.mat in the base workspace and names the variable');
evalin('base', "clear " + vE + " " + vB);

fprintf('\n== 3b2. Trials tab: prefetch the ticked datasets, auto approve ==\n');
evFile = fullfile(dT.outputFolder(), dT.Name + "_events.mat");
check(isfile(evFile) && string(app.TrialsPrefetchButton.Text) == "Prefetch ticked" ...
    && ~app.TrialsAutoApproveCheckBox.Value && ~app.Config.Behavior.AutoApprove, ...
    'Load cached the lines; the Prefetch button is there and Auto approve is off by default');
delete(evFile);
dT.setTrialPairing([]);
app.clearTrialsView();
ticked0 = app.tickedDatasetIndices();
app.onSelectDatasets("all");
app.onTrialsPrefetch();
check(isfile(evFile) && contains(app.StatusBar.Text, "1 read, 0 already cached") && isempty(dT.TrialPairing), ...
    'Prefetch reads and caches the lines of the ticked dataset, and pairs nothing without Auto approve');
app.onTrialsPrefetch();
check(contains(app.StatusBar.Text, "0 read, 1 already cached"), 'a second Prefetch finds the lines cached');
app.onTrialsLoad("recorded");
check(app.TrialsEvents.source == "cache" && app.TrialsPairing.status == "unreviewed" && ~app.TrialsPairing.recorded, ...
    'Load takes the prefetched lines from the cache');
app.TrialsAutoApproveCheckBox.Value = true;
app.onTrialsSettingsChanged();
mT = readJsonFile(dT.manifestFile());
check(app.Config.Behavior.AutoApprove && app.TrialsPairing.status == "approved" && app.TrialsPairing.autoApproved ...
    && contains(app.TrialsSummaryLabel.Text, "APPROVED automatically") && mT.behavior.pairing.auto_approved ...
    && contains(app.DatasetsTable.Data.Behavior(1), "pairing approved (auto)"), ...
    'ticking Auto approve approves the shown pairing (its counts match) and marks it automatic');
BT = load(behT);
check(BT.behavior.pairing.status == "approved" && BT.behavior.pairing.autoApproved, ...
    'the automatic approval reaches the existing <name>_behavior.mat');
dT.setTrialPairing([]);
app.clearTrialsView();
app.onTrialsPrefetch();
check(dT.TrialPairing.status == "approved" && dT.TrialPairing.auto_approved ...
    && contains(app.StatusBar.Text, "1 approved automatically, 0 already approved, 0 need review"), ...
    'with Auto approve, Prefetch also approves each ticked pairing whose counts match');
app.onTrialsLoad("recorded");
app.onTrialsApprove("approved");
check(~dT.TrialPairing.auto_approved && app.TrialsPairing.status == "approved" && ~app.TrialsPairing.autoApproved ...
    && ~contains(app.TrialsSummaryLabel.Text, "automatically"), 'approving by hand replaces the automatic approval');
BT = load(behT);
check(BT.behavior.pairing.status == "approved" && ~BT.behavior.pairing.autoApproved && contains(app.StatusBar.Text, "rewrote"), ...
    'approving by hand rewrites <name>_behavior.mat and says so');
app.TrialsAutoApproveCheckBox.Value = false;
app.onTrialsSettingsChanged();
if isempty(ticked0); app.onSelectDatasets("none"); end

fprintf('\n== 3c. Sorting tab: optimize for probe, reset to defaults ==\n');
dS = app.currentDataset();
app.onOptimizeKS4ForProbe();
check(app.Config.Sorting.KS4.nblocks == 3 && strcmp(app.ParamControls.dmin.Value, '12'), ...
    'without a probe (the dataset''s or the default) nothing is loaded');
probeFile = fullfile(root, 'square4.json');
writeJsonFile(probeFile, struct('chanMap', (0:3).', 'xc', [0; 25; 0; 25], 'yc', [0; 0; 25; 25], 'kcoords', zeros(4, 1)));
paramsFile = EphysPipelineConfig.ks4ParamsFile(probeFile);
dS.ProbeFile = probeFile;
app.onOptimizeKS4ForProbe("cancel");
check(~isfile(paramsFile) && app.Config.Sorting.KS4.nblocks == 3, ...
    'a probe without a parameter file: cancelling the offer writes and changes nothing');
K0 = app.Config.Sorting.KS4;
app.onOptimizeKS4ForProbe("generate");
P = readJsonFile(paramsFile);
check(isfile(paramsFile) && isequal(string(fieldnames(P.KS4)).', EphysPipelineConfig.KS4ProbeParams) ...
    && P.KS4.nblocks == 3 && P.KS4.dmin == 12 && isequaln(app.Config.Sorting.KS4, K0) ...
    && any(contains(string(app.KSLogArea.Value), "square4.ks4.json")), ...
    'the current-parameters option saves the current probe-dependent values next to the probe map and logs it');
probeFolder = app.ProbeFolderField.Value;
app.ProbeFolderField.Value = char(root);
app.refreshProbeList();
row = find(app.ProbePaths == string(probeFile), 1);
check(~isempty(row) && ~any(endsWith(app.ProbePaths, ".ks4.json")), 'the probe list shows the probe map but not its parameter file');
app.selectProbeRow(row);
check(contains(app.ProbeInfoLabel.Text, "Kilosort4 parameters: square4.ks4.json"), ...
    'the Probe tab names the selected probe''s parameter file');
app.ProbeFolderField.Value = probeFolder;
app.refreshProbeList();
delete(paramsFile);
app.onOptimizeKS4ForProbe("derive");
P = readJsonFile(paramsFile);
K = app.Config.Sorting.KS4;
check(isfile(paramsFile) && P.KS4.dminx == 25 && isfield(P, 'reasons') && contains(string(P.description), "probe layout") ...
    && K.nblocks == 0 && K.dmin == 25 && K.dminx == 25 && K.nearest_chans == 4 && K.nearest_templates == 4 ...
    && K.x_centers == 1 && app.ParamControls.nearest_chans.Value == 4 && strcmp(app.ParamControls.dmin.Value, '25'), ...
    'the probe-layout option saves the layout defaults with their reasons and loads them into the controls and the config');
check(any(contains(string(app.KSLogArea.Value), "from the probe layout")) ...
    && any(contains(string(app.KSLogArea.Value), "x_centers: 4 -> 1 (a single shank")), ...
    'the generated file and each loaded value with its reason are logged');
noLayout = fullfile(root, 'nolayout.json');
writeJsonFile(noLayout, struct('chanMap', (0:3).'));
dS.ProbeFile = noLayout;
app.onOptimizeKS4ForProbe("derive");
check(~isfile(EphysPipelineConfig.ks4ParamsFile(noLayout)) && app.Config.Sorting.KS4.x_centers == 1, ...
    'a probe map without site positions gives no layout defaults: nothing is written or changed');
dS.ProbeFile = "";
app.ProbeDefaultField.Value = char(probeFile);
app.ParamControls.nearest_chans.Value = 9;
app.onConfigChanged();
app.onOptimizeKS4ForProbe();
check(app.Config.Sorting.KS4.nearest_chans == 4 && any(contains(string(app.KSLogArea.Value), "default probe")), ...
    'a dataset without a probe uses the default probe''s parameter file');
app.ProbeDefaultField.Value = '';
before = app.Config.Sorting;
app.ExtraSettingsArea.Value = {'{"nblocks": 2}'};
app.onConfigChanged();
app.onResetKS4Params();
S = app.Config.Sorting;
check(isequaln(S.KS4, EphysPipelineConfig.defaults("Sorting").KS4) && S.KS4ExtraJSON == "" ...
    && strcmp(app.ParamControls.dmin.Value, '') && isequal(app.ExtraSettingsArea.Value, {'{'; '}'}), ...
    'Reset to defaults restores every Kilosort4 parameter and clears the extra JSON');
check(S.PythonExe == before.PythonExe && S.Enabled == before.Enabled ...
    && app.Config.Probe.DefaultProbeFile == "", 'and leaves the other Sorting settings alone');

fprintf('\n== 4. run one step through the pipeline ==\n');
app.runPipeline(Steps="spikes");
R = app.RunResultsTable.Data;
spikesFile = fullfile(outRoot, 'recA_260101_120000', 'recA_260101_120000_spikes.mat');
check(istable(R) && any(R.Step == "spikes" & R.Status == "done") && isfile(spikesFile), 'the Spikes step ran and wrote its file');
M = load(spikesFile);
check(~isempty(M.detected) && isequal(M.units.unitId, [0; 1]) && M.detected.detection.options.Threshold == 1500, ...
    'the file reflects the edited threshold and the sorted units');
check(~app.RunActive && strcmp(app.RunButton.Enable, 'on'), 'run state is reset afterwards');
app.runLog("the report reads this line");
runTail = string(app.RunLogArea.Value);
runTail = runTail(strlength(strip(runTail)) > 0);
rep = app.issueReport("bug", System=false, Config=false);
check(contains(rep, "**Run log**") && contains(rep, runTail(end)) && contains(rep, "the report reads this line") ...
    && isempty(app.LastError), 'the issue report carries the Run log as the tab shows it; the run recorded no error');

fprintf('\n== 4a. Review tab: unit labels, location, notes ==\n');
app.selectDataset(1);
app.syncReviewDataset();
R = app.ReviewData;
C = app.ReviewUnitsTable.Data;
check(~isempty(R) && isequal(string(app.ReviewUnitsTable.ColumnName(:)).', ...
    ["Unit" "Group" "Shank" "Ch" "X(um)" "Y(um)" "#Spk" "FR(Hz)" "Amp" "Cont%" "Notes"]) ...
    && size(C, 2) == 11 && isequal(logical(app.ReviewUnitsTable.ColumnEditable), [false(1, 10) true]) ...
    && R.unitLabel(R.clusterID == 0) == "su000_recA_260101T1200" ...
    && any(contains(string(app.ReviewSummaryLabel.Text), "<class><id>_recA_260101T1200")), ...
    'the active dataset''s sort shows unit labels, location columns and an editable Notes column');
row = find(cellfun(@(v) isequal(v, 1), C(:, 1)), 1);
app.onReviewNoteEdited(struct('Indices', [row 11], 'NewData', 'two cells?', 'PreviousData', ''));
[ids, notes] = EphysDataset.readUnitNotes(phyDir);
check(isequal(ids, 1) && notes == "two cells?" && app.ReviewData.notes(app.ReviewData.clusterID == 1) == "two cells?" ...
    && string(app.ReviewUnitsTable.Data{row, 11}) == "two cells?", 'editing a Notes cell saves cluster_notes.tsv');
app.syncReviewDataset();
check(app.ReviewData.notes(app.ReviewData.clusterID == 1) == "two cells?", 'the note is read back on reload');
settingsFile = fullfile(phyDir, 'settings.json');
S0 = readJsonFile(settingsFile);
S1 = S0; S1.tmin = 0.005;   % Kilosort4 sorted from 5 ms on
writeJsonFile(settingsFile, S1);
app.syncReviewDataset();
R = app.ReviewData;
dR = app.currentDataset();
check(abs(R.durSec - (dR.Duration - 0.005)) < 1e-9 && all(abs(R.firingRate - R.nSpikes / R.durSec) < 1e-9) ...
    && any(contains(string(app.ReviewSummaryLabel.Text), "Sorted")), ...
    'firing rates are over the sorted part of the recording: tmin (settings.json) to its end, not to the last spike');
writeJsonFile(settingsFile, S0);
app.syncReviewDataset();

fprintf('\n== 4b. Run tab: the run diagram ==\n');
check(app.RunDiagramPanel.Visible == "off" && isequal(app.RunSplitGrid.ColumnWidth, {'1x', 0}) ...
    && contains(string(app.RunDiagramHTML.HTMLSource), "function setup(htmlComponent)"), ...
    'the run diagram is off by default and its page is loaded');
app.RunDiagramCheckBox.Value = true;
app.onRunDiagramToggled();
D = app.RunDiagramHTML.Data;
st = [D.steps.state];
check(app.RunDiagramPanel.Visible == "on" && isequal(app.RunSplitGrid.ColumnWidth, {'1x', '1x'}) ...
    && isequal([D.steps.key], EphysPipelineConfig.StepNames) && D.phase == "done" ...
    && st(6) == "done" && D.steps(6).pct == 100 && D.steps(6).summary ~= "" && all(st([1:5 7]) == "off") ...
    && D.steps(1).label == "not in this run", ...
    'ticked, it takes half of the right side and shows the last run (followed while hidden): Spikes done at 100%');
app.resetRunDiagram(["probe" "signals" "spikes"], false);
D = app.RunDiagramHTML.Data;
check(D.phase == "running" && all([D.steps([1 5 6]).state] == "queued") && D.steps(3).state == "off" ...
    && D.headline == "Starting...", 'a run starts with its steps waiting and the others not in it');
ev = @(step, ds, i, n, done, total, msg) struct('step', string(step), 'dataset', string(ds), 'index', i, ...
    'count', n, 'done', done, 'total', total, 'message', string(msg));
app.updateRunDiagram(ev("probe", "", 0, 4, 0, 1, "starting"));
app.updateRunDiagram(ev("signals", "", 0, 4, 0, 1, "starting"));
app.updateRunDiagram(ev("signals", "recB", 2, 4, 1, 2, "LFP"));
D = app.RunDiagramHTML.Data;
s = D.steps(5);
check(D.steps(1).state == "done" && D.steps(1).pct == 100 && s.state == "running" && s.pct == 37.5 ...
    && s.now == "Dataset 2 of 4: recB" && s.msg == "LFP" && D.steps(6).state == "queued" ...
    && D.headline == "Step 2 of 3: Signals", ...
    'an event makes its step the one underway at (index - 1 + done/total) / count, the steps before it done');
app.updateRunDiagram(ev("signals", "recA", 1, 4, 0, 1, "late"));
check(app.RunDiagramHTML.Data.steps(5).pct == 37.5, 'a step''s percentage never goes back');
Rd = EphysPipeline.emptyResults();
Rd(1:2, :) = {"signals", "recA", "done", "", "", 1; "signals", "recB", "cancelled", "", "", 1};
app.finishRunDiagram(Rd, "cancelled", "");
D = app.RunDiagramHTML.Data;
check(D.phase == "cancelled" && D.steps(5).state == "cancelled" && D.steps(5).pct == 37.5 ...
    && D.steps(6).state == "notrun" && D.steps(5).summary == "1 done, 1 cancelled" ...
    && startsWith(D.headline, "Cancelled during Signals"), ...
    'a cancel leaves its step at the percentage reached, with its counts, and the later steps not run');
app.resetRunDiagram();
app.RunSignalsCheckBox.Value = true;
app.RunSignalsCheckBox.ValueChangedFcn(app.RunSignalsCheckBox, []);   % as a click would
D = app.RunDiagramHTML.Data;
check(D.phase == "idle" && D.steps(1).label == "will run" && D.steps(5).label == "will run" ...
    && D.steps(3).label == "off" && startsWith(D.headline, "Ready: "), ...
    'before a run it previews the ticked steps and follows the checklist');
app.RunSignalsCheckBox.Value = false;
app.RunSignalsCheckBox.ValueChangedFcn(app.RunSignalsCheckBox, []);
check(app.RunDiagramHTML.Data.steps(5).label == "off", 'unticking a step takes it out of the preview');
app.savePreferences();
check(isequal(getpref(g, 'ShowRunDiagram'), true), 'the switch is saved as a preference');
app.RunDiagramCheckBox.Value = false;
app.onRunDiagramToggled();
check(app.RunDiagramPanel.Visible == "off" && isequal(app.RunSplitGrid.ColumnWidth, {'1x', 0}), ...
    'unticked, the progress, results and log have the whole right side again');

fprintf('\n== 4c. Run tab: resource monitoring ==\n');
check(app.RunMonitorPanel.Visible == "off" && isequal(app.RunLeftGrid.RowHeight, {'1x', 0}) ...
    && isempty(app.ResourceMonitorTimer) && app.ResourceMonitor.dir == "", ...
    'resource monitoring is off by default: no panel, no sampler, no timer');
S = struct('t', '2026-09-18T10:41:21', 'cpu', 37.2, 'memUsedGB', 12.3, 'memTotalGB', 31.7, ...
    'disk', 95, 'diskName', '1 D:', 'readMBs', 80.2, 'writeMBs', 12.5, ...
    'gpus', struct('index', {0 1}, 'name', {'A' 'B'}, 'util', {28 61}, 'memUsedMB', {869 1024}, 'memTotalMB', {4094 8192}), ...
    'gpuNote', '');
app.showResourceSample(S);
tx = string({app.RunMonitorTexts.Text});
check(isequal(tx, ["37%" "12.3 / 31.7 GB" "95%  93 MB/s" "61%  1.0/8.0 GB"]) ...
    && isequal(app.RunMonitorBars(3).Children(1).BackgroundColor, [0.9 0.45 0.1]) ...
    && isequal(app.RunMonitorBars(1).Children(1).BackgroundColor, [0.25 0.55 0.85]) ...
    && contains(app.RunMonitorTexts(3).Tooltip, "1 D:") && contains(app.RunMonitorTexts(4).Tooltip, "GPU 0 A"), ...
    'a sample shows each figure, the busiest GPU, and a bar at 90% or more in orange');
S.gpus = []; S.gpuNote = 'nvidia-smi not found'; S.cpu = [];
app.showResourceSample(S);
check(app.RunMonitorTexts(4).Text == "n/a" && contains(app.RunMonitorTexts(4).Tooltip, "not found") ...
    && app.RunMonitorTexts(1).Text == "n/a", 'a missing reading shows n/a and says why');
app.selectTab(app.TabRun);
app.RunMonitorCheckBox.Value = true;
app.onResourceMonitorToggled();
dirMon = app.ResourceMonitor.dir;
check(app.RunMonitorPanel.Visible == "on" && isequal(app.RunLeftGrid.RowHeight, {'1x', 'fit'}) ...
    && isfolder(dirMon) && strcmp(app.ResourceMonitorTimer.Running, 'on'), ...
    'ticked, the panel opens under the steps and the sampler and timer start');
t0 = tic;
while toc(t0) < 20 && ~startsWith(string(app.RunMonitorNote.Text), "Sampled every")
    pause(0.5);
end
tx = string({app.RunMonitorTexts.Text});
check(startsWith(string(app.RunMonitorNote.Text), "Sampled every") && endsWith(tx(1), "%") ...
    && endsWith(tx(2), " GB"), sprintf('live samples arrive within %.0f s', toc(t0)));
app.savePreferences();
check(isequal(getpref(g, 'MonitorResources'), true), 'the switch is saved as a preference');
app.RunMonitorCheckBox.Value = false;
app.onResourceMonitorToggled();
t0 = tic;
while toc(t0) < 10 && isfolder(dirMon)
    pause(0.5);
end
check(app.RunMonitorPanel.Visible == "off" && isequal(app.RunLeftGrid.RowHeight, {'1x', 0}) ...
    && isempty(app.ResourceMonitorTimer) && ~isfolder(dirMon), ...
    'unticked, the panel closes, the timer stops and the sampler exits and removes its folder');

fprintf('\n== 4d. Clean up tab ==\n');
ksRoot = app.Project.Datasets(1).kilosortDir();   % under the OutputRoot
ksOut = ksRoot;
if ~isfolder(ksOut); mkdir(ksOut); end
fid = fopen(fullfile(ksOut, 'temp_wh.dat'), 'w'); fwrite(fid, zeros(1, 512, 'int16'), 'int16'); fclose(fid);
app.selectTab(app.TabCleanup);
check(contains(app.CleanupScopeLabel.Text, "1 dataset") && app.CleanupRunButton.Enable == "off" ...
    && isempty(app.CleanupPlan), 'the tab says which datasets it acts on; nothing can be removed before a Preview');
app.onCleanupPreview();
P = app.CleanupPlan;
rawRow = P(P.File == string(fullfile(f1, 'recA.rhd')), :);
check(height(P) > 2 && isequal(P.Action(P.File == string(fullfile(ksOut, 'temp_wh.dat'))), "remove") ...
    && rawRow.Action == "keep" && contains(rawRow.Reason, "no source copy") ...
    && app.CleanupRunButton.Enable == "on" && startsWith(app.CleanupSummaryLabel.Text, "Would remove 1 file(s)") ...
    && size(app.CleanupTable.Data, 1) == height(P) && isfile(fullfile(ksOut, 'temp_wh.dat')), ...
    'Preview lists every file as Remove or Keep (a raw recording without a copy record stays) and deletes nothing');
check(app.CleanupTable.ColumnSortable && isequal(P.Include, P.Action == "remove") ...
    && isequal(app.CleanupSubjectDropDown.Items, [{'All subjects'}; cellstr(unique(P.Subject))].'), ...
    'the columns sort, every Remove file starts ticked and the Subject ID list holds the plan''s subjects');
app.CleanupShowKeptCheckBox.Value = false;
app.refreshCleanupTable();
check(size(app.CleanupTable.Data, 1) == 1 && isequal(app.CleanupTable.Data(1, 1:2), {true, 'Remove'}), ...
    'unticking Show the files that remain leaves only the Remove rows');
app.CleanupShowKeptCheckBox.Value = true;
app.CleanupSearchField.Value = 'temp_wh\.dat$';
app.refreshCleanupTable();
check(size(app.CleanupTable.Data, 1) == 1 && startsWith(app.CleanupShownLabel.Text, "Showing 1 of"), ...
    'the regexp search shows only the matching files');
app.CleanupSearchField.Value = 'no-such-file';
app.refreshCleanupTable();
check(isempty(app.CleanupTable.Data) && isequal(app.CleanupSearchField.BackgroundColor, [1.00 0.85 0.85]), ...
    'a search matching no file empties the table and is flagged');
app.CleanupSearchField.Value = '';
app.CleanupSubjectDropDown.Value = app.CleanupSubjectDropDown.Items{end};
app.refreshCleanupTable();
check(size(app.CleanupTable.Data, 1) == nnz(P.Subject == string(app.CleanupSubjectDropDown.Value)), ...
    'the Subject ID list shows only that subject''s files');
app.CleanupSubjectDropDown.Value = 'All subjects';
app.refreshCleanupTable();
r = find(strcmp(app.CleanupTable.Data(:, 2), 'Remove'));
app.onCleanupFileTicked(struct('Indices', [r 1], 'NewData', false));
check(~app.CleanupPlan.Include(app.CleanupRowMap(r)) && app.CleanupRunButton.Enable == "off" ...
    && contains(app.CleanupSummaryLabel.Text, "Would remove 0 file(s)"), ...
    'unticking the only Remove file leaves nothing to remove');
k = find(strcmp(app.CleanupTable.Data(:, 2), 'Keep'), 1);
app.CleanupTable.Data{k, 1} = true;
app.onCleanupFileTicked(struct('Indices', [k 1], 'NewData', true));
check(~app.CleanupTable.Data{k, 1} && ~any(app.CleanupPlan.Include(app.CleanupPlan.Action == "keep")), ...
    'a Keep file cannot be ticked');
app.onCleanupSelect("all");
check(app.CleanupPlan.Include(app.CleanupRowMap(r)) && app.CleanupRunButton.Enable == "on", 'All visible ticks the Remove files shown');
app.onCleanupSelect("invert");
check(~any(app.CleanupPlan.Include), 'Invert visible flips them');
app.onCleanupSelect("all");
app.CleanupSearchField.Value = 'no-such-file';
app.refreshCleanupTable();
app.onCleanupSelect("only");
check(~any(app.CleanupPlan.Include), 'Only visible with nothing shown unticks every hidden file');
app.CleanupSearchField.Value = '';
app.refreshCleanupTable();
app.onCleanupSelect("all");
app.onCleanupSelect("none");
check(~any(app.CleanupPlan.Include) && app.CleanupRunButton.Enable == "off", 'None visible unticks what is shown');
app.onCleanupSelect("all");
app.CleanupSorterCopyCheckBox.Value = false;
app.onCleanupSettingsChanged();
check(isempty(app.CleanupPlan) && app.CleanupRunButton.Enable == "off" && contains(app.CleanupSummaryLabel.Text, "Preview again"), ...
    'changing the kinds to remove discards the preview until Preview is pressed again');
check(numel(app.CleanupStepCheckBoxes) == 6 && isequal(string({app.CleanupStepCheckBoxes.Tag}), ...
    ["sorting" "signals" "spikes" "behavior" "artifacts" "export"]) && ~any([app.CleanupStepCheckBoxes.Value]) ...
    && string(app.CleanupMethodDropDown.Value) == "delete" && app.CleanupDestField.Enable == "off" ...
    && app.CleanupRunButton.Text == "Delete files...", ...
    'one box per step that writes files, none ticked; files are deleted by default and the folder field is off');
writelines('{"state": "done"}', fullfile(ksRoot, 'ks4_status.json'));
app.CleanupStepCheckBoxes(1).Value = true;   % Sorting (Kilosort4)
app.onCleanupSettingsChanged();
app.onCleanupPreview();
P = app.CleanupPlan;
inKs = startsWith(P.File, string(ksRoot) + filesep);
check(nnz(inKs) == 2 && all(P.Action(inKs) == "remove") && all(P.Step(inKs) == "sorting") ...
    && ~any(P.Action(~inKs & P.Step ~= "sorting") == "remove"), ...
    'ticking Sorting marks everything in the kilosort4 folder Remove, and nothing outside the step''s files');
app.CleanupMethodDropDown.Value = 'move';
app.onCleanupMethodChanged();
check(app.CleanupDestField.Enable == "on" && app.CleanupRunButton.Text == "Move files..." && ~isempty(app.CleanupPlan), ...
    'Move to a folder turns the folder field on and keeps the preview');
app.CleanupDestField.Value = fullfile(proj, 'moved');
app.onCleanupRun();   % refused with an alert, before any confirmation
check(all(isfile(P.File(inKs))) && ~isfolder(fullfile(proj, 'moved')), ...
    'a folder inside the project root is refused and nothing moves');
moveDest = fullfile(root, 'moved');
app.CleanupDestField.Value = moveDest;
R = app.runCleanup(app.CleanupPlan);
movedTo = string(fullfile(moveDest, R.Key, extractAfter(R.File, strlength(R.Root) + 1)));
check(height(R) == nnz(P.Action == "remove") && all(R.Status == "removed") && isequal(R.To, movedTo) ...
    && all(isfile(movedTo)) && ~isfolder(ksRoot) && ~any(startsWith(app.CleanupPlan.File, string(ksRoot))) ...
    && contains(string(app.CleanupLogArea.Value{end}), "Moved") ...
    && isfile(fullfile(f1, app.Project.Datasets(1).Name + "_cleanup.json")), ...
    'Move files moves them to <folder>\<dataset key>\..., removes the emptied kilosort4 folder, keeps a record and previews again');
app.savePreferences();
v = getpref(g, 'CleanupOptions');
check(isequal(string(v.steps), "sorting") && string(v.method) == "move" && string(v.destination) == string(moveDest), ...
    'the ticked steps, the method and the folder are saved as preferences');
app.CleanupStepCheckBoxes(1).Value = false;
app.CleanupSorterCopyCheckBox.Value = true;
app.CleanupMethodDropDown.Value = 'delete';
app.CleanupDestField.Value = '';
app.onCleanupMethodChanged();
app.onCleanupSettingsChanged();
if isfolder(ksRoot); rmdir(ksRoot, 's'); end
app.selectTab(app.TabProject);

fprintf('\n== 4e. Run tab: background Kilosort4 runs, N at a time ==\n');
check(app.RunKSAtOnceSpinner.Value == 1 && strcmp(app.RunKSAtOnceSpinner.Enable, 'on') ...
    && app.Config.Sorting.MaxConcurrent == 1, 'one background Kilosort4 run at a time by default, set on the Run tab');
app.ExecModeDropDown.Value = true;   % Blocking (wait)
app.ExecModeDropDown.ValueChangedFcn(app.ExecModeDropDown, []);
check(app.Config.Sorting.Execution == "blocking" && strcmp(app.RunKSAtOnceSpinner.Enable, 'off'), ...
    'blocking execution greys out the runs-at-once spinner');
app.ExecModeDropDown.Value = false;
app.ExecModeDropDown.ValueChangedFcn(app.ExecModeDropDown, []);
app.RunKSAtOnceSpinner.Value = 2;
app.RunKSAtOnceSpinner.ValueChangedFcn(app.RunKSAtOnceSpinner, []);   % as a click would
check(app.Config.Sorting.MaxConcurrent == 2 && strcmp(app.RunKSAtOnceSpinner.Enable, 'on'), ...
    'the spinner sets Sorting.MaxConcurrent');
app.RunKSAtOnceSpinner.Value = 1;
app.RunKSAtOnceSpinner.ValueChangedFcn(app.RunKSAtOnceSpinner, []);
% A run from an earlier Run still holds the only slot: this Run waits for it
% (the sampler below ends that run once both labels have said so), and the
% monitor follows the new run from its start. A stand-in "python" sleeps
% ~4 s and writes ks4_status.json.
probe4 = fullfile(root, 'probe4.json');
writeJsonFile(probe4, struct('chanMap', 0:numAmp-1, 'xc', zeros(1, numAmp), 'yc', (0:numAmp-1) * 20, ...
    'kcoords', zeros(1, numAmp), 'n_chan', numAmp));
app.Project.Datasets(1).ProbeFile = probe4;
fakePython = fullfile(root, 'fake_python.cmd');
writelines(["@echo off"; "ping -n 5 127.0.0.1 > nul"; "echo sorted by the stand-in"
    "echo {""state"": ""done""}> ""%~dp1ks4_status.json"""], fakePython, LineEnding="\r\n");
app.PythonExeField.Value = fakePython;
app.onConfigChanged();
priorDir = fullfile(root, 'earlier_run'); mkdir(priorDir);
priorStatus = fullfile(priorDir, 'ks4_status.json');
app.KSRuns = EphysPipeline.sortRun("earlier", struct('statusFile', priorStatus, ...
    'resultsDir', priorDir, 'stdoutLog', "", 'device', ""));
app.startKSMonitor();
labelsSeen = strings(0, 1);
tSample = tic;
    function sampleLabels()
        labelsSeen(end+1, 1) = string(app.RunKSLabel.Text) + " | " + string(app.RunStepLabel.Text);
        both = any(contains(labelsSeen, "waiting to start")) && any(contains(labelsSeen, "waiting for a free"));
        if ~isfile(priorStatus) && (both || toc(tSample) > 60)
            writelines('{"state": "done"}', priorStatus);   % the earlier run finishes
        end
    end
sampler = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.5, 'BusyMode', 'drop', ...
    'TimerFcn', @(~,~) sampleLabels());
start(sampler);
app.runPipeline(Steps="sorting");
stop(sampler); delete(sampler);
R = app.RunResultsTable.Data;
check(any(R.Step == "sorting" & R.Status == "launched") && toc(tSample) < 60, ...
    'the Run waited for the earlier run''s slot, then launched');
check(any(contains(labelsSeen, "sorting: recA_260101_120000 - waiting for a free Kilosort4 slot (1 at a time): 1 running")) ...
    && any(contains(labelsSeen, "Background Kilosort4: 0 of 2 finished (1 running, 1 waiting to start).")), ...
    'while waiting, the step line and the Kilosort4 label say how many run and wait');
check(numel(app.KSRuns) == 2 && app.KSRuns(2).Name == "recA_260101_120000", ...
    'the new run joined the monitor as it started');
t0 = tic;
while toc(t0) < 30 && ~isempty(app.KSRuns)
    pause(0.5);
end
exitMarker = fullfile(app.Project.Datasets(1).kilosortDir(), EphysDataset.SortExitMarker);
while toc(t0) < 40 && ~isfile(exitMarker)
    pause(0.25);
end
ksLog = strjoin(string(app.KSLogArea.Value), newline);
check(contains(ksLog, "recA_260101_120000 | sorted by the stand-in"), ...
    'the monitor streamed the run''s log (CRLF lines, as Python on Windows writes them)');
check(isempty(app.KSRuns) && contains(ksLog, "[done] recA_260101_120000 - Kilosort4 complete") ...
    && contains(ksLog, "=== all 2 background run(s) complete ===") ...
    && startsWith(string(app.RunKSLabel.Text), "Background Kilosort4: 2 of 2 finished"), ...
    'the monitor logged it done and cleared the finished batch');
R = app.RunResultsTable.Data;
row = R(R.Step == "sorting", :);
check(height(row) == 1 && row.Status == "done" && row.Message == "Kilosort4 finished" && row.Seconds >= 3, ...
    'the monitor turned the run''s "launched" row into "done", adding the time it ran');
check(app.RunDiagram.results.Status(app.RunDiagram.results.Step == "sorting") == "done", ...
    'the run diagram counts it done too');

fprintf('\n== 4f. Run tab: GPUs, and queueing the waiting runs ==\n');
app.RunKSDevicesField.Value = 'cuda:0, cuda:1';
app.RunKSDevicesField.ValueChangedFcn(app.RunKSDevicesField, []);
check(isequal(app.Config.Sorting.Devices, ["cuda:0" "cuda:1"]), 'the GPUs field sets Sorting.Devices');
app.RunKSDevicesField.Value = '';
app.RunKSDevicesField.ValueChangedFcn(app.RunKSDevicesField, []);
check(isempty(app.Config.Sorting.Devices), 'a blank GPUs field lists no devices');
app.ExecModeDropDown.Value = true;
app.ExecModeDropDown.ValueChangedFcn(app.ExecModeDropDown, []);
check(strcmp(app.RunKSQueueCheckBox.Enable, 'off'), 'blocking execution greys out the queue box');
app.ExecModeDropDown.Value = false;
app.ExecModeDropDown.ValueChangedFcn(app.ExecModeDropDown, []);
app.RunKSQueueCheckBox.Value = true;
% An earlier run holds the only slot again: this time the Run queues the
% dataset and ends without waiting. A safety timer ends the earlier run
% after 60 s, so a Run that waited after all cannot hang the suite.
priorDir = fullfile(root, 'earlier_run2'); mkdir(priorDir);
priorStatus = fullfile(priorDir, 'ks4_status.json');
app.KSRuns = EphysPipeline.sortRun("earlier", struct('statusFile', priorStatus, ...
    'resultsDir', priorDir, 'stdoutLog', "", 'device', ""));
app.startKSMonitor();
safety = timer('StartDelay', 60, 'TimerFcn', @(~,~) writelines('{"state": "done"}', priorStatus));
start(safety);
t0 = tic;
app.runPipeline(Steps="sorting");
R = app.RunResultsTable.Data;
check(toc(t0) < 30 && ~app.RunActive && any(R.Step == "sorting" & R.Status == "queued") ...
    && numel(app.KSQueue) == 1 && numel(app.KSRuns) == 1, ...
    'with the earlier run holding the slot, the Run queued the dataset and ended at once');
t0 = tic;
while toc(t0) < 10 && ~contains(app.RunKSLabel.Text, "1 waiting to start"); pause(0.25); end
check(strcmp(app.RunKSStopQueueButton.Enable, 'on') && contains(app.RunKSLabel.Text, "(1 running, 1 waiting to start)"), ...
    'Stop queue is on and the Kilosort4 label counts the queued dataset');
writelines('{"state": "done"}', priorStatus);   % the earlier run finishes
t0 = tic;
while toc(t0) < 20 && ~isempty(app.KSQueue); pause(0.25); end
R = app.RunResultsTable.Data;
check(isempty(app.KSQueue) && any(R.Step == "sorting" & R.Status == "launched" & contains(R.Message, "started from the queue")) ...
    && strcmp(app.RunKSStopQueueButton.Enable, 'off'), ...
    'once the slot freed, the monitor started the queued run and its row says so');
t0 = tic;
while toc(t0) < 30 && ~isempty(app.KSRuns); pause(0.5); end
R = app.RunResultsTable.Data;
check(any(R.Step == "sorting" & R.Status == "done") && contains(strjoin(string(app.KSLogArea.Value), newline), ...
    "recA_260101_120000: launched from the queue"), 'the queued run ran to the end: its row says "done"');
while toc(t0) < 40 && ~isfile(exitMarker); pause(0.25); end
% Stop queue drops a queued run that has not started.
priorDir = fullfile(root, 'earlier_run3'); mkdir(priorDir);
priorStatus3 = fullfile(priorDir, 'ks4_status.json');
app.KSRuns = EphysPipeline.sortRun("earlier", struct('statusFile', priorStatus3, ...
    'resultsDir', priorDir, 'stdoutLog', "", 'device', ""));
app.startKSMonitor();
app.runPipeline(Steps="sorting");
check(numel(app.KSQueue) == 1, 'queued again behind a running earlier run');
app.RunKSStopQueueButton.ButtonPushedFcn(app.RunKSStopQueueButton, []);
R = app.RunResultsTable.Data;
check(isempty(app.KSQueue) && any(R.Status == "cancelled" & R.Message == "queue stopped before it started") ...
    && strcmp(app.RunKSStopQueueButton.Enable, 'off') && numel(app.KSRuns) == 1, ...
    'Stop queue drops the queued run, marks its row cancelled and leaves the running one');
writelines('{"state": "done"}', priorStatus3);
t0 = tic;
while toc(t0) < 20 && ~isempty(app.KSRuns); pause(0.25); end
stop(safety); delete(safety);
app.RunKSQueueCheckBox.Value = false;
% Stop runs... ends a run that is going: a stand-in that would take ~30 s.
slowPython = fullfile(root, 'slow_python.cmd');
writelines(["@echo off"; "ping -n 31 127.0.0.1 > nul"
    "echo {""state"": ""done""}> ""%~dp1ks4_status.json"""], slowPython, LineEnding="\r\n");
app.PythonExeField.Value = slowPython;
app.onConfigChanged();
check(strcmp(app.RunKSStopRunsButton.Enable, 'off'), 'Stop runs... is off with no run going');
app.runPipeline(Steps="sorting");
t0 = tic;
while toc(t0) < 10 && ~strcmp(app.RunKSStopRunsButton.Enable, 'on'); pause(0.25); end
check(strcmp(app.RunKSStopRunsButton.Enable, 'on') && numel(app.KSRuns) == 1, 'Stop runs... is on while a run is going');
app.stopKSRuns();   % what the button does once confirmed
t0 = tic;
while toc(t0) < 10 && ~isempty(app.KSRuns); pause(0.25); end
R = app.RunResultsTable.Data;
ksLog = strjoin(string(app.KSLogArea.Value), newline);
check(isempty(app.KSRuns) && any(R.Step == "sorting" & R.Status == "cancelled" & R.Message == "stopped before it finished") ...
    && contains(ksLog, "[stopped] recA_260101_120000 - Kilosort4 stopped by the user") ...
    && strcmp(app.RunKSStopRunsButton.Enable, 'off'), ...
    'stopKSRuns ended the run: logged, its row cancelled, the button off again');
app.PythonExeField.Value = '';
app.onConfigChanged();
app.Project.Datasets(1).ProbeFile = "";
app.Project.Datasets(1).writeManifest();
rmdir(app.Project.Datasets(1).kilosortDir(), 's');

fprintf('\n== 5. save and reopen ==\n');
ok = app.onSaveConfig();
check(ok && ~startsWith(app.Fig.Name, "*"), 'save clears the unsaved marker');
c2 = EphysPipelineConfig.load(cfgFile);
check(c2.Spikes.Threshold == 1500 && c2.Project.Root == string(proj), 'the saved file holds the edit');
app.onNewConfig();
check(app.Config.Name == "Untitled" && app.Config.File == "" && ~app.SpkEnableCheckBox.Value, 'New config resets to defaults');
ok = app.openConfigFile(cfgFile);
check(ok && app.Config.Spikes.Threshold == 1500 && any(app.RecentConfigs == string(cfgFile)), 'reopen + recent list');
check(ispref(g, 'LastConfigFile') && strcmp(getpref(g, 'LastConfigFile'), cfgFile), 'the last config file is remembered');

fprintf('\n== 6. a config for another root; a rescan; Visualize bins and overlay ==\n');
% A second project: recM002 (one file) and recM003, five files of 512
% samples with one spike at recording sample 2500 of channel 1 - a long
% recording in small, whose Visualize bins cross the file boundaries.
root2 = fullfile(root, 'proj2');
flatRaw = repmat(uint16(32768), numAmp, 4 * spb);
flatDig = zeros(1, 4 * spb);
fM2 = fullfile(root2, 'recM002_260102_120000'); mkdir(fM2);
writeSyntheticRHD(fullfile(fM2, 'recM002.rhd'), flatRaw, flatDig, Fs, spb);
fM3 = fullfile(root2, 'recM003_260103_120000'); mkdir(fM3);
tSpike = 2500;   % 0-based recording sample
for k = 1:5
    raw = flatRaw;
    s = tSpike - (k - 1) * 4 * spb;
    if s >= 0 && s < 4 * spb; raw(1, s + 1) = 32768 + 5000; end   % 975 uV
    fk = fullfile(fM3, sprintf('recM003_part%d.rhd', k));
    writeSyntheticRHD(fk, raw, flatDig, Fs, spb, FirstTimestamp=(k - 1) * 4 * spb);
    setFileModifiedTime(fk, datetime(2026, 1, 3, 12, 0, k));   % the files' order
end
cfgB = cfg;
cfgB.Name = "second project";
cfgB.Project.Root = root2;
cfgB.Project.OutputRoot = fullfile(root, 'out2');
cfgB.Project.Selection = "list";
cfgB.Project.Datasets = "recM003_260103_120000";
cfgBFile = fullfile(root, 'second_project.json');
cfgB = cfgB.save(cfgBFile);
app.onScan();   % gui_test.json's project
check(app.Project.NumDatasets == 1 && app.projectAtRoot(proj), 'the first project is scanned');
ok = app.openConfigFile(cfgBFile);
check(ok && isempty(app.Project) && height(app.DatasetsTable.Data) == 0 && app.Config.Project.Selection == "list" ...
    && isequal(app.Config.Project.Datasets, "recM003_260103_120000"), ...
    'opening a config for another root drops the scanned project and keeps the config''s selection');
id = "";
try
    app.buildPipeline();
catch ME
    id = string(ME.identifier);
end
check(id == "EphysPreprocessingApp:NoProject", 'before its Scan, a run or plan refuses');
app.onScan();
T = app.DatasetsTable.Data;
check(app.Project.NumDatasets == 2 && isequal(T.Select(T.Name == "recM003_260103_120000"), true) && nnz(T.Select) == 1 ...
    && app.Config.Project.Selection == "list" && isequal(app.Config.Project.Datasets, "recM003_260103_120000"), ...
    'Scan loads the config''s datasets and ticks its selection (not "all")');
app.RootPathField.Value = char(proj);   % edited, not scanned
app.onConfigChanged();
id = "";
try
    app.buildPipeline();
catch ME
    id = string(ME.identifier);
end
check(id == "EphysPreprocessingApp:OtherProject" && isequal(app.Config.Project.Datasets, "recM003_260103_120000"), ...
    'with the root edited, a run or plan refuses the datasets scanned under the other root, and the selection is kept');
app.RootPathField.Value = char(root2);
app.onConfigChanged();
names = [app.Project.Datasets.Name];
dM2 = app.Project.Datasets(names == "recM002_260102_120000");
dM3 = app.Project.Datasets(names == "recM003_260103_120000");
dM2.ManualArtifacts = [0.001 0.002]; dM2.writeManifest();
dM3.ManualArtifacts = [0.03 0.031]; dM3.writeManifest();
app.selectDataset(find(names == "recM003_260103_120000"));
app.selectTab(app.TabVisualize);
app.VizChannelsField.Value = '1';
app.VizFileDropDown.Value = '(all)';
app.VizHighpassField.Value = ''; app.VizLowpassField.Value = '';
app.VizRefDropDown.Value = 'none'; app.VizDetrendCheckBox.Value = false;
app.VizModeDropDown.Value = 'traces';
app.VizStartField.Value = 0; app.VizDurField.Value = 1;
app.VizMemoryBudget = 1150;   % 5 x 512 samples of one channel: 9-sample bins
app.onPlotVisualization();
hl = findobj(app.VizAxes, 'Type', 'line');
[~, iPk] = max(hl(1).YData);
tPk = hl(1).XData(iPk);
check(contains(app.VizStatusLabel.Text, "Decimated 9x") && app.Viewer.NumSamples == ceil(5 * 4 * spb / 9) ...
    && tPk <= tSpike / Fs && tPk > (tSpike - 9) / Fs, ...
    'decimated bins run across the files: the spike in the last file is drawn within one bin of its recording time, and the last bin holds the last samples');
check(isempty(app.vizDetectedIntervals()) && contains(app.VizArtStatusLabel.Text, "Detect / Preview") ...
    && numel(findobj(app.VizAxes, 'Type', 'constantregion')) == 1, ...
    'before a Detect / Preview only the manual period is shaded (red), and the tab says where detected periods come from');
app.selectTab(app.TabArtifacts);
app.ArtMethodDropDown.Value = 'microvolts';
app.onArtifactControlsChanged();
app.ArtThresholdField.Value = 500;
app.ArtMinChannelsField.Value = 1;
app.onArtifactControlsChanged();
app.onDetectArtifacts();
app.selectTab(app.TabVisualize);   % the overlay follows the preview
iv = app.vizDetectedIntervals();
tMid = (tSpike + 0.5) / Fs;   % inside the spike's sample, [tSpike tSpike+1) / Fs
check(size(iv, 1) == 1 && iv(1, 1) < tMid && iv(1, 2) > tMid ...
    && numel(findobj(app.VizAxes, 'Type', 'constantregion')) == 2 && contains(app.VizArtStatusLabel.Text, "1 detected"), ...
    'after a Detect / Preview the plot shades the preview''s detection (orange) beside the manual period (red)');
app.selectTab(app.TabArtifacts);
app.ArtThresholdField.Value = 600;
app.onArtifactControlsChanged();
app.selectTab(app.TabVisualize);
check(isempty(app.vizDetectedIntervals()) && contains(app.VizArtStatusLabel.Text, "changed") ...
    && numel(findobj(app.VizAxes, 'Type', 'constantregion')) == 1, ...
    'a detection setting changed since the preview: nothing is shaded orange, and the tab says so');
app.applyArtifactsSection(cfgB.Artifacts);
app.onArtifactControlsChanged();
fM1 = fullfile(root2, 'recM001_260101_120000'); mkdir(fM1);
writeSyntheticRHD(fullfile(fM1, 'recM001.rhd'), flatRaw, flatDig, Fs, spb);
app.onScan();
names = [app.Project.Datasets.Name];
dM2 = app.Project.Datasets(names == "recM002_260102_120000");
dM3 = app.Project.Datasets(names == "recM003_260103_120000");
iM3 = find(names == "recM003_260103_120000");
check(app.Project.NumDatasets == 3 && app.currentDataset() == dM3 && app.VizDataset == dM3 ...
    && strcmp(app.VizArtButton.Enable, 'on') && ~contains(app.VizStatusLabel.Text, "Press Plot"), ...
    'a rescan that finds a dataset in front keeps recM003 active, and its plot current (a mark goes to recM003)');
app.onVizArtClear();
check(isempty(dM3.ManualArtifacts) && isequal(dM2.ManualArtifacts, [0.001 0.002]), ...
    'Clear Artifacts clears the plotted recM003''s periods, not those of the dataset now in its old place');
dM3.SortingDir = phyDir;
app.refreshDatasetsTable(Datasets=iM3);
T = app.DatasetsTable.Data;
r = T.DatasetIdx == iM3;
check(startsWith(T.Sorting(r), "manual") && T.Select(r), 'refreshing one dataset''s row updates its cells and keeps its tick');
dM3.SortingDir = fullfile(root, 'not_there');
app.refreshDatasetsTable(Datasets=iM3);
app.selectTab(app.TabReview);
T = app.DatasetsTable.Data;
check(T.Sorting(r) == "missing: manual" && contains(string(app.ReviewSummaryLabel.Text), "not there now") ...
    && isempty(app.ReviewData), ...
    'a hand-picked sorted-output folder that is not there reads "missing", and the Review tab says so instead of showing another sort');
dM3.SortingDir = "";
app.ProbeDefaultField.Value = char(probe4);
app.onConfigChanged();
check(all(app.DatasetsTable.Data.Probe == "default: probe4.json"), 'datasets without a probe of their own show the default probe');
app.ProbeDefaultField.Value = '';
app.onConfigChanged();
app.RunActive = true;   % as while a blocking run is under way
P0 = app.Project;
ref0 = dM3.ArtifactConfig.Reference;
app.ArtRefDropDown.Value = 'car';
app.onArtifactControlsChanged();
app.onScan();
app.ExcludeChannelsField.Value = '1';
app.onApplyExclude("selected");
check(app.Config.Artifacts.Reference == "car" && dM3.ArtifactConfig.Reference == ref0 && app.Project == P0 ...
    && isempty(dM3.ExcludeChannels), ...
    'while a run is under way config edits wait for its end, and Scan and per-dataset edits are refused');
app.RunActive = false;
app.ArtRefDropDown.Value = 'none';
app.onArtifactControlsChanged();
app.selectTab(app.TabProject);
badManifest = fullfile(fM1, "recM001_260101_120000_manifest.json");
writelines("not json", badManifest);
app.onScan();
check(contains(app.StatusBar.Text, "1 with a problem") && strtrim(string(fileread(badManifest))) == "not json", ...
    'a manifest that cannot be read is reported after the scan and left as it is');
delete(badManifest);
app.onScan();
names = [app.Project.Datasets.Name];
dM2 = app.Project.Datasets(names == "recM002_260102_120000");
dM3 = app.Project.Datasets(names == "recM003_260103_120000");

fprintf('\n== 6b. a Plan while a background Kilosort4 run is going ==\n');
bgDir = fullfile(root, 'bg_run'); mkdir(bgDir);
bgStatus = fullfile(bgDir, 'ks4_status.json');
app.KSRuns = EphysPipeline.sortRun("recM003_260103_120000", struct('statusFile', bgStatus, ...
    'resultsDir', bgDir, 'stdoutLog', "", 'device', ""));
app.RunResults = EphysPipeline.emptyResults();
app.RunResults(1, :) = {"sorting", "recM003_260103_120000", "launched", "background run", string(bgDir), 1};
app.startKSMonitor();
app.onPlan();   % the results table now holds the plan
writelines('{"state": "done"}', bgStatus);
t0 = tic;
while toc(t0) < 20 && ~isempty(app.KSRuns); pause(0.25); end
T = app.RunResultsTable.Data;
check(isempty(app.KSRuns) && app.RunResults.Status(1) == "done" && ismember("Key", T.Properties.VariableNames) ...
    && contains(strjoin(string(app.KSLogArea.Value), newline), "[done] recM003_260103_120000"), ...
    'a run that ends while a Plan fills the results table is marked done in the Run''s results, and the monitor goes on');

fprintf('\n== 6c. the queue: each dataset once; a plan skips a queued one ==\n');
holdDir = fullfile(root, 'hold_run'); mkdir(holdDir);
holdStatus = fullfile(holdDir, 'ks4_status.json');
app.KSRuns = EphysPipeline.sortRun("hold", struct('statusFile', holdStatus, ...
    'resultsDir', holdDir, 'stdoutLog', "", 'device', ""));   % takes the only slot
prep = struct('statusFile', string(fullfile(dM3.kilosortDir(), 'ks4_status.json')), ...
    'resultsDir', string(dM3.kilosortDir()), 'stdoutLog', "", 'device', "", 'dryRun', false);
app.queueKSRun(dM3, prep);
app.queueKSRun(dM3, prep);
prepHold = prep;
prepHold.resultsDir = string(holdDir);   % the folder of the run going
app.queueKSRun(dM2, prepHold);
check(numel(app.KSQueue) == 1 && count(strjoin(string(app.KSLogArea.Value), newline), "not queued again") == 2, ...
    'a dataset whose Kilosort4 folder already has a run queued or going is not queued again');
pipe = app.buildPipeline();
Tp = pipe.plan(Steps="sorting");
check(any([pipe.PriorRuns.queued]) && Tp.Status(Tp.Dataset == "recM003_260103_120000") == "skip: Kilosort4 queued", ...
    'the queued run is one of the pipeline''s PriorRuns, so a plan (and a run) leaves its dataset alone');
app.onStopKSQueue();
writelines('{"state": "done"}', holdStatus);
t0 = tic;
while toc(t0) < 20 && ~isempty(app.KSRuns); pause(0.25); end

fprintf('\n== 6d. phy starts in a folder whose path holds & and spaces ==\n');
phyHome = fullfile(root, 'Mouse & Rat', 'kilo sort4');
mkdir(phyHome);
writelines("dat_path = 'recording.bin'", fullfile(phyHome, 'params.py'));
fakePhy = fullfile(root, 'fake phy.cmd');
writelines(["@echo off"; "cd > launched.txt"; "if exist params.py echo params.py found>> launched.txt"
    "echo %*>> launched.txt"], fakePhy, LineEnding="\r\n");
phyCmd0 = app.PhyCmdField.Value;
app.PhyCmdField.Value = ['"' fakePhy '"'];
app.launchPhy(phyHome, "Mouse & Rat");
marker = fullfile(phyHome, 'launched.txt');
t0 = tic;
while toc(t0) < 15 && ~(isfile(marker) && numel(readlines(marker)) >= 3); pause(0.25); end
L = strings(0, 1);
if isfile(marker); L = strtrim(readlines(marker)); end
check(~isempty(L) && strcmpi(L(1), phyHome) && any(L == "params.py found") && any(L == "template-gui params.py"), ...
    'phy is started in the results folder, also when its path holds & and spaces');
app.PhyCmdField.Value = phyCmd0;

fprintf('\n== 7. deleting the figure (not Close) stops the timers ==\n');
never = fullfile(root, 'never_run');
app.KSRuns = EphysPipeline.sortRun("never", struct('statusFile', fullfile(never, 'ks4_status.json'), ...
    'resultsDir', never, 'stdoutLog', "", 'device', ""));
app.startKSMonitor();
tK = app.KSMonitorTimer;
delete(app.Fig);   % as close all force does
check(~isvalid(tK) && isempty(app.KSMonitorTimer) && isempty(timerfindall('Name', 'EphysPreprocessingAppMonitor')), ...
    'deleting the figure stops the Kilosort4 monitor (the figure''s DeleteFcn)');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysPreprocessingApp:Failures', '%d checks failed.', nFail);
end
end


function closeApp(app)
try
    if isvalid(app) && isvalid(app.Fig)
        app.stopKSMonitor();
        app.stopResourceMonitor();
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
if isfolder(root); rmdir(root, 's'); end
end


function tip = tabTip(app, tab)
%tabTip  Status tooltip of TAB's button in the tab strip.
tip = string(app.TabButtons(app.TabList == tab).Tooltip);
end
