function onNasTableEdited(obj, evt)
%onNasTableEdited  A Copy tick changed in the NAS sessions table.
%   Ambiguous rows cannot be ticked: the tick is undone with an explanation.
row = evt.Indices(1);
if evt.Indices(2) ~= 1 || row > height(obj.NasSessions); return; end
tick = logical(evt.NewData);
if tick && obj.NasSessions.Status(row) == "ambiguous"
    tick = false;
    uialert(obj.Fig, "This pairing is ambiguous and is never copied: " + obj.NasSessions.Note(row) ...
        + newline + newline + "Pair these files by hand.", "Ambiguous session", "Icon", "warning");
end
obj.NasTicked(row) = tick;
obj.refreshNasTable();
end
