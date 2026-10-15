function tf = hasLine(src, ref)
%hasLine  The line of an event reference exists where the reference's scope looks for it.
%   TF = hasLine(SRC, REF) for a loadAnalysisSource struct SRC and an
%   EventRef REF: "Trial" (or the trial line) needs paired trials or the
%   trial line's events; a trial-scoped reference (or "auto" with paired
%   trials) looks in the trials' TrialEvents, any other in SRC.events.
%
%   See also missingStepLine, figureSkipReason.
if ref.line == "Trial" || (src.trialLine ~= "" && ref.line == src.trialLine)
    tf = src.hasTrials || isfield(src.events, src.trialLine);
    return
end
useTrials = ref.scope == "trial" || (ref.scope == "auto" && src.hasTrials);
if useTrials && src.hasTrials && height(src.trials) > 0
    tf = isfield(src.trials.TrialEvents, char(ref.line));
else
    tf = isfield(src.events, ref.line);
end
end
