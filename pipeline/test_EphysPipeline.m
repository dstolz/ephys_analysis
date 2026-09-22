function test_EphysPipeline()
%test_EphysPipeline  Verification suite for the config-driven runner.
%   Builds a synthetic project (two recordings with the same leaf name, a
%   probe, a phy fixture associated with one recording, an Epsych2 session
%   file, a hand-made extract) and checks dataset selection by key, plan()
%   (writes nothing; flags existing / duplicate outputs, missing probe,
%   missing sorting output, missing extract), the sorting dry run, spike
%   detection against direct calls, the exports, the behavior association,
%   the artifact cache and cancellation. Steps needing the Signal Processing
%   Toolbox (toMat) are checked only when it is licensed.
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
f2 = fullfile(proj, 'mouse2', 'M1_260101_120000'); mkdir(f2);
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
cfgS = cfg; cfgS.Spikes.Source = "sorted"; cfgS.Project.Datasets = "mouse2/M1_260101_120000";
p2 = EphysPipeline(cfgS, Project=pipe.Project, Refresh=false);
T2 = p2.plan();
check(T2.Status(T2.Step == "spikes") == "no sorting output" && T2.Status(T2.Step == "probe") == "no probe" ...
    && T2.Status(T2.Step == "sorting") == "no probe", 'missing sorting output and probe are flagged');
cfgD = cfg; cfgD.Project.Selection = "all";
pD = EphysPipeline(cfgD, Project=pipe.Project, Refresh=false);
TD = pD.plan(Steps="signals");
check(all(TD.Status == "duplicate output"), 'two datasets with the same name under one OutputRoot collide');
check(strcmp(errorId(@() pD.run(Steps="signals")), 'EphysPipeline:PlanInvalid'), 'run refuses a plan with duplicate outputs');
% Both fixtures are subject M1 starting 2026-01-01 12:00, so their unit labels would collide.
cfgU = cfgD; cfgU.Spikes.Source = "sorted";
pU = EphysPipeline(cfgU, Project=pipe.Project, Refresh=false);
TU = pU.plan(Steps="spikes");
rowU = TU.Key == "mouse1/M1_260101_120000";
check(TU.Status(rowU) == "error: unit label collision" && contains(TU.Note(rowU), "mouse2/M1_260101_120000") ...
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
cfgP = cfg; cfgP.Probe.DefaultProbeFile = bigProbe; cfgP.Project.Datasets = "mouse2/M1_260101_120000";
pP = EphysPipeline(cfgP, Project=pipe.Project, Refresh=false);
TP = pP.plan(Steps="probe");
check(TP.Status(1) == "ready" && contains(TP.Note(1), "default"), 'default probe assignment is planned');
cfgV = cfg; cfgV.Sorting.PythonExe = "";
pV = EphysPipeline(cfgV, Project=pipe.Project, Refresh=false);
check(strcmp(errorId(@() pV.run()), 'EphysPipeline:ConfigInvalid'), 'run refuses an invalid config');

fprintf('\n== 3. probe + behavior preflights ==\n');
pP.checkProbes();
dP = pP.selected();
check(dP.ProbeFile == string(bigProbe) && pP.Results.Status(1) == "probe-channel mismatch", ...
    'default probe assigned; 8-site probe vs 4-channel recording is a mismatch');
dP.ProbeFile = "";
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
d1.ManualArtifacts = [0.001 0.002; 0.005 0.006];
pipe.reset();
pipe.runArtifacts();
check(contains(pipe.Results.Message(1), "computed"), 'changing the manual periods invalidates the cache');
cfgA = cfg; cfgA.Artifacts.Threshold = 2000;
pipe.Config = cfgA; pipe.reset(); pipe.runArtifacts();
check(contains(pipe.Results.Message(1), "computed"), 'changing the settings invalidates the cache');
pipe.Config = cfg;
d1.ManualArtifacts = [0.001 0.002];
d1.writeManifest();
cfgQ = cfg; cfgQ.Parallel.Enabled = true; cfgQ.Artifacts.CacheIntervals = false;
pipe.Config = cfgQ; pipe.reset(); logs = strings(0, 1);
pipe.runArtifacts();
ivQ = pipe.artifactIntervalsFor(d1);
check(contains(pipe.Results.Message(1), "computed") && isequal(ivQ, d1.artifactIntervals()) ...
    && any(contains(logs, "parallel")), 'Parallel.Enabled reaches artifactIntervals (one chunk: serial) and is logged');
check(any(contains(logs, "interval(s) computed, covering")), ...
    'the artifact log line reports how much of the recording the intervals cover');
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
pipe.reset();
pipe.runSorting();
R = pipe.Results;
if R.Status(1) ~= "dry run"; disp(R); end
check(R.Status(1) == "dry run" && endsWith(R.Output(1), "settings.json") && isfile(R.Output(1)) ...
    && contains(R.Message(1), "settings.json"), 'dry run writes settings.json (runKilosort)');
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
pipe.Config = cfg;
R = pipe.run(DryRun=true);
check(all(R.Status(R.Step == "spikes") == "dry run") && all(R.Status(startsWith(R.Step, "export")) == "dry run"), ...
    'run(DryRun=true) executes no writing step');
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
pipe.run(Steps=["probe" "artifacts" "spikes" "export"]);
names = [evts.step];
starts = evts([evts.index] == 0);
check(isequal([starts.step], ["probe" "artifacts" "spikes" "export"]) && all([starts.dataset] == "") ...
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
    ref = d1.toMat(File=fullfile(root, 'direct_extract.mat'), SignalOptions=EphysPipelineConfig.signalOptions(cfg.Signals));
    Mr = load(ref.file);
    check(R.Status(1) == "done" && isequal(Mx.Y, Mr.Y) && isequal(Mx.events, Mr.events) && ~isfield(Mx, 'behavior'), ...
        'runSignals equals a direct toMat call (no behavior variable)');
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
    oM = d1.exportChronux(File=fullfile(root, 'merged_chronux.mat'), Units=false, Overwrite=true);
    Cm = load(oM.file);
    check(isequal(sort(oM.signals), ["LFP" "MUA"]) && size(Cm.LFP.data, 1) == size(Ml.Y.LFP, 1) ...
        && size(Cm.MUA.data, 1) == size(Mm.Y.MUA, 1), ...
        'exporters find and merge the per-type files');
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
    d1.ExcludeChannels = [];
else
    fprintf('  (skipped: no Signal Processing Toolbox)\n');
end

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysPipeline:Failures', '%d checks failed.', nFail);
end
end
