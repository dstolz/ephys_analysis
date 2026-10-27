function showReviewSorts(obj, folder)
%showReviewSorts  Set whether the Review tab's Use this sort is on for the sort shown.
%   FOLDER is the sort shown ("" for none). Use this sort is on while FOLDER
%   is the loaded sort and not already the active dataset's own
%   (onReviewUseSort). Which sort to show is the Datasets table's Sort cell
%   (reviewSortChoice).
folder = string(folder);
d = obj.currentDataset();
R = obj.ReviewData;
shown = folder ~= "" && ~isempty(R) && isfield(R, 'folder') ...
    && EphysDataset.pathKey(R.folder) == EphysDataset.pathKey(folder);
own = ~isempty(d) && EphysDataset.pathKey(d.sortingResultsDir()) == EphysDataset.pathKey(folder);
obj.ReviewUseSortButton.Enable = matlab.lang.OnOffSwitchState(shown && ~isempty(d) && ~own);
end
