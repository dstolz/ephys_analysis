function test_EventEpochs()
%test_EventEpochs  Verification suite for the event-organized (epoch) export.
%   Checks EphysDataset.eventEpochs / exportEpochs against the sample
%   alignment and spike-window rules they inherit from ChronuxDataset: which
%   samples an epoch holds, which spikes land in it and with what stamp, what
%   the trials table says about incomplete epochs, how the behavior source
%   carries the session columns, and what the .mat holds. The Export section's
%   epoch settings and the DatasetOutputs "epochs" kind are covered too.
%
%   The fixtures are an in-memory extract (no recording is read) in a temp
%   folder which is deleted on completion. Neither Chronux nor FieldTrip is
%   needed.
%
%   Usage:  test_EventEpochs

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

root = fullfile(tempdir, sprintf('EventEpochs_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's'));

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
    function id = errIdOf(fcn)
        id = '';
        try
            fcn();
        catch ME
            id = ME.identifier;
        end
    end

% --- fixtures ----------------------------------------------------------------
Fs = 1000; N = 1000; nCh = 2;
X  = [(1:N).', -(1:N).'];                 % known, per-channel distinguishable
S  = struct();
S.Y     = struct('LFP', single(X), 'MUA', single([]), 'SPIKE', single([]));
S.info  = struct('LFP', struct('Fs', Fs), 'labels', ["c1" "c2"], 'origFs', Fs);
S.events = struct('din0', [0.100 0.150; 0.400 0.450; 0.990 0.995], ...
                  'InTrial', [0.200 0.300]);
twin = [-0.01 0.02];
s0 = -10; s1 = 20; nTime = s1 - s0 + 1;
onsets = S.events.din0(:, 1);

recFolder = fullfile(root, 'rec_A');
outFolder = fullfile(root, 'out_A');
mkdir(recFolder); mkdir(outFolder);
ds = EphysDataset(recFolder, AutoMetadata=false);
ds.OutputDir = outFolder;

fprintf('\n== 1. epochs around a digital-input line ==\n');
E = ds.eventEpochs(Extract=S, EventSource="line", EventLine="din0", Window=twin, ...
    Units=false, Detected=false);
check(E.event.source == "line" && E.event.name == "din0" && E.event.nEpochs == 3 ...
    && isequal(E.event.window, twin) && E.event.onsetRule == "event", ...
    'event: source, line, window and onset rule are recorded');
check(isequal(E.event.onsets, onsets) && isequal(E.event.offsets, S.events.din0(:, 2)) ...
    && max(abs(E.event.durations - (S.events.din0(:,2) - onsets))) < 1e-12, ...
    'event: onsets, offsets and durations come from the line');
check(isequal(sort(E.event.lines), ["InTrial" "din0"]), 'event: every dig-in line is listed');
check(E.event.recordingRangeSource == "extract" && isequal(E.event.recordingRange, [0 N/Fs]), ...
    'event: the recording range falls back to the extract when the folder has no files');

L = E.signals.LFP;
check(isequal(size(L.data), [nTime 3 nCh]) && L.fs == Fs && L.nTime == nTime && L.nChan == nCh, ...
    'signals.LFP: [nTime x nEpochs x nChan] at the signal rate');
check(isequal(L.labels, ["c1" "c2"]) && max(abs(L.t - (s0:s1)/Fs)) < 1e-12, ...
    'signals.LFP: channel labels and t relative to the onset');
check(isequal(L.data(:, 1, 1), double(X(90:120, 1))) && isequal(L.data(:, 2, 1), double(X(390:420, 1))), ...
    'signals.LFP: epoch i is rows round(t*Fs)+s0 ... round(t*Fs)+s1 (the "event" rule)');
check(isequal(L.data(:, 1, 2), double(X(90:120, 2))), 'signals.LFP: the second channel is its own data');
check(isequal(L.data(1:21, 3, 1), double(X(980:1000, 1))) && all(isnan(L.data(22:end, 3, 1))), ...
    'signals.LFP: a window past the end keeps its samples and is padded with NaN');
check(L.nIncomplete == 1 && L.nNonFinite == 0, 'signals.LFP: the incomplete epoch is counted');

V = E.trials;
check(height(V) == 3 && isequal(string(V.Properties.VariableNames(1:2)), ["EpochIndex" "EventIndex"]) ...
    && isequal(V.EpochIndex, (1:3).') && isequal(V.EventIndex, (1:3).'), ...
    'trials: one row per epoch, with the row it came from in the line''s event list');
check(isequal(V.EpochOnset, onsets) && isequal(V.EpochComplete, [true; true; false]), ...
    'trials: EpochOnset and EpochComplete (the third window runs past the recording)');
check(isempty(E.units) && isempty(E.detected) && isempty(E.behavior), ...
    'units / detected / behavior are empty when they are not asked for');
check(E.meta.tool == "EphysDataset.eventEpochs" && E.meta.dataset == ds.Name ...
    && isequal(E.meta.signals, "LFP") && E.meta.nEpochs == 3, 'meta records what was built');

fprintf('\n== 2. spikes, epoch by epoch ==\n');
tPre = twin(1); tPost = twin(2);
u1 = [0.095; 0.100; 0.110; onsets(2) + tPre; onsets(2) + tPost];
units = struct('unitId', [7; 8], 'label', ["su007_A_260101T1200"; "mua008_A_260101T1200"], ...
    'class', ["su"; "mua"], 'group', ["good"; "mua"], 'channel', [3; 1], ...
    'channelName', ["A-003"; "A-001"], 'times', {{u1; 0.999}});
det = struct('ts', {{[0.0955; 0.1005], zeros(0,1)}}, 'channels', [1 2], 'channelNames', ["c1" "c2"]);
E2 = ds.eventEpochs(Extract=S, EventSource="line", EventLine="din0", Window=twin, ...
    Units=units, Detected=det);
check(numel(E2.units) == 2 && E2.units(1).id == 7 && E2.units(1).label == "su007_A_260101T1200" ...
    && E2.units(1).class == "su" && E2.units(1).channel == 3, 'units: identity travels with the epochs');
check(numel(E2.units(1).times) == 3 && isequal(E2.units(1).counts, [3 1 0]), ...
    'units: one cell per epoch, spikes counted per epoch');
check(max(abs(E2.units(1).times{1} - (u1(1:3) - onsets(1)))) < 1e-12, ...
    'units: TimeBase "onset" stamps spikes relative to the event');
check(numel(E2.units(1).times{2}) == 1 && abs(E2.units(1).times{2} - tPost) < 1e-12, ...
    'units: the window is half-open (t > onset+tPre, t <= onset+tPost)');
check(E2.spikes.timeBase == "onset" && isequal(E2.spikes.window, twin) && E2.spikes.nUnits == 2, ...
    'spikes: the stamping rule is recorded');
check(numel(E2.detected) == 2 && E2.detected(1).channel == 1 && E2.detected(1).channelName == "c1" ...
    && isequal(E2.detected(1).counts, [2 0 0]), 'detected: one element per channel, counts per epoch');

E3 = ds.eventEpochs(Extract=S, EventSource="line", EventLine="din0", Window=twin, ...
    Units=units, Detected=false, SpikeTimeBase="window");
check(max(abs(E3.units(1).times{1} - (u1(1:3) - onsets(1) - tPre))) < 1e-12, ...
    'SpikeTimeBase="window": 0 at the start of the window');
E4 = ds.eventEpochs(Extract=S, EventSource="line", EventLine="din0", Window=twin, ...
    Units=units, Detected=false, SpikeTimeBase="absolute");
check(isequal(E4.units(1).times{1}, u1(1:3)), 'SpikeTimeBase="absolute": recording times are left alone');

fprintf('\n== 3. epochs around the paired behavior trials ==\n');
T = table([1; 2; 3], [0.100; NaN; 0.400], [0.150; NaN; 0.450], ["a"; "b"; "c"], ...
    'VariableNames', {'TrialID', 'TrialOnset', 'TrialOffset', 'Stim'});
b = struct('trials', T, 'info', struct(), 'meta', struct('nTrials', 3), 'file', "session.mat", ...
    'subject', "subjA", 'startTime', NaT, 'nTrials', 3, ...
    'pairing', struct('status', "approved", 'trialLine', "InTrial"));
Eb = ds.eventEpochs(Extract=S, EventSource="behavior", Behavior=b, Window=twin, ...
    Units=false, Detected=false);
check(Eb.event.source == "behavior" && Eb.event.name == "InTrial" && Eb.event.nEpochs == 2 ...
    && Eb.event.pairingStatus == "approved" && isequal(Eb.event.unpairedTrials, 2), ...
    'behavior: paired trials become the epochs, unpaired ones are listed');
check(isequal(Eb.trials.BehaviorRow, [1; 3]) && isequal(Eb.trials.EpochOnset, [0.100; 0.400]) ...
    && isequal(Eb.trials.Stim, ["a"; "c"]) && isequal(Eb.trials.TrialID, [1; 3]), ...
    'behavior: the session columns ride along, in epoch order');
check(isequal(Eb.signals.LFP.data(:, 2, 1), double(X(390:420, 1))), ...
    'behavior: the epochs are cut at the paired trial onsets');
check(Eb.behavior.file == "session.mat" && Eb.behavior.subject == "subjA" ...
    && Eb.behavior.pairing.status == "approved", 'behavior: the session and pairing are summarized');

b2 = b; b2.pairing.status = "unreviewed";
ws = warning('off', 'EphysDataset:eventEpochs:PairingNotApproved');
lastwarn('');
Eb2 = ds.eventEpochs(Extract=S, EventSource="behavior", Behavior=b2, Window=twin, ...
    Units=false, Detected=false);
[~, wid] = lastwarn();
warning(ws);
check(strcmp(wid, 'EphysDataset:eventEpochs:PairingNotApproved') && Eb2.event.pairingStatus == "unreviewed", ...
    'behavior: a pairing that is not approved warns, and says so in the file');

fprintf('\n== 4. onsets passed in, and the epoch policies ==\n');
Et = ds.eventEpochs(Extract=S, EventSource="times", Times=[0.400; 0.100], Window=twin, ...
    Units=false, Detected=false);
check(Et.event.nEpochs == 2 && isequal(Et.trials.EpochOnset, [0.400; 0.100]) ...
    && isequal(Et.signals.LFP.data(:, 1, 1), double(X(390:420, 1))), ...
    'times: the onsets are epoched in the order they were given, never sorted');
check(all(isnan(Et.trials.EpochOffset)) && all(isnan(Et.trials.EpochDuration)), ...
    'times: there is no offset to report');

ws = warning('off', 'ChronuxDataset:IncompleteTrials');
Ed = ds.eventEpochs(Extract=S, EventSource="line", EventLine="din0", Window=twin, ...
    Units=false, Detected=false, Incomplete="drop");
warning(ws);
check(size(Ed.signals.LFP.data, 2) == 2 && isequal(Ed.signals.LFP.info.keptTrials, [1 2]) ...
    && height(Ed.trials) == 3, ...
    'Incomplete="drop": the signal holds the epochs it could fill, the table still lists every one');

Snan = S;
Snan.Y.LFP(395, 1) = single(NaN);
ws = warning('off', 'ChronuxDataset:NonFiniteTrials');
En = ds.eventEpochs(Extract=Snan, EventSource="line", EventLine="din0", Window=twin, ...
    Units=false, Detected=false, NonFinite="drop");
warning(ws);
check(isequal(En.signals.LFP.info.keptTrials, [1 3]) && En.signals.LFP.nNonFinite == 1, ...
    'NonFinite="drop": an epoch with NaN samples is dropped and counted');
Ek = ds.eventEpochs(Extract=Snan, EventSource="line", EventLine="din0", Window=twin, ...
    Units=false, Detected=false);
check(isnan(Ek.signals.LFP.data(6, 2, 1)), 'NonFinite="keep" (default): the NaN sample is kept as recorded');

Es = ds.eventEpochs(Extract=S, EventSource="line", EventLine="din0", Window=twin, ...
    Units=false, Detected=false, Class="single", OnsetRule="sample");
check(isa(Es.signals.LFP.data, 'single') && isequal(double(Es.signals.LFP.data(:, 1, 1)), double(X(91:121, 1))), ...
    'Class="single" and OnsetRule="sample" (base = round(t*Fs)+1)');

fprintf('\n== 5. guard rails ==\n');
check(strcmp(errIdOf(@() ds.eventEpochs(Extract=S, Window=[0.5 -0.5])), 'EphysDataset:eventEpochs:BadWindow'), ...
    'a reversed window is refused');
check(strcmp(errIdOf(@() ds.eventEpochs(Extract=S, EventLine="nope")), 'EphysDataset:eventEpochs:EventLine'), ...
    'a line the extract does not have is refused');
ds.TrialConfig.TrialLine = "";
check(strcmp(errIdOf(@() ds.eventEpochs(Extract=S)), 'EphysDataset:eventEpochs:EventLine'), ...
    'with several lines and no trial line, the line must be named');
check(strcmp(errIdOf(@() ds.eventEpochs(Extract=S, EventSource="times")), 'EphysDataset:eventEpochs:NoOnsets'), ...
    'EventSource="times" without Times is refused');
Tbad = removevars(T, 'TrialOnset');
bBad = b; bBad.trials = Tbad;
check(strcmp(errIdOf(@() ds.eventEpochs(Extract=S, EventSource="behavior", Behavior=bBad)), ...
    'EphysDataset:eventEpochs:NoPairing'), 'unpaired behavior trials are refused, not guessed');
Sempty = S; Sempty.Y.LFP = single([]);
check(strcmp(errIdOf(@() ds.eventEpochs(Extract=Sempty)), 'EphysDataset:eventEpochs:NoSignals'), ...
    'an extract with no signal is refused');

ds.TrialConfig.TrialLine = "InTrial";
Ei = ds.eventEpochs(Extract=S, Window=twin, Units=false, Detected=false);
check(Ei.event.name == "InTrial" && Ei.event.nEpochs == 1 ...
    && isequal(Ei.signals.LFP.data(:, 1, 1), double(X(190:220, 1))), ...
    'a blank line falls back to TrialConfig.TrialLine');

fprintf('\n== 6. exportEpochs writes <Name>_epochs.mat ==\n');
out = ds.exportEpochs(Extract=S, EventSource="line", EventLine="din0", Window=twin, Units=units, Detected=det);
check(out.file == string(fullfile(outFolder, ds.Name + "_epochs.mat")) && isfile(out.file) ...
    && out.nEpochs == 3 && out.nUnits == 2 && out.eventName == "din0" && isequal(out.window, twin), ...
    'exportEpochs writes the default file and reports what is in it');
M = load(out.file);
check(isequal(sort(string(fieldnames(M))), ["epochs"; "export"]) ...
    && M.export.tool == "EphysDataset.exportEpochs" && M.export.dataset == ds.Name, ...
    'the file holds epochs + export provenance');
check(M.epochs.event.nEpochs == 3 && istable(M.epochs.trials) && height(M.epochs.trials) == 3 ...
    && isequal(M.epochs.signals.LFP.data(:, 1, 1), double(X(90:120, 1))) ...
    && isequal(M.epochs.units(1).counts, [3 1 0]), ...
    'the saved epochs survive the round trip unchanged');
check(strcmp(errIdOf(@() ds.exportEpochs(Extract=S, EventLine="din0")), 'EphysDataset:exportEpochs:Exists'), ...
    'exportEpochs does not overwrite by default');
o2 = ds.exportEpochs(Extract=S, EventLine="din0", Window=twin, Units=false, Detected=false, Overwrite=true);
check(o2.nUnits == 0 && isfile(o2.file), 'Overwrite=true replaces the file');

outs = ds.outputs();
check(outs.has("epochs") && endsWith(outs.EpochsFile, ds.Name + "_epochs.mat") && isfile(outs.EpochsFile), ...
    'DatasetOutputs finds the epoch file by the variables it holds');
check(outs.Epochs.epochs.event.name == "din0", 'DatasetOutputs loads it as the epochs kind');

fprintf('\n== 7. the Export section''s epoch settings ==\n');
D = EphysPipelineConfig.defaults("Export");
check(D.EpochSource == "line" && D.EpochLine == "" && isequal(D.EpochWindow, [-0.2 0.5]) ...
    && D.EpochOnsetRule == "event" && D.EpochIncomplete == "nan" && D.EpochNonFinite == "keep" ...
    && D.EpochSpikeTimeBase == "onset" && D.EpochClass == "double", ...
    'defaults("Export") carries the epoch settings');
Ecfg = EphysPipelineConfig.normalizeSection("Export", ...
    struct('Formats', "epochs", 'EpochWindow', {{-0.1, 0.3}}, 'EpochSource', "behavior"));
check(isequal(Ecfg.Formats, "epochs") && isequal(Ecfg.EpochWindow, [-0.1 0.3]) && Ecfg.EpochSource == "behavior", ...
    'normalizeSection coerces the epoch settings to their default types');
o = EphysPipelineConfig.exportOptions(Ecfg, "epochs");
check(o.EventSource == "behavior" && isequal(o.Window, [-0.1 0.3]) && o.Incomplete == "nan" ...
    && o.SpikeTimeBase == "onset" && o.Class == "double" && ~isfield(o, 'Validate'), ...
    'exportOptions(..., "epochs") uses the exporter''s own option names');
Erun = EphysPipelineConfig.defaults("Export");
Erun.EpochLine = "din0";
Erun.EpochWindow = twin;
orun = rmfield(EphysPipelineConfig.exportOptions(Erun, "epochs"), {'Overwrite', 'MatVersion'});
args = namedargs2cell(orun);
Ecfg3 = ds.eventEpochs('Extract', S, args{:});
check(Ecfg3.event.name == "din0" && Ecfg3.event.nEpochs == 3 && isequal(Ecfg3.event.window, twin) ...
    && isequal(Ecfg3.signals.LFP.data(:, 1, 1), double(X(90:120, 1))), ...
    'the section''s settings drive eventEpochs unchanged, through exportOptions');

fprintf('\n######## %d passed, %d failed ########\n', nPass, nFail);
if nFail > 0
    error('test_EventEpochs:Failures', '%d check(s) failed.', nFail);
end
end
