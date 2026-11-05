function s = eventRefLabel(ref, opts)
%eventRefLabel  An event reference's event in words, e.g. "Trial offset then Trough onset".
%   S = eventRefLabel(REF) names the line and edge of the eventRef REF
%   ("Stim onset") and, with a sequence, each step after it: "then
%   <line> <edge>" for a followedBy step ("then 2nd Trough onset within
%   1 s"), "with no <line> <edge>" for a notFollowedBy one. When the epoch
%   is aligned to another event than the last step's, the label says
%   which: "Stim onset then Trough onset within 1 s (aligned to Stim
%   onset)". Captions, titles, raster-mark legends and the app use it.
%
%   S = eventRefLabel(REF, Detail=true) also says which of the events
%   (REF.which "last" or "nth": "last Platform offset", "2nd Trough
%   onset") and its shifts (" + RespLatency (ms)", " +0.05 s"):
%   eventLatency's and trialMeasureLabel's words.
%
%   See also eventRef, figureCaption, renderFigure, eventLatency, trialMeasureLabel.

arguments
    ref
    opts.Detail (1,1) logical = false
end

ref = EphysAnalysisConfig.normalizeSection("EventRef", ref);
s = ref.line + " " + ref.edge;
steps = ref.sequence;
if ~isempty(steps); s = sequenceWords(s, ref, steps); end
if ~opts.Detail; return; end
switch ref.which
    case "last", s = "last " + s;
    case "nth",  s = ordinal(ref.n) + " " + s;
end
if ref.offsetParam ~= ""; s = s + " + " + ref.offsetParam + " (" + ref.offsetParamUnit + ")"; end
if ref.offsetSec ~= 0; s = s + sprintf(" %+g s", ref.offsetSec); end
end


function s = sequenceWords(s, ref, steps)
%sequenceWords  S with each sequence step after it, and the event aligned to when it is not the last step's.
names = strings(1, numel(steps));
for k = 1:numel(steps)
    st = steps(k);
    names(k) = st.line + " " + st.edge;
    what = names(k);
    if st.relation == "followedBy" && st.n > 1; what = ordinal(st.n) + " " + what; end
    if isfinite(st.maxGapSec); what = what + sprintf(" within %g s", st.maxGapSec); end
    if st.relation == "notFollowedBy"
        s = s + " with no " + what;
    else
        s = s + " then " + what;
    end
end
a = ref.alignStep;
last = find([steps.relation] == "followedBy", 1, 'last');
if isempty(last); last = 0; end
if isinf(a); a = last; end
if a ~= last
    if a == 0
        s = s + " (aligned to " + ref.line + " " + ref.edge + ")";
    else
        s = s + " (aligned to " + names(a) + ")";
    end
end
end


function s = ordinal(n)
suffix = "th";
if mod(n, 100) < 11 || mod(n, 100) > 13
    switch mod(n, 10)
        case 1, suffix = "st";
        case 2, suffix = "nd";
        case 3, suffix = "rd";
    end
end
s = n + suffix;
end
