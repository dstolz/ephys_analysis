function test_TrialPairing()
%test_TrialPairing  Verification suite for Epsych2 trial <-> digital-line pairing.
%   Checks pairEpsychTrials on synthetic trials and events (equal counts,
%   late timestamps, phantom and missing TTLs, no timestamps, a manual
%   assignment, inverted lines, nested lines, derived-signal samples), then
%   EphysDataset.digitalEvents / pairTrials / setTrialPairing / behaviorToMat
%   on a synthetic RHD recording, inverted-line events in toMat and
%   ChronuxDataset, and the pipeline's behavior step (record,
%   approve, reuse, stale after a config change).
%
%   Usage:  test_TrialPairing

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

root = fullfile(tempdir, sprintf('Pairing_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
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

% ---- synthetic session: 20 trials, 8-10.4 s apart, 3 s long ---------------
Fs = 1000;
n = 20;
on = 5 + cumsum([0; 8 + mod((1:n-1).' * 7, 5) * 0.6]);    % uneven gaps, like real sessions
off = on + 3;
iv = [on off];
t0 = datetime(2026, 1, 1, 12, 0, 0);
lag = zeros(n, 1); lag([4 11]) = [1.5 6];            % Epsych stamps some trials late
trials = table((1:n).', 60 + (1:n).', t0 + seconds(off + 20 + lag), ...
    'VariableNames', {'TrialIndex', 'ToneLevel', 'computerTimestamp'});
stim = [on + 1, on + 1.2; on(3) + 2, on(3) + 2.1];     % trial 3 has two Stim pulses
events = struct('InTrial', iv, 'Stim', sortrows(stim), 'Reward', [off(2) + 5, off(2) + 5.5]);

fprintf('\n== 1. pairEpsychTrials: counts agree ==\n');
P = pairEpsychTrials(trials, events, Fs, SignalFs=struct('LFP', 500, 'Bad', NaN));
check(P.method == "timestamps" && isequal(P.interval, (1:n).') && P.nPaired == n, 'every trial pairs with its interval');
check(abs(P.clockOffsetS - (20 + off(1) - off(1)) + off(1)) < 1e-6 || abs(P.residual(1)) < 1e-6, 'clock offset found');
check(isequal(find(P.flag == "timestamp off"), [4; 11]) && abs(P.residual(11) - 6) < 1e-6, 'late timestamps stay paired and are flagged');
check(isequal(P.onsetSample, round(on * Fs)) && isequal(P.offsetSample, round(off * Fs)), 'samples are rows at Fs (t = row/Fs)');
check(isfield(P.signalSamples, 'LFP') && ~isfield(P.signalSamples, 'Bad') && isequal(P.signalSamples.LFP(:, 1), round(on * 500)), ...
    'derived-signal samples round(t*Fs) for valid rates only');
check(size(P.lines.Stim{3}, 1) == 2 && size(P.lines.Stim{1}, 1) == 1 && isempty(P.lines.Reward{2}) ...
    && ~isfield(P.lines, 'InTrial'), 'other lines nested per trial by overlap');
C = P.columns;
check(height(C) == n && all(ismember(["TrialInterval" "TrialOnset" "TrialOffset" "TrialOnsetSample" ...
    "TrialOffsetSample" "TrialOnsetSample_LFP" "TrialOffsetSample_LFP" "TimestampResidual" "PairingFlag" ...
    "TrialEvents" "TrialEventSamples"], string(C.Properties.VariableNames))), 'columns table has the documented variables');
check(isequal(C.TrialEventSamples(3).Stim, round(P.lines.Stim{3} * Fs)), 'TrialEventSamples mirror TrialEvents in rows');

fprintf('\n== 2. phantom, missing, early stop ==\n');
evX = events; evX.InTrial = sortrows([iv; on(7) + 4.5, on(7) + 4.6]);   % phantom TTL after trial 7
PX = pairEpsychTrials(trials, evX, Fs);
check(PX.nPaired == n && isequal(PX.unpairedIntervals, 8) && isequal(PX.interval, [1:7, 9:n+1].'), 'a phantom interval is skipped');
evM = events; evM.InTrial(12, :) = [];                                  % missing TTL for trial 12
PM = pairEpsychTrials(trials, evM, Fs);
check(isequal(PM.unpairedTrials, 12) && isequaln(PM.interval, [1:11, NaN, 12:n-1].') && PM.flag(12) == "unpaired", ...
    'a missing interval leaves that trial unpaired');
PE = pairEpsychTrials(trials(1:5, :), events, Fs);
check(isequal(PE.interval, (1:5).') && numel(PE.unpairedIntervals) == n - 5, 'a session that stopped early pairs its trials only');

fprintf('\n== 3. no timestamps, manual assignment ==\n');
PO = pairEpsychTrials(removevars(trials, 'computerTimestamp'), evX, Fs);
check(PO.method == "order" && isequal(PO.interval, (1:n).') && all(isnan(PO.residual)), 'without timestamps pair in order');
a = (1:n).'; a(2) = NaN;
PA = pairEpsychTrials(trials, events, Fs, Assignment=a);
check(PA.method == "manual" && isnan(PA.onset(2)) && isequal(PA.unpairedIntervals, 2), 'a given assignment is used as is');
err = '';
try
    pairEpsychTrials(trials, events, Fs, Assignment=[1; 1; (3:n).']);
catch ME
    err = ME.identifier;
end
check(strcmp(err, 'pairEpsychTrials:Assignment'), 'duplicate intervals in an assignment are refused');
err = '';
try
    pairEpsychTrials(trials, events, Fs, TrialLine="Nope");
catch ME
    err = ME.identifier;
end
check(strcmp(err, 'pairEpsychTrials:NoTrialLine'), 'a missing trial line is an error');

fprintf('\n== 4. inverted lines ==\n');
N = round((off(end) + 10) * Fs);
rows = round(iv * Fs);
low = [[1; rows(:, 2) + 1], [rows(:, 1) - 1; N]] / Fs;                % high runs of an inverted line
evL = events; evL.InTrial = low;
PL = pairEpsychTrials(trials, evL, Fs, InvertedLines=["InTrial" "NotALine"], NumSamples=N);
check(isequal(PL.interval, (1:n).') && isequal(PL.onsetSample, rows(:, 1)) && isequal(PL.offsetSample, rows(:, 2)) ...
    && isequal(PL.invertedLines, "InTrial"), 'an inverted trial line: onset = falling edge, unknown names ignored');
err = '';
try
    pairEpsychTrials(trials, evL, Fs, InvertedLines="InTrial");
catch ME
    err = ME.identifier;
end
check(strcmp(err, 'digitalLinePolarity:NumSamples'), 'inverting a line needs NumSamples');
[ev2, ap] = digitalLinePolarity(struct('a', [0.002 0.004; 0.008 0.010], 'b', zeros(0, 2)), ["a" "b"], 12, 1000);
check(isequal(round(ev2.a * 1000), [1 1; 5 7; 11 12]) && isequal(ev2.b, [1 12] / 1000) && isequal(ap, ["a" "b"]), ...
    'digitalLinePolarity: low runs incl. the recording edges; a never-high line is one long event');

% ---- recording fixture: one dig-in line "din0" ------------------------------
fprintf('\n== 5. EphysDataset: digitalEvents, pairTrials, setTrialPairing ==\n');
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
tsR = t0 + seconds(offR / Fs2 + 3); tsR(3) = tsR(3) + seconds(2);
Data = struct('ToneLevel', num2cell(60 + (1:k)), 'TrialIndex', num2cell(1:k), ...
    'computerTimestamp', num2cell(tsR.'), 'isTest', num2cell(false(1, k)));
Info = struct('Subject', struct('Name', "mouseA"), 'StartTime', t0, 'FormatVersion', 2); %#ok<NASGU>
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
check(P.status == "unreviewed" && ~P.recorded && isequal(P.interval, (1:k).') && P.nTimestampOff == 1 ...
    && isequal(P.onsetSample, onR), 'pairTrials pairs the recording (one late timestamp flagged)');
d.setTrialPairing(P);
m = readJsonFile(d.manifestFile());
check(isfield(m.behavior, 'pairing') && strcmp(m.behavior.pairing.status, 'unreviewed') ...
    && isequal(m.behavior.pairing.assignment(:), (1:k).'), 'unreviewed pairing written to the manifest');

a = P.interval; a(2) = NaN;
PA = d.pairTrials(Assignment=a);
d.setTrialPairing(PA, "approved");
dR = EphysDataset(recDir);
dR.OutputDir = d.OutputDir; dR.TrialConfig = d.TrialConfig;
dR.applyManifest();
PR = dR.pairTrials();
check(dR.TrialPairing.status == "approved" && PR.recorded && PR.status == "approved" && PR.method == "manual" ...
    && isnan(PR.interval(2)), 'an approved edited pairing survives the manifest round trip (NaN kept)');
tc = dR.TrialConfig; tc.InvertedLines = "din0"; dR.TrialConfig = tc;
PS = dR.pairTrials();
check(PS.stale && ~PS.recorded && PS.status == "unreviewed", 'a changed line polarity makes the recorded pairing stale');

o = d.behaviorToMat(Pairing=PR);
B = load(o.file);
bt = B.behavior.trials;
check(o.paired && all(ismember(["ToneLevel" "TrialOnset" "TrialOnsetSample" "TrialOnsetSample_LFP"], string(bt.Properties.VariableNames))) ...
    && isequal(bt.TrialOnsetSample([1 3:k]), onR([1 3:k])) && isequal(bt.TrialOnsetSample_LFP(1), round(onR(1) / Fs2 * 250)) ...
    && B.behavior.pairing.status == "approved" && B.behavior.pairing.signalFs.LFP == 250, ...
    'behaviorToMat writes the pairing columns and summary');
check(isempty(d.behaviorStruct().pairing), 'behaviorStruct without a pairing leaves trials untouched');

fprintf('\n== 5b. inverted polarity in the extract events ==\n');
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

fprintf('\n== 6. pipeline behavior step ==\n');
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
check(~any(issues.Field == "TrialLine") && any(issuesBad.Field == "TrialLine"), 'validate requires a trial line when pairing');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_TrialPairing:Failures', '%d checks failed.', nFail);
end
end
