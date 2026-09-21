function test_SortingConcurrency()
%test_SortingConcurrency  Background Kilosort4 runs go Sorting.MaxConcurrent at a time.
%   Uses stand-in "python" executables: .cmd files that note their start
%   and end in a shared timeline file, sleep ~2 s and write ks4_status.json
%   (or exit without one), so the pipeline's slot handling is checked
%   without Kilosort4 or a GPU. Checks EphysDataset.sortRunState,
%   waitForSortingSlot, the pipeline with one and two slots (the
%   SpikeInterface and the native engine), a run that exits without a
%   status, runs started elsewhere (PriorRuns), a cancel while waiting and
%   blocking runs. Windows only (the stand-ins are batch files).
%
%   Usage:  test_SortingConcurrency

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

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

if ~ispc
    fprintf('  (skipped: the stand-in executables are Windows batch files)\n');
    return
end

root = fullfile(tempdir, sprintf('SortConc_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>

% ---- fixtures: three recordings, one probe --------------------------------------
rng(3);
Fs = 30000; numAmp = 4; spb = 128; nSamp = 4 * spb;
proj = fullfile(root, 'proj');
for s = 1:3
    f = fullfile(proj, sprintf('M%d_260101_120000', s));
    mkdir(f);
    writeSyntheticRHD(fullfile(f, sprintf('M%d_260101_120000.rhd', s)), ...
        uint16(randi([0 65535], numAmp, nSamp)), zeros(1, nSamp), Fs, spb);
end
probeFile = fullfile(root, 'probe.json');
writeJsonFile(probeFile, struct('chanMap', 0:numAmp-1, 'xc', zeros(1, numAmp), 'yc', (0:numAmp-1) * 20, ...
    'kcoords', zeros(1, numAmp), 'n_chan', numAmp));

fprintf('\n== 1. EphysDataset.sortRunState ==\n');
rd = fullfile(root, 'state'); mkdir(rd);
sf = fullfile(rd, 'ks4_status.json');
ex = fullfile(rd, char(EphysDataset.SortExitMarker));
check(EphysDataset.sortRunState(sf) == "running", 'no status and no exit marker: running');
writelines('{"state": "do', sf);
check(EphysDataset.sortRunState(sf) == "running", 'a status caught mid-write reads as running');
writelines('', ex);
[st, msg] = EphysDataset.sortRunState(sf);
check(st == "error" && contains(msg, "unreadable"), 'an unreadable status after the process exited is an error');
delete(sf);
[st, msg] = EphysDataset.sortRunState(sf);
check(st == "error" && contains(msg, "exited without writing"), 'exited without a status: error, saying so');
writelines('{"state": "error", "message": "CUDA out of memory"}', sf);
[st, msg] = EphysDataset.sortRunState(sf);
check(st == "error" && msg == "CUDA out of memory", 'the driver''s error state and message');
delete(ex);
writelines('{"state": "done", "num_units": 5}', sf);
check(EphysDataset.sortRunState(sf) == "done", 'the driver''s done state');

fprintf('\n== 2. waitForSortingSlot ==\n');
t0 = tic;
waitForSortingSlot(string(sf), 1);
waitForSortingSlot(strings(0, 1), 1);
check(toc(t0) < 1, 'returns at once when the runs have finished (or there are none)');
sf2 = string(fullfile(root, 'state2', 'ks4_status.json')); mkdir(fileparts(sf2));
ticks = 0;
    function tick(nRunning, nFinished)
        ticks = ticks + 1;
        check(nRunning == 1 && nFinished == 1, 'TickFcn gets the running / finished counts');
        writelines('{"state": "done"}', sf2);   % the run finishes while waiting
    end
waitForSortingSlot([string(sf); sf2], 2);
check(ticks == 0, 'one running of two slots: no wait');
waitForSortingSlot([string(sf); sf2], 1, Period=0.1, TickFcn=@tick);
check(ticks == 1, 'one running of one slot: waits until it finishes');

fprintf('\n== 3. one slot, SpikeInterface engine ==\n');
tl = fullfile(root, 'timeline3.txt');
fake = makeFake(root, 'fake3.cmd', tl, true);
S = runScenario(proj, probeFile, 1, "spikeinterface", fake, fullfile(root, 'out3'));
check(numel(S.launched) == 3 && all(S.results.Status == "launched"), 'all three datasets launched');
[maxRun, nEvents] = concurrency(tl);
check(nEvents == 6 && maxRun == 1, sprintf('never more than one at a time (max %d over %d events)', maxRun, nEvents));
check(S.nWaitMsgs > 0 && max(S.waitingSeen) == 2, 'progress while waiting: a slot message, with 2 datasets still to start');
check(S.pipe.SortingWaiting == 0, 'SortingWaiting is 0 once every dataset has started');
check(S.allExited, 'each run left its exit marker once its process ended');
check(all(arrayfun(@(r) EphysDataset.sortRunState(r.statusFile) == "done", S.launched)), 'every run reports done');

fprintf('\n== 4. two slots, native engine ==\n');
tl = fullfile(root, 'timeline4.txt');
fake = makeFake(root, 'fake4.cmd', tl, true);
S = runScenario(proj, probeFile, 2, "kilosort", fake, fullfile(root, 'out4'));
[maxRun, nEvents] = concurrency(tl);
check(numel(S.launched) == 3 && nEvents == 6 && maxRun == 2, sprintf('two at a time (max %d over %d events)', maxRun, nEvents));
check(all(arrayfun(@(r) isfile(fullfile(r.resultsDir, 'settings.json')), S.launched)), ...
    'the native engine wrote each run''s files before launching');

fprintf('\n== 5. a run that exits without a status frees its slot ==\n');
tl = fullfile(root, 'timeline5.txt');
fake = makeFake(root, 'fake5.cmd', tl, false);
S = runScenario(proj, probeFile, 1, "spikeinterface", fake, fullfile(root, 'out5'));
[maxRun, nEvents] = concurrency(tl);
check(~S.timedOut && numel(S.launched) == 3 && nEvents == 6 && maxRun == 1, 'all three ran, one at a time, without hanging');
[st, msg] = EphysDataset.sortRunState(S.launched(1).statusFile);
check(st == "error" && contains(msg, "exited without writing"), 'the run counts as failed');

fprintf('\n== 6. runs started elsewhere take slots (PriorRuns) ==\n');
tl = fullfile(root, 'timeline6.txt');
fake = makeFake(root, 'fake6.cmd', tl, true);
prior = string(fullfile(root, 'prior', 'ks4_status.json')); mkdir(fileparts(prior));
S = runScenario(proj, probeFile, 1, "spikeinterface", fake, fullfile(root, 'out6'), PriorRuns=prior);
check(S.waitedForPrior, 'the first dataset waited for the earlier run to finish');
check(numel(S.launched) == 3, 'then all three launched');

fprintf('\n== 7. cancel while waiting for a slot ==\n');
tl = fullfile(root, 'timeline7.txt');
fake = makeFake(root, 'fake7.cmd', tl, true);
S = runScenario(proj, probeFile, 1, "spikeinterface", fake, fullfile(root, 'out7'), CancelOnWait=true);
check(S.errorId == "EphysPipeline:Cancelled", 'runSorting ends with EphysPipeline:Cancelled');
check(numel(S.launched) == 1 && isequal(S.results.Status.', ["launched" "cancelled" "cancelled"]), ...
    'the running dataset carries on; the other two are cancelled');

fprintf('\n== 8. blocking runs go one at a time, without the slot wait ==\n');
tl = fullfile(root, 'timeline8.txt');
fake = makeFake(root, 'fake8.cmd', tl, true);
S = runScenario(proj, probeFile, 3, "spikeinterface", fake, fullfile(root, 'out8'), Execution="blocking");
[maxRun, nEvents] = concurrency(tl);
check(all(S.results.Status == "done") && isempty(S.launched) && S.nWaitMsgs == 0, 'three blocking runs, done, no background launches');
check(nEvents == 6 && maxRun == 1, 'blocking ignores MaxConcurrent: one at a time');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_SortingConcurrency:Failures', '%d checks failed.', nFail);
end

end


function S = runScenario(proj, probeFile, maxConcurrent, engine, fake, outRoot, opts)
%runScenario  Sort the three datasets, then wait for every run to end.
arguments
    proj
    probeFile
    maxConcurrent
    engine
    fake
    outRoot
    opts.PriorRuns (:,1) string = strings(0, 1)
    opts.CancelOnWait (1,1) logical = false
    opts.Execution (1,1) string = "background"
end
cfg = EphysPipelineConfig();
cfg.Project.Root = proj;
cfg.Project.OutputRoot = outRoot;
cfg.Probe.DefaultProbeFile = probeFile;
cfg.Sorting.Enabled = true;
cfg.Sorting.Engine = engine;
cfg.Sorting.PythonExe = fake;
cfg.Sorting.Execution = opts.Execution;
cfg.Sorting.MaxConcurrent = maxConcurrent;
pipe = EphysPipeline(cfg);
pipe.LogFcn = [];
pipe.checkProbes();
pipe.reset();
pipe.PriorRuns = opts.PriorRuns;
S = struct('pipe', pipe, 'launched', EphysPipeline.emptyRuns(), 'nWaitMsgs', 0, ...
    'waitingSeen', [], 'waitedForPrior', false, 'timedOut', false, 'errorId', "", ...
    'results', [], 'allExited', false);
started = tic;
pipe.LaunchFcn = @(run) onLaunch(run);
pipe.ProgressFcn = @(evt) onProgress(evt);
try
    pipe.runSorting();
catch ME
    S.errorId = string(ME.identifier);
end
S.results = pipe.Results;
% Let the last runs finish (their processes gone too) before the next
% scenario and the cleanup.
waitForSortingSlot([S.launched.statusFile], 1, Period=0.25);
t0 = tic;
while ~S.allExited && toc(t0) < 10
    S.allExited = all(arrayfun(@(r) isfile(fullfile(r.resultsDir, EphysDataset.SortExitMarker)), S.launched));
    if ~S.allExited; pause(0.25); end
end

    function onLaunch(run)
        S.launched(end+1) = run;
    end

    function onProgress(evt)
        if ~contains(evt.message, "waiting for a free Kilosort4 slot"); return; end
        S.nWaitMsgs = S.nWaitMsgs + 1;
        S.waitingSeen(end+1) = pipe.SortingWaiting;
        if ~isempty(opts.PriorRuns) && isempty(S.launched) && ~S.waitedForPrior
            S.waitedForPrior = true;
            writelines('{"state": "done"}', opts.PriorRuns(1));   % the earlier run finishes
        end
        if opts.CancelOnWait
            pipe.cancel();
        end
        if toc(started) > 120   % a stuck slot must not hang the suite
            S.timedOut = true;
            pipe.cancel();
        end
    end
end


function fake = makeFake(folder, name, timeline, writeStatus)
%makeFake  A stand-in python.exe: note start / end, sleep ~2 s, write the status.
%   Called as <fake> <driver.py> <config.json>; the driver sits in the run
%   folder, where the pipeline expects ks4_status.json (%~dp1).
L = ["@echo off"
    "echo start %~dp1>> """ + timeline + """"
    "ping -n 3 127.0.0.1 > nul"
    "echo end %~dp1>> """ + timeline + """"];
if writeStatus
    L(end+1) = "echo {""state"": ""done"", ""num_units"": 0}> ""%~dp1ks4_status.json""";
else
    L(end+1) = "exit /b 3";
end
fake = string(fullfile(folder, name));
writelines(L, fake, LineEnding="\r\n");
end


function [maxRun, nEvents] = concurrency(timeline)
%concurrency  Most runs going at once, from the start / end lines in order.
maxRun = 0; nEvents = 0;
if ~isfile(timeline); return; end
L = strtrim(readlines(timeline));
L(L == "") = [];
nEvents = numel(L);
running = 0;
for k = 1:nEvents
    running = running + ternary(startsWith(L(k), "start"), 1, -1);
    maxRun = max(maxRun, running);
end
end


function v = ternary(c, a, b)
if c; v = a; else; v = b; end
end
