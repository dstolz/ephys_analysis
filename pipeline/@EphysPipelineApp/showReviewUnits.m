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
removeStyle(tbl);
% Rows tinted by group, in the hues of the units-per-shank plot (good green,
% mua grey, anything else orange); styles address rows of Data, so they are
% laid on after the sort.
grp = string(C(:, 2));
tints = {"good", [0.80 0.92 0.80]; "mua", [0.88 0.88 0.90]};
other = true(size(grp));
for k = 1:size(tints, 1)
    r = find(grp == tints{k, 1});
    other(r) = false;
    if ~isempty(r)
        addStyle(tbl, uistyle("BackgroundColor", tints{k, 2}, "FontColor", [0 0 0]), "row", r);
    end
end
r = find(other);
if ~isempty(r)
    addStyle(tbl, uistyle("BackgroundColor", [0.97 0.86 0.76], "FontColor", [0 0 0]), "row", r);
end
row = [];
u = obj.ReviewSelectedUnit;
if u >= 1 && u <= numel(R.clusterID)
    row = find(cellfun(@(c) isequal(c, R.clusterID(u)), C(:, 1)), 1);
end
tbl.Selection = row;
end
