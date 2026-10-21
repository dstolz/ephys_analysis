function onSearchNotes(obj)
%onSearchNotes  The Search notes window (toolbar): every note of the scanned datasets, searched as you type; Go to opens a note's dataset.
%   One window (NoteSearch, kept in NoteSearchWindow) lists the notes of
%   every scanned dataset (noteEntries): on the dataset, its channels and
%   the units of its sort, and notes on units of an earlier sort too. Typing
%   keeps the notes holding every word, in their dataset name, what they
%   are on or their text. Go to, or a double-click, makes the note's
%   dataset the active one and picks its unit or channel for the Figures
%   tab's preview (goToNote); Edit note opens it in the notepad
%   (openNotePad, staying on that note). Pressed again while it is open,
%   the window comes to the front with the notes listed again.
%
%   See also NoteSearch, noteEntries, goToNote, refreshNotes.
s = obj.NoteSearchWindow;
if ~isempty(s) && isvalid(s)
    s.setEntries(noteEntries(obj));
    if s.Fig.Visible == "on"
        figure(s.Fig);
        focus(s.Field);
    end
    return
end
if isempty(obj.Runner)
    empty = "Scan for datasets first (Data tab): this searches the notes of the scanned datasets.";
else
    empty = "No notes in the scanned datasets yet: write one with ✎ beside a Dataset or Observation drop-down, " + ...
        "or in the Data tab's ✎ column.";
end
obj.NoteSearchWindow = NoteSearch(noteEntries(obj), Parent=obj.Fig, Visible=obj.Fig.Visible == "on", ...
    GoToFcn=@(e) goToNote(obj, e), EditFcn=@(e) openNotePad(obj, e.dataset, e.level, e.id, "", Front=true), ...
    EmptyText=empty);
end
