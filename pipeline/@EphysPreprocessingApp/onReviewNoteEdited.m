function onReviewNoteEdited(obj, evt)
%onReviewNoteEdited  Save a Notes cell of the Review units table.
%   The note belongs to the cluster in column 1 of the edited row and is
%   written with EphysDataset.writeUnitNotes to cluster_notes.tsv next to the
%   sort, the file phy reads and writes as its "notes" label, so every later
%   read (spikes step, exports, unitTable) carries it. A failed write puts the
%   previous text back and says why.
if isempty(obj.ReviewData) || isempty(evt.Indices)
    return
end
row = evt.Indices(1);
col = evt.Indices(2);
C = obj.ReviewUnitsTable.Data;
if ~iscell(C) || size(C, 1) < row
    return
end
cid = C{row, 1};
u = find(obj.ReviewData.clusterID == cid, 1);
if isempty(u)
    return
end
note = strtrim(regexprep(string(evt.NewData), '[\t\r\n]+', ' '));
try
    EphysDataset.writeUnitNotes(obj.ReviewData.folder, cid, note);
catch ME
    C{row, col} = char(obj.ReviewData.notes(u));
    obj.ReviewUnitsTable.Data = C;
    uialert(obj.Fig, sprintf("Could not save the note for unit %d:\n%s", cid, ME.message), "Review");
    return
end
obj.ReviewData.notes(u) = note;
obj.ReviewData.units.notes(u) = note;
C{row, col} = char(note);
obj.ReviewUnitsTable.Data = C;
obj.setStatus(sprintf("Saved the note for %s.", obj.ReviewData.unitLabel(u)), ...
    "Notes are kept in cluster_notes.tsv next to the sort.");
end
