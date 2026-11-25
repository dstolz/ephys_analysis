function onNotesEdited(obj)
%onNotesEdited  Save the Notes box as the note on the dataset it shows.
%   The box's ValueChangedFcn (it fires when the box loses focus), and
%   syncNotesPanel before it shows another dataset. The text, its lines
%   joined by line breaks and its ends trimmed, becomes the dataset's own
%   note in <Name>_notes.json in its output folder (DatasetNotes.setNote,
%   the analysis app's notepad's note; the folder is made when it is not
%   there yet). Empty text removes the note. Nothing is done when the text
%   is the note as read. When it cannot be written (a read-only share) an
%   alert says why and the text stays in the box. Notes are not part of
%   the config: an edit never marks it unsaved.
%
%   See also syncNotesPanel, DatasetNotes.
area = obj.NotesArea;
u = area.UserData;
if ~isstruct(u) || isempty(u.dataset) || ~isvalid(u.dataset) || area.Enable == "off"; return; end
txt = strtrim(strjoin(string(area.Value), newline));
if txt == u.text; return; end
d = u.dataset;
folder = string(d.outputFolder());
try
    if ~isfolder(folder); mkdir(folder); end
    N = DatasetNotes(folder, Name=d.Name);
    N.setNote("dataset", NaN, txt);
catch ME
    uialert(obj.Fig, "The note on " + d.Name + " is not saved: " + string(ME.message), "Notes", "Icon", "warning");
    return
end
u.text = N.note("dataset");
area.UserData = u;
if u.text == ""
    obj.setStatus("Removed the note on " + d.Name + ".");
else
    obj.setStatus("Saved the note on " + d.Name + ".", "In " + N.File + ", where the analysis app's notepad shows it too.");
end
end
