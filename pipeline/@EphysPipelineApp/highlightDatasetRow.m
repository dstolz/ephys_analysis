function highlightDatasetRow(obj, opts)
%highlightDatasetRow  Mark the active dataset's row in the Project table.
%   Bold on light blue; no row is marked while the token filters hide it.
%   The style is set on the table, not the data, so every rebuild of the
%   table (refreshDatasetsTable) marks the row again.
arguments
    obj (1,1) EphysPreprocessingApp
    opts.Scroll (1,1) logical = false   % also scroll the row into view
end
t = obj.DatasetsTable;
if isempty(t) || ~isvalid(t); return; end
removeStyle(t);
T = t.Data;
if ~istable(T) || ~any(strcmp('DatasetIdx', T.Properties.VariableNames)); return; end
row = find(T.DatasetIdx == obj.SelectedDatasetIdx, 1);
if isempty(row); return; end
addStyle(t, uistyle("BackgroundColor", [0.85 0.92 1], "FontWeight", "bold"), "row", row);
if opts.Scroll
    scroll(t, "row", row);
end
end
