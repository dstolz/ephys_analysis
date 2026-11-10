function iv = lineIntervals(src, line, what)
%lineIntervals  The [on off] intervals of a digital line over the whole recording.
%   IV = lineIntervals(SRC, LINE) is every interval of LINE in the dataset
%   SRC (loadAnalysisSource): SRC.events' ("Trial" = the pairing's trial
%   line), else the paired trials' own [TrialOnset TrialOffset] ("Trial"),
%   else the trials' copies (TrialEvents), once each. [0 x 2] when the line
%   has none. Error resolveEvents:NoLine when the recording has no such
%   line; WHAT (optional, e.g. "the event sequence") says what wanted it.
%
%   See also followSequence, lineCleaner, resolveEvents.

if nargin < 3 || what == ""; what = ""; else; what = " for " + what; end
name = line;
if line == "Trial" && src.trialLine ~= ""
    name = src.trialLine;
end
if isfield(src.events, name)
    iv = double(src.events.(name));
elseif line == "Trial" && src.hasTrials
    iv = [src.trials.TrialOnset src.trials.TrialOffset];
elseif src.hasTrials && height(src.trials) > 0 && isfield(src.trials.TrialEvents, char(name))
    iv = unique(double(vertcat(src.trials.TrialEvents.(name), zeros(0, 2))), 'rows');   % the trials' copies, once each
else
    error('resolveEvents:NoLine', '%s: no digital line "%s"%s (lines: %s).', ...
        src.name, line, what, strjoin(string(fieldnames(src.events)), ", "));
end
if isempty(iv); iv = zeros(0, 2); end
end
