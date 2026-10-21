function onNoteButton(obj, what)
%onNoteButton  A note button pressed: the notepad on the active dataset (WHAT "dataset") or on the observation previewed ("observation").
%   WHAT "dataset": the button beside the Dataset drop-down of the
%   Alignment and Figures tabs, or the Data tab's ✎ column. WHAT
%   "observation": the button beside the observation picker, for what the
%   figure preview shows: a sorted unit (its note kept with its sort), a
%   channel or a detection channel (its recording channel's note) or, for
%   a figure of the dataset, the dataset (observedItem). The notepad
%   (NotePad, openNotePad) then follows it: another active dataset, or
%   another observation picked (< and > too), moves it there, the text in
%   it written first (syncNoteButtons). Notes are written beside the data,
%   <Name>_notes.json in the output folder (DatasetNotes).
%
%   See also openNotePad, syncNoteButtons, onSearchNotes, DatasetNotes.
arguments
    obj (1,1) EphysAnalysisApp
    what (1,1) string {mustBeMember(what, ["dataset" "observation"])}
end
if isempty(obj.Runner) || obj.ActiveIdx < 1 || numel(obj.Notes) < obj.ActiveIdx
    obj.setStatus("Scan and pick a dataset to write a note on it.");
    return
end
if what == "dataset"
    openNotePad(obj, obj.ActiveIdx, "dataset", NaN, "dataset", Front=true);
    return
end
[level, id, why] = observedItem(obj);
if why ~= ""
    obj.setStatus("Nothing to write a note on: " + why + ".");
    return
end
openNotePad(obj, obj.ActiveIdx, level, id, "observation", Front=true);
end
