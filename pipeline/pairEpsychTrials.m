function P = pairEpsychTrials(trials, events, Fs, opts)
%pairEpsychTrials  Pair Epsych2 trials, in order, with the intervals of a digital line.
%   P = pairEpsychTrials(TRIALS, EVENTS, Fs, Name=Value) pairs the rows of
%   TRIALS (readEpsychSession: one row per trial, in the order they were
%   run) with the intervals of the digital line Epsych2 holds on for the
%   duration of a trial (TrialLine, default "InTrial") and returns the timing
%   of every trial in seconds and in samples, plus the intervals of every
%   other line that overlap each trial. Nothing here depends on the
%   acquisition system: EVENTS is the universal events struct (one field per
%   line, [k x 2] [t_on t_off] seconds with t = row/Fs, see EphysReader) and
%   Fs its sample rate.
%
%   Pairing
%   -------
%   The Epsych2 timestamps are not used. The first trial pairs with the
%   first interval of the trial line, the second with the second, and so on:
%   every interval is taken to be one trial. When the number of trials and
%   the number of intervals differ, the first min(nTrials, nIntervals) still
%   pair in order and the result is flagged (countMismatch, warnings, and a
%   pairEpsychTrials:CountMismatch warning unless Warn=false). A mismatch
%   means the recording did not cover the whole session (it was started
%   late or stopped early) or the line carries intervals that are not
%   trials. Resolve it with CutTrials / CutIntervals, which drop trials or
%   intervals from the start or the end before pairing; the app's Trials tab
%   does this interactively and EphysDataset.pairTrials keeps the reviewed
%   cuts in the manifest. Every result is meant to be reviewed.
%
%   Intervals at the recording edges
%   --------------------------------
%   An interval that begins at the first sample of the recording, or ends at
%   its last sample (NumSamples), is partial: the line was already on when
%   the recording started (it started during a trial, or before Epsych2 had
%   set the line to its idle level, which for an inverted line is high) or
%   was still on when the recording stopped. Such intervals are listed in
%   partialIntervals, the trials paired with them are flagged "partial", and
%   the count-mismatch warning points them out, since they are usually what
%   has to be cut. Without NumSamples only the recording start is checked.
%
%   Line polarity
%   -------------
%   EVENTS holds the HIGH runs of every line, as readers return them. Lines
%   named in InvertedLines are on while low: their onset is the falling edge
%   and their offset the last low sample (digitalLinePolarity, which needs
%   NumSamples). Pass EVENTS that already had the polarity applied (e.g. an
%   extract's events) with InvertedLines empty.
%
%   Options
%   -------
%     TrialLine       "InTrial"   line whose intervals are trials
%     InvertedLines   string list of lines with inverted polarity (default
%                     none; names the struct lacks are ignored)
%     NumSamples      recording length in samples (needed to invert a line
%                     and to detect intervals that run to the recording end)
%     CutTrials       [0 0]  trials to drop [from the start, from the end]
%     CutIntervals    [0 0]  trial-line intervals to drop [start, end]
%     SignalFs        struct of derived-signal rates, e.g. struct('LFP', 1000)
%     Warn            true: a count mismatch raises pairEpsychTrials:CountMismatch
%
%   Output P
%   --------
%     trialLine, invertedLines (those applied), Fs, nSamples, nTrials,
%        nIntervals, cutTrials, cutIntervals
%     intervals       [nIntervals x 2] the trial line's intervals (s, polarity applied)
%     events          the events struct with the polarity applied
%     interval        [nTrials x 1] index into intervals (NaN when cut or unpaired)
%     onset, offset   [nTrials x 1] seconds (t = row/Fs), NaN when unpaired
%     onsetSample, offsetSample   1-based rows at Fs (first / last on sample)
%     signalFs        struct: <signal> -> rate used (valid SignalFs entries)
%     signalSamples   struct: <signal> -> [nTrials x 2] 1-based rows of that
%                     signal, round((t - 1/Fs) * signalFs) + 1: row r at Fs
%                     lies at (r-1)/Fs on the continuous clock, and this is
%                     the signal's sample nearest it (ChronuxDataset.trials'
%                     "event" onset rule)
%     flag            [nTrials x 1] "ok" | "partial" | "cut" | "unpaired"
%     partialIntervals   intervals touching the recording start or end
%     unpairedTrials, unpairedIntervals   kept, but left without a partner
%     nPaired, countMismatch
%     warnings        string list: the count-mismatch message, or empty
%     lines           struct: <line> -> {nTrials x 1} [n x 2] seconds of that
%                     line's intervals overlapping the trial (every line but
%                     the trial line, polarity applied)
%     columns         table (nTrials rows) to append to TRIALS: TrialInterval,
%                     TrialOnset, TrialOffset, TrialOnsetSample,
%                     TrialOffsetSample, TrialOnsetSample_<SIG>,
%                     TrialOffsetSample_<SIG>, PairingFlag, TrialEvents
%                     (struct: <line> -> [n x 2] s) and TrialEventSamples
%                     (<line> -> [n x 2] rows at Fs)
%     summary         one line of text
%
%   See also readEpsychSession, EphysDataset.pairTrials, ChronuxDataset.trials.

arguments
    trials table
    events (1,1) struct
    Fs (1,1) double {mustBePositive}
    opts.TrialLine (1,1) string = "InTrial"
    opts.InvertedLines (1,:) string = string.empty(1,0)
    opts.NumSamples (1,1) double = NaN
    opts.CutTrials (1,2) double {mustBeNonnegative, mustBeInteger} = [0 0]
    opts.CutIntervals (1,2) double {mustBeNonnegative, mustBeInteger} = [0 0]
    opts.SignalFs (1,1) struct = struct()
    opts.Warn (1,1) logical = true
end

lineNames = string(fieldnames(events)).';
if ~ismember(opts.TrialLine, lineNames)
    error('pairEpsychTrials:NoTrialLine', 'No digital line "%s" (lines: %s).', ...
        opts.TrialLine, strjoin(lineNames, ", "));
end

% --- polarity ---------------------------------------------------------------
[events, inverted] = digitalLinePolarity(events, opts.InvertedLines, opts.NumSamples, Fs);
for ln = lineNames
    iv = double(events.(ln));
    if isempty(iv); iv = zeros(0, 2); end
    events.(ln) = iv;
end
trialIv = events.(opts.TrialLine);

nT = height(trials);
nI = size(trialIv, 1);
ct = opts.CutTrials;
ci = opts.CutIntervals;
if sum(ct) > nT
    error('pairEpsychTrials:Cuts', 'CutTrials [%d %d] drops more than the %d trial(s).', ct(1), ct(2), nT);
end
if sum(ci) > nI
    error('pairEpsychTrials:Cuts', 'CutIntervals [%d %d] drops more than the %d %s interval(s).', ...
        ci(1), ci(2), nI, opts.TrialLine);
end

P = struct();
P.trialLine     = opts.TrialLine;
P.invertedLines = inverted;
P.Fs            = Fs;
P.nSamples      = opts.NumSamples;
P.nTrials       = nT;
P.nIntervals    = nI;
P.cutTrials     = ct;
P.cutIntervals  = ci;
P.intervals     = trialIv;
P.events        = events;

% --- in-order pairing of what is left after the cuts -------------------------
tKeep = (ct(1) + 1 : nT - ct(2)).';
iKeep = (ci(1) + 1 : nI - ci(2)).';
n = min(numel(tKeep), numel(iKeep));
a = NaN(nT, 1);
a(tKeep(1:n)) = iKeep(1:n);
paired = ~isnan(a);
isCut = true(nT, 1);
isCut(tKeep) = false;

rows = round(trialIv * Fs);
atStart = rows(:, 1) <= 1;
atEnd = false(nI, 1);
if isfinite(opts.NumSamples) && opts.NumSamples > 0
    atEnd = rows(:, 2) >= opts.NumSamples;
end
partial = find(atStart | atEnd);

P.interval = a;
P.onset = NaN(nT, 1);
P.offset = NaN(nT, 1);
P.onset(paired)  = trialIv(a(paired), 1);
P.offset(paired) = trialIv(a(paired), 2);
P.onsetSample  = round(P.onset * Fs);
P.offsetSample = round(P.offset * Fs);

P.signalFs = struct();
P.signalSamples = struct();
for sig = string(fieldnames(opts.SignalFs)).'
    fsSig = double(opts.SignalFs.(sig));
    if isscalar(fsSig) && isfinite(fsSig) && fsSig > 0
        P.signalFs.(sig) = fsSig;
        P.signalSamples.(sig) = round(([P.onset P.offset] - 1/Fs) * fsSig) + 1;
    end
end

P.flag = repmat("ok", nT, 1);
P.flag(paired & ismember(a, partial)) = "partial";
P.flag(isCut) = "cut";
P.flag(~paired & ~isCut) = "unpaired";
P.partialIntervals = partial;
P.unpairedTrials = tKeep(n + 1:end);
P.unpairedIntervals = iKeep(n + 1:end);
P.nPaired = n;
P.countMismatch = numel(tKeep) ~= numel(iKeep);

% --- the count-mismatch warning ---------------------------------------------
P.warnings = strings(1, 0);
if P.countMismatch
    msg = sprintf("Epsych2 has %d trial(s) but the %s line has %d interval(s)", ...
        numel(tKeep), opts.TrialLine, numel(iKeep));
    if any(ct) || any(ci)
        msg = msg + sprintf(" after cutting %d + %d trial(s) and %d + %d interval(s) (start + end)", ...
            ct(1), ct(2), ci(1), ci(2));
    end
    msg = msg + ".";
    if ~isempty(iKeep) && atStart(iKeep(1))
        msg = msg + sprintf(" Interval %d begins at the first sample of the recording: the recording " + ...
            "started during a trial, or before Epsych2 had set the line to its idle level.", iKeep(1));
    end
    if ~isempty(iKeep) && atEnd(iKeep(end))
        msg = msg + sprintf(" Interval %d ends at the last sample of the recording: the recording " + ...
            "stopped during a trial, or after Epsych2 had released the line.", iKeep(end));
    end
    msg = msg + " Cut trials or intervals from the start or the end to resolve it " + ...
        "(CutTrials / CutIntervals; the app's Trials tab), then review the pairing.";
    P.warnings = msg;
    if opts.Warn
        warning('pairEpsychTrials:CountMismatch', '%s', msg);
    end
end

% --- other lines, per trial -------------------------------------------------
P.lines = struct();
others = lineNames(lineNames ~= opts.TrialLine);
trialEv = repmat(struct(), nT, 1);
trialEvS = repmat(struct(), nT, 1);
for ln = others
    iv = events.(ln);
    per = cell(nT, 1);
    for i = 1:nT
        if paired(i) && ~isempty(iv)
            per{i} = iv(iv(:, 1) <= P.offset(i) & iv(:, 2) >= P.onset(i), :);
        else
            per{i} = zeros(0, 2);
        end
        trialEv(i).(ln) = per{i};
        trialEvS(i).(ln) = round(per{i} * Fs);
    end
    P.lines.(ln) = per;
end

% --- columns to append to the trials table ---------------------------------
C = table(P.interval, P.onset, P.offset, P.onsetSample, P.offsetSample, ...
    'VariableNames', {'TrialInterval', 'TrialOnset', 'TrialOffset', 'TrialOnsetSample', 'TrialOffsetSample'});
for sig = string(fieldnames(P.signalSamples)).'
    C.("TrialOnsetSample_" + sig)  = P.signalSamples.(sig)(:, 1);
    C.("TrialOffsetSample_" + sig) = P.signalSamples.(sig)(:, 2);
end
C.PairingFlag = P.flag;
C.TrialEvents = trialEv;
C.TrialEventSamples = trialEvS;
P.columns = C;

s = sprintf("%d of %d trial(s) paired in order with %d %s interval(s)", n, nT, nI, opts.TrialLine);
if any(ct); s = s + sprintf("; %d + %d trial(s) cut (start + end)", ct(1), ct(2)); end
if any(ci); s = s + sprintf("; %d + %d interval(s) cut (start + end)", ci(1), ci(2)); end
if ~isempty(partial)
    s = s + sprintf("; partial interval(s) at the recording edge: %s", strjoin(string(partial(:).'), ", "));
end
if P.countMismatch
    s = s + sprintf("; COUNT MISMATCH: %d trial(s) vs %d interval(s)", numel(tKeep), numel(iKeep));
end
P.summary = s;
end
