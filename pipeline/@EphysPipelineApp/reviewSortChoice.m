function folder = reviewSortChoice(obj, idx)
%reviewSortChoice  The folder of the sort picked for dataset IDX in the Datasets table's Sort cell.
%   "" when none is picked ("(in use)": the dataset's own sort), or the one
%   picked is not among the dataset's sorts now. syncReviewDataset loads
%   this sort when the tab shows the dataset (onReviewSortEdited).
folder = "";
if idx < 1 || isempty(obj.Project) || idx > obj.Project.NumDatasets; return; end
key = string(obj.Project.datasetKey(idx));
j = find(string([obj.ReviewDatasetStats.key]) == key, 1);
if isempty(j); return; end
s = obj.ReviewDatasetStats(j);
if isempty(s.choice) || isempty(s.list); return; end
ch = string(s.choice);
if ch ~= "" && any(EphysDataset.pathKey(string({s.list.dir})) == EphysDataset.pathKey(ch))
    folder = ch;
end
end
