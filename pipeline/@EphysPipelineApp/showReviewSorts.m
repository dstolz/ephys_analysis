function showReviewSorts(obj, folder)
%showReviewSorts  List the dataset's sorts (ReviewSorts) in the Review tab's Sort dropdown.
%   FOLDER is the one shown as chosen. A folder not among them (one from
%   Browse... / Load) is added at the end as "other: <folder>"; "" adds
%   none. Without any, the dropdown says "(no sorts)" and is disabled.
%   Use this sort is on while FOLDER is the loaded sort and not already
%   the active dataset's own (onReviewUseSort).
dd = obj.ReviewSortDropDown;
dirs = string({obj.ReviewSorts.dir});
labels = string({obj.ReviewSorts.label});
folder = string(folder);
if folder ~= "" && ~any(EphysDataset.pathKey(dirs) == EphysDataset.pathKey(folder))
    dirs(end + 1) = folder;
    labels(end + 1) = "other: " + folder;
end
d = obj.currentDataset();
R = obj.ReviewData;
shown = folder ~= "" && ~isempty(R) && isfield(R, 'folder') ...
    && EphysDataset.pathKey(R.folder) == EphysDataset.pathKey(folder);
own = ~isempty(d) && EphysDataset.pathKey(d.sortingResultsDir()) == EphysDataset.pathKey(folder);
obj.ReviewUseSortButton.Enable = matlab.lang.OnOffSwitchState(shown && ~isempty(d) && ~own);
dd.ItemsData = {};
if isempty(dirs)
    dd.Items = {'(no sorts)'};
    dd.Enable = "off";
    return
end
dd.Items = cellstr(labels);
dd.ItemsData = cellstr(dirs);
k = find(EphysDataset.pathKey(dirs) == EphysDataset.pathKey(folder), 1);
if isempty(k); k = 1; end
dd.Value = char(dirs(k));
dd.Enable = "on";
end
