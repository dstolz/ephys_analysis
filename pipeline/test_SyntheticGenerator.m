function test_SyntheticGenerator()
%test_SyntheticGenerator  Verification suite for the design-driven synthetic generator and the Synthetic tab.
%   Checks SyntheticDesign (defaults, validation, JSON round trips); that
%   the built-in task still writes its driven / suppressed units and its
%   evoked potential; that responses and LFP sit exactly at their latency
%   after the edge (a response never starts early); that PreviewOnly writes
%   nothing and previews exactly the spikes then written; the schedule
%   from a dataset's Epsych2 session with its recorded lines (identical
%   lines, the session copy, the pairing, parameter tuning, phase-locked vs
%   induced oscillations, MaxDuration) and rebuilt from the session alone
%   (expressions, custom lines, rejected expressions); and the app's
%   Synthetic tab headlessly (task and dataset sources, preview,
%   generate, rescan, preferences; the user's preferences are restored).
%
%   Usage:  test_SyntheticGenerator

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));
addpath(genpath(fullfile(fileparts(here), 'vendor')));

root = fullfile(tempdir, sprintf('SynthGen_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
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

taskLines = ["Trough" "Platform" "Stim" "InTrial" "RespWindow" "Commutator"];

fprintf('\n== 1. SyntheticDesign ==\n');
D = SyntheticDesign.builtIn(8);
check(height(D.Units) == 4 && height(D.LFP) == 1 && isequal(D.Units.Event.', ["" "Stim" "Stim" "Stim"]) ...
    && isnan(D.Units.Gain(2)) && D.Units.Gain(3) == 0.3 && D.LFP.Kind == "evoked" && D.LFP.AmplitudeUV == -150, ...
    'builtIn: half the units driven by Stim, the third suppressed, an evoked potential');
check(isempty(D.validate(taskLines, ["Depth" "TrialType"], 8, 10000)) && isequal(D.usedLines(), "Stim"), ...
    'builtIn validates against the task''s lines');
bad = D;
bad.Units.Event(1) = "Nope";
bad.Units.Channel(2) = 99;
bad.Units.Parameter(4) = "Loudness";
bad.LFP = [bad.LFP; SyntheticDesign.newLFP("oscillation", "Stim", "fast")];
bad.LFP.FrequencyHz(2) = 6000;
issues = bad.validate(taskLines, ["Depth" "TrialType"], 8, 10000);
check(numel(issues) == 4 && any(contains(issues, """Nope""")) && any(contains(issues, "Channel 99")) ...
    && any(contains(issues, """Loudness""")) && any(contains(issues, "half the sample rate")), ...
    'validate names an unknown line, a channel beyond the recording, an unknown parameter and a frequency above Nyquist');
check(strcmp(errorId(@() makeSyntheticRecording(fullfile(root, 'x'), Design=bad, Fs=10000, NumChannels=8, NumTrials=4, PreviewOnly=true)), ...
    'syntheticModel:Design'), 'a design that does not validate is refused before anything is written');
D.Units = [D.Units; SyntheticDesign.newUnit("tone", "Stim")];
D.Units.Parameter(end) = "Depth";
D.Background.LineFreqHz = 50;
f = fullfile(root, 'design.json');
D.save(f);
D2 = SyntheticDesign.load(f);
D3 = SyntheticDesign.fromStruct(jsondecode(jsonencode(D.toStruct())));   % the preferences path: NaN as null
check(isequaln(D2.Units, D.Units) && isequaln(D2.LFP, D.LFP) && isequal(D2.Background, D.Background) ...
    && isequaln(D3.Units, D.Units) && isequaln(D3.LFP, D.LFP), 'save / load and the preferences'' JSON keep the design (NaN included)');
check(strcmp(errorId(@() SyntheticDesign.load(fullfile(root, 'nope.json'))), 'readJsonFile:NotFound'), 'load of a missing file errors');

fprintf('\n== 2. built-in task: the default model ==\n');
Fs = 10000; nCh = 8;
f2 = fullfile(root, 'task', 'SYN-01_260101_120000');
T = makeSyntheticRecording(f2, Subject="SYN-01", Fs=Fs, NumChannels=nCh, NumTrials=20, FileSeconds=10, Seed=4);
check(isequal([T.units.modulation], ["none" "driven" "suppressed" "driven"]) && all([T.units.event] == ["" "Stim" "Stim" "Stim"]), ...
    'the default units: unmodulated, driven, suppressed, driven');
stim = T.events.Stim;
inStim = @(s) any((s - 1) / Fs >= stim(:, 1).' - 1 / Fs & (s - 1) / Fs < stim(:, 2).', 2);
stimTime = sum(stim(:, 2) - stim(:, 1));
ok = true;
for u = find([T.units.modulation] == "driven")
    s = double(T.units(u).samples);
    rIn = nnz(inStim(s)) / stimTime; rOut = nnz(~inStim(s)) / (T.duration - stimTime);
    ok = ok && rIn > 1.8 * rOut;
end
s = double(T.units(3).samples);
check(ok && nnz(inStim(s)) / stimTime < 0.6 * nnz(~inStim(s)) / (T.duration - stimTime), ...
    'driven units fire more while Stim is on, the suppressed one less');
ds = EphysDataset(T.folder); ds.applyManifest();
[~, mid] = max(T.lfp(1).gain);
on = round(stim(:, 1) * Fs);                        % the onset rows
w = round(0.2 * Fs);
art = round(T.artifacts * Fs);
on = on(~any(on + w >= art(:, 1).' & on <= art(:, 2).', 2));   % windows clear of the two artifacts
X = zeros(w, numel(on));
for k = 1:numel(on)
    x = ds.readWindowUV(on(k) - 1, w, Reference=false);
    X(:, k) = x(:, mid);
end
[mn, at] = min(mean(X, 2) - mean(X(1:5, :), 'all'));
check(mn < -80 && abs((at - 1) / Fs - 0.045) <= 0.012, ...
    sprintf('the evoked potential reads back: %.0f uV at %.1f ms after Stim onset (model: -150 uV at 45 ms)', mn, 1000 * (at - 1) / Fs));
J = readJsonFile(T.designFile);
Dj = SyntheticDesign.fromStruct(J.design);
check(isfile(T.designFile) && J.seed == 4 && string(J.schedule.kind) == "task" && isequaln(Dj.Units, SyntheticDesign.builtIn(nCh).Units), ...
    '<Name>_synthetic.json records the seed, the schedule and the design');

fprintf('\n== 3. timing: responses sit at their latency after the edge ==\n');
Dt = SyntheticDesign();
Dt.Background.RhythmScale = 0;
u1 = SyntheticDesign.newUnit("lat", "Stim");
u1.Shape = "sustained"; u1.Gain = 300; u1.BaselineHz = 0.5; u1.LatencyMs = 20; u1.DurationMs = 10; u1.JitterMs = 0; u1.Channel = 3;
u2 = SyntheticDesign.newUnit("off", "InTrial");
u2.Edge = "offset"; u2.Shape = "sustained"; u2.Gain = 300; u2.BaselineHz = 0.5; u2.LatencyMs = 0; u2.DurationMs = 15; u2.JitterMs = 0; u2.Channel = 6;
Dt.Units = [u1; u2];
ev = SyntheticDesign.newLFP("evoked", "Stim", "ep");
ev.LatencyMs = 30; ev.RiseMs = 10; ev.AmplitudeUV = -200; ev.JitterMs = 0; ev.Profile = "uniform";
Dt.LFP = ev;
Tp = makeSyntheticRecording(fullfile(root, 'timing'), Design=Dt, Fs=Fs, NumChannels=nCh, NumTrials=30, Seed=5, PreviewOnly=true);
M = Tp.model;
check(isequal(M.units(1).eventTimes, (M.rows.Stim(M.rows.Stim(:, 1) > 1, 1) - 1) / Fs) ...
    && isequal(M.units(2).eventTimes, (M.rows.InTrial(M.rows.InTrial(:, 2) < M.nSamp, 2) - 1) / Fs), ...
    'onsets align at (first on row - 1)/Fs, offsets at (last on row - 1)/Fs');
for u = 1:2
    q = M.units(u);
    r = (double(q.samples) - 1) / Fs - q.eventTimes.';   % every spike relative to every edge
    near = r(r >= -0.05 & r < 0.08);
    lat = q.latencyMs / 1000; dur = q.durationMs / 1000;
    inside = near >= lat - 1 / Fs & near < lat + dur;      % a spike lies up to one sample before its time
    check(nnz(inside) >= 0.9 * numel(near) && nnz(inside) > 0.5 * numel(q.eventTimes), ...
        sprintf('unit "%s": %d of %d spikes near its edges fall in [%g, %g) ms', q.name, nnz(inside), numel(near), 1000 * lat, 1000 * (lat + dur)));
    early = near(near >= -0.01 & near < lat - 1 / Fs);
    check(numel(early) <= 0.1 * numel(q.eventTimes), sprintf('unit "%s": its response never starts before the latency (%d baseline spikes there)', q.name, numel(early)));
end
tau = (0:0.0001:0.1).';
y = M.componentWave(1, tau);
[~, k] = min(y);
te = M.lfp(1).eventTimes;
n = round(0.1 * Fs);
Y = zeros(n, numel(te));
for k2 = 1:numel(te)
    x = M.window(round(te(k2) * Fs), n);
    Y(:, k2) = x(:, 1);
end
[~, kd] = min(mean(Y, 2));
check(abs(tau(k) - 0.040) < 1e-9 && abs((kd - 1) / Fs - 0.040) <= 2.5e-3, ...
    sprintf('the evoked potential peaks at latency + rise: model %.1f ms, data %.1f ms (expected 40)', 1000 * tau(k), 1000 * (kd - 1) / Fs));

fprintf('\n== 4. PreviewOnly writes nothing and previews what is written ==\n');
f4 = fullfile(root, 'preview', 'SYN-04_260101_120000');
args = {'Subject', "SYN-04", 'Design', Dt, 'Fs', 5000, 'NumChannels', 8, 'NumTrials', 6, 'Seed', 9, 'Scenario', "late-start"};
P4 = makeSyntheticRecording(f4, args{:}, PreviewOnly=true);
check(~isfolder(f4) && isfield(P4, 'model') && P4.nSamples > 0, 'PreviewOnly returns the model and writes nothing');
T4 = makeSyntheticRecording(f4, args{:});
check(isequal({P4.model.units.samples}, {T4.units.samples}) && isequal(P4.events, T4.events) ...
    && isequaln(P4.trials, T4.trials) && isequal(P4.expectedCuts, T4.expectedCuts), ...
    'the same options write exactly the previewed spikes, lines and trials');

fprintf('\n== 5. from a dataset''s Epsych2 session (recorded lines) ==\n');
S = syntheticSessionSchedule(ds);
check(S.timing == "recording" && isequal(S.lineNames, taskLines) && height(S.trials) == 20 && all(isfinite(S.trials.Onset)) ...
    && S.Fs == Fs && S.nSamples == T.nSamples && S.nChannels == nCh && ismember("Depth", string(S.trials.Properties.VariableNames)), ...
    'the schedule: the recorded lines, the paired trials with their parameters, the recording''s size');
D5 = SyntheticDesign();
D5.Background.RhythmScale = 0.3;
tu = SyntheticDesign.newUnit("tuned", "Stim");
tu.Shape = "sustained"; tu.Gain = 10; tu.BaselineHz = 3; tu.LatencyMs = 0; tu.DurationMs = NaN; tu.JitterMs = 0;
tu.Parameter = "Depth"; tu.Channel = 2;
D5.Units = tu;
lk = SyntheticDesign.newLFP("oscillation", "Stim", "locked");
lk.FrequencyHz = 40; lk.AmplitudeUV = 80; lk.LatencyMs = 0; lk.DurationMs = 300; lk.RiseMs = 20; lk.JitterMs = 0; lk.Profile = "uniform";
ind = lk; ind.Name = "induced"; ind.FrequencyHz = 25; ind.Event = "RespWindow"; ind.PhaseLocked = false;
D5.LFP = [lk; ind];
f5 = fullfile(root, 'fromSession', 'SYN-05_260101_120000');
T5 = makeSyntheticRecording(f5, Subject="SYN-05", Session=S, Design=D5, FileSeconds=10, Seed=2, WriteProbe=true);
ds5 = EphysDataset(T5.folder); ds5.applyManifest();
E0 = ds.digitalEvents(Cache=false); E5 = ds5.digitalEvents(Cache=false);
same = T5.Fs == Fs && T5.nSamples == T.nSamples && numel(T5.channelNames) == nCh;
for ln = taskLines
    same = same && isequal(E5.events.(ln), E0.events.(ln));
end
check(same, 'the synthetic recording has the source''s rate, channels, length and every line at the same rows');
L5 = load(T5.behaviorFile);
L0 = load(T.behaviorFile);
check(isequal([L5.Data.TrialIndex], [L0.Data.TrialIndex]) && isequal([L5.Data.Depth], [L0.Data.Depth]) ...
    && isequal([L5.Data.computerTimestamp], [L0.Data.computerTimestamp]) && L5.Info.Subject.Name == "SYN-05" ...
    && L5.Info.Synthetic.SourceFile == T.behaviorFile && string(L5.Info.DataFilename) == T5.behaviorFile ...
    && startsWith(T5.behaviorFile, fullfile(f5, "SYN-05_")), ...
    'a copy of the session goes with it: the trials as saved, the new subject, a note naming the source');
P5 = ds5.pairTrials(Warn=false);
check(ds5.BehaviorFile == T5.behaviorFile && P5.nPaired == 20 && ~P5.countMismatch, 'its manifest associates the copy, which pairs 20 of 20');
check(T5.probeSource == "synthetic" && endsWith(T5.probeFile, "_probe.json") && isfile(T5.probeFile) && ds5.ProbeFile == T5.probeFile, ...
    'WriteProbe writes the synthetic probe and associates it');
% tuning: the response grows with Depth
st = (double(T5.units(1).samples) - 1) / Fs;
dep = S.trials.Depth; onT = S.trials.Onset; offT = S.trials.Offset;
rate = NaN(size(T5.events.Stim, 1), 1); dv = rate;
for k = 1:size(T5.events.Stim, 1)
    a = T5.events.Stim(k, 1) - 1 / Fs; b = T5.events.Stim(k, 2);
    tr = find(onT <= a + 1 / Fs & offT >= b, 1);
    rate(k) = nnz(st >= a & st < b) / (b - a);
    dv(k) = dep(tr);
end
check(any(dv == 0) && any(dv == 1) && mean(rate(dv == 1)) > 4 * max(1, mean(rate(dv == 0))) ...
    && abs(mean(rate(dv == 0)) - 3) < 3, ...
    sprintf('tuned to Depth: %.1f Hz on catch trials (Depth 0), %.1f Hz at Depth 1 (baseline 3, gain 10)', mean(rate(dv == 0)), mean(rate(dv == 1))));
% LFP: the locked oscillation survives averaging, the induced one does not (its power does)
    function [avgAmp, trialAmp] = bandAmp(line, fHz)
        on5 = round(T5.events.(line)(:, 1) * Fs);
        nw = round(0.3 * Fs);
        tt = (0:nw-1).' / Fs;
        h = 0.5 - 0.5 * cos(2 * pi * (0:nw-1).' / (nw - 1));
        Z = zeros(nw, numel(on5));
        for kk = 1:numel(on5)
            xx = ds5.readWindowUV(on5(kk) - 1, nw, Reference=false);
            Z(:, kk) = xx(:, 1);
        end
        ph = exp(-2i * pi * fHz * tt) .* h / sum(h) * 2;
        avgAmp = abs(sum(mean(Z, 2) .* ph));
        trialAmp = mean(abs(sum(Z .* ph, 1)));
    end
[aL, tL] = bandAmp("Stim", 40);
[aI, tI] = bandAmp("RespWindow", 25);
check(aL > 25 && tL > 25 && aI < 0.4 * tI && tI > 25, ...
    sprintf('locked 40 Hz: %.0f uV in the average (%.0f per event); induced 25 Hz: %.0f uV in the average, %.0f per event', aL, tL, aI, tI));
J5 = readJsonFile(T5.designFile);
check(string(J5.schedule.source) == T.name && string(J5.schedule.timing) == "recording" && string(J5.schedule.behaviorFile) == T.behaviorFile, ...
    '<Name>_synthetic.json names the source dataset and its session');
f6 = fullfile(root, 'fromSession', 'SYN-06_260101_120000');
T6 = makeSyntheticRecording(f6, Subject="SYN-06", Session=S, Design=D5, MaxDuration=20, Fs=5000, NumChannels=4, Seed=2, SortedOutput=false);
ds6 = EphysDataset(T6.folder); ds6.applyManifest();
P6 = ds6.pairTrials(Warn=false);
check(T6.duration <= 20 && T6.duration > 19.9 && T6.Fs == 5000 && P6.countMismatch && P6.nIntervals < 20, ...
    sprintf('MaxDuration stops the recording early (%.2f s at 5 kHz): %d intervals for 20 trials, a mismatch to resolve', T6.duration, P6.nIntervals));
check(strcmp(errorId(@() makeSyntheticRecording(fullfile(root, 'y'), MaxDuration=5, PreviewOnly=true)), 'makeSyntheticRecording:MaxDuration'), ...
    'MaxDuration without a session is refused');

fprintf('\n== 6. rebuilt from the session alone ==\n');
S7 = syntheticSessionSchedule(ds, Timing="session");
tr = S7.trials;
check(S7.timing == "session" && isequal(S7.lineNames, ["InTrial" "Stim" "RespWindow" "Trough"]) && height(tr) == 20 ...
    && S7.trialDuration == "StimDelay + RespWinDelay + RespWinDur + 50", 'automatic lines from StimDelay / RespWinDelay / RespLatency');
ts = [L0.Data.computerTimestamp].';
check(max(abs(S7.events.Stim(:, 1) - (tr.Onset + tr.StimDelay / 1000))) < 1e-9 ...
    && max(abs(diff(S7.events.Stim, 1, 2) - tr.StimDur / 1000)) < 1e-9 ...
    && max(abs(diff(tr.Offset) - seconds(diff(ts)))) < 1e-6 ...
    && max(abs(tr.Offset - tr.Onset - (tr.StimDelay + tr.RespWinDelay + tr.RespWinDur + 50) / 1000)) < 1e-9 ...
    && size(S7.events.Trough, 1) == nnz(isfinite(tr.RespLatency)), ...
    'each trial ends at its computerTimestamp, Stim at StimDelay for StimDur, a Trough poke per response');
rules = table("Tone", "StimDelay + 10", "StimDur", 'VariableNames', {'Name', 'Onset', 'Duration'});
S8 = syntheticSessionSchedule(T.behaviorFile, Lines=rules, TrialDuration="3000", TrialLine="Trial");
check(isequal(S8.lineNames, ["Trial" "Tone"]) && all(abs(S8.trials.Offset - S8.trials.Onset - 3) < 1e-9) ...
    && max(abs(S8.events.Tone(:, 1) - S8.trials.Onset - (S8.trials.StimDelay + 10) / 1000)) < 1e-9, ...
    'a session file alone, with custom lines and trial line');
check(strcmp(errorId(@() syntheticSessionSchedule(ds, Timing="session", TrialDuration="StimDelay + Foo")), 'syntheticSessionSchedule:Expression') ...
    && strcmp(errorId(@() syntheticSessionSchedule(ds, Timing="session", TrialDuration="system('dir')")), 'syntheticSessionSchedule:Expression') ...
    && strcmp(errorId(@() syntheticSessionSchedule(T.behaviorFile, Timing="recording")), 'syntheticSessionSchedule:Timing'), ...
    'unknown parameters, anything but arithmetic, and recorded timing without a dataset are refused');
D8 = SyntheticDesign();
t8 = SyntheticDesign.newUnit("tone", "Tone"); t8.Channel = 2;
D8.Units = t8;
T8 = makeSyntheticRecording(fullfile(root, 'rebuilt', 'SYN-08_260101_120000'), Subject="SYN-08", Session=S8, Design=D8, ...
    Fs=5000, NumChannels=4, Format="binary", Seed=3);
ds8 = EphysDataset(T8.folder); ds8.applyManifest();
ds8.TrialConfig.TrialLine = "Trial";
P8 = ds8.pairTrials(Warn=false);
E8 = ds8.digitalEvents(Cache=false);
check(isequal(string(fieldnames(E8.events)).', ["Trial" "Tone"]) && P8.nPaired == 20 && ~P8.countMismatch ...
    && numel(T8.units(1).eventTimes) == 20, 'the rebuilt lines are written (binary layout) and pair 20 of 20 on the chosen trial line');

fprintf('\n== 7. the app''s Synthetic tab ==\n');
g = 'EphysPreprocessingApp';
savedPrefs = [];
if ispref(g); savedPrefs = getpref(g); end
prefsCleanup = onCleanup(@() restorePrefs(g, savedPrefs));
if ispref(g, 'LastConfigFile'); setpref(g, 'LastConfigFile', ''); end
if ispref(g, 'SynthOptions'); rmpref(g, 'SynthOptions'); end
app = EphysPreprocessingApp;
appCleanup = onCleanup(@() closeApp(app));
check(any(app.TabList == app.TabSynthetic) && find(app.TabList == app.TabSynthetic) == numel(app.TabList) - 1, ...
    'the Synthetic tab sits just before Clean up');
app.selectTab(app.TabSynthetic);
check(app.helpURL("tab") == app.WikiURL + "/Synthetic-Tab" && contains(app.StatusBar.Text, "Synthetic"), ...
    'its Help page and status line');
app.SynthSourceDropDown.Value = 'task';
app.onSynthSourceChanged();
app.SynthFsField.Value = 10000; app.SynthChannelsField.Value = 8; app.SynthTrialsSpinner.Value = 8;
app.SynthSeedField.Value = 11;
app.onSynthDesign("builtIn");
app.onSynthDesign("addUnit");
app.onSynthDesign("addOscillation");
Da = app.gatherSynthDesign();
check(height(Da.Units) == 5 && Da.Units.Event(5) == "Stim" && height(Da.LFP) == 2 && Da.LFP.Kind(2) == "oscillation" ...
    && ismember('Stim', app.SynthUnitsTable.ColumnFormat{2}) && ismember('Depth', app.SynthUnitsTable.ColumnFormat{13}), ...
    'Built-in design, Add unit and Add oscillation; the Event and Parameter lists hold the task''s lines and parameters');
ok = app.onSynthPreview();
Pm = app.SynthModel;
check(ok && numel(Pm.model.units) == 5 && numel(app.SynthUnitDropDown.Items) == 5 && numel(app.SynthLFPDropDown.Items) == 2 ...
    && ~isempty(app.SynthTimelineAxes.Children) && ~isempty(app.SynthRasterAxes.Children) ...
    && ~isempty(app.SynthPSTHAxes.Children) && ~isempty(app.SynthLFPAxes.Children) && ~isempty(app.SynthProfileAxes.Children), ...
    'Preview builds the model and draws the timeline, raster, PSTH, LFP and probe');
app.SynthLFPDropDown.Value = 2;
app.SynthUnitDropDown.Value = 1;
app.renderSynthPreview();
check(contains(string(app.SynthLFPAxes.Title.String), "40 Hz locked oscillation") && contains(string(app.SynthRasterAxes.XLabel.String), "InTrial onset"), ...
    'the Unit / LFP boxes choose what is drawn (an unlinked unit is shown around the trial onsets)');
out = fullfile(root, 'appOut');
app.SynthOutputField.Value = out;
Ta = app.generateSynthetic(Scan=false);
check(~isempty(Ta) && isfolder(Ta.folder) && startsWith(Ta.folder, fullfile(out, "SYNTH-01")) && isfile(Ta.behaviorFile) ...
    && isequal({Pm.model.units.samples}, {Ta.units.samples}) && isfile(Ta.probeFile), ...
    'Generate writes exactly the previewed spikes, with a synthetic probe, under <folder>\<Subject>');
Tb = app.generateSynthetic(Scan=false, Args=app.synthGeneratorArgs(), Folder=Ta.folder);
check(isempty(Tb) && contains(app.SynthStatusLabel.Text, "not empty"), 'an existing folder is not overwritten');

proj = fullfile(root, 'proj');
Sp = makeSyntheticProject(proj, Preset="small", Scenarios="clean", NumTrials=6, Seed=7);
app.RootPathField.Value = proj;
app.onScan();
app.selectDataset(1);
app.SynthSourceDropDown.Value = 'recording';
app.onSynthSourceChanged();
ok = app.onSynthLoadSource();
check(ok && app.SynthSource.timing == "recording" && app.SynthFsField.Value == Sp.datasets(1).Fs ...
    && app.SynthChannelsField.Value == 8 && string(app.SynthSubjectField.Value) == "SYNTH-01-SYN" ...
    && contains(app.SynthProbeLabel.Text, "SYNTH-01_probe.json") && contains(app.SynthProbeLabel.Text, "own"), ...
    'Load source reads the active dataset: its rate, channels, subject and own probe');
app.SynthMaxDurField.Value = 0;
ok = app.onSynthPreview();
check(ok && app.SynthModel.model.duration == Sp.datasets(1).nSamples / Sp.datasets(1).Fs, 'Preview of the dataset source covers the whole recording');
app.SynthOutputField.Value = fullfile(proj, 'synth');
n0 = app.Project.NumDatasets;
Tc = app.generateSynthetic();
d = app.currentDataset();
check(~isempty(Tc) && app.Project.NumDatasets == n0 + 1 && ~isempty(d) && EphysProject.normalizeKey(d.Folder) == EphysProject.normalizeKey(Tc.folder) ...
    && Tc.probeSource == "session" && Tc.probeFile == Sp.probeFile && d.ProbeFile == Sp.probeFile && d.BehaviorFile == Tc.behaviorFile, ...
    'written under the project root: the project is scanned again, the new dataset is active and uses the source''s probe');
check(isempty(app.SynthSource) && contains(app.SynthStatusLabel.Text, "scanned"), ...
    'the new active dataset drops the schedule read from the previous one');
app.selectDataset(find(arrayfun(@(x) x.Name == Sp.datasets(1).name, app.Project.Datasets), 1));
app.SynthSourceDropDown.Value = 'session';
app.onSynthSourceChanged();
app.SynthLinesTable.Data = cell(0, 3);
app.SynthTrialDurField.Value = '';
ok = app.onSynthLoadSource();
check(ok && app.SynthSource.timing == "session" && size(app.SynthLinesTable.Data, 1) == 3 ...
    && strcmp(app.SynthLinesTable.Data{1, 1}, 'Stim') && contains(app.SynthTrialDurField.Placeholder, "RespWinDur"), ...
    'Epsych2 session only: the automatic lines are filled in for editing');
app.onSynthDesign("removeLine");
check(isempty(app.SynthSource) && size(app.SynthLinesTable.Data, 1) == 2, 'editing the rebuilt lines drops the loaded schedule');
app.savePreferences();
v = getpref(g, 'SynthOptions');
Dp = SyntheticDesign.fromStruct(jsondecode(v.design));
check(v.source == "session" && isequal(Dp.Units.Name, app.gatherSynthDesign().Units.Name) && size(v.lines, 1) == 2, ...
    'the settings and the design are kept as preferences');

fprintf('\n== summary: %d passed, %d failed ==\n', nPass, nFail);
if nFail > 0
    error('test_SyntheticGenerator:Failed', '%d check(s) failed.', nFail);
end
end


function closeApp(app)
try
    if isvalid(app) && isvalid(app.Fig)
        app.stopKSMonitor();
        app.stopResourceMonitor();
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


function rmdirQuiet(p)
try
    if isfolder(p); rmdir(p, 's'); end
catch
end
end
