function test_EphysPreprocessingApp()
%test_EphysPreprocessingApp  Headless checks of the GUI's config model.
%   Builds the app in the current session (uifigure; no display interaction),
%   opens a config over a synthetic project, and checks: config -> controls ->
%   config round trip, the unsaved-changes marker, scan + selection ticks,
%   plan, running one step through EphysPipeline, save, and that the app's
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
cfgFile = fullfile(root, 'gui_test.json');
cfg = cfg.save(cfgFile);

fprintf('\n== 1. build + open ==\n');
app = EphysPreprocessingApp;
appCleanup = onCleanup(@() closeApp(app));
check(isvalid(app.Fig) && numel(app.Tabs.Children) == 10, 'app builds with 10 tabs');
check(startsWith(app.Fig.Name, "Ephys preprocessing") && ~startsWith(app.Fig.Name, "*"), 'fresh app is clean');
ok = app.openConfigFile(cfgFile);
check(ok && app.Config.Name == "gui test" && app.Config.File == string(cfgFile), 'openConfigFile loads the config');
check(strcmp(app.RootPathField.Value, proj) && app.SpkEnableCheckBox.Value && strcmp(app.SpkThresholdField.Value, '2000') ...
    && app.ExpChronuxCheckBox.Value && ~app.ExpFieldTripCheckBox.Value && app.ParamControls.nblocks.Value == 3 ...
    && strcmp(app.ParamControls.dmin.Value, '12'), 'controls reflect the config');
check(strcmp(app.TabSpikes.Title, 'Spikes') && strcmp(app.TabSignals.Title, 'Signals [off]') && app.RunSpikesCheckBox.Value, ...
    'tab titles and the Run checklist follow the enabled steps');
g2 = app.gatherConfig();
check(g2.isequalConfig(app.Config) && isequaln(g2.toStruct(), cfg.toStruct()), 'gatherConfig reproduces the loaded config exactly');
check(~startsWith(app.Fig.Name, "*") && contains(app.Fig.Name, "gui_test.json"), 'title shows the file and no unsaved marker');

fprintf('\n== 2. edits and the unsaved marker ==\n');
app.SpkThresholdField.Value = '1500';
app.onSpikesControlsChanged();
check(app.Config.Spikes.Threshold == 1500 && startsWith(app.Fig.Name, "*"), 'a control edit updates the config and marks it unsaved');
app.RunSignalsCheckBox.Value = true;
app.RunSignalsCheckBox.ValueChangedFcn(app.RunSignalsCheckBox, []);   % as a click would
check(app.Config.Signals.Enabled && app.SigEnableCheckBox.Value && strcmp(app.TabSignals.Title, 'Signals'), ...
    'the Run checklist and the step tab stay in sync');
app.SigEnableCheckBox.Value = false;
app.onConvertControlsChanged();
check(~app.Config.Signals.Enabled && ~app.RunSignalsCheckBox.Value, 'and back');
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
