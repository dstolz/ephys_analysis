function test_EphysPipeline()
%test_EphysPipeline  Verification suite for the config-driven runner.
%   Builds a synthetic project (two recordings of one subject started in the
%   same minute, a probe, a phy fixture associated with one recording, an
%   Epsych2 session file, a hand-made extract) and checks dataset selection
%   by key, plan() (writes nothing; flags existing / duplicate outputs,
%   missing probe, missing sorting output, missing extract), the probe and
%   behavior preflights (the default probe, a session file that is not
%   there), the sorting dry run, spike detection against direct calls, the
%   exports, the artifact cache, run(DryRun=true) writing nothing and
%   cancellation. Then, on projects of their own: two recordings with the
%   same name under one output root, an unsorted dataset that cannot label
%   units, associations whose files are offline, an unreadable manifest,
%   Kilosort4 runs already queued or going, and the manifest's own parsing.
%   Steps needing the Signal Processing Toolbox (toMat) are checked only when
%   it is licensed.
%
%   Usage:  test_EphysPipeline

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

root = fullfile(tempdir, sprintf('Pipe_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>

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

% ---- fixtures ---------------------------------------------------------------
rng(7);
Fs = 30000; numAmp = 4; spb = 128; nSamp = 4 * spb;
ampRaw = uint16(randi([0 65535], numAmp, nSamp));
digRaw = zeros(1, nSamp); digRaw(50:70) = 1;
proj = fullfile(root, 'proj');
f1 = fullfile(proj, 'mouse1', 'M1_260101_120000'); mkdir(f1);
f2 = fullfile(proj, 'mouse2', 'M1_260101_120030'); mkdir(f2);   % same subject, same start minute
writeSyntheticRHD(fullfile(f1, 'mouseA_260101T120000_260101_120004.rhd'), ampRaw, digRaw, Fs, spb);
writeSyntheticRHD(fullfile(f2, 'other_rec.rhd'), ampRaw, digRaw, Fs, spb);
probeFile = fullfile(root, 'probe.json');
writeJsonFile(probeFile, struct('chanMap', 0:numAmp-1, 'xc', zeros(1, numAmp), 'yc', (0:numAmp-1) * 20, ...
    'kcoords', zeros(1, numAmp), 'n_chan', numAmp));
bigProbe = fullfile(root, 'probe8.json');
writeJsonFile(bigProbe, struct('chanMap', 0:7, 'xc', zeros(1, 8), 'yc', (0:7) * 20, 'kcoords', zeros(1, 8), 'n_chan', 8));
phyDir = fullfile(root, 'phy_manual');
makePhyFixture(phyDir, Fs, ChannelMap=[0 1 2 3], SettingsJson=true);
ds1 = EphysDataset(f1);
ds1.SortingDir = phyDir;
ds1.ProbeFile = probeFile;
ds1.ManualArtifacts = [0.001 0.002];
ds1.writeManifest();
behDir = fullfile(root, 'beh'); mkdir(behDir);
Data = struct('ToneLevel', {60, 70}, 'RespCode', {uint32(1), uint32(2)}, 'TrialIndex', {1, 2}, ...
    'TrialID', {1, 2}, 'computerTimestamp', {datetime(2026,1,1,12,0,5), datetime(2026,1,1,12,0,9)}, 'isTest', {false, false});
Info = struct('Subject', struct('Name', "mouseA"), 'StartTime', datetime(2026,1,1,12,0,0), 'FormatVersion', 2); %#ok<NASGU>
save(fullfile(behDir, 'mouseA_260101T120000.mat'), 'Data', 'Info');
outRoot = fullfile(root, 'out');

cfg = EphysPipelineConfig();
cfg.Name = "unit test";
cfg.Project.Root = proj;
cfg.Project.OutputRoot = outRoot;
cfg.Project.Selection = "list";
cfg.Project.Datasets = "mouse1/M1_260101_120000";

fprintf('\n== 1. construction, selection, applyConfigToDatasets ==\n');
logs = strings(0, 1);
pipe = EphysPipeline(cfg);
pipe.LogFcn = @(m) evalin('base', '1;');       % replaced below
pipe.LogFcn = @(m) appendLog(m);
    function appendLog(m); logs(end+1, 1) = string(m); end
check(pipe.Project.NumDatasets == 2 && isequal(pipe.DatasetIdx, pipe.Project.findByKey("mouse1/M1_260101_120000")), ...
    'selection by root-relative key');
d1 = pipe.selected();
check(numel(d1) == 1 && d1.ProbeFile == string(probeFile) && d1.SortingDir == string(phyDir) ...
    && isequal(d1.ManualArtifacts, [0.001 0.002]), 'manifest state restored by the project refresh');
check(startsWith(d1.OutputDir, outRoot) && isequal(fieldnames(d1.ArtifactConfig), fieldnames(EphysDataset.defaultArtifactConfig())), ...
    'output dir under OutputRoot; artifact config pushed');
i2 = pipe.Project.findByKey("mouse2/M1_260101_120030");
check(isnan(pipe.Project.Datasets(i2).Fs) && ~isfile(pipe.Project.Datasets(i2).manifestFile()) && ~isnan(d1.Fs), ...
    'constructing the pipeline refreshes the selected datasets only');
cfg0 = cfg; cfg0.Project.OutputRoot = "";
pipe.Config = cfg0;
check(d1.OutputDir == "" && d1.outputFolder() == d1.Folder, 'clearing Project.OutputRoot puts the outputs next to the recording again');
pipe.Config = cfg;
cfgAll = cfg; cfgAll.Project.Selection = "all";
pAll = EphysPipeline(cfgAll, Project=pipe.Project, Refresh=false);
check(isequal(pAll.DatasetIdx, [1 2]), 'Selection="all" selects every dataset');
cfgBad = cfg; cfgBad.Project.Datasets = ["mouse1/M1_260101_120000" "nope/x"];
ws = warning('off', 'EphysPipeline:UnknownDataset');
pBad = EphysPipeline(cfgBad, Project=pipe.Project, Refresh=false);
warning(ws);
check(isequal(pBad.DatasetIdx, pipe.DatasetIdx), 'unknown keys are dropped with a warning');
check(strcmp(errorId(@() EphysPipeline(EphysPipelineConfig())), 'EphysPipeline:NoRoot'), 'no root -> clear error');

fprintf('\n== 2. plan ==\n');
cfg.Signals.Enabled = true; cfg.Spikes.Enabled = true; cfg.Export.Enabled = true; cfg.Export.Formats = ["chronux" "fieldtrip"];
cfg.Sorting.Enabled = true; cfg.Sorting.PythonExe = "C:\envs\ks\python.exe"; cfg.Sorting.Execution = "blocking";
pipe.Config = cfg;
T = pipe.plan();
check(isempty(dir(fullfile(outRoot, '**', '*.mat'))) && ~isfolder(fullfile(outRoot, 'M1_260101_120000')), 'plan writes nothing');
check(all(ismember(["probe" "sorting" "signals" "spikes" "export:chronux" "export:fieldtrip"], T.Step)), 'one row per enabled step (export per format)');
check(T.Status(T.Step == "probe") == "ok" && T.Status(T.Step == "sorting") == "exists: will re-sort", 'probe ok; existing sorting output noted');
check(T.Status(T.Step == "signals") == "ready" && T.Status(T.Step == "spikes") == "ready", 'signals / spikes ready');
check(all(T.Status(startsWith(T.Step, "export")) == "ready"), 'export ready when Signals will produce the extract');
cfgE = cfg; cfgE.Signals.Enabled = false;
pipe.Config = cfgE;
T = pipe.plan();
check(all(T.Status(startsWith(T.Step, "export")) == "no extract file"), 'export without an extract is flagged');
pipe.Config = cfg;
cfgS = cfg; cfgS.Spikes.Source = "sorted"; cfgS.Project.Datasets = "mouse2/M1_260101_120030";
p2 = EphysPipeline(cfgS, Project=pipe.Project, Refresh=false);
T2 = p2.plan();
check(T2.Status(T2.Step == "spikes") == "no sorting output" && T2.Status(T2.Step == "probe") == "no probe" ...
    && T2.Status(T2.Step == "sorting") == "no probe", 'missing sorting output and probe are flagged');
cfgD = cfg; cfgD.Project.Selection = "all";
pD = EphysPipeline(cfgD, Project=pipe.Project, Refresh=false);
TD = pD.plan(Steps="signals");
check(height(TD) == 2 && all(TD.Status == "ready"), 'recordings with different names share no output under one OutputRoot');
% Both fixtures are subject M1 starting 2026-01-01 12:00, so their unit labels would collide.
cfgU = cfgD; cfgU.Spikes.Source = "sorted";
pU = EphysPipeline(cfgU, Project=pipe.Project, Refresh=false);
TU = pU.plan(Steps="spikes");
rowU = TU.Key == "mouse1/M1_260101_120000";
check(TU.Status(rowU) == "error: unit label collision" && contains(TU.Note(rowU), "mouse2/M1_260101_120030") ...
    && TU.Status(~rowU) == "no sorting output", ...
    'a sorted dataset sharing subject + start minute with another selected dataset cannot label its units');
check(strcmp(errorId(@() pU.run(Steps="spikes")), 'EphysPipeline:PlanInvalid'), 'run refuses unit label collisions');
cfgI = cfg; cfgI.Spikes.Source = "sorted"; cfgI.Project.NamePattern = "X-{SubjectID}_{Date:yyMMdd}_{Time:HHmmss}";
pI = EphysPipeline(cfgI, Project=pipe.Project, Refresh=false);
check(all([pI.Project.Datasets.NamePattern] == cfgI.Project.NamePattern), 'the config''s NamePattern is pushed onto the datasets');
TI = pI.plan(Steps=["signals" "spikes" "export"]);
check(TI.Status(TI.Step == "spikes") == "error: unit identity" && all(TI.Status(startsWith(TI.Step, "export")) == "error: unit identity") ...
    && contains(TI.Note(TI.Step == "spikes"), "does not match") && TI.Status(TI.Step == "signals") == "ready", ...
    'a name that does not match NamePattern stops only the steps that read sorted units');
cfgI.Spikes.Source = "detect"; cfgI.Export.IncludeUnits = false;
pI.Config = cfgI;
TI = pI.plan(Steps=["signals" "spikes" "export"]);
check(~any(startsWith(TI.Status, "error")), 'steps that do not read sorted units ignore the name');
pipe.Config = cfg;
cfgN = cfg; cfgN.Signals.LFP_Fs = 60000;
pN = EphysPipeline(cfgN, Project=pipe.Project, Refresh=false);
TN = pN.plan(Steps="signals");
check(startsWith(TN.Status(1), "error: LFP_Fs"), 'a rate above the recording rate is flagged per dataset');
cfgP = cfg; cfgP.Probe.DefaultProbeFile = bigProbe; cfgP.Project.Datasets = "mouse2/M1_260101_120030";
pP = EphysPipeline(cfgP, Project=pipe.Project);   % refreshes mouse2: its channel count
TP = pP.plan(Steps="probe");
check(TP.Status(1) == "probe-channel mismatch" && contains(TP.Note(1), "default probe") && TP.Output(1) == string(bigProbe), ...
    'plan checks the default probe for a dataset without one');
cfgV = cfg; cfgV.Sorting.PythonExe = "";
pV = EphysPipeline(cfgV, Project=pipe.Project, Refresh=false);
check(strcmp(errorId(@() pV.run()), 'EphysPipeline:ConfigInvalid'), 'run refuses an invalid config');

fprintf('\n== 3. probe + behavior preflights ==\n');
pP.checkProbes();
dP = pP.selected();
mP = readJsonFile(dP.manifestFile());
check(dP.ProbeFile == "" && pP.Results.Output(1) == string(bigProbe) && pP.Results.Status(1) == "probe-channel mismatch" ...
    && string(mP.probe.file) == "", ...
    'the default probe is used, neither assigned nor saved; 8-site probe vs 4-channel recording is a mismatch');
cfgP2 = cfgP; cfgP2.Probe.DefaultProbeFile = probeFile;
pP.Config = cfgP2;
check(pP.probeFor(dP) == string(probeFile), 'an edited default probe applies at once');
cfgW = cfgP; cfgW.Probe.WriteDefaultToManifest = true;
pP.Config = cfgW; pP.reset();
pP.checkProbes(DryRun=true);
mP = readJsonFile(dP.manifestFile());
check(dP.ProbeFile == "" && string(mP.probe.file) == "" && contains(pP.Results.Message(1), "dry run"), ...
    'WriteDefaultToManifest in a dry run: the default is not saved');
pP.reset();
pP.checkProbes();
mP = readJsonFile(dP.manifestFile());
check(dP.ProbeFile == string(bigProbe) && string(mP.probe.file) == string(bigProbe) && mP.probe.exists, ...
    'WriteDefaultToManifest assigns the default probe and saves it');
dP.ProbeFile = "";
dP.writeManifest();
cfg.Behavior.Enabled = true; cfg.Behavior.SearchDirs = behDir;
pipe.Config = cfg;
pipe.reset();
pipe.checkBehavior();
check(pipe.Results.Status(1) == "matched (prefix)" && d1.BehaviorFile == string(fullfile(behDir, 'mouseA_260101T120000.mat')), ...
    'behavior matched by file-name prefix');
m = readJsonFile(d1.manifestFile());
check(strcmp(m.behavior.subject, 'mouseA') && m.behavior.n_trials == 2, 'association written to the manifest');
behOut = pipe.outputPathFor("behavior", d1);
Bh = load(behOut);
check(any(pipe.Results.Step == "behavior:file" & pipe.Results.Output == behOut) && Bh.behavior.nTrials == 2, ...
    'behavior step writes <Name>_behavior.mat (Behavior.WriteFile)');
pipe.reset();
pipe.checkBehavior();
check(pipe.Results.Status(1) == "associated", 'existing association kept unless Overwrite');
% The session file offline (a disk or share not connected): the association stays.
behFile = d1.BehaviorFile;
movefile(behFile, behFile + ".offline");
pipe.reset();
pipe.checkBehavior();
Tb = pipe.plan(Steps="behavior");
rep = pipe.Project.refresh(Datasets=pipe.DatasetIdx);
m = readJsonFile(d1.manifestFile());
check(pipe.Results.Status(1) == "behavior file missing" && height(pipe.Results) == 1 && Tb.Status(1) == "behavior file missing" ...
    && d1.BehaviorFile == behFile && rep.Manifest && string(m.behavior.file) == behFile && ~m.behavior.exists, ...
    'a session file that is not there keeps its association (step, plan, refresh and manifest)');
movefile(behFile + ".offline", behFile);
% A dry run matches, but associates, pairs and writes nothing.
d1.BehaviorFile = "";
delete(behOut);
pipe.reset();
pipe.checkBehavior(DryRun=true);
R = pipe.Results;
m = readJsonFile(d1.manifestFile());
check(R.Status(R.Step == "behavior") == "dry run" && R.Output(R.Step == "behavior") == behFile && d1.BehaviorFile == "" ...
    && nnz(startsWith(R.Step, "behavior:")) == 2 && all(R.Status(startsWith(R.Step, "behavior:")) == "dry run") ...
    && ~isfile(behOut) && string(m.behavior.file) == behFile, ...
    'checkBehavior(DryRun=true) says what it would associate, pair and write, and changes nothing');
d1.BehaviorFile = behFile;
pipe.reset();
pipe.checkBehavior();

fprintf('\n== 4. artifacts cache ==\n');
cfg.Artifacts.Enabled = true; cfg.Artifacts.Method = "microvolts"; cfg.Artifacts.Threshold = 3000; cfg.Artifacts.MinChannels = 1;
pipe.Config = cfg;
pipe.reset(); logs = strings(0, 1);
pipe.runArtifacts();
cacheFile = pipe.outputPathFor("artifacts", d1);
check(isfile(cacheFile) && contains(pipe.Results.Message(1), "computed"), 'intervals computed and cached');
pipe.reset(); logs = strings(0, 1);
pipe.runArtifacts();
check(contains(pipe.Results.Message(1), "cache"), 'second run reuses the cache');
cached = readJsonFile(cacheFile);
d1.ManualArtifacts = [0.001 0.002; 0.005 0.006];
pipe.reset();
pipe.runArtifacts();
ivM = pipe.artifactIntervalsFor(d1);
check(contains(pipe.Results.Message(1), "cache") && isequal(readJsonFile(cacheFile), cached) ...
    && isequal(ivM, d1.artifactIntervals()), ...
    'a new manual period needs no new detection: the cached detection is merged with the manual periods');
check(string(cached.schema) == "ephys-artifacts/3" && isequal(EphysDataset.mergeIntervals([d1.ManualArtifacts; ...
    reshape(cached.intervals, [], 2)]), ivM), 'the cache holds the automatic detection alone');
cfgA = cfg; cfgA.Artifacts.Threshold = 2000;
pipe.Config = cfgA; pipe.reset(); pipe.runArtifacts();
check(contains(pipe.Results.Message(1), "computed"), 'changing the settings invalidates the cache');
pipe.Config = cfg;
d1.ExcludeChannels = 3;
pipe.reset(); pipe.runArtifacts();
check(contains(pipe.Results.Message(1), "computed"), 'changing the excluded channels invalidates the cache');
d1.ExcludeChannels = [];
d1.ManualArtifacts = [0.001 0.002];
d1.writeManifest();
cfgQ = cfg; cfgQ.Parallel.Enabled = true; cfgQ.Artifacts.CacheIntervals = false;
pipe.Config = cfgQ; pipe.reset(); logs = strings(0, 1);
pipe.runArtifacts();
ivQ = pipe.artifactIntervalsFor(d1);
check(contains(pipe.Results.Message(1), "computed") && isequal(ivQ, d1.artifactIntervals()) ...
    && any(contains(logs, "parallel")), 'Parallel.Enabled reaches artifactIntervals (one chunk: serial) and is logged');
check(any(contains(logs, "interval(s) computed") & contains(logs, "covering")), ...
    'the artifact log line reports how much of the recording the intervals cover');
check(any(contains(logs, "detected earlier in this run")), ...
    'without the cache file a detection is still made once per run (reused by the next step)');
manual0 = d1.ManualArtifacts;
d1.ManualArtifacts = [0 d1.NumSamples / d1.Fs];
logs = strings(0, 1);
pipe.artifactIntervalsFor(d1);
check(any(contains(logs, "(100%)") & contains(logs, "WARNING")), ...
    'silencing over half the recording is flagged in the log');
d1.ManualArtifacts = manual0;
pipe.Config = cfg;

fprintf('\n== 5. sorting dry run ==\n');
cfg.Sorting.DryRun = true;
pipe.Config = cfg;
pipe.reset(); logs = strings(0, 1);
pipe.runSorting();
R = pipe.Results;
if R.Status(1) ~= "dry run"; disp(R); end
check(R.Status(1) == "dry run" && endsWith(R.Output(1), "settings.json") && isfile(R.Output(1)) ...
    && contains(R.Message(1), "settings.json"), 'dry run writes settings.json (runKilosort)');
check(~any(contains(logs, "[artifacts]")) && ~isfile(d1.BinFile), 'a sorting dry run detects no artifacts and writes no .bin');
st = readJsonFile(R.Output(1));
ks = EphysPipelineConfig.ks4Settings(cfg.Sorting);
check(all(isfield(st, fieldnames(ks))), 'settings.json carries the config''s Kilosort4 settings');
cfg.Sorting.DryRun = false; cfg.Sorting.Enabled = false;

fprintf('\n== 6. spikes step ==\n');
cfg.Spikes.Filter = false; cfg.Spikes.ThresholdMethod = "absolute"; cfg.Spikes.Threshold = 2000;
cfg.Spikes.Source = "both";
pipe.Config = cfg;
pipe.reset();
pipe.runSpikeDetection();
R = pipe.Results;
check(R.Status(1) == "done" && isfile(R.Output(1)) && endsWith(R.Output(1), "M1_260101_120000_spikes.mat"), 'spikes file written under OutputRoot/<Name>');
M = load(R.Output(1));
iv = pipe.artifactIntervalsFor(d1);
[tsRef, ~, ~] = d1.detectSpikes(Filter=false, ThresholdMethod="absolute", Threshold=2000);
tsRef = cellfun(@(t) t(~any(t >= iv(:, 1).' & t <= iv(:, 2).', 2)), tsRef, 'UniformOutput', false);
check(isequal(M.detected.ts, tsRef), 'detected times equal detectSpikes with the artifact periods removed');
uRef = d1.readSortedUnits(Groups=["good" "mua"]);
check(isequal(M.units.unitId, uRef.unitId) && isequal(M.units.times, uRef.times), 'units equal readSortedUnits');
check(M.units.label(1) == "su000_M1_260101T1200" && M.units.datasetKey(1) == "mouse1/M1_260101_120000" ...
    && M.units.subject(1) == "M1", 'saved units carry the label and the project-relative dataset key');
check(~isfield(M, 'behavior'), 'no behavior variable in the spikes file');
pipe.reset();
pipe.runSpikeDetection();
check(pipe.Results.Status(1) == "skipped" && contains(pipe.Results.Message(1), "exists"), 'existing output is skipped without Overwrite');
cfgX = cfg; cfgX.Spikes.Channels = "list"; cfgX.Spikes.ChannelList = "2"; cfgX.Spikes.Overwrite = true; cfgX.Spikes.Source = "detect";
pipe.Config = cfgX; pipe.reset(); pipe.runSpikeDetection();
M2 = load(pipe.Results.Output(1));
check(isequal(M2.detected.channels, 2) && isempty(M2.units), 'channel list + Source="detect"');
cfgP = cfg; cfgP.Parallel.Enabled = true; cfgP.Spikes.Overwrite = true;
pipe.Config = cfgP; pipe.reset(); logs = strings(0, 1); pipe.runSpikeDetection();
M3 = load(pipe.Results.Output(1));
check(pipe.Results.Status(1) == "done" && M3.detected.detection.options.UseParallel && isequal(M3.detected.ts, tsRef) ...
    && any(contains(logs, "parallel")), 'Parallel.Enabled reaches spikesToMat (one chunk: serial) with the same result');
pipe.Config = cfg;

fprintf('\n== 7. export step (hand-made extract) ==\n');
extract = pipe.outputPathFor("signals", d1);
src = d1.readData();
Sx.Y = struct('LFP', single(src.amplifier(1:256, :)), 'MUA', single([]), 'SPIKE', single([]));
Sx.events = src.events;
Sx.info = struct('LFP', struct('Fs', Fs), 'labels', d1.ChannelNames, 'origFs', Fs); %#ok<STRNU>
save(extract, '-struct', 'Sx');
cfg.Export.IncludeDetected = true;
cfgY = cfg; cfgY.Spikes.Overwrite = true;                 % restore the full-channel spikes file
pipe.Config = cfgY; pipe.reset(); pipe.runSpikeDetection();
pipe.Config = cfg;
pipe.reset();
pipe.runExport();
R = pipe.Results;
check(height(R) == 2 && all(R.Status == "done") && isfile(R.Output(1)) && isfile(R.Output(2)), 'both export files written');
C = load(R.Output(R.Step == "export:chronux"));
F = load(R.Output(R.Step == "export:fieldtrip"));
check(isequal(size(C.LFP.data), [256 numAmp]) && numel(C.sp) == 2 && numel(C.spDetected) == numAmp && ~isfield(C, 'behavior'), ...
    'chronux export carries signals, units and detected spikes (behavior is separate)');
check(isequal(size(F.data_LFP.trial{1}), [numAmp 256]) && isequal(F.spike.timestamp{1}, [300 600 30000]) ...
    && numel(F.spikeDetected.label) == numAmp, 'fieldtrip export carries signals, units and detected spikes');
oC = d1.exportChronux(File=fullfile(root, 'direct_chronux.mat'), Extract=extract, Detected=pipe.outputPathFor("spikes", d1));
Cd = load(oC.file);
check(isequal(Cd.LFP.data, C.LFP.data) && isequal(Cd.sp, C.sp) && isequal(Cd.spDetected, C.spDetected), ...
    'pipeline export equals a direct exportChronux call');
pipe.reset(); pipe.runExport();
check(all(pipe.Results.Status == "skipped"), 'existing exports are skipped');
cfgF = cfg; cfgF.Signals.MUA = true; cfgF.Signals.Enabled = false;   % an MUA file that was never written
pipe.Config = cfgF;
TF = pipe.plan(Steps="export");
cfgF.Export.Signals = "LFP";
pipe.Config = cfgF;
TF2 = pipe.plan(Steps="export");
check(all(TF.Status == "no extract file") && ~any(TF2.Status == "no extract file") ...
    && isequal(pipe.exportExtractFiles(d1), extract), ...
    'with Export.Signals (separate files) an export needs only the extract files of those signals');
pipe.Config = cfg;

cfgP = cfg; cfgP.Export.Formats = "epochs"; cfgP.Export.EpochWindow = [-0.001 0.002];
pipe.Config = cfgP; pipe.reset(); pipe.runExport();
Rp = pipe.Results;
check(height(Rp) == 1 && Rp.Step(1) == "export:epochs" && Rp.Status(1) == "done" ...
    && endsWith(Rp.Output(1), "_epochs.mat"), 'the epochs format writes <Name>_epochs.mat');
P = load(Rp.Output(1));
check(isfield(P, 'epochs') && P.epochs.event.nEpochs == 1 && istable(P.epochs.trials) ...
    && isequal(size(P.epochs.signals.LFP.data), [91 1 numAmp]) ...
    && isequal(P.epochs.signals.LFP.data(:, 1, 1), double(Sx.Y.LFP(20:110, 1))) ...
    && numel(P.epochs.units) == 2 && numel(P.epochs.detected) == numAmp, ...
    'the epoch file holds the samples around the dig-in onset, with the units and detected spikes');
pipe.Config = cfg;

fprintf('\n== 8. run(), dry run and cancel ==\n');
cfg.Sorting.Enabled = false; cfg.Signals.Enabled = false; cfg.Export.Overwrite = true; cfg.Spikes.Overwrite = true;
cfg.Behavior.PairTrials = true; cfg.Behavior.Overwrite = true;
pipe.Config = cfg;
before = fileState([string(d1.Folder) string(d1.outputFolder())]);
R = pipe.run(DryRun=true);
check(all(R.Status(R.Step == "spikes") == "dry run") && all(R.Status(startsWith(R.Step, "export")) == "dry run"), ...
    'run(DryRun=true) executes no writing step');
check(all(R.Status(ismember(R.Step, ["behavior" "behavior:pairing" "behavior:file" "artifacts"])) == "dry run") ...
    && isequal(fileState([string(d1.Folder) string(d1.outputFolder())]), before), ...
    'the behavior and artifacts steps of a dry run write nothing either (no manifest, cache or behavior file)');
cfg.Behavior.Overwrite = false;
pipe.Config = cfg;
R = pipe.run(Steps=["spikes" "export"]);
check(isequal(unique(R.Step, 'stable'), ["spikes"; "export:chronux"; "export:fieldtrip"]) && all(R.Status == "done"), ...
    'run(Steps=...) runs the given steps in canonical order');
check(strcmp(errorId(@() pipe.run(Steps="nope")), 'EphysPipeline:BadStep'), 'unknown step name errors');
evts = struct('step', {}, 'dataset', {}, 'index', {}, 'count', {}, 'done', {}, 'total', {}, 'message', {});
    function recordEvent(evt)
        evts(end+1) = evt;
    end
cfgE = cfg; cfgE.Artifacts.CacheIntervals = false;   % so Spikes has to detect the artifacts itself
pipe.Config = cfgE;
pipe.ProgressFcn = @recordEvent;
pipe.run(Steps=["probe" "spikes" "export"]);
names = [evts.step];
starts = evts([evts.index] == 0);
check(isequal([starts.step], ["probe" "spikes" "export"]) && all([starts.dataset] == "") ...
    && all([starts.message] == "starting"), 'run() announces each step as it starts (dataset "", index 0)');
[~, pos] = ismember(names, EphysPipelineConfig.StepNames);
check(all(pos > 0) && issorted(pos) && any(names == "spikes" & startsWith([evts.message], "artifact intervals, detecting")) ...
    && any(names == "export" & [evts.message] == "fieldtrip: done"), ...
    'every event names its own step: the detection Spikes needs reports as spikes, both formats as export');
frac = arrayfun(@(e) (max(e.index, 1) - 1 + e.done / e.total) / e.count, evts);
grows = true;
for s = reshape(unique(names), 1, [])
    grows = grows && all(diff(frac(names == s)) >= 0);
end
check(grows && frac(find(names == "export", 1, 'last')) == 1, 'each step''s fraction only grows, reaching 1 as export ends');
evts = evts([]); logs = strings(0, 1);
pipe.run(Steps=["artifacts" "spikes"]);
names = [evts.step];
check(any(names == "artifacts" & startsWith([evts.message], "detecting")) ...
    && ~any(names == "spikes" & startsWith([evts.message], "artifact intervals, detecting")) ...
    && any(contains(logs, "detected earlier in this run")), ...
    'with CacheIntervals off, Spikes reuses the detection the artifacts step made in the same run');
pipe.ProgressFcn = @(evt) cancelOnProbe(evt, pipe);
    function cancelOnProbe(evt, p)
        if evt.step == "probe" && evt.index > 0; p.cancel(); end
    end
R = pipe.run(Steps=["probe" "artifacts"]);
check(all(R.Status(R.Step == "probe") ~= "cancelled") && isequal(R.Status(R.Step == "artifacts"), "cancelled"), ...
    'a cancel between steps is recorded by the next step, which does not announce itself');
pipe.ProgressFcn = [];
pipe.Config = cfg;
delete(pipe.outputPathFor("spikes", d1));
pipe.ProgressFcn = @(evt) cancelOnDetect(evt, pipe);
    function cancelOnDetect(evt, p)
        if evt.step == "spikes" && evt.done > 0 && ~p.CancelRequested
            p.cancel();
        end
    end
R = pipe.run(Steps="spikes");
check(any(R.Status == "cancelled") && ~isfile(pipe.outputPathFor("spikes", d1)) ...
    && isempty(dir(fullfile(outRoot, 'M1_260101_120000', '~*.partial.mat'))), 'cancel stops the run and leaves no partial file');
check(any(contains(logs, "cancelled")), 'the log records the cancellation');
pipe.ProgressFcn = [];

fprintf('\n== 9. signals step (needs the Signal Processing Toolbox) ==\n');
if license('test', 'Signal_Toolbox')
    cfg.Signals.Enabled = true; cfg.Signals.Overwrite = true; cfg.Signals.LFP_Fs = 1000;
    pipe.Config = cfg;
    pipe.reset();
    pipe.runSignals();
    R = pipe.Results;
    Mx = load(R.Output(1));
    % Signals.BlankArtifacts (default): the manual period and the detection, as Sorting takes them
    ivS = pipe.artifactIntervalsForStep(d1, cfg.Artifacts.ApplyToSignals, @(varargin) []);
    so = EphysPipelineConfig.signalOptions(cfg.Signals);
    so.artifactIntervals = ivS;
    ref = d1.toMat(File=fullfile(root, 'direct_extract.mat'), SignalOptions=so);
    Mr = load(ref.file);
    check(R.Status(1) == "done" && isequal(Mx.Y, Mr.Y) && isequal(Mx.events, Mr.events) && ~isfield(Mx, 'behavior'), ...
        'runSignals equals a direct toMat call with the dataset''s artifact periods (no behavior variable)');
    check(size(ivS, 1) > 1 && any(ivS(:, 1) <= 0.001 & ivS(:, 2) >= 0.002) && isequal(Mx.info.artifacts.intervals, ivS) ...
        && Mx.info.artifacts.nSamples > 0, ...
        'the manual period (merged with any detection it touches) and the automatic detection are erased and recorded in info.artifacts');
    check(contains(R.Message(1), sprintf("%d artifact period(s) erased", size(ivS, 1))), ...
        'the result row says how many periods were erased');
    cfgNo = cfg; cfgNo.Signals.BlankArtifacts = false;
    pipe.Config = cfgNo; pipe.reset(); pipe.runSignals();
    Mn = load(pipe.Results.Output(1));
    Mp = load(d1.toMat(File=fullfile(root, 'plain_extract.mat'), SignalOptions=EphysPipelineConfig.signalOptions(cfg.Signals)).file);
    check(isequal(Mn.Y, Mp.Y) && isempty(Mn.info.artifacts.intervals) && ~isequal(Mn.Y.LFP, Mx.Y.LFP), ...
        'Signals.BlankArtifacts off: the recording as it is, no periods recorded');
    cfgMan = cfg; cfgMan.Artifacts.ApplyToSignals = false;
    pipe.Config = cfgMan; pipe.reset(); pipe.runSignals();
    Mman = load(pipe.Results.Output(1));
    check(isequal(Mman.info.artifacts.intervals, d1.ManualArtifacts), ...
        'Artifacts.ApplyToSignals off: the manual periods only');
    check(Mx.info.reference.mode == "none", 'Artifacts.Reference "none": the signals are not referenced');
    cfgRef = cfg; cfgRef.Artifacts.Reference = "car";
    refState = {d1.ReferenceExclude, d1.ReferenceExcludeSource};
    d1.ReferenceExclude = []; d1.ReferenceExcludeSource = "manual";
    logs = strings(0, 1);
    ws = warning('off', 'EphysDataset:prepareReference:FewChannels');
    pipe.Config = cfgRef; pipe.reset(); pipe.runSignals();
    Mref0 = load(pipe.Results.Output(1));
    check(pipe.Results.Status(1) == "done" && Mref0.info.reference.mode == "none" && Mref0.info.LFP.reference == "none", ...
        'Artifacts.Reference "car" with Signals.LFP_Reference off (the default): the LFP is taken as recorded');
    cfgRef.Signals.LFP_Reference = true;
    logs = strings(0, 1);
    pipe.Config = cfgRef; pipe.reset(); pipe.runSignals();
    warning(ws);
    Mref = load(pipe.Results.Output(1));
    check(pipe.Results.Status(1) == "done" && Mref.info.reference.mode == "car" && Mref.info.LFP.reference == "car" ...
        && isequal(Mref.info.reference.channels, 1:numAmp) ...
        && any(contains(logs, "common CAR reference over 4 channel(s), subtracted from LFP")), ...
        'Signals.LFP_Reference on: the Signals step references the LFP too, and logs it');
    [d1.ReferenceExclude, d1.ReferenceExcludeSource] = refState{:};
    pipe.Config = cfg;
    cfgM = cfg; cfgM.Signals.MUA = true;
    pipe.Config = cfgM; pipe.reset(); pipe.runSignals();
    R = pipe.Results;
    files = pipe.outputPathFor("signals", d1);
    check(height(R) == 2 && all(R.Status == "done") && isequal(R.Output.', files) ...
        && endsWith(files(1), "M1_260101_120000_extract_LFP.mat") && endsWith(files(2), "M1_260101_120000_extract_MUA.mat"), ...
        'SeparateFiles writes one file (and one result row) per signal type');
    Ml = load(files(1)); Mm = load(files(2));
    check(~isempty(Ml.Y.LFP) && isempty(Ml.Y.MUA) && ~isfield(Ml.info, 'MUA') ...
        && ~isempty(Mm.Y.MUA) && isempty(Mm.Y.LFP) && ~isfield(Mm.info, 'LFP') && isfield(Mm, 'events'), ...
        'each per-type file holds only its signal, plus events');
    check(isequal(Ml.info.artifacts.intervals, ivS) && isequal(Mm.info.artifacts.intervals, ivS), ...
        'every per-type file records the artifact periods (LFP and MUA alike)');
    oM = d1.exportChronux(File=fullfile(root, 'merged_chronux.mat'), Units=false, Overwrite=true);
    Cm = load(oM.file);
    check(isequal(sort(oM.signals), ["LFP" "MUA"]) && size(Cm.LFP.data, 1) == size(Ml.Y.LFP, 1) ...
        && size(Cm.MUA.data, 1) == size(Mm.Y.MUA, 1), ...
        'exporters find and merge the per-type files');
    oF = d1.exportFieldTrip(File=fullfile(root, 'merged_fieldtrip.mat'), Units=false, Validate=false, Overwrite=true);
    Fm = load(oF.file);
    check(isequal(Cm.artifacts.intervals, ivS) ...
        && isequal(Fm.data_LFP.cfg.artfctdef.preprocessing.artifact, EphysDataset.intervalRows(ivS, 1000, size(Ml.Y.LFP, 1))) ...
        && isequal(Fm.data_MUA.cfg.artfctdef.preprocessing.artifact, EphysDataset.intervalRows(ivS, Mm.info.MUA.Fs, size(Mm.Y.MUA, 1))), ...
        'the Chronux file carries the periods, the FieldTrip file each signal''s rows of them');
    cfgO = cfgM; cfgO.Signals.SeparateFiles = false;
    pipe.Config = cfgO; pipe.reset(); pipe.runSignals();
    Mo = load(pipe.Results.Output(1));
    check(height(pipe.Results) == 1 && isequal(Mo.Y.LFP, Ml.Y.LFP) && isequal(Mo.Y.MUA, Mm.Y.MUA), ...
        'SeparateFiles=false writes one combined file with the same data');
    pipe.Config = cfg;
    cfgQ = cfg; cfgQ.Signals.ExcludeHandling = "drop";
    d1.ExcludeChannels = 2;
    pipe.Config = cfgQ; pipe.reset(); pipe.runSignals();
    Mq = load(pipe.Results.Output(1));
    check(size(Mq.Y.LFP, 2) == numAmp - 1, 'ExcludeHandling="drop" removes manifest exclusions');
    cfgI = cfg; cfgI.Signals.ExcludeHandling = "interpolate"; cfgI.Probe.DefaultProbeFile = probeFile;
    own = d1.ProbeFile;
    d1.ProbeFile = "";
    pipe.Config = cfgI; pipe.reset(); pipe.runSignals();
    Mi = load(pipe.Results.Output(1));
    d1.ProbeFile = own;
    check(pipe.Results.Status(1) == "done" && isequal(Mi.info.badChannels.channels, 2) ...
        && isequal(Mi.info.badChannels.method, "geometry"), ...
        'an interpolated exclusion of a dataset without a probe is placed on the default probe');
    d1.ExcludeChannels = [];
else
    fprintf('  (skipped: no Signal Processing Toolbox)\n');
end

fprintf('\n== 10. Kilosort4 runs already queued or going; a cancel after the hand-off ==\n');
cfgK = cfg; cfgK.Sorting.Enabled = true; cfgK.Sorting.Execution = "background"; cfgK.Sorting.DryRun = false;
cfgK.Artifacts.ApplyToSorting = false;   % the manual periods only: no detection needed
pipe.Config = cfgK;
pipe.reset();
handed = struct('d', {}, 'res', {});
pipe.QueueFcn = @queueAndCancel;
    function queueAndCancel(d, res)
        handed(end+1) = struct('d', d, 'res', res);
        pipe.cancel();   % right after the hand-off: the run is queued and stays so
    end
ws = warning('off', 'EphysDataset:toBin:Clipping');   % full-range random samples
id = errorId(@() pipe.runSorting());
warning(ws);
R = pipe.Results;
check(strcmp(id, 'EphysPipeline:Cancelled') && height(R) == 1 && R.Status(1) == "queued" && isscalar(handed), ...
    'a cancel after the run was handed to the queue keeps its "queued" row (no "cancelled before launch")');
res = handed(1).res;
binTime = dir(d1.BinFile).datenum;
pipe.QueueFcn = [];
pipe.PriorRuns = EphysPipeline.sortRun(d1.Name, res, Queued=true);
writelines('{"state": "done"}', res.statusFile);   % a stale status of an earlier run: the run is still queued
Tk = pipe.plan(Steps="sorting");
pipe.reset();
pipe.runSorting();
R = pipe.Results;
check(R.Status(1) == "skipped" && contains(R.Message(1), "already queued") && Tk.Status(1) == "skip: Kilosort4 queued" ...
    && dir(d1.BinFile).datenum == binTime && pipe.PriorRuns.queued && isnat(pipe.PriorRuns.started), ...
    'a dataset with a queued Kilosort4 run is skipped (plan and step) and its .bin left alone');
delete(res.statusFile);
pipe.PriorRuns = EphysPipeline.sortRun(d1.Name, res);   % started, no status yet: running
pipe.reset();
pipe.runSorting();
check(pipe.Results.Status(1) == "skipped" && contains(pipe.Results.Message(1), "already running") ...
    && dir(d1.BinFile).datenum == binTime, 'a dataset whose Kilosort4 run is still going is skipped');
writelines('{"state": "done"}', res.statusFile);
Tk = pipe.plan(Steps="sorting");
check(~startsWith(Tk.Status(1), "skip:"), 'a finished run no longer holds the dataset back');
pipe.PriorRuns = EphysPipeline.emptyRuns();
pipe.Config = cfg;

fprintf('\n== 10a. Kilosort4 sorts the recording with the artifact periods erased ==\n');
cfgB = cfgK;
cfgB.Artifacts.Threshold = 6300; cfgB.Artifacts.MergeGapMs = 0; cfgB.Artifacts.PadMs = 0;   % a few % of the full-range noise, not most of it
cfgB.Artifacts.ApplyToSorting = true;
pipe.QueueFcn = @(d, res) [];   % write each run's .bin and files, start none
[binDir, binName] = fileparts(d1.BinFile);
binMeta = fullfile(binDir, binName + ".json");   % toBin's sidecar: the periods it erased
blanked = @(iv) nnz(d1.manualArtifactMask(d1.NumSamples, 0, d1.Fs, iv));
ws = warning('off', 'EphysDataset:toBin:Clipping');
pipe.Config = cfgB; pipe.reset();
pipe.runSorting();
ivAll = pipe.artifactIntervalsFor(d1);
ivManual = d1.artifactIntervals(IncludeAuto=false);
meta = readJsonFile(binMeta);
erased = reshape(meta.manual_artifacts, [], 2);
check(pipe.Results.Status(1) == "queued" && size(ivAll, 1) > size(ivManual, 1) ...
    && isequal(size(erased), size(ivAll)) && max(abs(erased - ivAll), [], 'all') < 1e-9 ...
    && meta.n_manual_blanked == blanked(ivAll) && meta.n_manual_blanked > blanked(ivManual), ...
    'the Sorting step writes the .bin with the manual and the automatic artifact periods erased');
cfgB.Artifacts.ApplyToSorting = false;
pipe.Config = cfgB; pipe.reset();
pipe.runSorting();
meta = readJsonFile(binMeta);
erased = reshape(meta.manual_artifacts, [], 2);
check(pipe.Results.Status(1) == "queued" && isequal(size(erased), size(ivManual)) ...
    && max(abs(erased - ivManual), [], 'all') < 1e-9 && meta.n_manual_blanked == blanked(ivManual), ...
    'with ApplyToSorting off the .bin has the manual periods erased only');
warning(ws);
pipe.QueueFcn = [];
pipe.Config = cfg;

fprintf('\n== 11. two recordings with the same name under one output root ==\n');
projS = fullfile(root, 'projS');
g1 = fullfile(projS, 'm1', 'rec'); g2 = fullfile(projS, 'm2', 'rec'); gc = fullfile(projS, 'calibration');
for g = string({g1, g2, gc})
    mkdir(g);
    writeSyntheticRHD(fullfile(g, 'a.rhd'), ampRaw, digRaw, Fs, spb);
end
cfgR = EphysPipelineConfig();
cfgR.Project.Root = projS; cfgR.Project.OutputRoot = fullfile(root, 'outS');
cfgR.Project.Selection = "list"; cfgR.Project.Datasets = "m2/rec";
cfgR.Signals.Enabled = true;
pR = EphysPipeline(cfgR);
pR.LogFcn = [];
TR = pR.plan();
check(all(startsWith(TR.Status(TR.Step ~= "probe"), "error: output folder shared with m1/rec")) ...
    && strcmp(errorId(@() pR.run()), 'EphysPipeline:PlanInvalid'), ...
    'a dataset whose output folder another discovered dataset maps to is refused, also when that one is not selected');
cfgR.Project.Datasets = "m1/rec";
pR.Config = cfgR;
TR = pR.plan();
check(startsWith(TR.Status(TR.Step == "signals"), "error: output folder shared with m2/rec"), '... either way round');
cfgR.Project.OutputRoot = "";
pR.Config = cfgR;
TR = pR.plan();
check(~any(startsWith(TR.Status, ["error" "duplicate"])), 'without an output root each recording keeps its outputs in its own folder');
cfgR.Signals.OutputDir = fullfile(root, 'sharedSignals');
pR.Config = cfgR;
TR = pR.plan();
check(TR.Status(TR.Step == "signals") == "duplicate output" && contains(TR.Note(TR.Step == "signals"), "m2/rec"), ...
    'one file name in a shared Signals.OutputDir: a duplicate output, the other dataset unselected');
cfgR.Signals.OutputDir = "";
cfgR.Project.OutputRoot = fullfile(root, 'outS');
pR.Config = cfgR;
PR = pR.Project;
e1 = PR.Datasets(PR.findByKey("m1/rec"));
e2 = PR.Datasets(PR.findByKey("m2/rec"));
foreignFile = string(fullfile(e1.outputFolder(), 'rec_extract_LFP.mat'));
mkdir(e1.outputFolder());
X = struct('Y', struct('LFP', single(1)), 'info', struct('LFP', struct('Fs', 1000)), ...
    'conversion', struct('dataset', "rec", 'sourceFolder', e1.Folder));
save(foreignFile, '-struct', 'X');
o1 = e1.outputs(); o2 = e2.outputs();
Tc = planLocalCleanup(e2, Remove="signals");
check(o1.has("LFP") && ~o2.has("LFP") && any(o2.Foreign == foreignFile) ...
    && Tc.Action(Tc.File == foreignFile) == "keep", ...
    'm2/rec neither loads nor cleans up the extract whose provenance names m1/rec (the same output folder)');
% An unsorted dataset whose name cannot label units: its exports leave the units out, epochs too.
cfgR.Project.Datasets = "calibration";
cfgR.Export.Enabled = true; cfgR.Export.Formats = ["chronux" "epochs"]; cfgR.Export.IncludeUnits = true;
pR.Config = cfgR;
TR = pR.plan(Steps=["signals" "export"]);
isExport = startsWith(TR.Step, "export:");
check(nnz(isExport) == 2 && all(TR.Status(isExport) == "ready") && all(contains(TR.Note(isExport), "left out")), ...
    'no unit identity error for exports that leave the units out (the epochs row included)');

fprintf('\n== 12. associations offline, an unreadable manifest, manifest parsing ==\n');
projO = fullfile(root, 'projO');
h1 = fullfile(projO, 'M3_260103_090000'); mkdir(h1);
writeSyntheticRHD(fullfile(h1, 'a.rhd'), ampRaw, digRaw, Fs, spb);
usb = fullfile(root, 'usb');            % a disk that is not connected
curated = string(fullfile(usb, 'curated'));
offProbe = string(fullfile(usb, 'probe.json'));
offBeh = string(fullfile(usb, 'beh.mat'));
eo = EphysDataset(h1);
eo.SortingDir = curated; eo.ProbeFile = offProbe; eo.BehaviorFile = offBeh;
eo.writeManifest();
makePhyFixture(fullfile(h1, 'kilosort4'), Fs, ChannelMap=[0 1 2 3]);   % an uncurated sort next to the recording
cfgO = EphysPipelineConfig(); cfgO.Project.Root = projO;
cfgO.Spikes.Enabled = true; cfgO.Spikes.Source = "sorted";
cfgO.Sorting.Enabled = true; cfgO.Sorting.PythonExe = "C:\envs\ks\python.exe"; cfgO.Sorting.Execution = "blocking";
cfgO.Sorting.SkipExisting = true;
pO = EphysPipeline(cfgO);               % the scan applies the manifest and writes it again
pO.LogFcn = [];
eo = pO.selected();
mo = readJsonFile(eo.manifestFile());
check(eo.SortingDir == curated && eo.ProbeFile == offProbe && eo.BehaviorFile == offBeh ...
    && string(mo.sorting.source) == "manual" && string(mo.sorting.results_dir) == curated && ~mo.sorting.exists ...
    && string(mo.probe.file) == offProbe && ~mo.probe.exists && string(mo.behavior.file) == offBeh, ...
    'a scan while the associations are offline keeps them, in the dataset and in the rewritten manifest');
check(mo.kilosort.has_results && string(mo.kilosort.results_dir) == string(eo.kilosortDir()), ...
    'the manifest''s kilosort block describes the run in kilosortDir');
TO = pO.plan();
check(TO.Status(TO.Step == "spikes") == "error: sorting folder missing" && contains(TO.Note(TO.Step == "spikes"), curated) ...
    && TO.Status(TO.Step == "probe") == "probe file missing" && TO.Status(TO.Step == "sorting") == "probe file missing", ...
    'plan names the missing folder and probe instead of using the kilosort4 sort next to the recording');
oo = eo.outputs();
check(oo.SortingDir == curated && ~oo.has("sorting") && strcmp(errorId(@() oo.Units), 'DatasetOutputs:Missing'), ...
    'DatasetOutputs keeps the hand-picked folder too: no fallback to the uncurated sort');
pO.reset(); pO.runSpikeDetection();
check(pO.Results.Status(1) == "skipped" && contains(pO.Results.Message(1), curated), 'the spikes step skips it, naming the folder');
makePhyFixture(curated, Fs, ChannelMap=[0 1 2 3]);   % the disk is back
writeJsonFile(offProbe, struct('chanMap', 0:numAmp-1, 'xc', zeros(1, numAmp), 'yc', (0:numAmp-1) * 20, ...
    'kcoords', zeros(1, numAmp), 'n_chan', numAmp));
TO = pO.plan();
check(eo.hasKilosortResults() && TO.Status(TO.Step == "spikes") == "ready" ...
    && TO.Status(TO.Step == "sorting") == "exists: skip (SkipExisting)", 'with the disk back the association works again');
% Kilosort4 4.x writes its own cluster_group.tsv (a copy of cluster_KSLabel.tsv) on every run.
fid = fopen(fullfile(h1, 'kilosort4', 'cluster_group.tsv'), 'w');
fprintf(fid, 'cluster_id\tKSLabel\n0\tmua\n1\tgood\n2\tgood\n');
fclose(fid);
eo.SortingDir = "";
sAuto = eo.sortingStruct();
eo.SortingDir = curated;
sCur = eo.sortingStruct();
check(~sAuto.curated && sAuto.num_units == 3 && sCur.curated && EphysDataset.phyCurated(curated) ...
    && ~EphysDataset.phyCurated(fullfile(h1, 'kilosort4')), ...
    'curated means phy''s cluster_group.tsv (header "group"), not the copy Kilosort4 writes');
% A manifest this code cannot read is neither applied nor replaced.
mf = eo.manifestFile();
for bad = ["{""schema"": ""intan-dataset-manifest/9"", ""probe"": {""file"": ""x""}}", "{not json"]
    writelines(bad, mf);
    txt0 = fileread(mf);
    ws = warning();
    warning('off', 'EphysDataset:applyManifest:Schema');
    warning('off', 'EphysDataset:applyManifest:Unreadable');
    warning('off', 'EphysDataset:writeManifest:Kept');
    rep = pO.Project.refresh();
    wrote = eo.writeManifest();
    warning(ws);
    check(strcmp(fileread(mf), txt0) && ~rep.Manifest(1) && contains(rep.Message(1), "manifest not read") && ~wrote, ...
        "a manifest " + ternaryText(startsWith(bad, "{not"), "that is not JSON", "of an unknown schema") + ...
        " is left as it is by a scan and by a later write");
end
% Channel lists in a manifest are parsed, never evaluated.
marker = fullfile(tempdir, "manifestEvalProbe" + string(datetime('now', 'Format', 'yyyyMMddHHmmssSSS')));
writeJsonFile(mf, struct('schema', "intan-dataset-manifest/2", 'exclude_channels', "mkdir('" + marker + "')", ...
    'reference_exclude', struct('channels', "1:3 5-6", 'source', "manual")));
eo.applyManifest();
evaluated = isfolder(marker);
if evaluated; rmdir(marker); end
check(~evaluated && isempty(eo.ExcludeChannels) && isequal(eo.ReferenceExclude, [1 2 3 5 6]), ...
    'manifest channel lists are parsed, never evaluated');
check(isequal(EphysDataset.parseChannelList("[1:4 9]"), [1 2 3 4 9]) ...
    && isequal(EphysDataset.parseChannelList("1, 3, 5 - 8"), [1 3 5 6 7 8]) ...
    && isequal(EphysDataset.parseChannelList("1:2:9"), [1 3 5 7 9]) && isempty(EphysDataset.parseChannelList("1, x")) ...
    && isempty(EphysDataset.parseChannelList("")) && isequal(EphysDataset.formatChannelList([1 3 5 6 7 8]), "1,3,5-8"), ...
    'channel lists: numbers, a-b / a:b ranges, steps and brackets; anything else gives no channels');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysPipeline:Failures', '%d checks failed.', nFail);
end
end


function S = fileState(folders)
%fileState  Every file under FOLDERS with its size and modification time, sorted.
S = strings(0, 1);
for f = unique(folders)
    D = dir(fullfile(f, '**', '*'));
    for k = find(~[D.isdir])
        S(end+1, 1) = sprintf("%s|%d|%.10f", fullfile(D(k).folder, D(k).name), D(k).bytes, D(k).datenum); %#ok<AGROW>
    end
end
S = sort(S);
end


function t = ternaryText(cond, a, b)
if cond; t = string(a); else; t = string(b); end
end
