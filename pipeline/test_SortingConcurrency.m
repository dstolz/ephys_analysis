function test_SortingConcurrency()
%test_SortingConcurrency  Background Kilosort4 runs go Sorting.MaxConcurrent at a time.
%   Uses stand-in "python" executables: .cmd files that note their start
%   and end in a shared timeline file, sleep ~2 s and write ks4_status.json
%   (or exit without one), so the pipeline's slot handling is checked
%   without Kilosort4 or a GPU. Checks EphysDataset.sortRunState,
%   sortingSlot and waitForSortingSlot, the pipeline with one and two
%   slots, a run that exits
%   without a status, runs started elsewhere (PriorRuns), a cancel while
%   waiting, blocking runs, GPUs shared out (Sorting.Devices, the
%   driver's --device), runs handed to a queue (QueueFcn, launchSorting),
%   restated result rows and stopping a run that is going
%   (stopSortRun). Windows only (the stand-ins are batch files).
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

fprintf('\n== 2. sortingSlot and waitForSortingSlot ==\n');
t0 = tic;
r1 = struct('statusFile', string(sf), 'device', "");
dev = waitForSortingSlot(r1, 1);
waitForSortingSlot([], 1);
check(toc(t0) < 1 && dev == "", 'returns at once when the runs have finished (or there are none), with no device');
sf2 = string(fullfile(root, 'state2', 'ks4_status.json')); mkdir(fileparts(sf2));
r2 = struct('statusFile', sf2, 'device', "");
ticks = 0;
    function tick(nRunning, nFinished)
        ticks = ticks + 1;
        check(nRunning == 1 && nFinished == 1, 'TickFcn gets the running / finished counts');
        writelines('{"state": "done"}', sf2);   % the run finishes while waiting
    end
waitForSortingSlot([r1 r2], 2);
check(ticks == 0, 'one running of two slots: no wait');
waitForSortingSlot([r1 r2], 1, Period=0.1, TickFcn=@tick);
check(ticks == 1, 'one running of one slot: waits until it finishes');
% Devices: runs on cuda:0 (three, one of them done) and cuda:1 (one).
rs = struct('statusFile', {}, 'device', {});
for j = 1:4
    f = string(fullfile(root, sprintf('dev%d', j), 'ks4_status.json')); mkdir(fileparts(f));
    rs(j).statusFile = f;
end
[rs.device] = deal("cuda:0", "cuda:0", "cuda:1", "cuda:0");
writelines('{"state": "done"}', rs(4).statusFile);
[free, dev, nRun, nFin] = sortingSlot(rs, 4, ["cuda:0" "cuda:1"]);
check(free && dev == "cuda:1" && nRun == 3 && nFin == 1, 'the device the fewest running runs use (a finished run no longer counts)');
[~, dev] = sortingSlot(rs(3), 4, ["cuda:0" "cuda:1"]);
check(dev == "cuda:0", 'a device nothing runs on goes first');
[~, dev] = sortingSlot(rs([1 3]), 4, ["cuda:0" "cuda:1"]);
check(dev == "cuda:0", 'a tie goes to the first listed device');
free = sortingSlot(rs, 3, ["cuda:0" "cuda:1"]);
check(~free, 'three running of three slots: no slot');
[~, dev] = sortingSlot(rs, 4, strings(1, 0));
check(dev == "", 'no devices: no device');
check(isequal(EphysDataset.isTorchDevice(["cuda:1" "cpu" "cuda" "gpu1" "cuda:x" ""]), [true true true false false false]), ...
    'isTorchDevice accepts cpu / cuda / cuda:N only');

fprintf('\n== 3. one slot ==\n');
tl = fullfile(root, 'timeline3.txt');
fake = makeFake(root, 'fake3.cmd', tl, true);
S = runScenario(proj, probeFile, 1, fake, fullfile(root, 'out3'));
check(numel(S.launched) == 3 && all(S.results.Status == "launched"), 'all three datasets launched');
[maxRun, nEvents] = concurrency(tl);
check(nEvents == 6 && maxRun == 1, sprintf('never more than one at a time (max %d over %d events)', maxRun, nEvents));
check(S.nWaitMsgs > 0 && max(S.waitingSeen) == 2, 'progress while waiting: a slot message, with 2 datasets still to start');
check(S.pipe.SortingWaiting == 0, 'SortingWaiting is 0 once every dataset has started');
check(S.allExited, 'each run left its exit marker once its process ended');
check(all(arrayfun(@(r) EphysDataset.sortRunState(r.statusFile) == "done", S.launched)), 'every run reports done');

fprintf('\n== 4. two slots ==\n');
tl = fullfile(root, 'timeline4.txt');
fake = makeFake(root, 'fake4.cmd', tl, true);
S = runScenario(proj, probeFile, 2, fake, fullfile(root, 'out4'));
[maxRun, nEvents] = concurrency(tl);
check(numel(S.launched) == 3 && nEvents == 6 && maxRun == 2, sprintf('two at a time (max %d over %d events)', maxRun, nEvents));
check(all(arrayfun(@(r) isfile(fullfile(r.resultsDir, 'settings.json')), S.launched)), ...
    'runKilosort wrote each run''s files before launching');

fprintf('\n== 5. a run that exits without a status frees its slot ==\n');
tl = fullfile(root, 'timeline5.txt');
fake = makeFake(root, 'fake5.cmd', tl, false);
S = runScenario(proj, probeFile, 1, fake, fullfile(root, 'out5'));
[maxRun, nEvents] = concurrency(tl);
check(~S.timedOut && numel(S.launched) == 3 && nEvents == 6 && maxRun == 1, 'all three ran, one at a time, without hanging');
[st, msg] = EphysDataset.sortRunState(S.launched(1).statusFile);
check(st == "error" && contains(msg, "exited without writing"), 'the run counts as failed');

fprintf('\n== 6. runs started elsewhere take slots (PriorRuns) ==\n');
tl = fullfile(root, 'timeline6.txt');
fake = makeFake(root, 'fake6.cmd', tl, true);
priorDir = fullfile(root, 'prior'); mkdir(priorDir);
prior = EphysPipeline.sortRun("elsewhere", struct('statusFile', fullfile(priorDir, 'ks4_status.json'), ...
    'resultsDir', priorDir, 'stdoutLog', fullfile(priorDir, 'ks4_run.log'), 'device', ""));
S = runScenario(proj, probeFile, 1, fake, fullfile(root, 'out6'), PriorRuns=prior);
check(S.waitedForPrior, 'the first dataset waited for the earlier run to finish');
check(numel(S.launched) == 3, 'then all three launched');

fprintf('\n== 7. cancel while waiting for a slot ==\n');
tl = fullfile(root, 'timeline7.txt');
fake = makeFake(root, 'fake7.cmd', tl, true);
S = runScenario(proj, probeFile, 1, fake, fullfile(root, 'out7'), CancelOnWait=true);
check(S.errorId == "EphysPipeline:Cancelled", 'runSorting ends with EphysPipeline:Cancelled');
check(numel(S.launched) == 1 && isequal(S.results.Status.', ["launched" "cancelled" "cancelled"]), ...
    'the running dataset carries on; the other two are cancelled');

fprintf('\n== 8. blocking runs go one at a time, without the slot wait ==\n');
tl = fullfile(root, 'timeline8.txt');
fake = makeFake(root, 'fake8.cmd', tl, true);
S = runScenario(proj, probeFile, 3, fake, fullfile(root, 'out8'), Execution="blocking");
[maxRun, nEvents] = concurrency(tl);
check(all(S.results.Status == "done") && isempty(S.launched) && S.nWaitMsgs == 0, 'three blocking runs, done, no background launches');
check(nEvents == 6 && maxRun == 1, 'blocking ignores MaxConcurrent: one at a time');

fprintf('\n== 9. two slots, two GPUs (Sorting.Devices) ==\n');
tl = fullfile(root, 'timeline9.txt');
fake = makeFake(root, 'fake9.cmd', tl, true);
S = runScenario(proj, probeFile, 2, fake, fullfile(root, 'out9'), Devices=["cuda:0" "cuda:1"]);
[maxRun, nEvents, shared] = concurrency(tl);
check(numel(S.launched) == 3 && nEvents == 6 && maxRun == 2, sprintf('two at a time (max %d over %d events)', maxRun, nEvents));
check(isequal([S.launched(1:2).device], ["cuda:0" "cuda:1"]) && ismember(S.launched(3).device, ["cuda:0" "cuda:1"]), ...
    'the first two runs get one GPU each, the third a freed one');
check(~shared, 'no two runs going at once shared a GPU (the drivers got --device)');
check(all(contains(S.results.Message, "background run on cuda:")), 'the result rows name the GPU');
tl = fullfile(root, 'timeline9b.txt');
fake = makeFake(root, 'fake9b.cmd', tl, true);
runScenario(proj, probeFile, 1, fake, fullfile(root, 'out9b'), Execution="blocking", Devices=["cuda:1" "cuda:0"]);
L = strtrim(readlines(tl)); L = L(startsWith(L, "start"));
check(numel(L) == 3 && all(endsWith(L, "--device cuda:1")), 'blocking runs go on the first device');

fprintf('\n== 10. runs handed to a queue (QueueFcn) ==\n');
tl = fullfile(root, 'timeline10.txt');
fake = makeFake(root, 'fake10.cmd', tl, true);
S = runScenario(proj, probeFile, 1, fake, fullfile(root, 'out10'), Queue=true);
check(~isfile(tl) && isempty(S.launched) && S.nWaitMsgs == 0, 'the step started nothing and never waited for a slot');
check(numel(S.queued) == 3 && all(S.results.Status == "queued") && S.pipe.SortingWaiting == 0, ...
    'each dataset went to QueueFcn, its row "queued"');
check(all(arrayfun(@(q) ~q.res.launched && isfile(q.res.binFile) && isfile(q.res.settingsPath), S.queued)), ...
    'the queued runs have their .bin and run files written, not launched');
launched = [];
for q = S.queued
    device = waitForSortingSlot(launched, 1, Devices="cuda:0", Period=0.25);
    res = q.d.launchSorting(q.res, Wait=false, Device=device);
    launched = [launched, res]; %#ok<AGROW>
    S.pipe.updateResult("sorting", q.d.Name, res.resultsDir, "launched", "started from the queue");
end
waitForSortingSlot(launched, 1, Period=0.25);
[maxRun, nEvents] = concurrency(tl);
check(nEvents == 6 && maxRun == 1 && all(arrayfun(@(r) EphysDataset.sortRunState(r.statusFile) == "done", launched)), ...
    'launchSorting starts them later, one at a time, and they finish');
check(all(S.pipe.Results.Status == "launched") && all(S.pipe.Results.Message == "started from the queue"), ...
    'updateResult restates each row');
check(all([launched.launched]) && all([launched.device] == "cuda:0") && all(contains(string({launched.command}), "--device cuda:0")), ...
    'launchSorting records the device and the command it ran');
waitForExits(launched);

fprintf('\n== 11. restating result rows ==\n');
T = EphysPipeline.emptyResults();
T(1, :) = {"sorting", "A", "launched", "background run", "C:/out/A/kilosort4", 12};
T(2, :) = {"sorting", "B", "launched", "background run", "C:/out/B/kilosort4", 5};
T2 = EphysPipeline.restateResult(T, "sorting", "B", "C:/out/B/kilosort4", "error", "Kilosort4 failed: boom", 100);
check(T2.Status(2) == "error" && T2.Message(2) == "Kilosort4 failed: boom" && T2.Seconds(2) == 105 && isequal(T2(1, :), T(1, :)), ...
    'the matching row takes the status and message, its Seconds grows, the others stay');
check(isequal(EphysPipeline.restateResult(T, "sorting", "C", "x", "done", "", 0), T), 'no matching row: unchanged');

fprintf('\n== 12. stopping a run that is going (stopSortRun) ==\n');
tl = fullfile(root, 'timeline12.txt');
fake = makeFake(root, 'fake12.cmd', tl, true, 30);   % would sort for ~30 s
S = runScenario(proj, probeFile, 1, fake, fullfile(root, 'out12'), Queue=true);
q = S.queued(1);
res = q.d.launchSorting(q.res, Wait=false);
t0 = tic;
while toc(t0) < 10 && ~isfile(tl); pause(0.1); end   % the stand-in has started
[stopped, msg] = EphysDataset.stopSortRun(res.statusFile);
[st, why] = EphysDataset.sortRunState(res.statusFile);
check(stopped && ~isempty(regexp(msg, '^stopped [1-9]\d* process\(es\)$', 'once')), ...
    sprintf('stopSortRun ended the run''s processes (%s)', msg));
check(st == "cancelled" && why == "stopped by the user" && isfile(fullfile(res.resultsDir, EphysDataset.SortExitMarker)), ...
    'its status says cancelled, and the exit marker is there');
pause(3);
L = strtrim(readlines(tl)); L(L == "") = [];
check(isscalar(L) && startsWith(L, "start"), 'the stand-in never reached its end (the process tree was killed)');
check(~EphysDataset.stopSortRun(res.statusFile), 'a run that is not going is left alone');
[free, ~, nRun, nFin] = sortingSlot(res, 1);
check(free && nRun == 0 && nFin == 1, 'a stopped run frees its slot');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_SortingConcurrency:Failures', '%d checks failed.', nFail);
end

end


function S = runScenario(proj, probeFile, maxConcurrent, fake, outRoot, opts)
%runScenario  Sort the three datasets, then wait for every run to end.
arguments
    proj
    probeFile
    maxConcurrent
    fake
    outRoot
    opts.PriorRuns struct = EphysPipeline.emptyRuns()
    opts.CancelOnWait (1,1) logical = false
    opts.Execution (1,1) string = "background"
    opts.Devices (1,:) string = strings(1, 0)
    opts.Queue (1,1) logical = false
end
cfg = EphysPipelineConfig();
cfg.Project.Root = proj;
cfg.Project.OutputRoot = outRoot;
cfg.Probe.DefaultProbeFile = probeFile;
cfg.Sorting.Enabled = true;
cfg.Sorting.PythonExe = fake;
cfg.Sorting.Execution = opts.Execution;
cfg.Sorting.MaxConcurrent = maxConcurrent;
cfg.Sorting.Devices = opts.Devices;
pipe = EphysPipeline(cfg);
pipe.LogFcn = [];
pipe.checkProbes();
pipe.reset();
pipe.PriorRuns = opts.PriorRuns;
S = struct('pipe', pipe, 'launched', EphysPipeline.emptyRuns(), 'nWaitMsgs', 0, ...
    'waitingSeen', [], 'waitedForPrior', false, 'timedOut', false, 'errorId', "", ...
    'results', [], 'allExited', false, 'queued', struct('d', {}, 'res', {}));
started = tic;
pipe.LaunchFcn = @(run) onLaunch(run);
if opts.Queue
    pipe.QueueFcn = @(d, res) onQueue(d, res);
end
pipe.ProgressFcn = @(evt) onProgress(evt);
try
    pipe.runSorting();
catch ME
    S.errorId = string(ME.identifier);
end
S.results = pipe.Results;
% Let the last runs finish (their processes gone too) before the next
% scenario and the cleanup.
waitForSortingSlot(S.launched, 1, Period=0.25);
S.allExited = waitForExits(S.launched);

    function onLaunch(run)
        S.launched(end+1) = run;
    end

    function onQueue(d, res)
        S.queued(end+1) = struct('d', d, 'res', res);
    end

    function onProgress(evt)
        if ~contains(evt.message, "waiting for a free Kilosort4 slot"); return; end
        S.nWaitMsgs = S.nWaitMsgs + 1;
        S.waitingSeen(end+1) = pipe.SortingWaiting;
        if ~isempty(opts.PriorRuns) && isempty(S.launched) && ~S.waitedForPrior
            S.waitedForPrior = true;
            writelines('{"state": "done"}', opts.PriorRuns(1).statusFile);   % the earlier run finishes
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


function allExited = waitForExits(runs)
%waitForExits  Wait (up to 10 s) until every run's process has left its exit marker.
t0 = tic;
allExited = false;
while ~allExited && toc(t0) < 10
    allExited = all(arrayfun(@(r) isfile(fullfile(r.resultsDir, EphysDataset.SortExitMarker)), runs));
    if ~allExited; pause(0.25); end
end
end


function fake = makeFake(folder, name, timeline, writeStatus, seconds)
%makeFake  A stand-in python.exe: note start / end, sleep, write the status.
%   Called as <fake> <driver.py> <config.json> [--device <device>]; the
%   driver sits in the run folder, where the pipeline expects
%   ks4_status.json (%~dp1). The start / end lines carry the run folder
%   and the device arguments. It sleeps about SECONDS (default 2).
if nargin < 5; seconds = 2; end
L = ["@echo off"
    "echo start %~dp1 %3 %4>> """ + timeline + """"
    "ping -n " + (seconds + 1) + " 127.0.0.1 > nul"
    "echo end %~dp1 %3 %4>> """ + timeline + """"];
if writeStatus
    L(end+1) = "echo {""state"": ""done"", ""num_units"": 0}> ""%~dp1ks4_status.json""";
else
    L(end+1) = "exit /b 3";
end
fake = string(fullfile(folder, name));
writelines(L, fake, LineEnding="\r\n");
end


function [maxRun, nEvents, shared] = concurrency(timeline)
%concurrency  Most runs going at once, from the start / end lines in order,
%   and whether two runs going at once had the same --device.
maxRun = 0; nEvents = 0; shared = false;
if ~isfile(timeline); return; end
L = strtrim(readlines(timeline));
L(L == "") = [];
nEvents = numel(L);
going = strings(1, 0);   % the devices of the runs going
for k = 1:nEvents
    dev = regexp(L(k), '--device (\S+)', 'tokens', 'once');
    if isempty(dev); dev = ""; else; dev = string(dev{1}); end
    if startsWith(L(k), "start")
        shared = shared || (dev ~= "" && any(going == dev));
        going(end+1) = dev; %#ok<AGROW>
    else
        going(find(going == dev, 1)) = [];
    end
    maxRun = max(maxRun, numel(going));
end
end

