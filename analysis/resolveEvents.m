function [t, trial, k, shift, nNoValue, nNoSequence] = resolveEvents(src, ref, mask)
%resolveEvents  The event times an event reference picks out.
%   [T, TRIAL, K, SHIFT, NNOVALUE, NNOSEQUENCE] = resolveEvents(SRC, REF, MASK)
%   returns, for the dataset SRC (loadAnalysisSource) and the eventRef REF,
%     T      [n x 1] event times, s (the digital-event convention t = row/Fs
%            of the recording, src.fs; polarity applied, plus
%            REF.offsetSec and SHIFT), ascending
%     TRIAL  [n x 1] row of src.trials each event belongs to (NaN outside
%            any trial)
%     K      [n x 1] which interval of its trial (trial scope) or of the
%            recording (recording scope) the event came from, 1-based,
%            counted after the duration / time-range filters
%     SHIFT  [n x 1] what REF.offsetParam added to each event, s (its
%            trial's value of the parameter; 0 without offsetParam)
%     NNOVALUE  how many events REF.offsetParam dropped: outside the
%            trials, or on a trial without a finite value
%     NNOSEQUENCE  how many events REF.sequence cost (below)
%
%   An interval belongs to the trial whose [TrialOnset, TrialOffset] holds
%   its REF.edge (the edge before REF.offsetSec), in both scopes: an
%   interval that spans several trials counts once, for the trial holding
%   its onset (or offset), never for every trial it overlaps; an edge on
%   the boundary of two touching trials belongs to the earlier one.
%   Trial scope (REF.scope "trial", or "auto" with paired trials): for every
%   trial in MASK (logical over src.trials; [] = every paired trial) the
%   intervals of REF.line that belong to it (taken from its TrialEvents, the
%   intervals overlapping it) are filtered by duration and by timeRange
%   (relative to the trial onset) and REF.which picks among them. line
%   "Trial" (or the trial line itself) is the trial's own [TrialOnset
%   TrialOffset].
%   Recording scope: every interval of REF.line in src.events, filtered by
%   duration and timeRange (recording time), and REF.which picks over the
%   whole recording. Each event is assigned the trial it belongs to; when
%   MASK is given (a restrictive trial selection), events outside the kept
%   trials are dropped. line "Trial" is the pairing's trial line.
%
%   With REF.sequence, the line's events are found as above and each is
%   kept only when its sequence completes: every followedBy step's event
%   comes after the event before it (within the step's maxGapSec) and no
%   notFollowedBy step's does, never looking past the next trial's onset
%   (paired trials). Steps read the whole recording's intervals, so a step
%   after the trial's end (a Trough onset after TrialOffset) is found. The
%   duration / time-range filters and REF.which apply to the line's own
%   events, REF.which after the sequence: which "first" is the first event
%   the sequence follows. The time returned is the event REF.alignStep
%   names (the last followedBy step's by default); TRIAL and K stay those
%   of the line's own event. NNOSEQUENCE counts the picks the sequence
%   cost: per trial (trial scope) or over the recording, those REF.which
%   would have made without it less those it made; with which "all", every
%   event the sequence does not follow (in recording scope, of the kept
%   trials when MASK is given).
%
%   With REF.offsetParam (e.g. "RespLatency", REF.offsetParamUnit "ms")
%   each event is then moved by its trial's value of that parameter: the
%   trial is still the one holding the unshifted edge, and the events
%   without a value are dropped (NNOVALUE). The events are sorted after the
%   shift.
%
%   Errors: resolveEvents:NoTrials (trial scope, or offsetParam, without
%   paired trials), resolveEvents:NoLine (no such line),
%   resolveEvents:NoParam / resolveEvents:BadParam (offsetParam is not a
%   numeric trial column), resolveEvents:NoEvents (nothing left).
%
%   See also eventRef, epochTable, selectTrials.

arguments
    src (1,1) struct
    ref
    mask = []
end

ref = eventRef(ref);
scope = ref.scope;
if scope == "auto"
    if src.hasTrials; scope = "trial"; else; scope = "recording"; end
end
isTrialLine = ref.line == "Trial" || (src.trialLine ~= "" && ref.line == src.trialLine);
col = 1 + (ref.edge == "offset");   % the column of IV holding REF.edge

if scope == "trial"
    if ~src.hasTrials
        error('resolveEvents:NoTrials', ...
            '%s has no paired trials; use scope "recording" to align to %s over the whole recording.', src.name, ref.line);
    end
    T = src.trials;
    n = height(T);
    if isempty(mask); mask = true(n, 1); end
    rows = find(mask(:) & isfinite(T.TrialOnset));
    if ~isTrialLine && ~(n > 0 && isfield(T.TrialEvents, char(ref.line)))
        error('resolveEvents:NoLine', '%s: no digital line "%s" in the trials (lines: %s).', ...
            src.name, ref.line, strjoin(trialLines(src), ", "));
    end
    tc = cell(numel(rows), 1); rc = cell(numel(rows), 1); kc = cell(numel(rows), 1);
    nNoSequence = 0;
    for j = 1:numel(rows)
        r = rows(j);
        if isTrialLine
            iv = [T.TrialOnset(r) T.TrialOffset(r)];
        else
            iv = double(T.TrialEvents(r).(ref.line));
            if isempty(iv); iv = zeros(0, 2); end
            iv = iv(containingTrial(iv(:, col), T.TrialOnset, T.TrialOffset) == r, :);
        end
        [e, kk, ~, nn] = pickEvents(iv, ref, T.TrialOnset(r), -Inf, src);
        tc{j} = e; rc{j} = repmat(r, numel(e), 1); kc{j} = kk;
        nNoSequence = nNoSequence + nn;
    end
    t = vertcat(tc{:}, zeros(0, 1));
    trial = vertcat(rc{:}, zeros(0, 1));
    k = vertcat(kc{:}, zeros(0, 1));
else
    line = ref.line;
    if isTrialLine
        if src.trialLine == ""
            error('resolveEvents:NoLine', '%s: "Trial" needs paired trials to name the trial line.', src.name);
        end
        line = src.trialLine;
    end
    if ~isfield(src.events, line)
        error('resolveEvents:NoLine', '%s: no digital line "%s" (lines: %s).', ...
            src.name, line, strjoin(string(fieldnames(src.events)), ", "));
    end
    iv = double(src.events.(line));
    if isempty(iv); iv = zeros(0, 2); end
    [t, k, row, nNoSequence, failRows] = pickEvents(iv, ref, 0, -Inf, src);
    trial = NaN(size(t));
    if src.hasTrials
        trial = containingTrial(iv(row, col), src.trials.TrialOnset, src.trials.TrialOffset);
    end
    if ~isempty(mask)
        keep = isfinite(trial);
        keep(keep) = mask(trial(keep));
        t = t(keep); trial = trial(keep); k = k(keep);
        if ref.which == "all" && src.hasTrials   % count only the events of the kept trials
            ft = containingTrial(iv(failRows, col), src.trials.TrialOnset, src.trials.TrialOffset);
            nNoSequence = nnz(isfinite(ft) & mask(max(ft, 1)));
        end
    end
end

shift = trialParamShift(src, ref, trial);
has = isfinite(shift);
nNoValue = nnz(~has);
t = t(has) + shift(has); trial = trial(has); k = k(has); shift = shift(has);
[t, o] = sort(t);
trial = trial(o);
k = k(o);
shift = shift(o);
if isempty(t)
    hint = "";
    if nNoValue > 0
        hint = sprintf(' %d event(s) were dropped because their trial has no value of %s.', nNoValue, ref.offsetParam);
    elseif nNoSequence > 0
        hint = sprintf(' %d event(s) were dropped because their sequence (%s) did not follow.', nNoSequence, eventRefLabel(ref));
    elseif scope == "trial" && ~isTrialLine
        hint = sprintf(' In trial scope an interval counts for the trial that holds its %s; use scope "recording" for a line whose intervals lie between trials.', ref.edge);
    end
    error('resolveEvents:NoEvents', '%s: no %s %s event is left after the selection (scope %s, which %s).%s', ...
        src.name, ref.line, ref.edge, scope, ref.which, hint);
end
end


function r = containingTrial(x, on, off)
%containingTrial  Row of the first trial whose [on off] holds each time in X (NaN: none).
r = NaN(size(x));
for j = 1:numel(x)
    k = find(on <= x(j) & off >= x(j), 1);
    if ~isempty(k); r(j) = k; end
end
end


function names = trialLines(src)
names = string.empty(1, 0);
if src.hasTrials && height(src.trials) > 0
    names = string(fieldnames(src.trials.TrialEvents(1))).';
end
names = ["Trial" names];
end
