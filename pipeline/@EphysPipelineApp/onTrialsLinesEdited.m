function onTrialsLinesEdited(obj, evt)
%onTrialsLinesEdited  A Name or Inverted cell of the Trials lines table changed.
%   Renaming a line writes a Signals.LineNames entry "native=name" (removed
%   again when the name is set back to the line's default) and re-pairs from
%   the events in memory; the trial line and the inverted lines follow the
%   new name. Ticking Inverted changes Signals.InvertedLines.
col = evt.Indices(2);
L = obj.TrialsLinesTable.Data;
if strcmp(L.Properties.VariableNames{col}, 'Name')
    row = evt.Indices(1);
    old = string(evt.PreviousData);
    new = strtrim(string(evt.NewData));
    E = obj.namedTrialsEvents();
    if new == "" && ~isempty(E)
        new = E.digInDefaultNames(row);     % blank: back to the default name
    end
    if ~isvarname(new)
        L.Name(row) = old;
        obj.TrialsLinesTable.Data = L;
        obj.setStatus(sprintf("Trials: ""%s"" is not a valid line name (letters, digits and _, starting with a letter).", new));
        return
    end
    if any(L.Name([1:row-1, row+1:end]) == new)
        L.Name(row) = old;
        obj.TrialsLinesTable.Data = L;
        obj.setStatus(sprintf("Trials: another line is already named ""%s"".", new));
        return
    end
    L.Name(row) = new;
    obj.TrialsLinesTable.Data = L;
    S = obj.Config.Signals;
    S.InvertedLines(S.InvertedLines == old) = [];
    obj.Config.Signals = S;
    if string(obj.TrialsLineDropDown.Value) == old
        obj.setTrialsLineItems(L.Name, new);
    end
    obj.onConfigChanged();
    obj.fillTrialsLines();
    if ~isempty(obj.TrialsEvents)
        obj.repairTrials("recorded");
    end
else
    obj.onTrialsSettingsChanged();
end
end
