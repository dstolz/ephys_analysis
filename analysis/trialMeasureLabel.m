function s = trialMeasureLabel(m)
%trialMeasureLabel  A trial measure in words, e.g. "Stim onset → Platform offset (ms)".
%   S = trialMeasureLabel(M) is M.label when it is set (its TeX character
%   names as the characters they name: "\Deltat (ms)" is "Δt (ms)",
%   figureLabelSymbols), else built from the
%   TrialMeasure M (EphysAnalysisConfig.defaults("TrialMeasure"); a partial
%   struct is completed from it) by its kind:
%     delay     after:  "<A> → <B> (<unit>)", e.g. "Stim onset → Platform
%                       offset (ms)"
%               before: "<B> before <A> (<unit>)", e.g. "Platform offset
%                       before Stim onset (ms)"
%     duration  "<A's line> duration (<unit>)", e.g. "Platform duration
%               (ms)"; with a sequence the whole reference follows in
%               parentheses
%     count     "<B line> <B edge>s after <A>", e.g. "Trough onsets after
%               Stim onset" (" within 2 s" with a finite maxGapSec)
%     param     the parameter, e.g. "RespLatency"
%   where A and B are eventRefLabel(..., Detail=true) of M.from and M.to:
%   the event with its sequence, "last " / "2nd " for which "last" / "nth"
%   and its shifts, as eventLatency names an event; a delay to every B
%   (which "all") reads "every <B>". The figure panels' trials layers
%   (their automatic names), the label variable {Measure} and the app use
%   it.
%
%   See also trialMeasure, eventRefLabel, eventLatency, figureLabelVariables.

arguments
    m (1,1) struct
end

m = EphysAnalysisConfig.normalizeSection("TrialMeasure", m);
if strtrim(m.label) ~= ""
    s = figureLabelSymbols(m.label);
    return
end
a = eventRefLabel(m.from, Detail=true);
unit = " (" + m.unit + ")";
switch m.kind
    case "delay"
        b = eventRefLabel(m.to, Detail=true);
        if m.to.which == "all"; b = "every " + b; end
        if m.direction == "before"
            s = b + " before " + a + unit;
        else
            s = a + " → " + b + unit;
        end
    case "duration"
        s = alignedLine(m.from) + " duration" + unit;
        if ismember(m.from.which, ["last" "nth"]); s = extractBefore(a, m.from.line) + s; end   % "last Platform duration"
        if ~isempty(m.from.sequence); s = s + " (" + a + ")"; end
    case "count"
        s = m.to.line + " " + m.to.edge + "s after " + a;
        if isfinite(m.maxGapSec); s = s + sprintf(" within %g s", m.maxGapSec); end
    case "param"
        s = m.param;
    otherwise
        s = m.kind;
end
end


function line = alignedLine(ref)
%alignedLine  The line of the event a reference picks: its own, or its sequence step aligned to (as eventRefLabel reads it).
line = ref.line;
steps = ref.sequence;
if isempty(steps); return; end
a = ref.alignStep;
last = find([steps.relation] == "followedBy", 1, 'last');
if isempty(last); last = 0; end
if isinf(a); a = last; end
if a >= 1 && a <= numel(steps); line = steps(a).line; end
end
