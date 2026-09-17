function test_TrialPairing()
%test_TrialPairing  Verification suite for Epsych2 trial <-> digital-line pairing.
%   Checks pairEpsychTrials on synthetic trials and events (equal counts, a
%   recording started late or stopped early with partial intervals at the
%   edges, the count-mismatch warning, the cuts that resolve it, an inverted
%   line idle at the recording start, inverted lines, nested lines,
%   derived-signal samples), then EphysDataset.digitalEvents / pairTrials /
%   setTrialPairing / behaviorToMat on a synthetic RHD recording,
%   inverted-line events in toMat and ChronuxDataset, and the pipeline's
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
check(isequal(P.onsetSample, round(on * Fs)) && isequal(P.offsetSample, round(off * Fs)), 'samples are rows at Fs (t = row/Fs)');
check(isfield(P.signalSamples, 'LFP') && ~isfield(P.signalSamples, 'Bad') && isequal(P.signalSamples.LFP(:, 1), round(on * 500)), ...
    'derived-signal samples round(t*Fs) for valid rates only');
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
d.setTrialPairing(P);
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

o = d.behaviorToMat(Pairing=PR);
B = load(o.file);
bt = B.behavior.trials;
check(o.paired && all(ismember(["ToneLevel" "TrialOnset" "TrialOnsetSample" "TrialOnsetSample_LFP" "PairingFlag"], string(bt.Properties.VariableNames))) ...
    && isequaln(bt.TrialOnsetSample, [NaN; onR(1:k-1)]) && bt.TrialOnsetSample_LFP(2) == round(onR(1) / Fs2 * 250) ...
    && B.behavior.pairing.status == "approved" && B.behavior.pairing.signalFs.LFP == 250 ...
    && isequal(B.behavior.pairing.cutTrials, [1 0]) && B.behavior.pairing.countMismatch, ...
    'behaviorToMat writes the pairing columns and summary');
check(isempty(d.behaviorStruct().pairing), 'behaviorStruct without a pairing leaves trials untouched');

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
    && B.behavior.trials.TrialOnsetSample_LFP(1) == round(onR(1) / Fs2 * 500), 'the behavior file carries the pairing (LFP rate from the config)');
dp.setTrialPairing(dp.pairTrials(), "approved");
pipe.reset();
pipe.checkBehavior();
check(any(pipe.Results.Step == "behavior:pairing" & pipe.Results.Status == "approved"), 'an approved pairing is reused');
T = pipe.plan(Steps="behavior");
check(any(contains(T.Note, "recorded pairing: approved")), 'plan mentions the recorded pairing');

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
