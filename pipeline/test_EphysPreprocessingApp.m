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
if ispref(g, 'TrialsParamColumns'); rmpref(g, 'TrialsParamColumns'); end
if ispref(g, 'TrialsColumnOrder'); rmpref(g, 'TrialsColumnOrder'); end
if ispref(g, 'TrialsLabelParams'); rmpref(g, 'TrialsLabelParams'); end

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
check(isvalid(app.Fig) && numel(app.Tabs.Children) == 13 && app.Tabs.Children(1) == app.TabCopy ...
    && app.Tabs.Children(3) == app.TabTrials && app.Tabs.SelectedTab == app.TabProject, ...
    'app builds with 13 tabs (Copy first, Trials third) and opens on Project');
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
app.selectTab(app.TabProject);
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
app.ParamControls.tmax.Value = 'abc';
[~, msg] = app.gatherSortingSection();
check(msg ~= "", 'an unparseable KS4 field is reported');
app.ParamControls.tmax.Value = 'Infinity';

fprintf('\n== 3. scan, selection, plan ==\n');
app.onScan();
T = app.DatasetsTable.Data;
check(~isempty(app.Project) && app.Project.NumDatasets == 1 && height(T) == 1 && T.Key(1) == "recA_260101_120000" ...
    && contains(T.Sorting(1), "manual"), 'scan fills the table with keys and the sorting association');
check(~T.Select(1) && app.Config.Project.Selection == "all", 'no ticks = every dataset');
check(numel(app.DatasetTickedItems) == 1 && string(app.DatasetTickedItems.Text) == "(no datasets ticked)" ...
    && numel(app.DatasetMenuItems) == 1 && app.DatasetMenu.Children(1) == app.DatasetAllMenu, ...
    'the Dataset menu lists no datasets while none is ticked; All datasets lists every one');
app.onSelectDatasets("all");
check(app.Config.Project.Selection == "list" && isequal(app.Config.Project.Datasets, "recA_260101_120000"), 'ticking rows selects by key');
check(numel(app.DatasetTickedItems) == 1 && isequal(app.DatasetTickedItems.UserData, 1) && app.DatasetTickedItems.Checked ...
    && app.DatasetMenu.Children(1) == app.DatasetAllMenu, ...
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
app.onPlan();
P = app.RunResultsTable.Data;
check(istable(P) && any(P.Step == "spikes" & P.Status == "ready"), 'plan lists the spikes step as ready');
app.onValidate();
check(iscell(app.RunIssuesTable.Data) || istable(app.RunIssuesTable.Data), 'validate fills the issues table');

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
hiRows = round(app.TrialsEvents.events.din0 * FsT);
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
check(isequaln(S.SI, before.SI) && S.PythonExe == before.PythonExe && S.Enabled == before.Enabled ...
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
