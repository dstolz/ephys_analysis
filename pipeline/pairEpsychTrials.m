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
%   intervals from the start or the end before pairing, and DropIntervals,
%   which drops single intervals from the middle of the list (a glitch pulse
%   on the line); the app's Trials tab does the end cuts interactively and
%   EphysDataset.pairTrials keeps the reviewed cuts and drops in the
%   manifest. Every result is meant to be reviewed.
%
%   Timing cross-check
%   ------------------
%   Pairing by order alone cannot tell a glitch pulse plus a missing last
%   pulse (the counts still agree, and every trial after the glitch is paired
%   with the wrong interval) from a good pairing. When TRIALS has the
%   Epsych2 computerTimestamp, it is checked against the intervals. Epsych2
%   logs that time once it sees the trial is over, and starts the next trial
%   only after that, so on the recording's clock a trial's timestamp lies
%   after the end of its own interval and before the onset of the next
%   trial's. It is not the trial's end: on real sessions it comes a few tens
%   of ms after the TrialOffset on most trials but 1-3 s after it on a hit
%   (the reward) and up to 20 s on the odd trial, so only these two bounds
%   are tested, never the lag itself. Each paired trial bounds the offset
%   between the computer clock and the recording's, [ts - next onset,
%   ts - offset], widened by timingTolerance (0.5 s, for the drift between
%   the two clocks); the first trial whose bounds miss those of every trial
%   before it is reported as timingMismatch (its row; 0: none), with a
%   pairEpsychTrials:TimingMismatch warning (unless Warn=false) when the
%   counts agree: with a count mismatch the pairing is not trusted anyway and
%   the check runs again on whatever the cuts leave. A trial paired one
%   interval too early ends after the next onset it was given, one paired
%   too late ends before its interval does. A session without
%   computerTimestamp is not checked (timingChecked 0).
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
%     DropIntervals   []  indices of single trial-line intervals to drop from
%                     the middle of the list, numbered as in P.intervals (before
%                     any cut); intervals the end cuts already drop are
%                     ignored
%     SignalFs       struct of derived-signal rates, e.g. struct('LFP', 1000)
%     Warn            true: a count mismatch raises pairEpsychTrials:CountMismatch
%
%   Output P
%   --------
%     trialLine, invertedLines (those applied), Fs, nSamples, nTrials,
%        nIntervals, cutTrials, cutIntervals, dropIntervals ([1 x k] sorted)
%     intervals      [nIntervals x 2] the trial line's intervals (s, polarity applied)
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
%     timingMismatch  row of the first trial whose Epsych2 timestamp its
%                     interval cannot have (0: none), timingChecked (how many
%                     paired trials with a timestamp were checked),
%                     timingTolerance (s; NaN when none was)
%     warnings        string list: the count-mismatch message and/or the
%                     timing-mismatch message, or empty
%     lines           struct: <line> -> {nTrials x 1} [n x 2] seconds of that
%                     line's intervals overlapping the trial (every line but
%                     the trial line, polarity applied). An interval belongs
%                     to every trial it overlaps: it begins at or before
%                     TrialOffset + 1/Fs (an event on the first low row after
%                     the trial still belongs to it) and ends at or after
%                     TrialOnset
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
    opts.DropIntervals (1,:) double {mustBePositive, mustBeInteger} = zeros(1, 0)
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
dropI = reshape(unique(opts.DropIntervals), 1, []);
if any(dropI > nI)
    error('pairEpsychTrials:Cuts', 'DropIntervals %s: the %s line has only %d interval(s).', ...
        mat2str(dropI(dropI > nI)), opts.TrialLine, nI);
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
P.dropIntervals = dropI;
P.intervals     = trialIv;
P.events        = events;

% --- in-order pairing of what is left after the cuts and drops -----------------
tKeep = (ct(1) + 1 : nT - ct(2)).';
iKeep = (ci(1) + 1 : nI - ci(2)).';
iKeep(ismember(iKeep, dropI)) = [];
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
    if ~isempty(dropI)
        msg = msg + sprintf(" and dropping interval(s) %s", strjoin(string(dropI), ", "));
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
    msg = msg + " Cut trials or intervals from the start or the end, or drop a glitch interval, to resolve it " + ...
        "(CutTrials / CutIntervals / DropIntervals; the app's Trials tab cuts), then review the pairing.";
    P.warnings = msg;
    if opts.Warn
        warning('pairEpsychTrials:CountMismatch', '%s', msg);
    end
end

% --- timing cross-check against the Epsych2 clock -----------------------------
[P.timingMismatch, P.timingChecked, P.timingTolerance, side, by] = timingCheck(trials, P.onset, P.offset);
if P.timingMismatch > 0 && ~P.countMismatch
    if side == "early"
        what = sprintf("at least %.1f s before its paired %s interval ended", by, opts.TrialLine);
    else
        what = sprintf("at least %.1f s after the next trial's %s interval began", by, opts.TrialLine);
    end
    msgT = sprintf(['Trial %d does not agree with the Epsych2 timestamps: by the computer clock, set by the ' ...
        'trials before it, it ended %s. Epsych2 logs a trial''s end after the line goes off and starts the ' ...
        'next trial after that. The intervals from here on may be paired with the wrong trials: a glitch ' ...
        'pulse on the line, or one missing. Drop the extra interval (DropIntervals) or cut trials / ' ...
        'intervals, then review the pairing.'], P.timingMismatch, what);
    P.warnings(end + 1) = string(msgT);
    if opts.Warn
        warning('pairEpsychTrials:TimingMismatch', '%s', msgT);
    end
end

% --- other lines, per trial -------------------------------------------------
% An interval is listed in every trial it overlaps: it begins at or before the
% trial's last high row + 1 sample and ends at or after its first (containingTrial).
P.lines = struct();
others = lineNames(lineNames ~= opts.TrialLine);
trialEv = repmat(struct(), nT, 1);
trialEvS = repmat(struct(), nT, 1);
for ln = others
    iv = events.(ln);
    per = repmat({zeros(0, 2)}, nT, 1);
    if ~isempty(iv) && any(paired)
        [~, pr] = containingTrial(iv, P.onset, P.offset, 1 / Fs);   % [interval trial], by trial
        if ~isempty(pr)
            ids = accumarray(pr(:, 2), pr(:, 1), [nT 1], @(v) {v});
            for i = find(~cellfun(@isempty, ids)).'
                per{i} = iv(ids{i}, :);
            end
        end
    end
    for i = 1:nT
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
if ~isempty(dropI); s = s + sprintf("; interval(s) %s dropped", strjoin(string(dropI), ", ")); end
if ~isempty(partial)
    s = s + sprintf("; partial interval(s) at the recording edge: %s", strjoin(string(partial(:).'), ", "));
end
if P.countMismatch
    s = s + sprintf("; COUNT MISMATCH: %d trial(s) vs %d interval(s)", numel(tKeep), numel(iKeep));
end
if P.timingMismatch > 0
    s = s + sprintf("; TIMING MISMATCH at trial %d", P.timingMismatch);
end
P.summary = s;
end


function [bad, nChecked, tol, side, by] = timingCheck(trials, onset, offset)
%timingCheck  First paired trial whose Epsych2 timestamp its interval cannot have (0: none).
%   Trial i's computerTimestamp ts, on the recording's clock (ts - b for one
%   clock offset b), lies after its interval's offset and before the next
%   trial's onset: b is in [ts - onset(i+1), ts - offset(i)], widened by TOL.
%   The first trial whose range misses the intersection of the ranges of
%   the trials before it is BAD; SIDE says which bound it broke ("early":
%   logged before its interval ended; "late": after the next one began) and
%   BY by at least how many seconds. A trial without a timestamp or an
%   interval is skipped, and without a paired next trial only the lower
%   bound is known.
bad = 0;
nChecked = 0;
tol = NaN;
side = "";
by = NaN;
if ~ismember("computerTimestamp", string(trials.Properties.VariableNames)) || ~isdatetime(trials.computerTimestamp)
    return
end
ts = trials.computerTimestamp(:);
ok = ~isnat(ts) & isfinite(offset(:));
nChecked = nnz(ok);
if nChecked == 0
    return
end
tol = 0.5;
c = seconds(ts - ts(find(ok, 1)));
nextOn = [onset(2:end); NaN];
lo = c - nextOn - tol;
lo(isnan(lo)) = -Inf;
hi = c - offset(:) + tol;
L = -Inf;
H = Inf;
for i = find(ok).'
    if hi(i) < L
        bad = i; side = "early"; by = L - hi(i) + tol;
        return
    elseif lo(i) > H
        bad = i; side = "late"; by = lo(i) - H + tol;
        return
    end
    L = max(L, lo(i));
    H = min(H, hi(i));
end
end
