function test_EphysPreprocessingApp()
%test_EphysPreprocessingApp  Headless checks of the GUI's config model.
%   Builds the app in the current session (uifigure; no display interaction),
%   opens a config over a synthetic project, and checks: config -> controls ->
%   config round trip, the unsaved-changes marker, scan + selection ticks,
%   plan, the Sorting tab's Optimize for probe / Reset to defaults, running
%   one step through EphysPipeline, save, and that the app's
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
f1 = fullfile(proj, 'recA'); mkdir(f1);
writeSyntheticRHD(fullfile(f1, 'recA.rhd'), ampRaw, digRaw, Fs, spb);
phyDir = fullfile(root, 'phy');
makePhyFixture(phyDir, Fs, ChannelMap=[0 1 2 3], Legacy=true);
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
check(isvalid(app.Fig) && numel(app.Tabs.Children) == 11 && app.Tabs.Children(2) == app.TabTrials, ...
    'app builds with 11 tabs (Trials second)');
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
g2 = app.gatherConfig();
check(g2.isequalConfig(app.Config) && isequaln(g2.toStruct(), cfg.toStruct()), 'gatherConfig reproduces the loaded config exactly');
check(~startsWith(app.Fig.Name, "*") && contains(app.Fig.Name, "gui_test.json"), 'title shows the file and no unsaved marker');

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
app.RunMaxWorkersField.Value = '';
app.onParallelControlsChanged();
check(isnan(app.Config.Parallel.MaxWorkers) && app.Config.Parallel.Enabled, 'a blank worker cap means automatic');
app.RunParallelCheckBox.Value = false;
app.onParallelControlsChanged();
check(~app.Config.Parallel.Enabled && strcmp(app.RunMaxWorkersField.Enable, 'off'), 'unticking Parallel disables the worker cap');
app.RunParallelCheckBox.Value = true;
app.onParallelControlsChanged();
app.ParamControls.tmax.Value = 'abc';
[~, msg] = app.gatherSortingSection();
check(msg ~= "", 'an unparseable KS4 field is reported');
app.ParamControls.tmax.Value = 'Infinity';

fprintf('\n== 3. scan, selection, plan ==\n');
app.onScan();
T = app.DatasetsTable.Data;
check(~isempty(app.Project) && app.Project.NumDatasets == 1 && height(T) == 1 && T.Key(1) == "recA" ...
    && contains(T.Sorting(1), "manual"), 'scan fills the table with keys and the sorting association');
check(~T.Select(1) && app.Config.Project.Selection == "all", 'no ticks = every dataset');
app.onSelectDatasets("all");
check(app.Config.Project.Selection == "list" && isequal(app.Config.Project.Datasets, "recA"), 'ticking rows selects by key');
app.onSelectDatasets("none");
app.SelectedRow = 1;
app.onDatasetCellSelection(struct('Indices', [1 1]));
check(contains(app.SortResultsLabel.Text, "manual") && size(app.ArtManualTable.Data, 1) == 1, ...
    'selecting a row shows its sorting association and manual periods');
app.onPlan();
P = app.RunResultsTable.Data;
check(istable(P) && any(P.Step == "spikes" & P.Status == "ready"), 'plan lists the spikes step as ready');
app.onValidate();
check(iscell(app.RunIssuesTable.Data) || istable(app.RunIssuesTable.Data), 'validate fills the issues table');

fprintf('\n== 3a. name tokens ==\n');
check(isequal(string({app.NameTokenChecks.Text}), ["SubjectID" "Date" "Time"]) && isequal([app.NameTokenChecks.Value], [true false false]) ...
    && T.Token_SubjectID(1) == "-" && string(app.DatasetsTable.ColumnName{3}) == "SubjectID" ...
    && app.NameTokenStatusLabel.Text == "0 of 1 names match", ...
    'default pattern: one checkbox per token, SubjectID shown, recA does not match');
app.NamePatternField.Value = '{Stem}{Letter:[A-Z]}';
app.onNameTokensChanged();
check(isequal(string({app.NameTokenChecks.Text}), ["Stem" "Letter"]) && ~any([app.NameTokenChecks.Value]) ...
    && ~any(startsWith(app.DatasetsTable.Data.Properties.VariableNames, 'Token_')) ...
    && app.NameTokenStatusLabel.Text == "1 of 1 names match", 'a new pattern rebuilds the checkboxes');
app.NameTokenChecks(2).Value = true; app.NameTokenChecks(1).Value = true;
app.onNameTokensChanged();
T = app.DatasetsTable.Data;
check(T.Token_Stem(1) == "rec" && T.Token_Letter(1) == "A" && isequal(reshape(string(app.DatasetsTable.ColumnName(3:4)), 1, []), ["Stem" "Letter"]) ...
    && app.Config.Project.NamePattern == "{Stem}{Letter:[A-Z]}" && app.Config.Project.TokenColumns == "Stem, Letter" ...
    && numel(app.DatasetsTable.ColumnWidth) == width(T) && startsWith(app.Fig.Name, "*"), ...
    'ticked tokens become columns in pattern order and are saved in the config');
check(numel(app.NameTokenFilters) == 2 && isequal(string(app.NameTokenFilters(2).Items), ["(any)" "A"]), ...
    'one filter dropdown per token, listing the parsed values');
app.onSelectDatasets("all");
app.NameTokenFilters(2).Value = 'B';
app.refreshDatasetsTable();
app.onConfigChanged();
check(height(app.DatasetsTable.Data) == 0 && app.HiddenSelectedKeys == "recA" && isequal(app.selectedDatasetIndices(), 1) ...
    && isequal(app.Config.Project.Datasets, "recA") && contains(app.NameTokenStatusLabel.Text, "showing 0 of 1 (1 ticked hidden)"), ...
    'a filter hides non-matching rows and keeps their ticks in the selection');
app.NameTokenFilters(2).Value = 'b, a*';
app.refreshDatasetsTable();
check(height(app.DatasetsTable.Data) == 1 && app.DatasetsTable.Data.Select(1) && isempty(app.HiddenSelectedKeys), ...
    'wildcard / comma alternatives match case-insensitively and the tick returns');
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

fprintf('\n== 3b. Trials tab: load, cut, approve, polarity ==\n');
app.populateTrialsDatasets();
app.TrialsDatasetDropDown.Value = 1;
app.setTrialsLineItems("din0", "din0");
app.onTrialsSettingsChanged();
check(app.Config.Behavior.TrialLine == "din0" && startsWith(app.Fig.Name, "*"), 'the trial line is a config setting');
app.onTrialsLoad("recorded");
dT = app.currentTrialsDataset();
TT = app.TrialsTable.Data;
check(~isempty(app.TrialsPairing) && height(TT) == 1 && TT{1, 3} == 1 && TT{1, 6} == 50 ...
    && height(app.TrialsLinesTable.Data) == 1 && strcmp(app.TrialsApproveButton.Enable, 'on'), ...
    'Load pairs the single trial with the din0 interval (onset row 50)');
check(isequal(app.TrialsCutSpinners(1, 1).Limits, [0 1]) && strcmp(app.TrialsCutSpinners(2, 2).Enable, 'on') ...
    && app.TrialsCutIntervalsLabel.Text == "din0 intervals", 'the cut spinners are limited to the trial / interval counts');
check(app.TrialsAxes.InteractionOptions.LimitsDimensions == "x", 'the lines plot zooms and pans horizontally only');
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
g3 = app.gatherConfig();
check(isequal(g3.Signals.InvertedLines, "din0") && isequal(EphysPipelineConfig.signalOptions(g3.Signals).invertedLines, "din0"), ...
    'the polarity reaches the Signals options');
app.TrialsLinesTable.Data.Inverted(1) = false;
app.onTrialsSettingsChanged();
check(isempty(app.Config.Signals.InvertedLines) && app.TrialsPairing.recorded && app.TrialsPairing.status == "approved", ...
    'restoring the polarity brings the approved pairing back');
app.onTrialsWriteBehavior();
BT = load(fullfile(dT.outputFolder(), dT.Name + "_behavior.mat"));
check(BT.behavior.trials.TrialOnsetSample(1) == 50 && BT.behavior.pairing.status == "approved", 'Write behavior .mat carries the pairing');

fprintf('\n== 3c. Sorting tab: optimize for probe, reset to defaults ==\n');
dS = app.currentDataset();
app.onOptimizeKS4ForProbe();
check(app.Config.Sorting.KS4.nblocks == 3 && strcmp(app.ParamControls.dmin.Value, '12'), ...
    'without a probe (the dataset''s or the default) nothing is tuned');
probeFile = fullfile(root, 'square4.json');
writeJsonFile(probeFile, struct('chanMap', (0:3).', 'xc', [0; 25; 0; 25], 'yc', [0; 0; 25; 25], 'kcoords', zeros(4, 1)));
dS.ProbeFile = probeFile;
dS.ExcludeChannels = 4;
app.onOptimizeKS4ForProbe();
K = app.Config.Sorting.KS4;
check(K.nblocks == 0 && K.dmin == 25 && K.dminx == 25 && K.nearest_chans == 3 && K.nearest_templates == 3 ...
    && K.x_centers == 1 && app.ParamControls.nearest_chans.Value == 3 && strcmp(app.ParamControls.dmin.Value, '25'), ...
    'Optimize for probe tunes the controls and the config to the clicked dataset''s probe minus its excluded channel');
check(any(contains(string(app.KSLogArea.Value), "square4.json")) && any(contains(string(app.KSLogArea.Value), "x_centers")), ...
    'the tuning and its reasons are logged');
dS.ProbeFile = "";
dS.ExcludeChannels = double.empty(1, 0);
app.ProbeDefaultField.Value = char(probeFile);
app.onConfigChanged();
app.onOptimizeKS4ForProbe();
check(app.Config.Sorting.KS4.nearest_chans == 4 && any(contains(string(app.KSLogArea.Value), "default probe")), ...
    'a dataset without a probe uses the default probe');
app.ProbeDefaultField.Value = '';
before = app.Config.Sorting;
app.ExtraSettingsArea.Value = {'{"nblocks": 2}'};
app.onConfigChanged();
app.onResetKS4Params();
S = app.Config.Sorting;
check(isequaln(S.KS4, EphysPipelineConfig.defaults("Sorting").KS4) && S.KS4ExtraJSON == "" ...
    && strcmp(app.ParamControls.dmin.Value, '') && isequal(app.ExtraSettingsArea.Value, {'{'; '}'}), ...
    'Reset to defaults restores every Kilosort4 parameter and clears the extra JSON');
check(isequaln(S.SI, before.SI) && S.PythonExe == before.PythonExe && S.Enabled == before.Enabled ...
    && app.Config.Probe.DefaultProbeFile == "", 'and leaves the other Sorting settings alone');

fprintf('\n== 4. run one step through the pipeline ==\n');
app.runPipeline(Steps="spikes");
R = app.RunResultsTable.Data;
spikesFile = fullfile(outRoot, 'recA', 'recA_spikes.mat');
check(istable(R) && any(R.Step == "spikes" & R.Status == "done") && isfile(spikesFile), 'the Spikes step ran and wrote its file');
M = load(spikesFile);
check(~isempty(M.detected) && isequal(M.units.unitId, [0; 1]) && M.detected.detection.options.Threshold == 1500, ...
    'the file reflects the edited threshold and the sorted units');
check(~app.RunActive && strcmp(app.RunButton.Enable, 'on'), 'run state is reset afterwards');

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

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysPreprocessingApp:Failures', '%d checks failed.', nFail);
end
end


function closeApp(app)
try
    if isvalid(app) && isvalid(app.Fig)
        app.stopKSMonitor();
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
