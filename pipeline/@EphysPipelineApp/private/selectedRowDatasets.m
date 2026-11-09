function idx = selectedRowDatasets(obj)
%selectedRowDatasets  Datasets on the rows selected in the Project table (Tags..., Variables...).
%   Its Selection is [row column] per selected cell, rows of Data (not of
%   a header sort's order), mapped to datasets through DatasetIdx; the
%   Select ticks play no part. Ascending; empty when nothing is selected.
idx = zeros(1, 0);
T = obj.DatasetsTable.Data;
sel = obj.DatasetsTable.Selection;
if isempty(sel) || ~istable(T) || ~any(strcmp('DatasetIdx', T.Properties.VariableNames)); return; end
rows = unique(sel(:, 1));
rows = rows(rows >= 1 & rows <= height(T));
idx = reshape(unique(T.DatasetIdx(rows)), 1, []);
end
