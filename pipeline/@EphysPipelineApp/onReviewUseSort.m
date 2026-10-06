function onReviewUseSort(obj)
%onReviewUseSort  Make the sort the Review tab shows the active dataset's sorted output.
%   As the Sorting tab's Use folder... does: the folder is pinned to the
%   dataset (SortingDir, saved in its manifest), so Export, the analysis,
%   Visualize's units and phy from the Sorting tab read it. The run folder
%   of the config's sorter (sortRunDir: kilosort4, or si_<sorter>) is the
%   auto association instead, so for it the pin is cleared (Use auto). A
%   folder that is not one of the dataset's sorts (Browse... / Load) is
%   used only after a confirmation. The Sort list then marks it in use.
if obj.refuseWhileRunning("Use this sort"); return; end
R = obj.ReviewData;
d = obj.currentDataset();
if isempty(R) || isempty(d); return; end
folder = string(R.folder);
key = @(p) EphysDataset.pathKey(string(p));
if ~isfile(fullfile(folder, 'params.py'))
    uialert(obj.Fig, "No params.py in " + folder + ": phy and the steps that read sorted units need it.", "Use this sort");
    return
end
if ~any(key({obj.ReviewSorts.dir}) == key(folder))
    answer = uiconfirm(obj.Fig, folder + " is not one of " + d.Name + "'s sorts: it is not under its output folder. " + ...
        "Use it as " + d.Name + "'s sorted output anyway?", "Use this sort", ...
        "Options", ["Use it", "Cancel"], "DefaultOption", 2, "CancelOption", 2);
    if answer ~= "Use it"; return; end
end
if key(folder) == key(d.sortRunDir())
    d.SortingDir = "";
    how = "set to auto, " + folder;
else
    d.SortingDir = folder;
    how = "pinned to " + folder;
end
obj.saveManifests(d);
obj.refreshDatasetsTable();
obj.refreshSortingLabel();
[obj.ReviewSorts, ~] = reviewSorts(d);
obj.showReviewSorts(folder);
obj.setStatus(d.Name + ": sorted output " + how, ...
    "Export, the analysis and phy from the Sorting tab read this sort now.");
end
