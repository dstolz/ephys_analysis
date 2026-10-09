function ref = eventRef(s, opts)
%eventRef  Which digital-line event each epoch is aligned to.
%   REF = eventRef(Name=Value) or eventRef(S, Name=Value) returns a complete,
%   checked event reference: the fields of EphysAnalysisConfig.defaults
%   ("EventRef"), overlaid with struct S (e.g. from a config) and then with
%   the Name=Value options. eventRef("Platform") is short for
%   eventRef(line="Platform").
%
%   An event can be a sequence of events:
%     eventRef(line="Trial", edge="offset", sequence=struct('line', "Trough"))
%   aligns to the first Trough onset after each trial's end (before the next
%   trial), and
%     eventRef(line="Stim", sequence=struct('line', "Trough", 'maxGapSec', 1), alignStep=0)
%   to the stimuli that a Trough onset follows within 1 s.
%
%   Fields
%     line            digital line, e.g. "Stim". "Trial" is the paired trial
%                     line (behavior.pairing.trialLine): in trial scope its
%                     onset / offset are TrialOnset / TrialOffset
%     edge            "onset" | "offset" of each interval
%     which           "first" | "last" | "all" | "nth" interval (per trial in
%                     trial scope, over the whole recording otherwise)
%     n               the interval taken when which = "nth"
%     scope           "trial": the intervals of the line whose edge lies
%                     inside each selected trial, [TrialOnset, TrialOffset]
%                     (an interval spanning several trials counts once, for
%                     the trial holding its edge); "recording": every
%                     interval of the line (the extract's events); "auto"
%                     (default): trial when the dataset has paired trials,
%                     else recording
%     minDurationSec, maxDurationSec   keep intervals whose length lies in
%                     this range (default 0 .. Inf)
%     timeRange       [a b] s: keep intervals whose chosen edge lies in this
%                     range, relative to the trial onset in trial scope and to
%                     the recording start in recording scope
%     offsetSec       added to every resulting event time
%     offsetParam     "" (default) or a numeric trial parameter, e.g.
%                     "RespLatency": each event is moved by its trial's
%                     value of it (in offsetParamUnit), so epochs can be
%                     aligned to a per-trial time such as the response
%                     (RespWindow onset + RespLatency). Needs paired trials;
%                     an event outside the trials, or whose trial has no
%                     finite value (a miss's RespLatency), is dropped
%     offsetParamUnit "ms" (default, as Epsych2 stores times) or "s"
%     sequence        steps that must follow each event of line / edge
%                     (default none): a struct array of
%                     EphysAnalysisConfig.defaults("SequenceStep"), each
%                       relation   "followedBy" (default): the step's event
%                                  must come; "notFollowedBy": it must not
%                       line, edge the step's line ("Trial" = the trial
%                                  line) and edge
%                       n          followedBy: the nth such event (default 1)
%                       maxGapSec  within this long after the event before
%                                  (default Inf)
%                       minDurationSec, maxDurationSec   count only
%                                  intervals of this length
%                     Each step searches from the event before it (the line's
%                     own, or the last followedBy step's), never past the
%                     next trial's onset when the dataset has paired trials.
%                     An event whose sequence does not complete is left out
%                     before which picks, so which "first" is the first
%                     event that the sequence follows (see resolveEvents)
%     alignStep       which event of the sequence is the epoch's: 0 = the
%                     line's own (the steps are then conditions), k =
%                     sequence(k) (a followedBy step), Inf (default) = the
%                     last followedBy step. The trial is always the one
%                     holding the line's own event
%
%   Event times are the digital-event convention t = row/Fs, polarity
%   applied (see pairEpsychTrials); epochTable adds each event's time on
%   the continuous clock of the signals and spikes (t0Continuous). Errors:
%   eventRef:BadValue, eventRef:UnknownField.
%
%   See also resolveEvents, epochTable, epochWindow, trialSelection.

arguments
    s = []
    opts.line (1,1) string
    opts.edge (1,1) string
    opts.which (1,1) string
    opts.n (1,1) double
    opts.scope (1,1) string
    opts.minDurationSec (1,1) double
    opts.maxDurationSec (1,1) double
    opts.timeRange (1,2) double
    opts.offsetSec (1,1) double
    opts.offsetParam (1,1) string
    opts.offsetParamUnit (1,1) string
    opts.sequence
    opts.alignStep (1,1) double
end

if isempty(s)
    s = struct();
elseif isstring(s) || ischar(s)
    s = struct('line', string(s));
elseif ~isstruct(s) || ~isscalar(s)
    error('eventRef:BadValue', 'Pass a struct, a line name or Name=Value options.');
end
for f = string(fieldnames(opts)).'
    s.(f) = opts.(f);
end
[ref, unknown] = EphysAnalysisConfig.normalizeSection("EventRef", s);
if ~isempty(unknown)
    error('eventRef:UnknownField', 'Unknown event-reference field(s): %s.', strjoin(unknown, ", "));
end
ref.line = strtrim(ref.line);
if ref.line == ""
    error('eventRef:BadValue', 'line must name a digital line (or "Trial").');
end
mustBeOneOf(ref.edge, ["onset" "offset"], "edge");
mustBeOneOf(ref.which, ["first" "last" "all" "nth"], "which");
mustBeOneOf(ref.scope, ["trial" "recording" "auto"], "scope");
if ~(ref.n >= 1 && ref.n == round(ref.n))
    error('eventRef:BadValue', 'n must be a whole number >= 1.');
end
if ~(ref.minDurationSec >= 0 && ref.maxDurationSec >= ref.minDurationSec)
    error('eventRef:BadValue', 'Need 0 <= minDurationSec <= maxDurationSec.');
end
if ~(ref.timeRange(1) <= ref.timeRange(2))
    error('eventRef:BadValue', 'timeRange must be [a b] with a <= b.');
end
if ~isfinite(ref.offsetSec)
    error('eventRef:BadValue', 'offsetSec must be finite.');
end
ref.offsetParam = strtrim(ref.offsetParam);
mustBeOneOf(ref.offsetParamUnit, ["ms" "s"], "offsetParamUnit");
for k = 1:numel(ref.sequence)
    st = ref.sequence(k);
    what = sprintf("sequence(%d)", k);
    st.line = strtrim(st.line);
    if st.line == ""
        error('eventRef:BadValue', '%s.line must name a digital line (or "Trial").', what);
    end
    mustBeOneOf(st.relation, ["followedBy" "notFollowedBy"], what + ".relation");
    mustBeOneOf(st.edge, ["onset" "offset"], what + ".edge");
    if ~(st.n >= 1 && st.n == round(st.n) && isfinite(st.n))
        error('eventRef:BadValue', '%s.n must be a whole number >= 1.', what);
    end
    if ~(st.maxGapSec > 0)
        error('eventRef:BadValue', '%s.maxGapSec must be positive (Inf = up to the next trial).', what);
    end
    if ~(st.minDurationSec >= 0 && st.maxDurationSec >= st.minDurationSec)
        error('eventRef:BadValue', '%s: need 0 <= minDurationSec <= maxDurationSec.', what);
    end
    ref.sequence(k) = st;
end
a = ref.alignStep;
if ~(a == 0 || a == Inf || (a >= 1 && a == round(a) && a <= numel(ref.sequence)))
    error('eventRef:BadValue', 'alignStep must be 0 (the %s event), Inf (the last step) or a step of the sequence, 1..%d.', ...
        ref.line, numel(ref.sequence));
end
if a >= 1 && isfinite(a) && ref.sequence(a).relation ~= "followedBy"
    error('eventRef:BadValue', 'alignStep %d is a "notFollowedBy" step, which has no event to align to.', a);
end
end


function mustBeOneOf(v, allowed, name)
if ~ismember(v, allowed)
    error('eventRef:BadValue', '%s must be one of %s (got "%s").', name, strjoin(allowed, ", "), v);
end
end
