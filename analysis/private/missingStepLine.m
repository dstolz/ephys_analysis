function reason = missingStepLine(src, ref)
%missingStepLine  "no line X" for the first step of an event reference's sequence whose line the recording lacks.
%   REASON = missingStepLine(SRC, REF) for a loadAnalysisSource struct SRC
%   and an EventRef REF: "" when every step's line of REF.sequence exists
%   (in SRC.events or the trials' TrialEvents; "Trial" or the trial line:
%   paired trials or the trial line's events).
%
%   See also hasLine, plotSkipReason, figureSkipReason.
reason = "";
for k = 1:numel(ref.sequence)
    ln = ref.sequence(k).line;
    if ln == "Trial" || (src.trialLine ~= "" && ln == src.trialLine)
        ok = src.hasTrials || isfield(src.events, src.trialLine);
    else
        ok = isfield(src.events, ln) || (src.hasTrials && height(src.trials) > 0 && isfield(src.trials.TrialEvents, char(ln)));
    end
    if ~ok
        reason = "no line " + ln;
        return
    end
end
end
