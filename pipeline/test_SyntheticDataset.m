function test_SyntheticDataset()
%test_SyntheticDataset  Verification suite for the synthetic test-data generators.
%   Writes a small four-scenario project with makeSyntheticProject and
%   checks that it scans as an EphysProject; that every digital line, the
%   Epsych2 session, the spikes, the accelerometer and the artifacts read
%   back as written; that the trial pairing behaves as each scenario
%   documents and the expected cuts resolve it; that the other two layouts
%   hold identical data; that the generated config runs through
%   EphysPipeline; and that the app's File-menu action writes, opens and
%   scans a project headlessly (the user's preferences are restored).
%
%   Usage:  test_SyntheticDataset

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));
addpath(genpath(fullfile(fileparts(here), 'vendor')));

root = fullfile(tempdir, sprintf('Synth_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
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
        end
    end
    function id = errorId(fcn)
        id = '';
        try
            fcn();
        catch ME
            id = ME.identifier;
        end
    end

fprintf('\n== 1. makeSyntheticProject: layout and scan ==\n');
proj = fullfile(root, 'proj');
Fs = 20000; nCh = 4; N = 6;
S = makeSyntheticProject(proj, Preset="small", Fs=Fs, NumChannels=nCh, NumTrials=N, FileSeconds=8, Seed=3);
D = S.datasets;
check(isfile(S.configFile) && isfile(S.probeFile) && isfile(S.readmeFile) && numel(D) == 4, ...
    'config, probe, README and four datasets written');
check(isequal([D.scenario], ["clean" "late-start" "early-stop" "spurious"]), 'one dataset per scenario, in order');
P = EphysProject(proj);
P.refresh();
check(P.NumDatasets == 4 && all(arrayfun(@(d) d.RecordingFormat == "traditional" && d.NumFiles >= 2, P.Datasets)), ...
    'EphysProject finds four multi-file Intan recordings');
T1 = D(1);
d1 = P.dataset(T1.name);
check(d1.Fs == Fs && d1.NumChannels == nCh && isequal(d1.DigInNames, T1.digInNames) ...
    && d1.NumSamples == T1.nSamples && abs(d1.Duration - T1.duration) < 1e-9, 'header metadata matches the truth');
check(d1.BehaviorFile == T1.behaviorFile && d1.ProbeFile == S.probeFile && d1.hasKilosortResults(), ...
    'the manifest associates the session and the probe; sorted output is found');
check(strcmp(errorId(@() makeSyntheticProject(proj)), 'makeSyntheticProject:Exists'), ...
    'writing into a non-empty folder is refused without Overwrite');
other = fullfile(root, 'other'); mkdir(other);
fid = fopen(fullfile(other, 'x.txt'), 'w'); fclose(fid);
check(strcmp(errorId(@() makeSyntheticProject(other, Overwrite=true)), 'makeSyntheticProject:NotSynthetic'), ...
    'Overwrite never deletes a folder this tool did not write');

fprintf('\n== 2. digital lines, the Epsych2 session, matching ==\n');
for k = 1:4
    T = D(k);
    d = P.dataset(T.name);
    E = d.digitalEvents(Cache=false);
    ok = isequal(sort(string(fieldnames(E.events))), sort(T.digInNames(:)));
    for ln = T.digInNames
        ok = ok && isequal(round(E.events.(ln) * Fs), round(T.events.(ln) * Fs));
    end
    check(ok && E.nSamples == T.nSamples, sprintf('%s: all six lines read back exactly (%d InTrial intervals)', ...
        T.scenario, size(E.events.InTrial, 1)));
end
[trials, info, meta] = readEpsychSession(T1.behaviorFile);
check(height(trials) == N && meta.subject == "SYNTH-01" && meta.hasTrialTable && meta.responseCodeField == "RespCode" ...
    && isfield(info, 'Protocol') && isequal(trials.TrialIndex, (1:N).') && all(ismember(trials.RespCode, [1313 1154 2376 2180])), ...
    'the Epsych2 session reads back with the lab''s fields and response codes');
F = findEpsychSessions(proj);
check(height(F) == 4 && all(F.NTrials == N), 'findEpsychSessions sees one session per recording and nothing else');
if T1.fileTimesSet
    m = matchEpsychSession(F, d1, MaxStartOffsetMin=10);
    check(m.file == T1.behaviorFile && m.method == "time", 'the session matches its recording by start time');
else
    fprintf('  (time-match check skipped: file times could not be stamped)\n');
end

fprintf('\n== 3. pairing per scenario ==\n');
Pc = d1.pairTrials(Warn=false);
check(~Pc.countMismatch && Pc.nPaired == N && Pc.nIntervals == N && all(Pc.flag == "ok"), ...
    'clean: every trial pairs with a whole interval');
check(isequal(round(Pc.onset * Fs), round(T1.trials.Onset * Fs)) && isequal(round(Pc.offset * Fs), round(T1.trials.Offset * Fs)), ...
    'clean: onsets and offsets equal the written trial rows');
for k = 2:4
    T = D(k);
    d = P.dataset(T.name);
    P0 = d.pairTrials(Warn=false);
    c = T.expectedCuts;
    P1 = d.pairTrials(Cuts=c, Warn=false);
    nWhole = N - sum(c.trials);
    check(P0.countMismatch && P0.nIntervals == T.nIntervals && ~P1.countMismatch && P1.nPaired == nWhole ...
        && all(P1.flag(P1.flag ~= "cut") == "ok") && isequal(P1.cutTrials, c.trials) && isequal(P1.cutIntervals, c.intervals), ...
        sprintf('%s: %d trials vs %d intervals; cutting %s trials / %s intervals leaves %d whole pairs', ...
        T.scenario, N, T.nIntervals, mat2str(c.trials), mat2str(c.intervals), nWhole));
end
P2 = P.dataset(D(2).name).pairTrials(Warn=false);
check(isequal(P2.partialIntervals, 1) && P2.flag(1) == "partial" && isequal(P2.unpairedTrials(:).', [N-1 N]), ...
    'late-start: interval 1 is partial (begins at sample 1), the last two trials are unpaired');
P3 = P.dataset(D(3).name).pairTrials(Warn=false);
check(isequal(P3.partialIntervals, N - 2) && P3.flag(N - 2) == "partial" && isequal(P3.unpairedTrials(:).', [N-1 N]), ...
    'early-stop: the last interval is partial (ends at the last sample)');

fprintf('\n== 4. amplifier data, accelerometer, ground-truth units, artifacts ==\n');
data = d1.readData(IncludeAux=true);
[~, ib] = max([T1.units.amplitudeUV]);
u = T1.units(ib);
check(size(data.aux, 2) == 3 && data.auxFs == Fs / 4 && size(data.aux, 1) == T1.nSamples / 4 ...
    && all(data.aux(:) > 1.2 & data.aux(:) < 2.3) && isequal(string(data.auxNames), T1.aux.names), ...
    'three accelerometer inputs at Fs/4, in volts');
% Spike-triggered average at the peak channel: the LFP and noise average out
% and the template trough (about -0.88 x amplitude) remains. Spikes inside
% the artifacts are left out and the value 0.75 ms earlier is the baseline.
tS = (u.samples - 1) / Fs;
inArt = false(size(tS));
for k = 1:size(T1.artifacts, 1)
    inArt = inArt | (tS >= T1.artifacts(k, 1) - 0.01 & tS <= T1.artifacts(k, 2) + 0.01);
end
sel = u.samples(~inArt & u.samples > 20);
sta = mean(data.amplifier(sel, u.peakChannel)) - mean(data.amplifier(sel - 15, u.peakChannel));
check(sta < -0.6 * u.amplitudeUV, sprintf('spike-triggered average at the peak channel is the trough (%.0f uV for a %.0f uV unit)', sta, u.amplitudeUV));
U = d1.readSortedUnits();
check(numel(U.unitId) == numel(T1.units) && isequal(U.nSpikes(:), arrayfun(@(x) numel(x.samples), T1.units(:))) ...
    && isequal(U.channel(:), [T1.units.peakChannel].') && isequal(U.group(:), [T1.units.label].') && U.fs == Fs, ...
    'ground-truth units read back as sorted output (counts, peak channels, labels; noise cluster dropped)');
check(isequal(U.samples{ib}, int64(u.samples(:)) - 1), 'spike samples are the injected rows (0-based on disk)');
t0 = dateshift(T1.acqTime, 'start', 'second');
check(all(U.subject == S.subject) && all(U.recordingStart == t0) ...
    && all(endsWith(U.label, "_" + S.subject + "_" + string(t0, 'yyMMdd') + "T" + string(t0, 'HHmm'))) ...
    && isequal(U.class, replace(U.group, "good", "su")) && all(U.datasetKey == EphysProject.relativeKey(proj, T1.folder)), ...
    'units are labelled with the subject and recording start from the folder name, and their class');
check(all(isfinite([U.x; U.y; U.peakX; U.peakY])) && (isempty(d1.NativeNames) || isequal(U.channelName, d1.NativeNames(U.channel).')), ...
    'every unit has a site and template position and its channel name');
Un = d1.readSortedUnits(IncludeNoise=true);
check(numel(Un.unitId) == numel(T1.units) + 1 && any(Un.group == "noise"), 'the noise cluster is there when asked for');
acfg = d1.ArtifactConfig; acfg.Enabled = true; d1.ArtifactConfig = acfg;
iv = d1.artifactIntervals();
hit = arrayfun(@(k) any(iv(:, 1) <= T1.artifacts(k, 2) & iv(:, 2) >= T1.artifacts(k, 1)), 1:size(T1.artifacts, 1));
check(size(T1.artifacts, 1) == 2 && all(hit), 'the artifact detector finds both written artifacts');
acfg.Enabled = false; d1.ArtifactConfig = acfg;

fprintf('\n== 5. the other layouts hold the same data ==\n');
for fmt = ["one-file-per-signal" "binary"]
    f = fullfile(root, char(replace(fmt, "-", "_")), 'SYNTH-01_alt');
    makeSyntheticRecording(f, Format=fmt, Fs=Fs, NumChannels=nCh, NumTrials=N, FileSeconds=8, Seed=3, AcqTime=T1.acqTime);
    df = EphysDataset(f);
    Ef = df.digitalEvents(Cache=false);
    ok = df.RecordingFormat == fmt && df.NumSamples == T1.nSamples;
    for ln = T1.digInNames
        ok = ok && isequal(round(Ef.events.(ln) * Fs), round(T1.events.(ln) * Fs));
    end
    Xf = df.readData(IncludeAux=true);
    ok = ok && isequal(size(Xf.amplifier), size(data.amplifier)) && max(abs(Xf.amplifier(:) - data.amplifier(:))) < 1e-6;
    if fmt == "one-file-per-signal"
        ok = ok && Xf.auxFs == Fs && isequal(Xf.aux(1:4:end, :), data.aux);
    end
    check(ok, fmt + ": same events and identical amplifier (and aux) data as the traditional layout, same seed");
end

fprintf('\n== 6. the generated config through EphysPipeline ==\n');
hasSP = license('test', 'Signal_Toolbox') > 0;
cfg = EphysPipelineConfig.load(S.configFile);
cfg.Project.Selection = "list";
cfg.Project.Datasets = EphysProject.relativeKey(proj, T1.folder);
cfg.Signals.Enabled = hasSP;
cfg.Export.Enabled = hasSP;
cfg.Spikes.Filter = hasSP;
pipe = EphysPipeline(cfg, Project=P, Refresh=false);
pipe.LogFcn = [];
R = pipe.run();
check(any(R.Step == "probe" & R.Status == "ok"), 'probe preflight: the generated probe fits');
check(any(R.Step == "behavior" & R.Status == "associated") && any(R.Step == "behavior:pairing" & R.Status == "needs review") ...
    && any(R.Step == "behavior:file" & R.Status == "done"), 'behavior step: session kept, pairing recorded as needing review, file written');
B = load(pipe.outputPathFor("behavior", d1));
check(B.behavior.pairing.nPaired == N && B.behavior.pairing.status == "unreviewed" ...
    && isequal(B.behavior.trials.TrialOnsetSample, round(T1.trials.Onset * Fs)), 'the behavior file carries the pairing columns');
check(any(R.Step == "artifacts" & R.Status == "done") && any(R.Step == "spikes" & R.Status == "done"), 'artifacts and spikes steps done');
M = load(pipe.outputPathFor("spikes", d1));
check(numel(M.units.unitId) == numel(T1.units) && numel(M.detected.ts) == nCh && ~isempty(M.detected.ts{u.peakChannel}), ...
    'spikes file: the sorted units and threshold detections');
if hasSP
    outS = pipe.outputPathFor("signals", d1);
    check(all(R.Status(R.Step == "signals") == "done") && all(isfile(outS)) && any(contains(outS, "_AUX")), ...
        'signals written per type, AUX included');
    check(all(R.Status(startsWith(R.Step, "export")) == "done") && isfile(pipe.outputPathFor("export:chronux", d1)) ...
        && isfile(pipe.outputPathFor("export:fieldtrip", d1)), 'Chronux and FieldTrip exports written');
else
    fprintf('  (signals / export checks skipped: Signal Processing Toolbox not available)\n');
end

fprintf('\n== 7. the app: File > Create synthetic test project ==\n');
g = EphysPreprocessingApp.PrefGroup;
savedPrefs = [];
if ispref(g); savedPrefs = getpref(g); end
prefCleanup = onCleanup(@() restorePrefs(g, savedPrefs));
if ispref(g, 'LastConfigFile'); setpref(g, 'LastConfigFile', ''); end
app = EphysPreprocessingApp;
appCleanup = onCleanup(@() closeApp(app));
appRoot = fullfile(root, 'app_project');
Sa = app.createSyntheticProject(appRoot, Preset="small", ...
    Generator=struct('Fs', Fs, 'NumChannels', nCh, 'NumTrials', 5, 'FileSeconds', 8, 'Scenarios', ["clean" "late-start"]));
check(~isempty(Sa) && numel(Sa.datasets) == 2 && app.Config.File == Sa.configFile && ~isempty(app.Project) ...
    && app.Project.NumDatasets == 2 && strcmp(app.RootPathField.Value, char(appRoot)), ...
    'the menu action writes the project, opens its config and scans it');
check(app.Config.Behavior.TrialLine == "InTrial" && app.Config.Behavior.PairTrials && app.Config.Spikes.Source == "both" ...
    && app.Config.Probe.DefaultProbeFile == Sa.probeFile, 'the generated config reaches the controls');
names = [app.Project.Datasets.Name];
row1 = find(names == Sa.datasets(1).name, 1);
row2 = find(names == Sa.datasets(2).name, 1);
check(app.SelectedDatasetIdx == 1 && numel(app.DatasetMenuItems) == 2 && app.DatasetMenuItems(1).Checked ...
    && all(arrayfun(@(dd) isequal(dd.Value, 1) && isequal(dd.ItemsData, {1, 2}), app.DatasetPickers)), ...
    'the scan fills the Dataset menu and every tab''s Dataset box and makes the first dataset active');
app.selectDataset(row1);
app.onTrialsLoad("recorded");
check(~isempty(app.TrialsPairing) && app.TrialsPairing.nPaired == 5 && ~app.TrialsPairing.countMismatch, ...
    'Trials tab: the clean dataset pairs completely');
app.onSpikesPreview();
check(size(app.SpkPreviewTable.Data, 1) > 0 && startsWith(app.SpkPreviewLabel.Text, names(row1)), ...
    'Spikes preview runs on the active dataset');
app.selectTab(app.TabVisualize);
app.VizChannelsField.Value = sprintf('1:%d', nCh);   % the display options come from the user's preferences
app.VizFileDropDown.Value = '(all)';
app.onPlotVisualization();
check(app.VizDatasetIndex == row1 && strcmp(app.VizArtButton.Enable, 'on'), 'Visualize plots the active dataset');

dd = app.SpkDatasetDropDown;   % choose in one tab's Dataset box
dd.Value = row2;
dd.ValueChangedFcn(dd, []);
T = app.DatasetsTable.Data;
S = app.DatasetsTable.StyleConfigurations;
check(app.SelectedDatasetIdx == row2 && app.DatasetMenuItems(row2).Checked && ~app.DatasetMenuItems(row1).Checked ...
    && all(arrayfun(@(p) isequal(p.Value, row2), app.DatasetPickers)) ...
    && height(S) == 1 && isequal(S.TargetIndex{1}, find(T.DatasetIdx == row2)) ...
    && contains(app.SortResultsLabel.Text, names(row2)) && contains(app.ArtManualLabel.Text, names(row2)), ...
    'a tab''s Dataset box makes the dataset active in the menu, every other box, the table highlight and the per-dataset labels');
check(isempty(app.TrialsPairing) && contains(app.TrialsSummaryLabel.Text, names(row2)) && isempty(app.SpkPreviewTable.Data) ...
    && contains(app.ArtSummaryLabel.Text, names(row2)), ...
    'the previous dataset''s pairing and previews are cleared');
check(strcmp(app.VizArtButton.Enable, 'off') && contains(app.VizStatusLabel.Text, names(row1)) && contains(app.VizStatusLabel.Text, names(row2)), ...
    'Visualize flags that the plot shows the previous dataset and turns artifact marking off');
app.onDatasetCellSelection(struct('Indices', [find(T.DatasetIdx == row1) 2]));
check(app.SelectedDatasetIdx == row1 && app.TrialsDatasetDropDown.Value == row1 && app.DatasetMenuItems(row1).Checked ...
    && strcmp(app.VizArtButton.Enable, 'on') && ~contains(app.VizStatusLabel.Text, "Press Plot"), ...
    'clicking a Project-table row makes its dataset active everywhere; the plot matches again');
check(string(app.DatasetTickedItems.Text) == "(no datasets ticked)" && numel(app.DatasetMenuItems) == 2 ...
    && app.DatasetMenu.Children(1) == app.DatasetAllMenu, ...
    'with no rows ticked the Dataset menu lists no datasets; All datasets holds both');
T = app.DatasetsTable.Data;
T.Select = T.DatasetIdx == row2;   % tick one row in the table
app.DatasetsTable.Data = T;
app.DatasetsTable.CellEditCallback(app.DatasetsTable, []);
item = app.DatasetTickedItems;
check(numel(item) == 1 && isequal(item.UserData, row2) && ~item.Checked && app.DatasetMenu.Children(1) == app.DatasetAllMenu ...
    && numel(app.DatasetMenuItems) == 2 && isequal(app.Config.Project.Datasets, app.Project.datasetKey(row2)), ...
    'a tick lists only that dataset at the top of the Dataset menu, above All datasets');
check(all(arrayfun(@(dd) isequal(dd.ItemsData, {row1, row2}) && isequal(dd.Value, row1), app.DatasetPickers)), ...
    'every tab''s Dataset box lists the ticked dataset plus the unticked active one');
item.MenuSelectedFcn(item, []);
check(all(arrayfun(@(dd) isequal(dd.ItemsData, {row2}) && isequal(dd.Value, row2), app.DatasetPickers)), ...
    'once a ticked dataset is active, every tab''s Dataset box lists only the ticked datasets');
app.selectTab(app.TabReview);
check(app.SelectedDatasetIdx == row2 && item.Checked && app.DatasetMenuItems(row2).Checked && ~app.DatasetMenuItems(row1).Checked ...
    && app.ReviewDatasetDropDown.Value == row2 && app.ReviewDatasetIdx == row2 ...
    && ~isempty(app.ReviewData) && startsWith(string(app.ReviewFolderField.Value), string(app.Project.Datasets(row2).Folder)), ...
    'a ticked dataset in the Dataset menu makes it active, checked there and under All datasets; the Review tab loads its sorted output when opened');
app.onSelectDatasets("none");
item = app.DatasetMenuItems(row1);
item.MenuSelectedFcn(item, []);
check(app.SelectedDatasetIdx == row1 && item.Checked && ~app.DatasetMenuItems(row2).Checked && string(app.DatasetTickedItems.Text) == "(no datasets ticked)", ...
    'All datasets makes an unticked dataset active; unticking empties the top of the menu');
check(all(arrayfun(@(dd) isequal(dd.ItemsData, {1, 2}), app.DatasetPickers)), ...
    'with no rows ticked every tab''s Dataset box lists every dataset');
app.selectDataset(row2);
app.selectDataset(row1);
check(app.ReviewDatasetIdx == row1 && startsWith(string(app.ReviewFolderField.Value), string(app.Project.Datasets(row1).Folder)), ...
    'with the Review tab open, a new active dataset loads at once');
app.selectTab(app.TabTrials);
app.selectDataset(row2);
app.onTrialsLoad("recorded");
check(app.TrialsPairing.countMismatch && contains(app.TrialsSummaryLabel.Text, "WARNING"), ...
    'Trials tab: the late-start dataset shows the count-mismatch warning');
c = Sa.datasets(2).expectedCuts;
app.TrialsCutSpinners(1, 1).Value = c.trials(1);
app.TrialsCutSpinners(2, 1).Value = c.intervals(1);
app.onTrialsCutsChanged();
check(~app.TrialsPairing.countMismatch && app.TrialsPairing.nPaired == 5 - sum(c.trials), 'the expected cuts resolve it in the app');
app.onTrialsApprove("approved");
check(app.TrialsPairing.status == "approved" && contains(app.DatasetsTable.Data.Behavior(row2), "approved"), ...
    'Approve records the cuts in the manifest and the table shows it');
Sb = app.createSyntheticProject(appRoot, Preset="small", Scan=false);
check(isempty(Sb) && app.Project.NumDatasets == 2, 'a non-empty folder is refused unless Overwrite is passed; the app keeps its project');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_SyntheticDataset:Failures', '%d checks failed.', nFail);
end
end


function rmdirQuiet(root)
if isfolder(root)
    try
        rmdir(root, 's');
    catch
    end
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


function restorePrefs(g, savedPrefs)
try
    if ispref(g); rmpref(g); end
    if isstruct(savedPrefs)
        for f = string(fieldnames(savedPrefs)).'
            setpref(g, char(f), savedPrefs.(f));
        end
    end
catch
end
end
