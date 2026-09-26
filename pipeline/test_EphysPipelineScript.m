function test_EphysPipelineScript()
%test_EphysPipelineScript  Verification suite for the script generator.
%   Generates the compact and the standalone script for a config over a
%   synthetic project (spike detection + exports enabled, sorting as a dry
%   run), checks both with checkcode, runs each into its own output root and
%   requires the spikes / chronux / fieldtrip files and settings.json to
%   match between the two. Then runs both on copies of one synthetic
%   recording with its Epsych2 session (behavior step pairing and approving
%   the trials, epochs around the paired trials) and requires the same
%   pairing, behavior file and epochs. Also checks that disabled steps are
%   commented out in the compact script, that it stops on run()'s checks, that
%   the standalone script never uses the EphysPipeline runner, and that
%   literal(v) round-trips through eval.
%
%   Usage:  test_EphysPipelineScript

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

root = fullfile(tempdir, sprintf('PipeScript_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
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

fprintf('\n== 1. literal round trips ==\n');
vals = {"a", "q""uote", ["a" "b"], string.empty(1,0), 3, [1 2 3], Inf, -Inf, NaN, [], true, false, ...
    [-0.5 1.5], struct('x', 1, 'y', "s", 'z', [1 2]), struct('n', struct('m', Inf)), {1, "a"}};
ok = true;
for k = 1:numel(vals)
    v = vals{k};
    txt = EphysPipelineScript.literal(v);
    w = eval(char(txt));
    if ~isequaln(w, v) || ~strcmp(class(w), class(v))
        ok = false;
        fprintf(2, '    literal #%d: %s -> class %s\n', k, txt, class(w));
    end
end
check(ok, 'eval(literal(v)) reproduces every value and class');
L = EphysPipelineScript.structLiteral("s", struct('a', 1, 'b', struct('c', "x")));
check(numel(L) == 4 && L(1) == "s = struct();" && L(3) == "s.b = struct();" && L(4) == "s.b.c = ""x"";", ...
    'structLiteral emits nested assignments');

% ---- fixtures ---------------------------------------------------------------
rng(3);
Fs = 30000; numAmp = 4; spb = 128; nSamp = 4 * spb;
ampRaw = uint16(randi([0 65535], numAmp, nSamp));
digRaw = zeros(1, nSamp); digRaw(50:70) = 1;
proj = fullfile(root, 'proj');
f1 = fullfile(proj, 'A1_260101_120000'); mkdir(f1);
writeSyntheticRHD(fullfile(f1, 'A1_260101_120000.rhd'), ampRaw, digRaw, Fs, spb);
probeFile = fullfile(root, 'probe.json');
writeJsonFile(probeFile, struct('chanMap', 0:numAmp-1, 'xc', zeros(1, numAmp), 'yc', (0:numAmp-1) * 20, ...
    'kcoords', zeros(1, numAmp), 'n_chan', numAmp));
phyDir = fullfile(root, 'phy');
makePhyFixture(phyDir, Fs, ChannelMap=[0 1 2 3], SettingsJson=true);
d = EphysDataset(f1);
d.SortingDir = phyDir;
d.ProbeFile = probeFile;
d.writeManifest();

cfg = EphysPipelineConfig();
cfg.Name = "script test";
cfg.Description = "generated-script equivalence";
cfg.Project.Root = proj;
cfg.Sorting.Enabled = true; cfg.Sorting.PythonExe = "C:\envs\ks\python.exe"; cfg.Sorting.DryRun = true;
cfg.Sorting.Execution = "blocking"; cfg.Sorting.KS4.nblocks = 2; cfg.Sorting.KS4ExtraJSON = "{""x_centers"": 2}";
cfg.Spikes.Enabled = true; cfg.Spikes.Source = "both"; cfg.Spikes.Filter = false;
cfg.Spikes.ThresholdMethod = "absolute"; cfg.Spikes.Threshold = 2000;
cfg.Export.Enabled = true; cfg.Export.Formats = ["chronux" "fieldtrip"]; cfg.Export.IncludeDetected = true;
cfg.Artifacts.Enabled = false;
% signals off: an extract is written by hand into each output root instead
cfg.Signals.Enabled = false;

outA = fullfile(root, 'outA'); outB = fullfile(root, 'outB');
src = d.readData();
Sx.Y = struct('LFP', single(src.amplifier(1:256, :)), 'MUA', single([]), 'SPIKE', single([]));
Sx.events = src.events;
Sx.info = struct('LFP', struct('Fs', Fs), 'labels', d.ChannelNames, 'origFs', Fs); %#ok<STRNU>
for o = [string(outA) string(outB)]
    mkdir(fullfile(o, 'A1_260101_120000'));
    save(fullfile(o, 'A1_260101_120000', 'A1_260101_120000_extract_LFP.mat'), '-struct', 'Sx');   % Signals.SeparateFiles (default)
end

fprintf('\n== 2. generate ==\n');
cfgA = cfg; cfgA.Project.OutputRoot = outA;
cfgB = cfg; cfgB.Project.OutputRoot = outB;
cfgFile = fullfile(root, 'pipeline.json');
cfgA = cfgA.save(cfgFile);
compactFile = fullfile(root, 'scripts', 'run_compact.m');
standaloneFile = fullfile(root, 'scripts', 'run_standalone.m');
txtC = EphysPipelineScript.compact(cfgA, File=compactFile);
txtS = EphysPipelineScript.standalone(cfgB, File=standaloneFile);
check(isfile(compactFile) && isfile(standaloneFile), 'both scripts written');
check(contains(txtC, "EphysPipelineConfig.load(") && contains(txtC, "pipe.runSpikeDetection();   % spikes") ...
    && contains(txtC, "% pipe.runSignals();   % signals (disabled") && contains(txtC, "% pipe.checkBehavior();"), ...
    'compact script loads the config and comments out disabled steps');
check(contains(txtC, "planned = pipe.checkRun();") && ~contains(txtC, "disp(pipe.plan())") ...
    && strfind(txtC, "pipe.checkRun()") < strfind(txtC, "pipe.checkProbes()"), ...
    'compact script makes run()''s checks before the first step');
check(~contains(txtS, "EphysPipeline(") && ~contains(txtS, "EphysPipelineConfig.load(") && ~contains(txtS, "pipe."), ...
    'standalone script never uses the runner or a config file');
cfgBg = cfgB; cfgBg.Sorting.Execution = "background"; cfgBg.Sorting.DryRun = false; cfgBg.Sorting.MaxConcurrent = 2;
txtBg = EphysPipelineScript.standalone(cfgBg);
check(contains(txtBg, "maxConcurrent = 2;") && contains(txtBg, "launched = [];") ...
    && contains(txtBg, "res = d.runKilosort(ProbeFile=probe, ExtraSettings=ks4, ArtifactIntervals=iv, Launch=false);") ...
    && contains(txtBg, "waitForSortingSlot(launched, maxConcurrent);") && contains(txtBg, "res = d.launchSorting(res, Wait=false);") ...
    && contains(txtBg, "launched = [launched, res];") && ~contains(txtBg, "devices ="), ...
    'standalone script writes each run''s files, waits for a slot (Sorting.MaxConcurrent at a time), then starts it');
check(~contains(txtS, "waitForSortingSlot"), 'blocking / dry-run sorting in the standalone script has no slot wait');
cfgGpu = cfgBg; cfgGpu.Sorting.Devices = ["cuda:0" "cuda:1"];
gpuFile = fullfile(root, 'scripts', 'run_gpus.m');
txtGpu = EphysPipelineScript.standalone(cfgGpu, File=gpuFile);
check(contains(txtGpu, "devices = [""cuda:0"" ""cuda:1""];") ...
    && contains(txtGpu, "device = waitForSortingSlot(launched, maxConcurrent, Devices=devices);") ...
    && contains(txtGpu, "res = d.launchSorting(res, Wait=false, Device=device);"), ...
    'standalone script shares Sorting.Devices out among the background runs');
cfgGpuB = cfgGpu; cfgGpuB.Sorting.Execution = "blocking";
txtGpuB = EphysPipelineScript.standalone(cfgGpuB);
check(contains(txtGpuB, "Wait=true, Device=""cuda:0"");") && ~contains(txtGpuB, "waitForSortingSlot"), ...
    'blocking runs in the standalone script go on the first device');
check(contains(txtS, "NamePattern=""{SubjectID}_{Date:yyMMdd}_{Time:HHmmss}""") && contains(txtS, "P.unitIdentities(Among=idx)"), ...
    'standalone script builds the project with the name pattern that labels sorted units');
check(contains(txtS, ", Recursive=true, ReaderOptions=readerOptions);") ...
    && contains(txtS, "readerOptions.OpenEphys.Recordings = ""concatenate"";"), ...
    'standalone script scans the project as Project.Recursive and Acquisition say');
check(contains(txtS, "ks4.nblocks = 2;") && contains(txtS, "ks4.x_centers = 2;") && contains(txtS, "detectOptions.Threshold = 2000;") ...
    && contains(txtS, '"schema": "ephys-pipeline-config"'), 'standalone script carries the parameters and the config JSON as a comment');
check(contains(txtS, "if false   % set to true to run this step"), 'standalone disabled steps are wrapped in if false');
check(contains(txtS, "res = d.runKilosort(ProbeFile=probe, ExtraSettings=ks4, ArtifactIntervals=iv"), ...
    'standalone sorting runs Kilosort4 (runKilosort) with the probe in effect');
check(contains(txtS, "d.TrialConfig = trialConfig;") && contains(txtS, "trialConfig.TrialLine = ""InTrial"";") ...
    && contains(txtS, "if probe == """"; probe = defaultProbe; end") && ~contains(txtS, "d.ProbeFile = defaultProbe"), ...
    'standalone script pushes the trial config and uses the default probe without assigning it');
check(contains(txtS, "parallelOpts.UseParallel = false;") && contains(txtS, "parallelArgs{:}") ...
    && contains(txtS, "detectOptions.UseParallel = false;"), 'standalone script carries the Parallel section into the chunked steps');
check(contains(txtS, "S = load(extract(1));") && contains(txtS, "d.exportChronux('File', outFiles(j), 'Extract', S, args{:});") ...
    && contains(txtS, "units = d.readSortedUnits(Groups=[""good"" ""mua""]);") && contains(txtS, "o.Detected = detected;") ...
    && count(txtS, "load(extract(") == 1, ...
    'standalone export reads each dataset''s extract, units and detected spikes once for every format');
cfgES = cfgB; cfgES.Signals.MUA = true; cfgES.Export.Signals = "LFP";
txtES = EphysPipelineScript.standalone(cfgES);
check(contains(txtES, "extract = EphysDataset.recordedSignalFiles(EphysDataset.signalFiles(fullfile(d.outputFolder(), " + ...
    "d.Name + ""_extract"" + "".mat""), ""LFP""));"), 'standalone export reads the extract files of Export.Signals only');
check(contains(txtS, "if isfield(sigOpts, 'badChannels')") && contains(txtS, "sigOpts.probeFile = d.ProbeFile;") ...
    && contains(txtS, "if sigOpts.probeFile == """"; sigOpts.probeFile = defaultProbe; end"), ...
    'standalone signals place interpolated channels on the probe in effect (its own, else the default)');
cfgNo = cfgB; cfgNo.Signals.BlankArtifacts = false;
cfgMan = cfgB; cfgMan.Artifacts.ApplyToSignals = false;
check(contains(txtS, "sigOpts.artifactIntervals = artifactIntervals(d);") ...
    && contains(EphysPipelineScript.standalone(cfgMan), "sigOpts.artifactIntervals = d.artifactIntervals(IncludeAuto=false);") ...
    && ~contains(EphysPipelineScript.standalone(cfgNo), "sigOpts.artifactIntervals"), ...
    'standalone signals erase the artifact periods (the manual ones only without ApplyToSignals; none without BlankArtifacts)');
mC = checkcode(compactFile, '-id');
mS = checkcode(standaloneFile, '-id');
isErr = @(m) arrayfun(@(x) startsWith(x.id, 'SYNER') || contains(x.message, 'Parse error'), m);
check(isempty(mC) || ~any(isErr(mC)), 'compact script has no checkcode errors');
check(isempty(mS) || ~any(isErr(mS)), 'standalone script has no checkcode errors');
if ~isempty(mS) && any(isErr(mS)); disp(mS(isErr(mS))); end
mG = checkcode(gpuFile, '-id');
check(isempty(mG) || ~any(isErr(mG)), 'the standalone script with background runs on two GPUs has no checkcode errors');

fprintf('\n== 3. run both ==\n');
outC = runScript(compactFile);
check(contains(outC, "A1_260101_120000") && isfile(fullfile(outA, 'A1_260101_120000', 'A1_260101_120000_spikes.mat')), 'compact script ran and wrote the spikes file');
outS = runScript(standaloneFile);
check(isfile(fullfile(outB, 'A1_260101_120000', 'A1_260101_120000_spikes.mat')), 'standalone script ran and wrote the spikes file');
check(~contains(outS, "FAILED"), 'standalone script reported no failures');
if contains(outS, "FAILED"); disp(outS); end
for f = ["A1_260101_120000_spikes.mat" "A1_260101_120000_chronux.mat" "A1_260101_120000_fieldtrip.mat"]
    A = load(fullfile(outA, 'A1_260101_120000', f));
    B = load(fullfile(outB, 'A1_260101_120000', f));
    A = stripVolatile(A); B = stripVolatile(B);
    check(isequaln(A, B), "identical " + f + " from both scripts");
end
paths = {'filename', 'probe', 'results_dir'};   % under each script's own output root
stA = rmfield(readJsonFile(fullfile(outA, 'A1_260101_120000', 'kilosort4', 'dryrun', 'settings.json')), paths);
stB = rmfield(readJsonFile(fullfile(outB, 'A1_260101_120000', 'kilosort4', 'dryrun', 'settings.json')), paths);
check(isequaln(stA, stB) && stA.nblocks == 2 && stA.x_centers == 2, 'identical settings.json (dry run) from both scripts');
cfgBad = cfgA; cfgBad.Signals.Enabled = true; cfgBad.Signals.LFP_Fs = 60000;   % above the recording rate: a plan error
badFile = fullfile(root, 'scripts', 'run_bad.m');
cfgBad = cfgBad.save(fullfile(root, 'bad.json'));
EphysPipelineScript.compact(cfgBad, File=badFile);
delete(fullfile(outA, 'A1_260101_120000', 'A1_260101_120000_spikes.mat'));
errBad = '';
try
    runScript(badFile);
catch ME
    errBad = ME.identifier;
end
check(strcmp(errBad, 'EphysPipeline:PlanInvalid') && ~isfile(fullfile(outA, 'A1_260101_120000', 'A1_260101_120000_spikes.mat')), ...
    'a compact script whose plan has an error stops before any step');

fprintf('\n== 4. behavior pairing and behavior epochs: both scripts do what the runner does ==\n');
nm = "SYN-01_260102_100000";
synA = fullfile(root, 'projBA', nm);
synB = fullfile(root, 'projBB', nm);
makeSyntheticRecording(synA, Subject="SYN-01", Fs=5000, NumChannels=4, NumTrials=4, FileSeconds=10, ...
    SortedOutput=false, WriteManifest=false, Artifacts=false);
copyfile(synA, synB);                     % the same recording, with its Epsych2 session, twice
outBA = fullfile(root, 'outBA'); outBB = fullfile(root, 'outBB');
ds = EphysDataset(synA);
src = ds.readData();
Sx = struct('Y', struct('LFP', single(src.amplifier(1:5:end, :)), 'MUA', single([]), 'SPIKE', single([])), ...
    'events', src.events, 'info', struct('LFP', struct('Fs', 1000), 'labels', ds.ChannelNames, 'origFs', 5000));
for o = [string(outBA) string(outBB)]
    mkdir(fullfile(o, nm));
    save(fullfile(o, nm, nm + "_extract_LFP.mat"), '-struct', 'Sx');   % the Signals step's file
end
cfgBeh = EphysPipelineConfig();
cfgBeh.Name = "behavior parity";
cfgBeh.Behavior.Enabled = true; cfgBeh.Behavior.AutoApprove = true;   % PairTrials, WriteFile, TrialLine "InTrial": defaults
cfgBeh.Export.Enabled = true; cfgBeh.Export.Formats = "epochs"; cfgBeh.Export.EpochSource = "behavior";
cfgBeh.Export.IncludeUnits = false; cfgBeh.Export.EpochWindow = [-0.1 0.2];
cfgBehA = cfgBeh; cfgBehA.Project.Root = fileparts(synA); cfgBehA.Project.OutputRoot = outBA;
cfgBehB = cfgBeh; cfgBehB.Project.Root = fileparts(synB); cfgBehB.Project.OutputRoot = outBB;
cfgBehA = cfgBehA.save(fullfile(root, 'behavior.json'));
behCompact = fullfile(root, 'scripts', 'run_behavior_compact.m');
behStandalone = fullfile(root, 'scripts', 'run_behavior_standalone.m');
EphysPipelineScript.compact(cfgBehA, File=behCompact);
txtBeh = EphysPipelineScript.standalone(cfgBehB, File=behStandalone);
check(contains(txtBeh, "pairing = d.pairTrials(Warn=false);") && contains(txtBeh, "pairing = d.autoApproveTrialPairing(pairing);") ...
    && contains(txtBeh, "d.setTrialPairing(pairing, pairing.status, Auto=pairing.autoApproved)") ...
    && contains(txtBeh, "r = d.behaviorToMat(Overwrite=true, Pairing=pairing);"), ...
    'the standalone behavior step pairs, approves matching counts, records the pairing and writes it into the behavior file');
mB = checkcode(behStandalone, '-id');
check(isempty(mB) || ~any(isErr(mB)), 'the standalone script with the behavior step has no checkcode errors');
cfgBehNS = cfgBehB; cfgBehNS.Behavior.Search = false;
behNoSearch = fullfile(root, 'scripts', 'run_behavior_nosearch.m');
txtNS = EphysPipelineScript.standalone(cfgBehNS, File=behNoSearch);
mNS = checkcode(behNoSearch, '-id');
check(~contains(txtNS, "findEpsychSessions") && ~contains(txtNS, "matchEpsychSession") ...
    && contains(txtNS, "r = d.behaviorToMat(Overwrite=true, Pairing=pairing);") && (isempty(mNS) || ~any(isErr(mNS))), ...
    'Behavior.Search off: the standalone behavior step pairs and writes the associated sessions without a search');
runScript(behCompact);
outS = runScript(behStandalone);
check(~contains(outS, "FAILED"), 'the standalone behavior script reported no failures');
if contains(outS, "FAILED"); disp(outS); end
mfA = readJsonFile(fullfile(synA, nm + "_manifest.json"));
mfB = readJsonFile(fullfile(synB, nm + "_manifest.json"));
check(strcmp(mfA.behavior.pairing.status, 'approved') && mfA.behavior.pairing.auto_approved ...
    && strcmp(mfB.behavior.pairing.status, 'approved') && mfB.behavior.pairing.auto_approved, ...
    'both record the pairing as approved automatically (the counts match without cuts)');
BA = load(fullfile(outBA, nm, nm + "_behavior.mat"));
BB = load(fullfile(outBB, nm, nm + "_behavior.mat"));
check(isequaln(BA.behavior.trials, BB.behavior.trials) && isequaln(BA.behavior.pairing, BB.behavior.pairing) ...
    && ismember("TrialOnset", string(BB.behavior.trials.Properties.VariableNames)) && BB.behavior.pairing.status == "approved", ...
    'identical behavior files from both scripts, with the pairing columns');
EA = load(fullfile(outBA, nm, nm + "_epochs.mat"));
EB = load(fullfile(outBB, nm, nm + "_epochs.mat"));
check(EB.epochs.event.nEpochs == 4 && isequaln(EA.epochs.trials, EB.epochs.trials) ...
    && isequaln(EA.epochs.signals, EB.epochs.signals) && isequaln(EA.epochs.event, EB.epochs.event), ...
    'identical epochs around the paired trials from both scripts');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysPipelineScript:Failures', '%d checks failed.', nFail);
end
end


function out = runScript(file)
%runScript  Run a script in a plain (non-static) workspace and capture its output.
out = evalc('run(file)');
end


function S = stripVolatile(S)
%stripVolatile  Drop timestamps / paths that legitimately differ between runs.
for f = ["conversion" "export"]
    if isfield(S, f)
        S = rmfield(S, f);
    end
end
if isfield(S, 'units') && isstruct(S.units) && isfield(S.units, 'readAt')
    S.units = rmfield(S.units, 'readAt');
end
if isfield(S, 'detected') && isstruct(S.detected)
    S.detected.detection = rmfield(S.detected.detection, 'options');
end
for f = ["spike" "spikeDetected" "data_LFP"]
    if isfield(S, f) && isstruct(S.(f)) && isfield(S.(f), 'hdr') && isfield(S.(f).hdr, 'orig')
        S.(f).hdr = rmfield(S.(f).hdr, 'orig');
    end
end
end
