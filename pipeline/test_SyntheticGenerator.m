function test_SyntheticGenerator()
%test_SyntheticGenerator  Verification suite for the design-driven synthetic generator and the Synthetic tab.
%   Checks SyntheticDesign (defaults, validation, JSON round trips); that
%   the built-in design writes its driven / silenced units and its evoked
%   potential, read back from the files; that responses sit exactly in
%   their window after the edge, evoked potentials peak exactly halfway
%   through theirs, and a trial parameter scales both; that PreviewOnly
%   writes nothing and previews exactly the spikes then written; and the
%   app's Synthetic tab headlessly (design buttons, preview, generate,
%   rescan, preferences; the user's preferences are restored).
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

taskLines = ["Trough" "Platform" "Stim" "InTrial" "RespWindow" "Commutator"];

fprintf('\n== 1. SyntheticDesign ==\n');
D = SyntheticDesign.builtIn(8);
check(height(D.Units) == 4 && height(D.LFP) == 1 && isequal(D.Units.Event.', ["" "Stim" "Stim" "Stim"]) ...
    && isequal(D.Units.Gain.', [1 5 0 5]) && isequal(D.Units.Channel.', [1 3 5 7]) && isequal(D.Units.AmplitudeUV.', [200 153 107 60]) ...
    && isnan(D.LFP.Channel) && D.LFP.AmplitudeUV == -150 && D.LFP.LatencyMs == 20 && D.LFP.DurationMs == 50 ...
    && D.NoiseUV == 10 && D.SineUV == 100, ...
    'builtIn: units spread over the channels, two driven by Stim, the third silenced, an evoked potential on every channel');
check(isempty(D.validate(taskLines, ["Depth" "TrialType"], 8)) && isequal(D.usedLines(), "Stim"), ...
    'builtIn validates against the task''s lines');
bad = D;
bad.Units.Event(1) = "Nope";
bad.Units.Channel(2) = 99;
bad.Units.Parameter(4) = "Loudness";
bad.LFP.DurationMs = 0;
issues = bad.validate(taskLines, ["Depth" "TrialType"], 8);
check(numel(issues) == 4 && any(contains(issues, """Nope""")) && any(contains(issues, "Channel 99")) ...
    && any(contains(issues, """Loudness""")) && any(contains(issues, "DurationMs must be > 0")), ...
    'validate names an unknown line, a channel beyond the recording, an unknown parameter and an empty window');
check(strcmp(errorId(@() makeSyntheticRecording(fullfile(root, 'x'), Design=bad, Fs=10000, NumChannels=8, NumTrials=4, PreviewOnly=true)), ...
    'syntheticModel:Design'), 'a design that does not validate is refused before anything is written');
D.Units = [D.Units; SyntheticDesign.newUnit("tone", "Stim")];
D.Units.Parameter(end) = "Depth";
D.LFP.Channel = 2;
D.LFP = [D.LFP; SyntheticDesign.newLFP("Stim", "all")];   % Channel NaN: every channel
D.SineUV = 0;
f = fullfile(root, 'design.json');
D.save(f);
D2 = SyntheticDesign.load(f);
D3 = SyntheticDesign.fromStruct(jsondecode(jsonencode(D.toStruct())));   % the preferences path: NaN as null
check(isequaln(D2.Units, D.Units) && isequaln(D2.LFP, D.LFP) && D2.SineUV == 0 && D2.NoiseUV == D.NoiseUV ...
    && isequaln(D3.Units, D.Units) && isequaln(D3.LFP, D.LFP) && D3.SineUV == 0, ...
    'save / load and the preferences'' JSON keep the design (NaN included)');
old = fullfile(root, 'old_design.json');
writeJsonFile(old, struct('schema', "ephys-synthetic-design/1", 'Units', []));
check(strcmp(errorId(@() SyntheticDesign.load(fullfile(root, 'nope.json'))), 'readJsonFile:NotFound') ...
    && strcmp(errorId(@() SyntheticDesign.load(old)), 'SyntheticDesign:BadFile'), ...
    'load of a missing file, or of a design an older generator wrote, errors');

fprintf('\n== 2. built-in design, read back from the files ==\n');
Fs = 10000; nCh = 8;
f2 = fullfile(root, 'task', 'SYN-01_260101_120000');
T = makeSyntheticRecording(f2, Subject="SYN-01", Fs=Fs, NumChannels=nCh, NumTrials=20, FileSeconds=10, Seed=4);
check(isequal([T.units.modulation], ["none" "driven" "suppressed" "driven"]) && all([T.units.event] == ["" "Stim" "Stim" "Stim"]), ...
    'the default units: unmodulated, driven, silenced, driven');
stim = T.events.Stim;
on = stim(:, 1) - 1 / Fs;                            % onsets on the continuous clock
rel = @(u) (double(T.units(u).samples(:)) - 1) / Fs - on.';   % every spike relative to every onset
ok = true;
for u = find([T.units.modulation] == "driven")
    r = rel(u);
    rIn = nnz(r >= 0.02 & r < 0.22) / (0.2 * numel(on));
    rOut = nnz(r >= -1 & r < -0.5) / (0.5 * numel(on));
    ok = ok && rIn > 2.5 * max(rOut, 1);
end
r3 = rel(3);
check(ok && ~any(r3(:) >= 1 / Fs & r3(:) < 0.5 - 1 / Fs), ...
    'driven units fire more from 20 to 220 ms after Stim onset; the silenced one never fires from 0 to 500 ms');
ds = EphysDataset(T.folder); ds.applyManifest();
ch = setdiff(1:nCh, [T.units.peakChannel]);
ch = ch(1);                                          % a channel without a unit: the evoked potential alone
w = round(0.15 * Fs);
art = round(T.artifacts * Fs);
onR = round(stim(:, 1) * Fs);                        % the onset rows
onR = onR(~any(onR + w >= art(:, 1).' & onR - 0.05 * Fs <= art(:, 2).', 2));   % windows clear of the artifacts
pre = round(0.05 * Fs);
X = zeros(pre + w, numel(onR));
for k = 1:numel(onR)
    s0 = onR(k) - 1 - pre;                           % rows s0+1 .. at (row - 1)/Fs
    x = ds.readWindowUV(s0, pre + w, Reference=false);
    X(:, k) = x(:, ch) - 100 * sin(2 * pi * 2 * (s0 + (0:pre+w-1).') / Fs);   % less the known 2 Hz sine
end
[mn, at] = min(movmean(mean(X, 2), round(0.002 * Fs)));
tPeak = (at - 1 - pre) / Fs;
check(abs(mn + 150) < 5 && abs(tPeak - 0.045) <= 0.002, ...
    sprintf('the evoked potential reads back on channel %d: %.1f uV at %.1f ms after Stim onset (model: -150 uV at 45 ms)', ...
    ch, mn, 1000 * tPeak));
data = ds.readData(IncludeAux=true);
r4 = (1:4:T.nSamples).';
iv = round(T.events.InTrial * Fs);
inT = any(r4 >= iv(:, 1).' & r4 <= iv(:, 2).', 2);
check(max(abs(data.aux - ([1.65 1.70 2.00] + 0.1 * inT)), [], 'all') < 1e-4, ...
    'the accelerometer inputs read back as their constants, 0.1 V higher while InTrial is on');
J = readJsonFile(T.designFile);
Dj = SyntheticDesign.fromStruct(J.design);
check(isfile(T.designFile) && J.seed == 4 && string(J.schedule.kind) == "task" && J.schedule.numTrials == 20 ...
    && isequaln(Dj.Units, SyntheticDesign.builtIn(nCh).Units), '<Name>_synthetic.json records the seed, the schedule and the design');

fprintf('\n== 3. exact timing and scaling in the model ==\n');
Dt = SyntheticDesign();
Dt.SineUV = 0;
u1 = SyntheticDesign.newUnit("lat", "Stim");
u1.Gain = 300; u1.BaselineHz = 0.5; u1.LatencyMs = 20; u1.DurationMs = 10; u1.Channel = 3;
u2 = SyntheticDesign.newUnit("off", "InTrial");
u2.Edge = "offset"; u2.Gain = 300; u2.BaselineHz = 0.5; u2.LatencyMs = 0; u2.DurationMs = 15; u2.Channel = 6;
u3 = SyntheticDesign.newUnit("tuned", "Stim");
u3.Gain = 10; u3.BaselineHz = 3; u3.LatencyMs = 0; u3.DurationMs = 500; u3.Parameter = "Depth"; u3.Channel = 8;
Dt.Units = [u1; u2; u3];
ev = SyntheticDesign.newLFP("Stim", "ep");
ev.LatencyMs = 30; ev.DurationMs = 20; ev.AmplitudeUV = -200; ev.Channel = 1;
Dt.LFP = ev;
Tp = makeSyntheticRecording(fullfile(root, 'timing'), Design=Dt, Fs=Fs, NumChannels=nCh, NumTrials=30, Seed=5, ...
    Artifacts=false, PreviewOnly=true);
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
check(isequal(M.expectedRate(1, [0.019; 0.02; 0.0299; 0.0301]), [0.5; 150; 150; 0.5]), ...
    'the model''s rate steps from 0.5 to 150 Hz exactly over [20, 30) ms');
y = M.componentWave(1, tau);
[ymin, k] = min(y);
te = M.lfp(1).eventTimes;
n = round(0.1 * Fs);
Y = zeros(n, numel(te));
for k2 = 1:numel(te)
    x = M.signal(round(te(k2) * Fs), n);
    Y(:, k2) = x(:, 1);
end
tY = (0:n-1).' / Fs;
[dmin, kd] = min(mean(Y, 2));
check(abs(tau(k) - 0.040) < 1e-9 && abs(ymin + 200) < 1e-9 && all(abs(y(tau < 0.030 - 1e-9 | tau > 0.050 + 1e-9)) < 1e-9) ...
    && abs((kd - 1) / Fs - 0.040) <= 2.5e-3 && abs(dmin + 200) < 10 ...
    && max(abs(mean(Y, 2) - M.componentWave(1, tY))) < 6 * Dt.NoiseUV / sqrt(numel(te)), ...
    sprintf('the evoked potential is -200 uV at latency + duration/2 and 0 outside [30, 50) ms: data %.0f uV at %.1f ms', dmin, 1000 * (kd - 1) / Fs));
q = M.units(3);
dep = Tp.schedule.trials.Depth;
check(isequal(q.eventScale(~isnan(q.eventTrial)), dep(q.eventTrial(~isnan(q.eventTrial))) / max(dep)), ...
    'a Parameter scales each response by its trial''s value normalized to 0..1 (Depth / max Depth)');
r = (double(q.samples) - 1) / Fs - q.eventTimes.';
rate = sum(r > 0 & r < 0.5, 1).' / 0.5;               % per Stim event
dv = NaN(size(rate)); dv(~isnan(q.eventTrial)) = dep(q.eventTrial(~isnan(q.eventTrial)));
check(any(dv == 0) && any(dv == 1) && mean(rate(dv == 1)) > 3 * max(1, mean(rate(dv == 0))) && mean(rate(dv == 0)) < 10, ...
    sprintf('tuned to Depth: %.1f Hz on catch trials (Depth 0), %.1f Hz at Depth 1 (baseline 3, gain 10)', mean(rate(dv == 0)), mean(rate(dv == 1))));

fprintf('\n== 4. PreviewOnly writes nothing and previews what is written ==\n');
f4 = fullfile(root, 'preview', 'SYN-04_260101_120000');
args = {'Subject', "SYN-04", 'Design', Dt, 'Fs', 5000, 'NumChannels', 8, 'NumTrials', 6, 'Seed', 9, 'Scenario', "late-start"};
P4 = makeSyntheticRecording(f4, args{:}, PreviewOnly=true);
check(~isfolder(f4) && isfield(P4, 'model') && P4.nSamples > 0, 'PreviewOnly returns the model and writes nothing');
T4 = makeSyntheticRecording(f4, args{:});
check(isequal({P4.model.units.samples}, {T4.units.samples}) && isequal(P4.events, T4.events) ...
    && isequaln(P4.trials, T4.trials) && isequal(P4.expectedCuts, T4.expectedCuts), ...
    'the same options write exactly the previewed spikes, lines and trials');

fprintf('\n== 5. the app''s Synthetic tab ==\n');
g = 'EphysPipelineApp';
prefsCleanup = AppPrefs.useTemporary(); %#ok<NASGU> preferences in a temporary file, never the user's
app = EphysPipelineApp;
appCleanup = onCleanup(@() closeApp(app));
check(any(app.TabList == app.TabSynthetic) && find(app.TabList == app.TabSynthetic) == numel(app.TabList) - 1, ...
    'the Synthetic tab sits just before Clean up');
app.selectTab(app.TabSynthetic);
check(app.helpURL("tab") == app.WikiURL + "/Synthetic-Tab" && contains(app.StatusBar.Text, "Synthetic"), ...
    'its Help page and status line');
app.SynthFsField.Value = 10000; app.SynthChannelsField.Value = 8; app.SynthTrialsSpinner.Value = 8;
app.SynthSeedField.Value = 11;
app.onSynthDesign("builtIn");
app.onSynthDesign("addUnit");
app.onSynthDesign("addEvoked");
Da = app.gatherSynthDesign();
uVars = app.synthColumns("unit");
check(height(Da.Units) == 5 && Da.Units.Event(5) == "Stim" && height(Da.LFP) == 2 && Da.LFP.Event(2) == "Stim" ...
    && ismember('Stim', app.SynthUnitsTable.ColumnFormat{uVars == "Event"}) ...
    && ismember('Depth', app.SynthUnitsTable.ColumnFormat{uVars == "Parameter"}), ...
    'Built-in design, Add unit and Add evoked; the Event and Parameter lists hold the task''s lines and parameters');
ok = app.onSynthPreview();
Pm = app.SynthModel;
check(ok && numel(Pm.model.units) == 5 && numel(app.SynthUnitDropDown.Items) == 5 && numel(app.SynthLFPDropDown.Items) == 2 ...
    && ~isempty(app.SynthTimelineAxes.Children) && ~isempty(app.SynthRasterAxes.Children) ...
    && ~isempty(app.SynthPSTHAxes.Children) && ~isempty(app.SynthLFPAxes.Children), ...
    'Preview builds the model and draws the timeline, raster, PSTH and LFP');
app.SynthLFPDropDown.Value = 2;
app.SynthUnitDropDown.Value = 1;
app.renderSynthPreview();
check(contains(string(app.SynthLFPAxes.Title.String), "-100 uV, 10-70 ms") && contains(string(app.SynthRasterAxes.XLabel.String), "InTrial onset"), ...
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
makeSyntheticProject(proj, Preset="small", Scenarios="clean", NumTrials=6, Seed=7);
app.RootPathField.Value = proj;
app.onScan();
app.SynthOutputField.Value = fullfile(proj, 'synth');
n0 = app.Project.NumDatasets;
Tc = app.generateSynthetic();
d = app.currentDataset();
check(~isempty(Tc) && app.Project.NumDatasets == n0 + 1 && ~isempty(d) && EphysProject.normalizeKey(d.Folder) == EphysProject.normalizeKey(Tc.folder) ...
    && d.BehaviorFile == Tc.behaviorFile && contains(app.SynthStatusLabel.Text, "scanned"), ...
    'written under the project root: the project is scanned again and the new dataset is active');
app.SynthSineField.Value = 0;
app.savePreferences();
v = AppPrefs.getpref(g, 'SynthOptions');
Dp = SyntheticDesign.fromStruct(jsondecode(v.design));
check(v.numTrials == 8 && isequal(Dp.Units.Name, app.gatherSynthDesign().Units.Name) && Dp.SineUV == 0, ...
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




function rmdirQuiet(p)
try
    if isfolder(p); rmdir(p, 's'); end
catch
end
end
