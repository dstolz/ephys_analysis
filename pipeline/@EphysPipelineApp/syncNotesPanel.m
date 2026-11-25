function syncNotesPanel(obj)
%syncNotesPanel  Show the active dataset's note in the Project tab's Notes panel.
%   The box (NotesArea) shows the note on the active dataset itself, read
%   with DatasetNotes from <Name>_notes.json in its output folder: the
%   note the analysis app's notepad writes and shows. The box's UserData
%   keeps the dataset and the text read (dataset, text), so an edit is
%   saved into the dataset it was typed for (onNotesEdited) even when the
%   active dataset changes before the box reports it; text typed and not
%   saved yet is saved first. The box is off, with the reason in its
%   placeholder, with no active dataset, without DatasetNotes on the path
%   (the repository's analysis folder) and over a notes file that cannot
%   be read. The panel title names the dataset.
%   Called when the active dataset changes (selectDataset).
%
%   See also onNotesEdited, DatasetNotes, selectDataset.
area = obj.NotesArea;
if isempty(area) || ~isvalid(area); return; end
obj.onNotesEdited();   % what was typed for the dataset shown so far
d = obj.currentDataset();
area.UserData = struct('dataset', d, 'text', "");
area.Value = {''};
area.Enable = "off";
obj.NotesPanel.Title = "Notes";
if isempty(d)
    area.Placeholder = "Scan a project to write notes on its datasets.";
    return
end
obj.NotesPanel.Title = "Notes: " + d.Name;
if ~exist('DatasetNotes', 'class')
    area.Placeholder = "Notes need the repository's analysis folder on the path (addpath_nogit on the repository adds it).";
    return
end
folder = string(d.outputFolder());
file = DatasetNotes.fileFor(folder, d.Name);
txt = "";
if isfolder(folder)
    N = DatasetNotes(folder, Name=d.Name);
    if N.Problem ~= ""
        area.Placeholder = "The notes file cannot be read: " + N.Problem + ". Fix or delete it to write notes here.";
        return
    end
    txt = N.note("dataset");
end
area.UserData.text = txt;
area.Value = cellstr(splitlines(txt));
area.Enable = "on";
area.Placeholder = "Notes on " + d.Name;
area.Tooltip = ["The note on the active dataset (the highlighted row), saved when you click elsewhere into" ...
    file, "the note the analysis app's notepad shows. Empty the box to remove it."];
end
