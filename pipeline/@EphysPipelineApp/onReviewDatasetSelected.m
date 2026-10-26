function onReviewDatasetSelected(obj, evt)
%onReviewDatasetSelected  A click on a row of the Review tab's Datasets table makes its dataset active.
%   EVT.Selection is the row of the table's Data (not of the order a header
%   click shows), and ReviewDatasetRows maps it to the dataset, so the
%   choice is the row clicked in any sort. Choosing it here is choosing it
%   anywhere (selectDataset): the Review tab loads its sorted output and
%   every other tab's Dataset box shows it. A click that leaves no row
%   selected selects the active dataset's row again.
rows = obj.ReviewDatasetRows;
sel = [];
if isfield(evt, 'Selection') || isprop(evt, 'Selection'); sel = evt.Selection; end
if isempty(sel) || sel(1) > numel(rows)
    obj.refreshReviewDatasets();
    return
end
obj.selectDataset(rows(sel(1)));
end
