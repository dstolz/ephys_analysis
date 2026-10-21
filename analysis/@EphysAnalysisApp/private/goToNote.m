function goToNote(obj, e)
%goToNote  Open the dataset of the note E (one row of noteEntries; the search window's Go to), as a favorite is gone to.
%   Its dataset becomes the active one; a unit's or channel's note then
%   picks that unit or channel in the Figures tab's observation list when
%   the figure selected there observes that kind (goToFavorite), else the
%   status bar says why not. A note on a unit of another sort than the one
%   in use goes to its dataset only. The app's window comes to the front.
%
%   See also onSearchNotes, NoteSearch, goToFavorite.
arguments
    obj (1,1) EphysAnalysisApp
    e table
end
if isempty(obj.Runner) || e.dataset < 1 || e.dataset > numel(obj.Runner.Keys); return; end
label = e.name + " · " + e.label;
if e.level == "dataset"; label = e.name; end
f = table(e.dataset, e.level, e.id, label, 'VariableNames', ["dataset" "level" "id" "label"]);
if ~e.current
    f.level = "dataset";
end
goToFavorite(obj, f, What="Note");
if ~e.current
    obj.setStatus("Note: " + label + ": its dataset is the active one; the unit is of a sort no longer in use.");
end
if obj.Fig.Visible == "on"
    figure(obj.Fig);
end
end
