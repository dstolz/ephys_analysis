function E = eventEpochs(obj, opts)
%eventEpochs  Event-organized (epoched) data for this recording, in memory.
%   E = ds.eventEpochs(Name=Value) cuts this dataset's derived continuous
%   signals, sorted units and threshold-detected spikes into one epoch per
%   event and returns everything as one struct, aligned trial by trial. It is
%   what EphysDataset.exportEpochs saves to <Name>_epochs.mat and what the
%   app's "Epochs to workspace" button puts in the base workspace, so a
%   trial-by-trial analysis can start from data that is already organized by
%   event.
%
%   It selects and re-packages; it never changes sample values. The epochs
%   are cut by ChronuxDataset.trials (continuous) and
%   ChronuxDataset.spikeTrials (spike times), so the sample alignment and the
%   spike-window rule are exactly the documented ones, and no trial is
%   silently dropped with the defaults: a window that runs past the recording
%   is padded with NaN and flagged (EpochComplete) rather than removed, and
%   one that touches an artifact period of the extract (info.artifacts, the
%   periods erased before the signals were derived) is flagged
%   (EpochArtifact) and left out of the signals.
%
%   Fields of E
%   -----------
%     event      how the epochs were defined: source ("line" | "behavior" |
%                "times"), name (the digital line, the trial line of the
%                pairing, or "times"), window [tPre tPost] seconds,
%                onsetRule, eventFs (the recording rate, the clock the event
%                times count rows of), nEpochs, nTotalEvents, onsets / offsets /
%                durations (seconds, one row per epoch), recordingRange and
%                its source, nIncomplete, what the selection left out
%                (droppedDuration / droppedTimeRange for a line,
%                unpairedTrials for a session), lines (every digital line in
%                the extract) and, for the behavior source, pairingStatus.
%                Which event or trial each epoch came from is a column of the
%                trials table
%     trials     table, one row per epoch: EpochIndex, EpochOnset,
%                EpochOffset, EpochDuration, EpochComplete (the window lies
%                inside the recording and inside every signal, so no sample of
%                the epoch is NaN padding), EpochArtifact (the window touches
%                an artifact period), plus EventIndex (row in the line's
%                event list) or BehaviorRow and the behavior trial columns
%                when the events came from a session
%     signals    struct, one field per exported signal (LFP / MUA / SPIKE /
%                AUX): data [nTime x nEpochs x nChan] in the signal's units,
%                t [1 x nTime] seconds relative to the onset, fs, labels,
%                units, nIncomplete / nNonFinite / nArtifact and the
%                ChronuxDataset.trials info (keptTrials says which epochs the
%                data holds; droppedArtifact the ones left out for an
%                artifact period)
%     units      1 x nUnits struct array of the sorted units: id, label,
%                class, group, channel, channelName, times {1 x nEpochs} and
%                counts [1 x nEpochs]. Empty when no units were included
%     detected   the same for threshold-detected spikes, one element per
%                channel (channel, channelName, times, counts), or []
%     spikes     how the spike times are stamped: timeBase, window, rule
%     behavior   meta / pairing summary of the session the events came from,
%                or []
%     artifacts  the extract's artifact periods (info.artifacts: intervals
%                [k x 2] [tStart tEnd) s on the continuous clock, fill,
%                nSamples); an epoch touches one when its window on that
%                clock, onset + [tPre tPost], overlaps it
%     meta       provenance: tool, created, dataset, sourceFolder, sources,
%                signals, window, nEpochs, conventions
%
%   Options
%   -------
%     Extract        "" (default: <outputFolder>/<Name>_extract.mat, else the
%                    <Name>_extract_<TYPE>.mat files present), other extract
%                    file(s) -- several are merged -- or a toMat-shaped
%                    struct (Y, events, info), as in exportChronux
%     Signals        subset of ["LFP" "MUA" "SPIKE" "AUX"] ([] = all present)
%     Units          [] (default: the associated sorted units) | a units
%                    struct | false (none)
%     Groups         phy groups to keep when reading units (["good" "mua"])
%     Detected       true (default: <Name>_spikes.mat when present) | a
%                    spikes file | a detected struct | false
%     Sources        provenance of inputs passed as structs, as in
%                    exportChronux
%     Events         true (default): use the extract's digital-input events;
%                    EventSource="line" needs them
%     EventSource    "line" (default) digital-input line | "behavior" the
%                    paired Epsych2 trials | "times" the Times option
%     EventLine      the line to use ("" = TrialConfig.TrialLine when the
%                    extract has it, else the only line)
%     Times          onsets in seconds for EventSource="times", in the order
%                    they should be epoched (they are never sorted)
%     Behavior       [] (default: <Name>_behavior.mat, else the associated
%                    session read with the recorded pairing) | a behavior
%                    file | a behaviorStruct
%     Window         [tPre tPost] seconds around the onset ([-0.2 0.5])
%     OnsetRule      "event" (default) | "sample" (ChronuxDataset.trials)
%     Incomplete     what to do with a window that runs past the recording:
%                    "nan" (default: keep it, pad with NaN), "drop", "error"
%     NonFinite      epochs whose in-range samples hold NaN/Inf: "keep"
%                    (default), "drop", "error"
%     Artifacts      epochs whose window touches an artifact period of the
%                    extract (the periods the Signals step erased): "drop"
%                    (default: flagged in EpochArtifact and left out of the
%                    signals) or "keep" (flagged only)
%     SpikeTimeBase  "onset" (default: 0 at the event, spanning the window),
%                    "window" (0 at the window start) or "absolute"
%                    (recording times), see ChronuxDataset.spikeTrials
%     Class          "double" (default) | "single" | "asis" for the epochs
%     MinDurationSec / MaxDurationSec   pulse-length filter for the "line"
%                    source (0 / Inf: every pulse)
%
%   With Incomplete="drop", NonFinite="drop" or Artifacts="drop" a signal
%   holds fewer epochs than the trials table has rows; its info.keptTrials
%   names the rows it kept. The spike epochs always cover every row.
%
%   See also EphysDataset.exportEpochs, ChronuxDataset.trials,
%   ChronuxDataset.spikeTrials, EphysDataset.pairTrials.

arguments
    obj (1,1) EphysDataset
    opts.Extract = ""
    opts.Signals (1,:) string = string.empty(1,0)
    opts.Units = []
    opts.Groups (1,:) string = ["good" "mua"]
    opts.Detected = true
    opts.Sources struct = struct()
    opts.Events (1,1) logical = true
    opts.EventSource (1,1) string {mustBeMember(opts.EventSource, ...
        ["line","behavior","times"])} = "line"
    opts.EventLine (1,1) string = ""
    opts.Times double = double.empty(0,1)
    opts.Behavior = []
    opts.Window (1,2) double {mustBeFinite} = [-0.2 0.5]
    opts.OnsetRule (1,1) string {mustBeMember(opts.OnsetRule, ["event","sample"])} = "event"
    opts.Incomplete (1,1) string {mustBeMember(opts.Incomplete, ["nan","drop","error"])} = "nan"
    opts.NonFinite (1,1) string {mustBeMember(opts.NonFinite, ["keep","drop","error"])} = "keep"
    opts.Artifacts (1,1) string {mustBeMember(opts.Artifacts, ["drop","keep"])} = "drop"
    opts.SpikeTimeBase (1,1) string {mustBeMember(opts.SpikeTimeBase, ...
        ["onset","window","absolute"])} = "onset"
    opts.Class (1,1) string {mustBeMember(opts.Class, ["double","single","asis"])} = "double"
    opts.MinDurationSec (1,1) double {mustBeNonnegative} = 0
    opts.MaxDurationSec (1,1) double {mustBePositive} = Inf
end

twin = opts.Window;
if twin(2) <= twin(1)
    error('EphysDataset:eventEpochs:BadWindow', ...
        'Window must be [tPre tPost] with tPre < tPost; got [%g %g].', twin(1), twin(2));
end

in = resolveExportInputs(obj, opts, 'eventEpochs');
if isempty(in.signals)
    error('EphysDataset:eventEpochs:NoSignals', ...
        ['The extract holds no continuous signal to epoch. Run the Signals step ' ...
         '(EphysDataset.toMat) for %s first.'], obj.Name);
end

% One connector serves the event lookup and the spike epoching; each signal
% gets its own below (the signal is what a connector is built around).
cx = ChronuxDataset(in.S, Signal=in.signals(1));

% --- the events the epochs are cut around ------------------------------------
ev = struct();
ev.source        = opts.EventSource;
ev.window        = twin;
ev.onsetRule     = opts.OnsetRule;
ev.eventFs       = in.eventFs;    % NaN: unknown, each signal takes its own rate
ev.lines         = string.empty(1,0);
if isstruct(in.events)
    ev.lines = string(fieldnames(in.events)).';
end
b = [];
behaviorRows = double.empty(0,1);
eventIndex   = double.empty(0,1);

switch opts.EventSource
    case "line"
        lineName = resolveLine(obj, opts.EventLine, ev.lines);
        [onsets, einfo] = cx.eventOnsets(lineName, MinDurationSec=opts.MinDurationSec, ...
            MaxDurationSec=opts.MaxDurationSec);
        offsets    = einfo.offsets;
        eventIndex = reshape(einfo.keptEvents, [], 1);
        ev.name             = einfo.name;
        ev.nTotalEvents     = einfo.nTotal;
        ev.droppedDuration  = einfo.droppedDuration;
        ev.droppedTimeRange = einfo.droppedTimeRange;
        ev.minDurationSec   = opts.MinDurationSec;
        ev.maxDurationSec   = opts.MaxDurationSec;

    case "behavior"
        b = resolveBehavior(obj, opts.Behavior);
        BT = b.trials;
        if ~ismember("TrialOnset", string(BT.Properties.VariableNames))
            error('EphysDataset:eventEpochs:NoPairing', ...
                ['The behavior data of %s has no TrialOnset column, so its trials are ' ...
                 'not paired with the recording. Run the behavior step with PairTrials ' ...
                 '(or pair and approve the trials on the app''s Trials tab) first.'], obj.Name);
        end
        onsetAll = double(BT.TrialOnset);
        paired   = isfinite(onsetAll);
        if ~any(paired)
            error('EphysDataset:eventEpochs:NoPairing', ...
                'No trial of %s is paired with the recording (every TrialOnset is NaN).', obj.Name);
        end
        onsets       = onsetAll(paired);
        behaviorRows = reshape(find(paired), [], 1);
        offsets      = nan(size(onsets));
        if ismember("TrialOffset", string(BT.Properties.VariableNames))
            offAll  = double(BT.TrialOffset);
            offsets = offAll(paired);
        end
        ev.name          = "trials";
        ev.nTotalEvents  = height(BT);
        ev.unpairedTrials = reshape(find(~paired), 1, []);
        ev.pairingStatus = "none";
        if isstruct(b.pairing) && isfield(b.pairing, 'status')
            ev.pairingStatus = string(b.pairing.status);
            if isfield(b.pairing, 'trialLine'); ev.name = string(b.pairing.trialLine); end
        end
        if ev.pairingStatus ~= "approved"
            warning('EphysDataset:eventEpochs:PairingNotApproved', ...
                ['The trial pairing of %s is "%s", not approved; the epochs follow it as ' ...
                 'it stands. Review it on the Trials tab.'], obj.Name, ev.pairingStatus);
        end

    case "times"
        onsets = double(opts.Times(:));
        if isempty(onsets)
            error('EphysDataset:eventEpochs:NoOnsets', ...
                'EventSource="times" needs the onsets in seconds (Times=).');
        end
        if any(~isfinite(onsets))
            error('EphysDataset:eventEpochs:NoOnsets', 'Times must be finite.');
        end
        offsets = nan(size(onsets));
        ev.name = "times";
        ev.nTotalEvents = numel(onsets);
end

onsets  = double(onsets(:));
offsets = double(offsets(:));
nEp     = numel(onsets);
ev.onsets    = onsets;
ev.offsets   = offsets;
ev.durations = offsets - onsets;
ev.nEpochs   = nEp;

% --- the onsets on the continuous clock ------------------------------------------
% Spike times and the artifact periods are on the continuous clock,
% (sample-1)/Fs. A digital-event onset (OnsetRule "event") t = row/eventFs is
% one recording sample later than that clock, so the spikes are cut around the
% onset's own recording row, (row-1)/eventFs, computed from the row so a spike
% in that sample is at exactly 0.
spikeOnsets = onsets;
if opts.OnsetRule == "event" && isfinite(ev.eventFs)
    spikeOnsets = (round(onsets * ev.eventFs) - 1) / ev.eventFs;
end

% --- which windows touch an artifact period ---------------------------------------
artifact = EphysDataset.overlapsIntervals(spikeOnsets + twin(1), spikeOnsets + twin(2), ...
    in.artifacts.intervals);
ev.nArtifact = nnz(artifact);

% --- continuous signals -------------------------------------------------------
S = struct();
inSignals = true(nEp, 1);          % every signal holds all of the epoch's rows
for sig = in.signals
    cxs = ChronuxDataset(in.S, Signal=sig);
    [data, ~, T, tinfo] = cxs.trials(onsets, twin, OnsetRule=opts.OnsetRule, ...
        EventFs=ev.eventFs, Incomplete=opts.Incomplete, NonFinite=opts.NonFinite, ...
        Class=opts.Class);
    data = reshape(data, tinfo.nTime, tinfo.nTrials, tinfo.nChan);
    tinfo.droppedArtifact = zeros(1, 0);
    if opts.Artifacts == "drop"
        cut = reshape(artifact(tinfo.keptTrials), 1, []);
        data = data(:, ~cut, :);
        tinfo.droppedArtifact = tinfo.keptTrials(cut);
        tinfo.keptTrials   = tinfo.keptTrials(~cut);
        tinfo.onsets       = tinfo.onsets(~cut);
        tinfo.onsetSamples = tinfo.onsetSamples(~cut);
        tinfo.nTrials      = numel(tinfo.keptTrials);
    end
    S.(sig) = struct( ...
        'data',   data, ...
        't',      T, ...
        'fs',     tinfo.fs, ...
        'labels', string(tinfo.labels(:)).', ...
        'units',  string(tinfo.units), ...
        'nEpochs', tinfo.nTrials, ...
        'nTime',  tinfo.nTime, ...
        'nChan',  tinfo.nChan, ...
        'nIncomplete', numel(tinfo.droppedIncomplete), ...
        'nNonFinite', numel(tinfo.droppedNonFinite), ...
        'nArtifact', numel(tinfo.droppedArtifact), ...
        'info',   tinfo);
    inSignals(tinfo.droppedIncomplete) = false;    % NaN-padded or dropped rows
end

% --- which windows fit inside the recording ----------------------------------
% In seconds (what the spike epochs are cut from) and in the rows of every
% signal, so an epoch with NaN padding is never marked complete.
[recRange, recSource] = recordingRange(obj, in.S, in.signals);
complete = inSignals;
if all(isfinite(recRange))
    complete = complete & (onsets + twin(1)) >= recRange(1) & (onsets + twin(2)) <= recRange(2);
end
ev.recordingRange       = recRange;
ev.recordingRangeSource = recSource;
ev.nIncomplete          = nnz(~complete);

% --- the trial table ----------------------------------------------------------
V = table((1:nEp).', onsets, offsets, offsets - onsets, complete, artifact(:), ...
    'VariableNames', {'EpochIndex', 'EpochOnset', 'EpochOffset', 'EpochDuration', 'EpochComplete', 'EpochArtifact'});
switch opts.EventSource
    case "line"
        V = addvars(V, eventIndex, 'After', 'EpochIndex', 'NewVariableNames', 'EventIndex');
    case "behavior"
        V = addvars(V, behaviorRows, 'After', 'EpochIndex', 'NewVariableNames', 'BehaviorRow');
        clash = intersect(string(V.Properties.VariableNames), string(b.trials.Properties.VariableNames));
        if ~isempty(clash)
            error('EphysDataset:eventEpochs:ColumnClash', ...
                'The behavior trials already have column(s) %s.', strjoin(clash, ", "));
        end
        V = [V, b.trials(behaviorRows, :)];
end

% --- sorted units -------------------------------------------------------------
U = emptyUnitStruct();
if ~isempty(in.units)
    nU = numel(in.units.unitId);
    U = repmat(emptyUnitTemplate(), 1, nU);
    sp = ChronuxDataset.toPointProcess(in.units.times);
    for u = 1:nU
        [ep, cnt] = epochSpikes(cx, sp(u), spikeOnsets, twin, opts.SpikeTimeBase);
        U(u).id          = in.units.unitId(u);
        U(u).label       = fieldOrDefault(in.units, 'label', u, "");
        U(u).class       = fieldOrDefault(in.units, 'class', u, "");
        U(u).group       = fieldOrDefault(in.units, 'group', u, "");
        U(u).channel     = fieldOrDefault(in.units, 'channel', u, NaN);
        U(u).channelName = fieldOrDefault(in.units, 'channelName', u, "");
        U(u).times       = ep;
        U(u).counts      = cnt;
    end
end

% --- detected spikes ----------------------------------------------------------
D = [];
if ~isempty(in.detected)
    nCh = numel(in.detected.ts);
    D = repmat(struct('channel', NaN, 'channelName', "", 'times', {{}}, 'counts', []), 1, nCh);
    spD = ChronuxDataset.toPointProcess(in.detected.ts);
    for c = 1:nCh
        [ep, cnt] = epochSpikes(cx, spD(c), spikeOnsets, twin, opts.SpikeTimeBase);
        D(c).channel     = fieldOrDefault(in.detected, 'channels', c, NaN);
        D(c).channelName = fieldOrDefault(in.detected, 'channelNames', c, "");
        D(c).times       = ep;
        D(c).counts      = cnt;
    end
end

% --- behavior summary ---------------------------------------------------------
B = [];
if ~isempty(b)
    B = struct();
    B.file      = fieldOr(b, 'file', "");
    B.subject   = fieldOr(b, 'subject', "");
    B.startTime = fieldOr(b, 'startTime', NaT);
    B.nTrials   = fieldOr(b, 'nTrials', height(b.trials));
    B.meta      = fieldOr(b, 'meta', struct());
    B.pairing   = fieldOr(b, 'pairing', []);
end

E = struct();
E.event    = ev;
E.trials   = V;
E.signals  = S;
E.units    = U;
E.detected = D;
E.spikes   = struct('timeBase', opts.SpikeTimeBase, 'window', twin, ...
    'rule', "t > onset+tPre and t <= onset+tPost (ChronuxDataset.spikeTrials), onset on the spikes' clock: (row-1)/eventFs for a digital-event onset (OnsetRule ""event"")", ...
    'nUnits', numel(U), 'nDetectedChannels', numel(D));
E.behavior = B;
E.artifacts = in.artifacts;
E.meta = struct( ...
    'tool',         "EphysDataset.eventEpochs", ...
    'created',      string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
    'dataset',      obj.Name, ...
    'sourceFolder', obj.Folder, ...
    'signals',      in.signals, ...
    'sources',      in.sources, ...
    'eventSource',  opts.EventSource, ...
    'eventName',    ev.name, ...
    'window',       twin, ...
    'nEpochs',      nEp, ...
    'nUnits',       numel(U), ...
    'nDetectedChannels', numel(D), ...
    'incomplete',   opts.Incomplete, ...
    'nonFinite',    opts.NonFinite, ...
    'artifacts',    opts.Artifacts, ...
    'nArtifact',    ev.nArtifact, ...
    'class',        opts.Class, ...
    'conventions',  struct( ...
        'epochs',  "trial i is rows base(i)+round(tPre*Fs) ... base(i)+round(tPost*Fs) of each signal, " + ...
                   baseRule(opts.OnsetRule) + "; t is relative to the onset", ...
        'onsets',  "seconds on the recording clock (t = row/eventFs for digital-input and paired trial times)", ...
        'complete', "EpochComplete: the window lies inside the recording and inside every signal (no NaN padding)", ...
        'artifact', "EpochArtifact: the window on the continuous clock, onset + [tPre tPost], overlaps a period of artifacts.intervals", ...
        'spikes',  "half-open window around the onset's recording row ((row-1)/eventFs, the spikes' clock), stamped per spikes.timeBase"));
end


% =========================================================================
function lineName = resolveLine(obj, wanted, lines)
%resolveLine  Which digital line the epochs are cut around.
if isempty(lines)
    error('EphysDataset:eventEpochs:NoEvents', ...
        ['The extract of %s carries no digital-input events, so there is no line to ' ...
         'epoch around (use EventSource="behavior" or "times").'], obj.Name);
end
if wanted ~= ""
    lineName = wanted;
    if ~ismember(lineName, lines)
        error('EphysDataset:eventEpochs:EventLine', ...
            'No digital-input line "%s" in %s; it has %s.', lineName, obj.Name, strjoin(lines, ", "));
    end
    return
end
trialLine = string(obj.TrialConfig.TrialLine);
if trialLine ~= "" && ismember(trialLine, lines)
    lineName = trialLine;
elseif isscalar(lines)
    lineName = lines(1);
else
    error('EphysDataset:eventEpochs:EventLine', ...
        'Name the digital-input line to epoch around (EventLine=); %s has %s.', ...
        obj.Name, strjoin(lines, ", "));
end
end


function b = resolveBehavior(obj, given)
%resolveBehavior  The behavior struct whose paired trials define the epochs.
if isstruct(given)
    b = given;
elseif (isstring(given) || ischar(given)) && strlength(string(given)) > 0
    file = string(given);
    if ~isfile(file)
        error('EphysDataset:eventEpochs:NoBehavior', 'No behavior file %s.', file);
    end
    b = loadBehaviorFile(file);
else
    file = string(fullfile(obj.outputFolder(), obj.Name + "_behavior.mat"));
    if isfile(file)
        b = loadBehaviorFile(file);
        return
    end
    P = [];
    if ~isempty(obj.TrialPairing)
        P = obj.pairTrials(Cuts="recorded", Warn=false);
    end
    b = obj.behaviorStruct(Pairing=P);
    if isempty(b)
        error('EphysDataset:eventEpochs:NoBehavior', ...
            ['No behavior data for %s: neither %s nor an associated Epsych2 session. ' ...
             'Run the behavior step, or pass Behavior=.'], obj.Name, file);
    end
end
if ~isstruct(b) || ~isfield(b, 'trials')
    error('EphysDataset:eventEpochs:NoBehavior', ...
        'The behavior data of %s has no trials table.', obj.Name);
end
if ~isfield(b, 'pairing'); b.pairing = []; end
end


function b = loadBehaviorFile(file)
%loadBehaviorFile  The behavior variable of a behaviorToMat output.
M = load(file, 'behavior');
if ~isfield(M, 'behavior') || ~isstruct(M.behavior)
    error('EphysDataset:eventEpochs:NoBehavior', ...
        '%s has no behavior variable (is it an EphysDataset.behaviorToMat output?).', file);
end
b = M.behavior;
if ~isfield(b, 'pairing'); b.pairing = []; end
end


function [range, source] = recordingRange(obj, S, signals)
%recordingRange  [t0 t1] seconds the epochs can be cut from.
range  = [0 NaN];
source = "recording duration";
if ~isnan(obj.Duration) && obj.Duration > 0
    range(2) = obj.Duration;
    return
end
dur = 0;
for sig = signals
    fs = double(S.info.(sig).Fs);
    n  = size(S.Y.(sig), 1);
    if isfinite(fs) && fs > 0; dur = max(dur, n / fs); end
end
if dur > 0
    range(2) = dur;
    source   = "extract";
else
    range  = [-Inf Inf];
    source = "unknown";
end
end


function s = baseRule(onsetRule)
%baseRule  The onset row base(i) of ChronuxDataset.trials' OnsetRule, as text.
switch onsetRule
    case "event"
        s = "base(i) = round((onset - 1/eventFs)*Fs) + 1, the signal row nearest the onset's recording row";
    case "sample"
        s = "base(i) = round(onset*Fs) + 1, the signal row nearest the onset on the continuous clock (row k at (k-1)/Fs)";
end
end


function [ep, counts] = epochSpikes(cx, sp, onsets, twin, timeBase)
%epochSpikes  One spike train cut into one cell per onset (every onset kept).
[d, ~, ~, sinfo] = cx.spikeTrials(onsets, twin, Spikes=sp, TimeBase=timeBase, ...
    Incomplete="keep");
ep = {d.times};
counts = reshape(sinfo.counts, 1, []);
end


function u = emptyUnitTemplate()
u = struct('id', NaN, 'label', "", 'class', "", 'group', "", ...
    'channel', NaN, 'channelName', "", 'times', {{}}, 'counts', []);
end


function U = emptyUnitStruct()
U = repmat(emptyUnitTemplate(), 1, 0);
end


function v = fieldOr(S, name, dflt)
%fieldOr  Field NAME of S, or DFLT when it is not there.
v = dflt;
if isfield(S, name); v = S.(name); end
end


function v = fieldOrDefault(S, name, k, dflt)
%fieldOrDefault  Element K of field NAME of S, or DFLT when it is not there.
v = dflt;
if ~isfield(S, name); return; end
x = S.(name);
if iscell(x)
    if numel(x) >= k; v = x{k}; end
elseif numel(x) >= k
    v = x(k);
end
end
