function test_TrialPairing()
%test_TrialPairing  Verification suite for Epsych2 trial <-> digital-line pairing.
%   Checks pairEpsychTrials on synthetic trials and events (equal counts, a
%   recording started late or stopped early with partial intervals at the
%   edges, the count-mismatch warning, the cuts that resolve it, an inverted
%   line idle at the recording start, inverted lines, nested lines,
%   derived-signal samples), then EphysDataset.digitalEvents / pairTrials /
%   setTrialPairing / behaviorToMat on a synthetic RHD recording,
%   inverted-line events in toMat and ChronuxDataset (from SignalOptions or
%   the dataset's TrialConfig), and the pipeline's
%   behavior step (record, approve, reuse, stale after a config change, a
%   count mismatch reported).
%
%   Usage:  test_TrialPairing

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

root = fullfile(tempdir, sprintf('Pairing_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>

nPass = 0; nFail = 0;
logLines = strings(0, 1);
    function check(cond, msg)
        if cond
            nPass = nPass + 1;
            fprintf('  PASS: %s\n', msg);
        else
            nFail = nFail + 1;
            fprintf(2, '  FAIL: %s\n', msg);
            LegacySuiteTest.checkFailed(msg);   % one failure per check in run_all_tests' report
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
    function logCapture(msg)
        logLines(end + 1, 1) = string(msg);
    end

% ---- synthetic session: 20 trials, 8-10.4 s apart, 3 s long ---------------
Fs = 1000;
n = 20;
on = 5 + cumsum([0; 8 + mod((1:n-1).' * 7, 5) * 0.6]);    % uneven gaps, like real sessions
off = on + 3;
iv = [on off];
N = round((off(end) + 10) * Fs);                           % recording length (samples)
t0 = datetime(2026, 1, 1, 12, 0, 0);
trials = table((1:n).', 60 + (1:n).', t0 + seconds(off + 20), ...
    'VariableNames', {'TrialIndex', 'ToneLevel', 'computerTimestamp'});
stim = [on + 1, on + 1.2; on(3) + 2, on(3) + 2.1];     % trial 3 has two Stim pulses
events = struct('InTrial', iv, 'Stim', sortrows(stim), 'Reward', [off(2) + 5, off(2) + 5.5]);

fprintf('\n== 1. pairEpsychTrials: counts agree ==\n');
lastwarn('');
P = pairEpsychTrials(trials, events, Fs, NumSamples=N, SignalFs=struct('LFP', 500, 'Bad', NaN));
[~, wid] = lastwarn;
check(isequal(P.interval, (1:n).') && P.nPaired == n && ~P.countMismatch && isempty(P.warnings) ...
    && isempty(wid) && all(P.flag == "ok"), 'every trial pairs in order with its interval, nothing to warn about');
check(P.timingMismatch == 0 && P.timingChecked == n - 1 && isempty(P.dropIntervals) && P.timingTolerance >= 0.5, ...
    'the Epsych2 timestamps agree with the line''s trial ends: nothing to report');
check(isequal(P.onsetSample, round(on * Fs)) && isequal(P.offsetSample, round(off * Fs)), 'samples are rows at Fs (t = row/Fs)');
check(isfield(P.signalSamples, 'LFP') && ~isfield(P.signalSamples, 'Bad') ...
    && isequal(P.signalSamples.LFP, round(([on off] - 1 / Fs) * 500) + 1), ...
    'derived-signal samples round((t - 1/Fs)*signalFs) + 1 for valid rates only');
PX = pairEpsychTrials(trials(1, :), struct('InTrial', [180001 240000] / 30000), 30000, ...
    SignalFs=struct('LFP', 1000));
check(PX.onsetSample == 180001 && isequal(PX.signalSamples.LFP, [6001 8001]) ...
    && PX.columns.TrialOnsetSample_LFP == 6001, ...
    'recording row 180001 at 30 kHz (continuous t = 6.000 s) is LFP row 6001 at 1 kHz, not 6000');
check(size(P.lines.Stim{3}, 1) == 2 && size(P.lines.Stim{1}, 1) == 1 && isempty(P.lines.Reward{2}) ...
    && ~isfield(P.lines, 'InTrial'), 'other lines nested per trial by overlap');
check(isequal(P.intervals, iv) && isequal(P.events.Stim, sortrows(stim)) && isempty(P.partialIntervals) ...
    && P.nSamples == N && isequal(P.cutTrials, [0 0]), 'the trial-line intervals and the events are returned');
C = P.columns;
check(height(C) == n && all(ismember(["TrialInterval" "TrialOnset" "TrialOffset" "TrialOnsetSample" ...
    "TrialOffsetSample" "TrialOnsetSample_LFP" "TrialOffsetSample_LFP" "PairingFlag" ...
    "TrialEvents" "TrialEventSamples"], string(C.Properties.VariableNames))) ...
    && ~ismember("TimestampResidual", string(C.Properties.VariableNames)), 'columns table has the documented variables');
check(isequal(C.TrialEventSamples(3).Stim, round(P.lines.Stim{3} * Fs)), 'TrialEventSamples mirror TrialEvents in rows');

fprintf('\n== 2. recording started late: fewer intervals, the first one partial ==\n');
evLate = events;                                            % the recording began during trial 4
evLate.InTrial = [1 / Fs, off(4); iv(5:end, :)];
lastwarn('');
PL = pairEpsychTrials(trials, evLate, Fs, NumSamples=N);
[wmsg, wid] = lastwarn;
check(PL.countMismatch && strcmp(wid, 'pairEpsychTrials:CountMismatch') && isscalar(PL.warnings) ...
    && string(wmsg) == PL.warnings(1), 'a count mismatch is warned about');
check(isequaln(PL.interval, [(1:n-3).'; NaN(3, 1)]) && isequal(PL.unpairedTrials, (n-2:n).') ...
    && isempty(PL.unpairedIntervals), 'the trials still pair in order from the first interval');
check(isequal(PL.partialIntervals, 1) && PL.flag(1) == "partial" && PL.flag(2) == "ok" ...
    && all(PL.flag(n-2:n) == "unpaired") && PL.onsetSample(1) == 1, 'the interval at the recording start is partial');
check(contains(PL.warnings, "Interval 1 begins at the first sample") && contains(PL.warnings, "Cut trials or intervals") ...
    && contains(PL.summary, "COUNT MISMATCH: 20 trial(s) vs 17 interval(s)"), 'the warning points at the partial interval and at the cuts');
PR = pairEpsychTrials(trials, evLate, Fs, NumSamples=N, CutTrials=[3 0]);
check(~PR.countMismatch && isempty(PR.warnings) && isequaln(PR.interval, [NaN(3, 1); (1:n-3).']) ...
    && isequal(PR.flag(1:4), ["cut"; "cut"; "cut"; "partial"]) && PR.nPaired == n - 3 ...
    && abs(PR.offset(4) - off(4)) < 1e-9 && isequal(PR.cutTrials, [3 0]), ...
    'cutting 3 trials from the start resolves it; trial 4 keeps its partial interval');
PR2 = pairEpsychTrials(trials, evLate, Fs, NumSamples=N, CutTrials=[4 0], CutIntervals=[1 0]);
check(~PR2.countMismatch && PR2.interval(5) == 2 && PR2.flag(5) == "ok" && abs(PR2.onset(5) - on(5)) < 1e-9 ...
    && isempty(PR2.unpairedIntervals) && contains(PR2.summary, "1 + 0 interval(s) cut"), ...
    'cutting the partial interval too pairs trial 5 with interval 2');
check(all(isnan(PR2.onset(1:4))) && all(cellfun(@isempty, PR2.lines.Stim(1:4))) && all(isnan(PR2.columns.TrialInterval(1:4))), ...
    'cut trials have no timing and no nested events');

fprintf('\n== 3. recording stopped early: the last interval partial ==\n');
m = 15;
N2 = round((on(m) + 1) * Fs);                               % the recording ends during trial m
evEarly = events;
evEarly.InTrial = [iv(1:m-1, :); on(m), N2 / Fs];
PS = pairEpsychTrials(trials, evEarly, Fs, NumSamples=N2, Warn=false);
check(PS.countMismatch && isequal(PS.partialIntervals, m) && PS.flag(m) == "partial" ...
    && isequal(PS.unpairedTrials, (m+1:n).') && contains(PS.warnings, sprintf("Interval %d ends at the last sample", m)), ...
    'the interval at the recording end is partial and the mismatch warned about');
PS2 = pairEpsychTrials(trials, evEarly, Fs, NumSamples=N2, CutTrials=[0 n-m], Warn=false);
check(~PS2.countMismatch && PS2.nPaired == m && all(PS2.flag(m+1:n) == "cut") && PS2.flag(m) == "partial", ...
    'cutting the trials Epsych2 ran after the recording resolves it');
PS3 = pairEpsychTrials(trials, evEarly, Fs, Warn=false);
check(isempty(PS3.partialIntervals) && PS3.flag(m) == "ok", 'without NumSamples the recording end is not checked');
PS4 = pairEpsychTrials(trials, evEarly, Fs, NumSamples=N2, CutTrials=[0 n-m+1], CutIntervals=[0 1], Warn=false);
check(~PS4.countMismatch && PS4.nPaired == m - 1 && all(PS4.flag == "ok" | PS4.flag == "cut"), ...
    'cutting the partial interval and its trial leaves whole trials only');
evMid = events;                                             % the recording began during trial 1
evMid.InTrial(1, 1) = 1 / Fs;
lastwarn('');
PM = pairEpsychTrials(trials, evMid, Fs, NumSamples=N);
[~, wid] = lastwarn;
check(~PM.countMismatch && isempty(PM.warnings) && isempty(wid) && PM.flag(1) == "partial" ...
    && isequal(PM.partialIntervals, 1) && contains(PM.summary, "partial interval(s) at the recording edge: 1"), ...
    'equal counts with a partial first interval: flagged, not warned');

fprintf('\n== 4. cuts are validated; the trial line must exist ==\n');
check(strcmp(errorId(@() pairEpsychTrials(trials, events, Fs, CutTrials=[n 1])), 'pairEpsychTrials:Cuts'), ...
    'cutting more trials than there are is refused');
check(strcmp(errorId(@() pairEpsychTrials(trials, events, Fs, CutIntervals=[0 n+1], Warn=false)), 'pairEpsychTrials:Cuts'), ...
    'cutting more intervals than there are is refused');
check(~isempty(errorId(@() pairEpsychTrials(trials, events, Fs, CutTrials=[-1 0]))), 'negative cuts are refused');
check(~isempty(errorId(@() pairEpsychTrials(trials, events, Fs, CutTrials=[1.5 0]))), 'fractional cuts are refused');
check(strcmp(errorId(@() pairEpsychTrials(trials, events, Fs, TrialLine="Nope")), 'pairEpsychTrials:NoTrialLine'), ...
    'a missing trial line is an error');
PA = pairEpsychTrials(trials, events, Fs, CutTrials=[n 0], CutIntervals=[0 n], Warn=false);
check(PA.nPaired == 0 && all(PA.flag == "cut") && ~PA.countMismatch && isempty(PA.unpairedIntervals), ...
    'cutting everything pairs nothing');
check(strcmp(errorId(@() pairEpsychTrials(trials, events, Fs, DropIntervals=n + 1, Warn=false)), 'pairEpsychTrials:Cuts') ...
    && ~isempty(errorId(@() pairEpsychTrials(trials, events, Fs, DropIntervals=0))) ...
    && ~isempty(errorId(@() pairEpsychTrials(trials, events, Fs, DropIntervals=1.5))), ...
    'dropping an interval that does not exist, or a non-positive / fractional index, is refused');

fprintf('\n== 4b. a glitch pulse plus a missing last pulse: equal counts, wrong pairs ==\n');
glitch = off(8) + 1.0;                                      % a stray 50 ms pulse 1 s after trial 8
evG = events;
evG.InTrial = [iv(1:8, :); glitch, glitch + 0.05; iv(9:n-1, :)];   % ... and the last trial's pulse is missing: n intervals
lastwarn('');
PG = pairEpsychTrials(trials, evG, Fs, NumSamples=N);
[wmsg, wid] = lastwarn;
check(~PG.countMismatch && PG.nIntervals == n && PG.timingMismatch == 9 && PG.timingChecked == n - 1 ...
    && strcmp(wid, 'pairEpsychTrials:TimingMismatch') && isscalar(PG.warnings) && string(wmsg) == PG.warnings(1) ...
    && contains(PG.warnings, "Trial 9 does not agree") && contains(PG.summary, "TIMING MISMATCH at trial 9"), ...
    'the counts agree, but trial 9 is flagged: its end does not follow the Epsych2 clock');
lastwarn('');
PGq = pairEpsychTrials(trials, evG, Fs, NumSamples=N, Warn=false);
[~, wid] = lastwarn;
check(PGq.timingMismatch == 9 && isempty(wid), 'Warn=false keeps it in the result and warns nothing');
PG2 = pairEpsychTrials(trials, evG, Fs, NumSamples=N, DropIntervals=9, CutTrials=[0 1]);
check(PG2.timingMismatch == 0 && ~PG2.countMismatch && PG2.nPaired == n - 1 && isequal(PG2.dropIntervals, 9) ...
    && isequal(PG2.interval(1:8), (1:8).') && isequal(PG2.interval(9:n-1), (10:n).') && abs(PG2.onset(9) - on(9)) < 1e-9 ...
    && PG2.flag(n) == "cut" && contains(PG2.summary, "interval(s) 9 dropped") && isempty(PG2.warnings), ...
    'dropping interval 9 (and cutting the trial that lost its pulse) pairs every trial with its own interval');
PG3 = pairEpsychTrials(trials, evG, Fs, NumSamples=N, DropIntervals=9, Warn=false);
check(PG3.countMismatch && PG3.timingMismatch == 0 && isequal(PG3.unpairedTrials, n) && contains(PG3.warnings, "dropping interval(s) 9") ...
    && contains(PG3.warnings, "DropIntervals"), 'a drop is part of the count-mismatch message');
PG4 = pairEpsychTrials(trials, evG, Fs, NumSamples=N, CutIntervals=[1 0], DropIntervals=[1 9 9], Warn=false);
check(isequal(PG4.dropIntervals, [1 9]) && PG4.nPaired == n - 2, 'drops inside an end cut are harmless; repeats are one');
tsNone = trials(:, 1:2);
PNT = pairEpsychTrials(tsNone, evG, Fs, NumSamples=N, Warn=false);
trialsNaT = trials; trialsNaT.computerTimestamp(:) = NaT;
PNaT = pairEpsychTrials(trialsNaT, evG, Fs, NumSamples=N, Warn=false);
check(PNT.timingChecked == 0 && PNT.timingMismatch == 0 && isempty(PNT.warnings) ...
    && PNaT.timingChecked == 0 && PNaT.timingMismatch == 0 && isempty(PNaT.warnings), ...
    'a session without computerTimestamp (or without values) is not cross-checked');

fprintf('\n== 4c. an event on the first low row after the trial is the trial''s ==\n');
evO = events;
evO.Reward = [off(2) + 1 / Fs, off(2) + 1 / Fs + 0.01; ...      % the first low row after trial 2
              off(2) + 2 / Fs, off(2) + 2 / Fs + 0.01; ...      % one row later: nobody's
              on(3) - 0.5, on(3) + 0.2];                         % begins before trial 3 and overlaps it
PO = pairEpsychTrials(trials, evO, Fs, NumSamples=N);
check(isequal(PO.lines.Reward{2}, evO.Reward(1, :)) && isequal(PO.lines.Reward{3}, evO.Reward(3, :)) ...
    && isempty(PO.lines.Reward{1}) && isequal(PO.columns.TrialEvents(2).Reward, evO.Reward(1, :)) ...
    && isequal(PO.columns.TrialEventSamples(2).Reward, round(evO.Reward(1, :) * Fs)), ...
    'TrialEvents lists the interval that begins on the first low row and the one that began before the trial');

fprintf('\n== 5. inverted lines ==\n');
rows = round(iv * Fs);
low = [[1; rows(:, 2) + 1], [rows(:, 1) - 1; N]] / Fs;                % high runs of an inverted trial line
evL = events; evL.InTrial = low;
PI = pairEpsychTrials(trials, evL, Fs, InvertedLines=["InTrial" "NotALine"], NumSamples=N);
check(isequal(PI.interval, (1:n).') && isequal(PI.onsetSample, rows(:, 1)) && isequal(PI.offsetSample, rows(:, 2)) ...
    && isequal(PI.invertedLines, "InTrial") && ~PI.countMismatch, 'an inverted trial line: onset = falling edge, unknown names ignored');
lowIdle = low;                                              % the line went high (idle) only 3 s before trial 1:
lowIdle(1, 1) = (rows(1, 1) - 3 * Fs) / Fs;                 % low (= on) from the recording start until then
evI = events; evI.InTrial = lowIdle;
PI2 = pairEpsychTrials(trials, evI, Fs, InvertedLines="InTrial", NumSamples=N, Warn=false);
check(PI2.countMismatch && PI2.nIntervals == n + 1 && isequal(PI2.partialIntervals, 1) && PI2.onsetSample(1) == 1 ...
    && contains(PI2.warnings, "before Epsych2 had set the line to its idle level"), ...
    'an inverted line idle at the recording start makes a partial phantom interval');
PI3 = pairEpsychTrials(trials, evI, Fs, InvertedLines="InTrial", NumSamples=N, CutIntervals=[1 0]);
check(~PI3.countMismatch && isequal(PI3.interval, (2:n+1).') && isequal(PI3.onsetSample, rows(:, 1)) && all(PI3.flag == "ok"), ...
    'cutting the phantom interval pairs every trial with its own');
check(strcmp(errorId(@() pairEpsychTrials(trials, evL, Fs, InvertedLines="InTrial")), 'digitalLinePolarity:NumSamples'), ...
    'inverting a line needs NumSamples');
[ev2, ap] = digitalLinePolarity(struct('a', [0.002 0.004; 0.008 0.010], 'b', zeros(0, 2)), ["a" "b"], 12, 1000);
check(isequal(round(ev2.a * 1000), [1 1; 5 7; 11 12]) && isequal(ev2.b, [1 12] / 1000) && isequal(ap, ["a" "b"]), ...
    'digitalLinePolarity: low runs incl. the recording edges; a never-high line is one long event');

% ---- recording fixture: one dig-in line "din0" ------------------------------
fprintf('\n== 6. EphysDataset: digitalEvents, pairTrials, setTrialPairing ==\n');
Fs2 = 1000; spb = 128; nSamp = 64 * spb; numAmp = 2;
k = 5;
onR = (1:k).' * 1200; offR = onR + 300;                                 % rows
digRaw = zeros(1, nSamp);
for i = 1:k; digRaw(onR(i):offR(i)) = 1; end
proj = fullfile(root, 'proj');
recDir = fullfile(proj, 'mouseA_260101T120000_rec'); mkdir(recDir);
rng(3);
writeSyntheticRHD(fullfile(recDir, 'mouseA_260101T120000_rec.rhd'), ...
    uint16(randi([30000 35000], numAmp, nSamp)), digRaw, Fs2, spb);
behDir = fullfile(root, 'beh'); mkdir(behDir);
tsR = t0 + seconds(offR / Fs2 + 3);
Data = struct('ToneLevel', num2cell(60 + (1:k)), 'TrialIndex', num2cell(1:k), ...
    'computerTimestamp', num2cell(tsR.'), 'isTest', num2cell(false(1, k)));
Info = struct('Subject', struct('Name', "mouseA"), 'StartTime', t0, 'FormatVersion', 2);
behFile = fullfile(behDir, 'mouseA_260101T120000.mat');
save(behFile, 'Data', 'Info');

d = EphysDataset(recDir);
d.OutputDir = fullfile(root, 'out', d.Name);
d.BehaviorFile = behFile;
tc = d.TrialConfig; tc.TrialLine = "din0"; tc.SignalFs = struct('LFP', 250);
d.TrialConfig = tc;
E = d.digitalEvents();
cacheFile = fullfile(d.outputFolder(), d.Name + "_events.mat");
check(E.source == "read" && isfile(cacheFile) && isequal(round(E.events.din0 * Fs2), [onR offR]) && E.nSamples == nSamp, ...
    'digitalEvents reads the line and caches it');
E2 = d.digitalEvents();
check(E2.source == "cache" && isequal(E2.events, E.events), 'second call uses the cache');
P = d.pairTrials();
check(P.status == "unreviewed" && ~P.recorded && ~P.stale && isequal(P.interval, (1:k).') && ~P.countMismatch ...
    && isequal(P.onsetSample, onR) && isequal(P.cutTrials, [0 0]) && P.nSamples == nSamp, 'pairTrials pairs the recording in order');
[fb, saved] = d.setTrialPairing(P);
check(fb == "" && saved && ~isfile(fullfile(d.outputFolder(), d.Name + "_behavior.mat")), ...
    'recording a pairing writes the manifest and creates no behavior file');
copyfile(d.manifestFile(), d.manifestFile() + ".bak");
writeText(d.manifestFile(), 'not json');
ws = warning('off', 'EphysDataset:writeManifest:Kept');
[~, savedBad] = d.setTrialPairing(P);
warning(ws);
check(~savedBad && strcmp(fileread(d.manifestFile()), 'not json'), ...
    'setTrialPairing says when the manifest is not written (an unreadable one is kept)');
movefile(d.manifestFile() + ".bak", d.manifestFile(), 'f');
mf = readJsonFile(d.manifestFile());
check(isfield(mf.behavior, 'pairing') && strcmp(mf.behavior.pairing.status, 'unreviewed') ...
    && isequal(mf.behavior.pairing.cut_trials(:).', [0 0]) && isequal(mf.behavior.pairing.cut_intervals(:).', [0 0]) ...
    && ~isfield(mf.behavior.pairing, 'assignment'), 'unreviewed pairing (its cuts) written to the manifest');

PA = d.pairTrials(Cuts=struct('trials', [1 0], 'intervals', [0 0]), Warn=false);
check(PA.countMismatch && isnan(PA.interval(1)) && PA.interval(2) == 1 && PA.flag(1) == "cut" && isequal(PA.unpairedIntervals, k), ...
    'cuts given to pairTrials are applied');
d.setTrialPairing(PA, "approved");
dR = EphysDataset(recDir);
dR.OutputDir = d.OutputDir; dR.TrialConfig = d.TrialConfig;
dR.applyManifest();
PR = dR.pairTrials(Warn=false);
check(dR.TrialPairing.status == "approved" && isequal(dR.TrialPairing.cut_trials, [1 0]) && PR.recorded ...
    && PR.status == "approved" && isequal(PR.cutTrials, [1 0]) && isnan(PR.interval(1)), ...
    'an approved pairing with cuts survives the manifest round trip');
check(strcmp(errorId(@() dR.pairTrials(Cuts="bogus")), 'EphysDataset:pairTrials:Cuts'), 'an unknown Cuts mode is refused');
PN = dR.pairTrials(Cuts="none");
check(~PN.recorded && ~PN.stale && isequal(PN.cutTrials, [0 0]) && PN.status == "unreviewed", ...
    'Cuts="none" ignores the record without calling it stale');
tc = dR.TrialConfig; tc.InvertedLines = "din0"; dR.TrialConfig = tc;
PS = dR.pairTrials(Warn=false);
check(PS.stale && ~PS.recorded && PS.status == "unreviewed" && isequal(PS.cutTrials, [0 0]), ...
    'a changed line polarity makes the recorded pairing stale and drops its cuts');

% autoApproveTrialPairing: only a pairing without cuts whose counts match.
dA = EphysDataset(recDir);
dA.OutputDir = d.OutputDir; dA.TrialConfig = d.TrialConfig;
dA.applyManifest();                                          % approved, cuts [1 0]
[PA1, tf1] = dA.autoApproveTrialPairing(dA.pairTrials(Warn=false));
check(~tf1 && PA1.status == "approved" && ~PA1.autoApproved && ~dA.TrialPairing.auto_approved, ...
    'auto approval leaves an approved pairing as it is');
dA.setTrialPairing(dA.pairTrials(Warn=false), "unreviewed");
[PA2, tf2] = dA.autoApproveTrialPairing(dA.pairTrials(Warn=false));
check(~tf2 && PA2.status == "unreviewed" && dA.TrialPairing.status == "unreviewed", ...
    'auto approval leaves a pairing with cuts for review');
[PA3, tf3] = dA.autoApproveTrialPairing(dA.pairTrials(Cuts="none", Warn=false));
mfA = readJsonFile(dA.manifestFile());
check(tf3 && PA3.status == "approved" && PA3.autoApproved && PA3.recorded && isequal(dA.TrialPairing.cut_trials, [0 0]) ...
    && strcmp(mfA.behavior.pairing.status, 'approved') && mfA.behavior.pairing.auto_approved, ...
    'a pairing whose counts match without cuts is approved and marked automatic in the manifest');
dB = EphysDataset(recDir);
dB.OutputDir = d.OutputDir; dB.TrialConfig = d.TrialConfig;
dB.applyManifest();
PB = dB.pairTrials(Warn=false);
check(dB.TrialPairing.auto_approved && PB.recorded && PB.status == "approved" && PB.autoApproved, ...
    'the automatic approval survives the manifest round trip');
dB.setTrialPairing(PB, "approved");
check(~dB.TrialPairing.auto_approved, 'approving by hand clears the automatic mark');

o = d.behaviorToMat(Pairing=PR);
B = load(o.file);
bt = B.behavior.trials;
lfpRow = round((onR(1) - 1) / Fs2 * 250) + 1;       % row 1200 lies at 1.199 s: 250 Hz row 301 (1.200 s)
check(o.paired && all(ismember(["ToneLevel" "TrialOnset" "TrialOnsetSample" "TrialOnsetSample_LFP" "PairingFlag"], string(bt.Properties.VariableNames))) ...
    && isequaln(bt.TrialOnsetSample, [NaN; onR(1:k-1)]) && bt.TrialOnsetSample_LFP(2) == lfpRow && lfpRow == 301 ...
    && B.behavior.pairing.status == "approved" && B.behavior.pairing.signalFs.LFP == 250 ...
    && isequal(B.behavior.pairing.cutTrials, [1 0]) && B.behavior.pairing.countMismatch, ...
    'behaviorToMat writes the pairing columns and summary');
check(isempty(d.behaviorStruct().pairing), 'behaviorStruct without a pairing leaves trials untouched');
check(startsWith(matHeader(o.file), "MATLAB 5.0 MAT-file") && isequal(sort(string(who('-file', o.file))), ["behavior"; "conversion"; "pairing"]) ...
    && B.pairing.status == "approved" && isequal(B.pairing, B.behavior.pairing), ...
    'the behavior file is -v7 (quick to load) and carries a small copy of the pairing');
check(isfield(B.behavior.pairing, 'autoApproved') && ~B.behavior.pairing.autoApproved, ...
    'the behavior file says whether the approval was automatic');
check(d.setTrialPairing(PR, "approved") == "", 'a behavior file that already carries the recorded pairing is left alone');
fb = d.setTrialPairing(PR, "unreviewed");
B = load(o.file);
check(fb == o.file && B.behavior.pairing.status == "unreviewed" && isequal(B.behavior.pairing.cutTrials, [1 0]) ...
    && isnan(B.behavior.trials.TrialOnsetSample(1)), 'a new status of the same pairing is written into the behavior file');
[~, tfZ] = d.autoApproveTrialPairing(d.pairTrials(Cuts="none", Warn=false));
B = load(o.file);
check(tfZ && B.behavior.pairing.status == "approved" && B.behavior.pairing.autoApproved ...
    && isequal(B.behavior.pairing.cutTrials, [0 0]) && isequal(B.behavior.trials.TrialOnsetSample, onR), ...
    'an automatic approval rewrites the behavior file with the approved pairing');

fprintf('\n== 6b. dropped interval in the record; auto-approval checks; another session''s fingerprint ==\n');
dD = EphysDataset(recDir);
dD.OutputDir = fullfile(root, 'outdrop', dD.Name);
dD.BehaviorFile = behFile;
dD.TrialConfig = d.TrialConfig;
PD = dD.pairTrials(Cuts=struct('trials', [0 0], 'intervals', [0 0], 'drop', 2), Warn=false);
check(PD.countMismatch && isequal(PD.dropIntervals, 2) && isequal(PD.interval(1:4), [1; 3; 4; 5]) && isnan(PD.interval(5)) ...
    && PD.flag(5) == "unpaired", 'pairTrials takes Cuts.drop: interval 2 leaves the pairing');
dD.setTrialPairing(PD, "approved");
mfD = readJsonFile(dD.manifestFile());
dD2 = EphysDataset(recDir);
dD2.OutputDir = dD.OutputDir; dD2.TrialConfig = d.TrialConfig;
dD2.applyManifest();
PD2 = dD2.pairTrials(Warn=false);
check(isequal(mfD.behavior.pairing.drop_intervals(:).', 2) && isequal(dD2.TrialPairing.drop_intervals, 2) ...
    && PD2.recorded && PD2.status == "approved" && isequal(PD2.dropIntervals, 2), ...
    'an approved pairing with a dropped interval survives the manifest round trip');
PD3 = dD2.pairTrials(Cuts=struct('trials', [1 0], 'intervals', [0 0]), Warn=false);
PD4 = dD2.pairTrials(Cuts=struct('trials', [0 0], 'intervals', [0 0], 'drop', zeros(1, 0)), Warn=false);
check(isequal(PD3.dropIntervals, 2) && isempty(PD4.dropIntervals) && ~PD4.countMismatch, ...
    'cuts given without drop (the Trials tab) keep the recorded drops; drop=[] clears them');
PZ = dD2.pairTrials(Cuts="none", Warn=false);                % unreviewed, no cuts, counts match
PZ.timingMismatch = 3;
[~, tfM] = dD2.autoApproveTrialPairing(PZ);
PZ.timingMismatch = 0; PZ.flag(1) = "partial";
[~, tfP] = dD2.autoApproveTrialPairing(PZ);
PZ.flag(1) = "ok"; PZ.dropIntervals = 2;
[~, tfD] = dD2.autoApproveTrialPairing(PZ);
check(PZ.status == "unreviewed" && ~tfM && ~tfP && ~tfD && dD2.TrialPairing.status == "approved" && ~dD2.TrialPairing.auto_approved, ...
    'auto-approval refuses a timing mismatch, a partial edge interval and a pairing that dropped an interval');
S73 = dD.behaviorToMat(File=fullfile(root, 'beh73.mat'), MatVersion="-v7.3", Pairing=PD);
check(startsWith(matHeader(S73.file), "MATLAB 7.3 MAT-file") && S73.paired, 'MatVersion="-v7.3" is still available');
% a different session with the same file name and trial count must not inherit the approval
S2 = struct('Data', Data, 'Info', Info);
for i = 1:k; S2.Data(i).computerTimestamp = Data(i).computerTimestamp + days(1); end
S2.Info.StartTime = t0 + days(1);
beh2 = fullfile(root, 'beh_other'); mkdir(beh2);
save(fullfile(beh2, 'mouseA_260101T120000.mat'), '-struct', 'S2');           % other start time and timestamps
S3 = struct('Data', Data, 'Info', Info);
for i = 1:k; S3.Data(i).computerTimestamp = Data(i).computerTimestamp + seconds(2); end
beh3 = fullfile(root, 'beh_later'); mkdir(beh3);
save(fullfile(beh3, 'mouseA_260101T120000.mat'), '-struct', 'S3');           % same start time, later timestamps
dD2.BehaviorFile = string(fullfile(beh2, 'mouseA_260101T120000.mat'));
PF = dD2.pairTrials(Warn=false);
dD2.BehaviorFile = string(fullfile(beh3, 'mouseA_260101T120000.mat'));
PF3 = dD2.pairTrials(Warn=false);
dD2.BehaviorFile = behFile;
PF0 = dD2.pairTrials(Warn=false);
check(PF.stale && ~PF.recorded && PF.status == "unreviewed" && isempty(PF.dropIntervals) ...
    && PF3.stale && ~PF3.recorded && PF3.status == "unreviewed" && PF0.recorded && PF0.status == "approved", ...
    'the fingerprint holds the start time and the first timestamp: another session does not inherit the cuts, the same one does');

fprintf('\n== 7. inverted polarity in the extract events ==\n');
lowRows = [[1; offR + 1], [onR - 1; nSamp]];
if license('test', 'Signal_Toolbox')
    xf = fullfile(root, 'inv_extract.mat');
    d.toMat(File=xf, SignalOptions=struct('dataTypeOut', "LFP", 'LFP_Fs', 250, 'invertedLines', ["din0" "nope"]));
    X = load(xf, 'events', 'info');
    check(isequal(round(X.events.din0 * Fs2), lowRows) && isequal(X.info.invertedLines, "din0"), ...
        'toMat events of an inverted line: onset = falling edge, offset = last low sample');
else
    fprintf('  (toMat check skipped: Signal Processing Toolbox not available)\n');
end
cx = ChronuxDataset(d, Signal="RAW", SignalOptions=struct('invertedLines', "din0"));
cx.loadSignal();
check(isequal(round(cx.Events.din0 * Fs2), lowRows), 'ChronuxDataset RAW honours invertedLines');
dI = EphysDataset(recDir);                                  % the line polarity and naming of TrialConfig
dI.OutputDir = d.OutputDir;
tcI = d.TrialConfig; tcI.InvertedLines = "din0"; dI.TrialConfig = tcI;
cx = ChronuxDataset(dI, Signal="RAW");
cx.loadSignal();
check(isequal(round(cx.Events.din0 * Fs2), lowRows) && isequal(cx.Info.invertedLines, "din0"), ...
    'ChronuxDataset RAW takes the line polarity from TrialConfig when SignalOptions leaves it out');
cx = ChronuxDataset(dI, Signal="RAW", SignalOptions=struct('invertedLines', string.empty(1, 0)));
cx.loadSignal();
check(isequal(round(cx.Events.din0 * Fs2), [onR offR]), 'an explicit empty invertedLines overrides TrialConfig');
tcN = tcI; tcN.LabelField = "native"; tcN.LineNames = "DIN-00=Trig"; tcN.InvertedLines = "Trig";
dI.TrialConfig = tcN;
cx = ChronuxDataset(dI, Signal="RAW");
cx.loadSignal();
check(isequal(fieldnames(cx.Events), {'Trig'}) && isequal(round(cx.Events.Trig * Fs2), lowRows) ...
    && isequal(cx.ChannelLabels, ["A-000" "A-001"]), ...
    'ChronuxDataset RAW takes the label field and line names from TrialConfig too');
if license('test', 'Signal_Toolbox')
    % These two need deriveSignals to take labelField / lineNames /
    % invertedLines it is not given from TrialConfig, as readData does.
    dI.TrialConfig = tcI;
    cx = ChronuxDataset(dI, Signal="LFP", SignalOptions=struct('LFP_Fs', 250));
    cx.loadSignal();
    check(isequal(round(cx.Events.din0 * Fs2), lowRows), ...
        'ChronuxDataset LFP takes the line polarity from TrialConfig (deriveSignals falls back to it)');
    dI.TrialConfig = tcN;
    cx = ChronuxDataset(dI, Signal="LFP", SignalOptions=struct('LFP_Fs', 250));
    cx.loadSignal();
    check(isequal(fieldnames(cx.Events), {'Trig'}) && isequal(round(cx.Events.Trig * Fs2), lowRows) ...
        && isequal(cx.ChannelLabels, ["A-000" "A-001"]), ...
        'ChronuxDataset LFP takes the label field and line names from TrialConfig (deriveSignals falls back)');
end

fprintf('\n== 8. pipeline behavior step ==\n');
delete(d.manifestFile());
cfg = EphysPipelineConfig();
cfg.Project.Root = proj;
cfg.Project.OutputRoot = fullfile(root, 'pipe');
cfg.Behavior.Enabled = true;
cfg.Behavior.SearchDirs = behDir;
cfg.Behavior.TrialLine = "din0";
cfg.Signals.LFP_Fs = 500;
pipe = EphysPipeline(cfg);
pipe.LogFcn = [];
pipe.checkBehavior();
R = pipe.Results;
dp = pipe.selected();
check(any(R.Step == "behavior:pairing" & R.Status == "needs review") && dp.TrialPairing.status == "unreviewed", ...
    'a new pairing is recorded and reported as needing review');
B = load(pipe.outputPathFor("behavior", dp));
check(ismember("TrialOnsetSample_LFP", string(B.behavior.trials.Properties.VariableNames)) ...
    && B.behavior.trials.TrialOnsetSample_LFP(1) == round((onR(1) / Fs2 - 1 / Fs2) * 500) + 1, ...
    'the behavior file carries the pairing (LFP rate from the config)');
dp.setTrialPairing(dp.pairTrials(), "approved");
B = load(pipe.outputPathFor("behavior", dp));
check(B.behavior.pairing.status == "approved", 'approving after the behavior step brings its behavior file up to date');
pipe.reset();
pipe.checkBehavior();
check(any(pipe.Results.Step == "behavior:pairing" & pipe.Results.Status == "approved"), 'an approved pairing is reused');
T = pipe.plan(Steps="behavior");
check(any(contains(T.Note, "recorded pairing: approved")), 'plan mentions the recorded pairing');
dp.setTrialPairing([]);
cfg.Behavior.AutoApprove = true;        % stays on below: a count mismatch must still need review
pipe.Config = cfg;
pipe.reset();
pipe.checkBehavior();
check(any(pipe.Results.Step == "behavior:pairing" & pipe.Results.Status == "auto-approved") ...
    && dp.TrialPairing.status == "approved" && dp.TrialPairing.auto_approved, ...
    'with AutoApprove a new pairing whose counts match is approved automatically');
pipe.reset();
pipe.checkBehavior();
T = pipe.plan(Steps="behavior");
check(any(pipe.Results.Step == "behavior:pairing" & pipe.Results.Status == "auto-approved") ...
    && any(contains(T.Note, "approving matching counts")), 'a reused automatic approval is reported as such, and plan mentions AutoApprove');

% A session with one trial more than the line has intervals: the approved
% record no longer matches and the mismatch is reported.
behDir2 = fullfile(root, 'beh2'); mkdir(behDir2);
S6 = struct('Data', [Data, Data(end)], 'Info', Info);
S6.Data(end).TrialIndex = k + 1;
behFile6 = fullfile(behDir2, 'mouseA_260101T120000.mat');
save(behFile6, '-struct', 'S6');
dp.BehaviorFile = behFile6;
dp.writeManifest();
pipe.LogFcn = @logCapture;
pipe.reset();
pipe.checkBehavior();
pipe.LogFcn = [];
R6 = pipe.Results;
row = R6(R6.Step == "behavior:pairing", :);
check(height(row) == 1 && row.Status == "count mismatch" && contains(row.Message, "6 trial(s) but the din0 line has 5") ...
    && any(contains(logLines, "WARNING")) && dp.TrialPairing.status == "unreviewed" && isequal(dp.TrialPairing.cut_trials, [0 0]), ...
    'a count mismatch is reported as such, logged as a warning, and the stale record replaced');
B6 = load(pipe.outputPathFor("behavior", dp));
check(height(B6.behavior.trials) == k + 1 && B6.behavior.trials.PairingFlag(end) == "unpaired" && B6.behavior.pairing.countMismatch, ...
    'the behavior file is still written, with the last trial unpaired');

cfg.Behavior.TrialLine = "nope";
pipe.Config = cfg;
pipe.reset();
pipe.checkBehavior();
check(any(pipe.Results.Step == "behavior:pairing" & pipe.Results.Status == "no trial line") ...
    && any(pipe.Results.Step == "behavior:file" & pipe.Results.Status == "done"), ...
    'a missing trial line is reported and the behavior file is still written');
issues = EphysPipelineConfig().validate(CheckPaths=false);
cfgBad = EphysPipelineConfig(); cfgBad.Behavior.Enabled = true; cfgBad.Behavior.TrialLine = "";
issuesBad = cfgBad.validate(CheckPaths=false);
check(~any(issues.Field == "TrialLine") && any(issuesBad.Field == "TrialLine") ...
    && ~isfield(EphysPipelineConfig().Behavior, 'AlignToleranceS'), 'validate requires a trial line when pairing; no tolerance setting remains');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_TrialPairing:Failures', '%d checks failed.', nFail);
end
end


function writeText(file, txt)
fid = fopen(file, 'w');
fwrite(fid, char(txt), 'char');
fclose(fid);
end


function h = matHeader(file)
%matHeader  The first characters of a MAT-file: "MATLAB 5.0 MAT-file" (-v7) or "MATLAB 7.3 MAT-file" (-v7.3).
fid = fopen(file, 'r');
h = string(fread(fid, [1 19], '*char'));
fclose(fid);
end
