function refreshNotes(obj)
%refreshNotes  Show the notes everywhere: the Data tab's ✎ column, the ✎ marks, the note buttons and the search window.
%   The Data tab's ✎ column (refreshDatasetsTable), the Dataset drop-downs
%   (refreshDatasetLabels), the observation picker (markObservations) and
%   the note buttons (syncNoteButtons) follow the notes in memory (Notes:
%   a DatasetNotes each, read on Scan); an open Search notes window lists
%   them again (NoteSearch.setEntries, its search and pick kept). Nothing
%   is read: the notepad has just written what changed.
%
%   See also DatasetNotes, onNoteButton, onSearchNotes, onScan.
r = obj.Runner;
if ~isempty(r) && ~isempty(r.Keys)
    obj.refreshDatasetsTable();
    refreshDatasetLabels(obj);
end
markObservations(obj);
syncNoteButtons(obj);
s = obj.NoteSearchWindow;
if ~isempty(s) && isvalid(s)
    s.setEntries(noteEntries(obj));
end
end
