function onReviewSortEdited(obj, evt)
%onReviewSortEdited  A Sort cell of the Review tab's Datasets table was edited: remember the sort picked for that dataset.
%   EVT.Indices(1) is the row of the table's Data, which ReviewDatasetRows
%   maps to the dataset. "(in use)" picks the dataset's own sort. A name the
%   dataset has no sort of is refused and the cell shows the previous choice.
%   The choice is what the tab loads when it shows the dataset
%   (syncReviewDataset, reviewSortChoice), for review only: nothing the
%   other steps read changes (Use this sort does). For the active dataset
%   the sort is loaded now.
rows = obj.ReviewDatasetRows;
r = evt.Indices(1);
if evt.Indices(2) ~= 2 || r > numel(rows)
    obj.refreshReviewDatasets();
    return
end
i = rows(r);
key = string(obj.Project.datasetKey(i));
j = find(string([obj.ReviewDatasetStats.key]) == key, 1);
name = string(evt.NewData);
choice = "";
if name ~= "(in use)"
    k = [];
    if ~isempty(j) && ~isempty(obj.ReviewDatasetStats(j).list)
        k = find(string({obj.ReviewDatasetStats(j).list.name}) == name, 1);
    end
    if isempty(k)
        uialert(obj.Fig, obj.Project.Datasets(i).Name + " has no sort """ + name + """.", "Sort");
        obj.refreshReviewDatasets();
        return
    end
    choice = string(obj.ReviewDatasetStats(j).list(k).dir);
end
obj.ReviewDatasetStats(j).choice = choice;
obj.refreshReviewDatasets();
if i == obj.SelectedDatasetIdx
    obj.syncReviewDataset();
end
end
