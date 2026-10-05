function showReviewUnits(obj)
%showReviewUnits  Fill the Review units table from ReviewData, in the table's sort.
%   One row per cluster (reviewTableRows), in the order of the remembered
%   header click (tableSort "Review"), else by cluster id, so a sort holds
%   for every sort loaded and the next session. Rows map to units by the
%   cluster id in column 1, never by position: the focused unit
%   (ReviewSelectedUnit) keeps its row selected wherever the sort puts it,
%   and no row is selected when none is focused.
tbl = obj.ReviewUnitsTable;
R = obj.ReviewData;
if isempty(R)
    tbl.Data = {};
    return
end
C = TableSort.apply(reviewTableRows(R), obj.tableSort("Review"), tbl.ColumnName);
tbl.Data = C;
row = [];
u = obj.ReviewSelectedUnit;
if u >= 1 && u <= numel(R.clusterID)
    row = find(cellfun(@(c) isequal(c, R.clusterID(u)), C(:, 1)), 1);
end
tbl.Selection = row;
end
