function fillTrialsLines(obj, S)
%fillTrialsLines  One row per digital line of the loaded events: Native |
%   Name | Intervals | Inverted (or the config's inverted lines when none
%   are loaded); the trial-line dropdown lists the named lines. S is the
%   Signals section whose LabelField / LineNames / InvertedLines apply
%   (default obj.Config.Signals).
if nargin < 2; S = obj.Config.Signals; end
low = reshape(string(S.InvertedLines), [], 1);
if isempty(obj.TrialsEvents)
    names = low;
    natives = strings(numel(names), 1);
    counts = NaN(numel(names), 1);
else
    try
        E = obj.namedTrialsEvents(S);
    catch ME
        E = EphysDataset.relabelEvents(obj.TrialsEvents, S.LabelField, string.empty(1, 0));
        obj.setStatus("Trials: " + string(ME.message) + " Showing the lines' default names.");
    end
    names = reshape(string(E.digInNames), [], 1);
    natives = reshape(string(E.digInNativeNames), [], 1);
    counts = zeros(numel(names), 1);
    for k = 1:numel(names)
        f = EphysReader.eventKey(names(k));
        if isfield(E.events, f); counts(k) = size(E.events.(f), 1); end
    end
end
obj.TrialsLinesTable.Data = table(natives, names, counts, ismember(names, low), ...
    'VariableNames', {'Native', 'Name', 'Intervals', 'Inverted'});
obj.setTrialsLineItems(names, string(obj.TrialsLineDropDown.Value));
end
