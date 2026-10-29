function D = sessionData(src, S, opts)
%sessionData  One dataset on its own clock, not cut into epochs: its spike trains or signal, every trial and digital line.
%   D = sessionData(SRC, S) takes the dataset SRC (loadAnalysisSource) and
%   epochMatrixSettings' S (a struct, a settings file or [] for the
%   defaults) and loads what epochMatrix would align, without aligning
%   anything: the spike trains of the units S picks (S.data "units" or
%   "detected", S.units; selectUnits with S.ref and S.selection, so the
%   units are those Compute uses) or the signal S.data with the channels
%   S.signal picks (selectChannels), whole. Every trial and every digital
%   line come along, with the trials S.selection keeps marked. Nothing is
%   computed. DatasetBrowser.loadSessions calls it for each ticked dataset.
%
%   With several kinds in S.data (["units" "LFP"]), D is a struct column,
%   one per kind in S.data's order, each as above (the settings of that
%   kind: epochMatrixSettings(S, Kind=K), so AUX among other kinds has all
%   its columns); the trials, lines and the rest are the same in each. A
%   kind the dataset lacks (no sorting, no such signal, no channel left) is
%   left out; when it lacks every kind, the first kind's error is raised.
%
%   D = sessionData(SRC, S, TrialsOnly=true) reads neither spikes nor
%   signal: D (one) has data "trials", spikes, units, signal and channels
%   are empty, and the rest (trials, events, lines, ...) is as above.
%
%   Two clocks. Spike times and signal samples are on the continuous
%   clock: sample k at (k-1)/fs. Digital events (events, lines, the
%   trials' TrialOnset, TrialEvents, ...) are on the digital clock: t =
%   row/fs. The same recording sample is 1/fs apart on the two;
%   eventsContinuous holds the events moved to the continuous clock, and
%   toContinuous(t) moves any digital-clock time (a trial column) there,
%   bit for bit as epochTable does: (round(t*fs) - 1)/fs.
%
%   D fields
%     key, name, folder, subject, startTime, tags
%     fs, durationSec   the recording's rate and length (NaN when unknown)
%     data              the kind: "units" | "detected" | "LFP" | "MUA" |
%                       "SPIKE" | "AUX"; "trials" with TrialsOnly
%     spikes            {nUnits x 1} spike times, s, continuous clock
%                       (spike data; {} for a signal)
%     units             table, one row per spike train (selectUnits' META;
%                       table() for a signal)
%     signal            [nSamples x nChannels] single, uV (AUX: V), row k
%                       at (k-1)/signalFs ([] for spike data). Whole: a MUA
%                       at 2 kHz x 64 channels x 1 h is ~1.8 GB
%     signalFs          its rate, Hz (NaN for spike data)
%     channels          table, one row per column of signal
%                       (selectChannels' META; table() for spike data)
%     events            struct: line -> [k x 2] [t_on t_off] s, digital
%                       clock (src.events: polarity applied, derived events
%                       included)
%     eventsContinuous  the same on the continuous clock
%     toContinuous      function: T -> T on the continuous clock
%     lines             table: Line, Count, MeanDurationSec, First, Last,
%                       Inverted, Derived (src.lines)
%     trials            every paired trial (src.trials; table() without)
%     kept              [nTrials x 1] logical: the trials S.selection keeps
%     group             [nTrials x 1] each trial's row of groups (0 = not kept)
%     groups            selectTrials' groups table: index, label, color, n,
%                       the groupBy parameters
%     hasTrials, trialLine, respField, paramNames, pairing, derivedEvents,
%     invertedLines     as in SRC
%     artifacts         [k x 2] s, continuous clock: the periods the
%                       Signals step erased
%     probe, labels     the probe map and the amplifier channel labels
%
%   Errors: those of selectUnits, selectChannels and selectTrials, plus
%   epochMatrix:NoChannels (no channel left by S.signal).
%
%   See also DatasetBrowser, epochMatrix, loadAnalysisSource, selectUnits,
%   selectChannels, selectTrials, epochTable.

arguments
    src (1,1) struct
    S = []
    opts.TrialsOnly (1,1) logical = false
end

S = epochMatrixSettings(S);
fs = src.fs;

D = struct();
D.key = src.key;
D.name = src.name;
D.folder = src.folder;
D.subject = src.subject;
D.startTime = src.startTime;
D.tags = src.tags;
D.fs = fs;
D.durationSec = src.durationSec;
D.data = "trials";
D.spikes = {};
D.units = table();
D.signal = [];
D.signalFs = NaN;
D.channels = table();

toContinuous = @(t) (round(t * fs) - 1) / fs;
D.events = src.events;
D.eventsContinuous = structfun(toContinuous, src.events, 'UniformOutput', false);
if isempty(fieldnames(src.events)); D.eventsContinuous = struct(); end
D.toContinuous = toContinuous;
D.lines = src.lines;

D.trials = src.trials;
[D.kept, D.groups, D.group] = selectTrials(src, S.selection);
D.hasTrials = src.hasTrials;
D.trialLine = src.trialLine;
D.respField = src.respField;
D.paramNames = src.paramNames;
D.pairing = src.pairing;
D.derivedEvents = src.derivedEvents;
D.invertedLines = src.invertedLines;
D.artifacts = src.artifacts;
D.probe = src.probe;
D.labels = src.labels;
if opts.TrialsOnly; return; end

% --- each kind: its spike trains or its signal
lacks = ["selectUnits:NoUnits" "selectUnits:NoDetected" "selectUnits:NoneLeft" "selectChannels:NoSignal" "epochMatrix:NoChannels"];
several = ~isscalar(S.data);
base = D;
D = repmat(base, 0, 1);
first = [];
for kind = S.data
    try
        D(end+1, 1) = kindData(base, src, epochMatrixSettings(S, Kind=kind)); %#ok<AGROW>
    catch ME
        if ~(several && ismember(string(ME.identifier), lacks)); rethrow(ME); end
        if isempty(first); first = ME; end   % the dataset lacks this kind: left out
    end
end
if isempty(D); rethrow(first); end
end


function D = kindData(D, src, S)
%kindData  D with the spike trains or the signal of S.data (one kind).
D.data = S.data;
if ismember(S.data, ["units" "detected"])
    [D.spikes, D.units] = selectUnits(src, S.units, Ref=S.ref, Selection=S.selection);
    return
end
sig = S.signal;
if S.data == "AUX"
    [Y, D.signalFs, meta] = selectChannels(src, S.data, Channels=sig.channels);
    cols = 1:height(meta);
else
    [Y, D.signalFs, meta] = selectChannels(src, S.data);
    keep = true(height(meta), 1);
    if ~isempty(sig.channels); keep = keep & ismember(meta.recordingChannel, sig.channels); end
    if ~isempty(sig.shanks); keep = keep & ismember(meta.shank, sig.shanks); end
    cols = reshape(find(keep), 1, []);
    if isempty(cols)
        error('epochMatrix:NoChannels', '%s: no %s channel is among recording channel(s) %s on shank(s) %s.', ...
            src.name, S.data, mat2str(sig.channels), mat2str(sig.shanks));
    end
end
if isequal(cols, 1:size(Y, 2))
    D.signal = Y;
else
    D.signal = Y(:, cols);
end
D.channels = meta(cols, :);
end
