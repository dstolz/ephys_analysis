function fillTrialsLines(obj)
%fillTrialsLines  One row per digital line of the loaded events (or the
%   config's inverted lines when none are loaded); the trial-line dropdown
%   lists the loaded lines.
low = obj.Config.Signals.InvertedLines;
E = obj.TrialsEvents;
if isempty(E)
    names = low(:);
    counts = NaN(numel(names), 1);
else
    names = string(fieldnames(E.events));
    counts = cellfun(@(f) size(E.events.(f), 1), cellstr(names));
end
obj.TrialsLinesTable.Data = table(names, counts, ismember(names, low), ...
    'VariableNames', {'Line', 'Intervals', 'Inverted'});
obj.setTrialsLineItems(names, obj.Config.Behavior.TrialLine);
end
