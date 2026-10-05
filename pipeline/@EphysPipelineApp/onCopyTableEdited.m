function onCopyTableEdited(obj, evt)
%onCopyTableEdited  A Copy tick changed in the source sessions table.
%   Ambiguous rows cannot be ticked: the tick is undone with an explanation.
row = evt.Indices(1);
if evt.Indices(2) ~= 1 || row > height(obj.CopySessions); return; end
tick = logical(evt.NewData);
if tick && obj.CopySessions.Status(row) == "ambiguous"
    tick = false;
    uialert(obj.Fig, "This pairing is ambiguous and is never copied: " + obj.CopySessions.Note(row) ...
        + newline + newline + "Pair these files by hand.", "Ambiguous session", "Icon", "warning");
end
obj.CopyTicked(row) = tick;
obj.refreshCopyTable();
end
