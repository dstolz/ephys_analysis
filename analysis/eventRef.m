function ref = eventRef(s, opts)
%eventRef  Which digital-line event each epoch is aligned to.
%   REF = eventRef(Name=Value) or eventRef(S, Name=Value) returns a complete,
%   checked event reference: the fields of EphysAnalysisConfig.defaults
%   ("EventRef"), overlaid with struct S (e.g. from a config) and then with
%   the Name=Value options. eventRef("Platform") is short for
%   eventRef(line="Platform").
%
%   Fields
%     line            digital line, e.g. "Stim". "Trial" is the paired trial
%                     line (behavior.pairing.trialLine): in trial scope its
%                     onset / offset are TrialOnset / TrialOffset
%     edge            "onset" | "offset" of each interval
%     which           "first" | "last" | "all" | "nth" interval (per trial in
%                     trial scope, over the whole recording otherwise)
%     n               the interval taken when which = "nth"
%     scope           "trial": the intervals of the line that overlap each
%                     selected trial (behavior TrialEvents); "recording":
%                     every interval of the line (the extract's events);
%                     "auto" (default): trial when the dataset has paired
%                     trials, else recording
%     minDurationSec, maxDurationSec   keep intervals whose length lies in
%                     this range (default 0 .. Inf)
%     timeRange       [a b] s: keep intervals whose chosen edge lies in this
%                     range, relative to the trial onset in trial scope and to
%                     the recording start in recording scope
%     offsetSec       added to every resulting event time
%
%   Event times are the digital-event convention t = row/Fs, polarity
%   applied (see pairEpsychTrials). Errors: eventRef:BadValue,
%   eventRef:UnknownField.
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
end


function mustBeOneOf(v, allowed, name)
if ~ismember(v, allowed)
    error('eventRef:BadValue', '%s must be one of %s (got "%s").', name, strjoin(allowed, ", "), v);
end
end
