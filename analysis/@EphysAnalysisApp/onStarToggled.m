function onStarToggled(obj, what, tf)
%onStarToggled  A star toggle pressed: star (TF true) or unstar the active dataset or the observation picked.
%   WHAT "dataset": the active dataset (the toggle beside the Dataset
%   drop-down of the Alignment and Figures tabs). WHAT "observation": what
%   the figure preview shows (the toggle beside the observation picker): a
%   sorted unit (recorded with its sort), a channel or a detection channel
%   (its recording channel) or, for a figure of the dataset, the dataset
%   (observedItem). It is written at once beside the data
%   (DatasetFavorites, <Name>_favorites.json in the output folder); when it
%   cannot be, the status bar says why and the toggle goes back (starItem).
%
%   See also starItem, refreshFavorites, DatasetFavorites.
arguments
    obj (1,1) EphysAnalysisApp
    what (1,1) string {mustBeMember(what, ["dataset" "observation"])}
    tf (1,1) logical = true
end
if isempty(obj.Runner) || obj.ActiveIdx < 1 || numel(obj.Favorites) < obj.ActiveIdx
    obj.setStatus("Scan and pick a dataset to star it.");
    syncStarButtons(obj);
    return
end
if what == "dataset"
    starItem(obj, obj.ActiveIdx, "dataset", [], tf);
    return
end
[level, id, why] = observedItem(obj);
if why ~= ""
    obj.setStatus("Nothing to star: " + why + ".");
    syncStarButtons(obj);
    return
end
if level == "dataset"; id = []; end
starItem(obj, obj.ActiveIdx, level, id, tf);
end
