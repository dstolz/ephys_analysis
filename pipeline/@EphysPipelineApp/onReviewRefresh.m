function onReviewRefresh(obj)
%onReviewRefresh  Read the active dataset's row, its sorts and the loaded sort again.
%   The Datasets table's rows, every dataset's (refreshReviewDatasets; the
%   active one's with its count of sorts), the active dataset's list of sorts (reviewSorts) and the sort now
%   shown, the one in the folder field, which may be another of the
%   dataset's sorts or a browsed folder: its summary, units table and plots
%   (loadReviewResults). The focused unit stays focused when the sort still
%   has it. With nothing loaded, or the folder gone, the dataset's own sort
%   is looked for again (syncReviewDataset), which says so when there is
%   none. For after phy saved, a sorting run finished or the criteria were
%   edited elsewhere.
idx = obj.SelectedDatasetIdx;
others = setdiff(obj.ReviewDatasetRows, idx);
if ~isempty(others)
    obj.refreshReviewDatasets(Datasets=others);   % every other row, so a save in phy shows in its "phy saved" cell
end
folder = strtrim(string(obj.ReviewFolderField.Value));
if idx >= 1 && (folder == "" || ~isfolder(folder))
    obj.syncReviewDataset();
    return
end

cid = [];
R = obj.ReviewData;
u = obj.ReviewSelectedUnit;
if ~isempty(R) && u >= 1 && u <= numel(R.clusterID)
    cid = R.clusterID(u);
end

if idx >= 1
    obj.applyConfigToProject();
    d = obj.Project.Datasets(idx);
    obj.ReviewSorts = reviewSorts(d);
    obj.refreshReviewDatasets(Datasets=idx);
end
try
    obj.loadReviewResults();
catch
    return   % loadReviewResults has already reported the failure in an alert.
end
if ~isempty(cid) && ~isempty(obj.ReviewData)
    u = find(obj.ReviewData.clusterID == cid, 1);
    if ~isempty(u)
        obj.ReviewSelectedUnit = u;
        obj.showReviewUnits();
        obj.renderReviewPlots();
    end
end
end
