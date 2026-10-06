function highlightDatasetRow(obj, opts)
%highlightDatasetRow  Mark the active dataset's row in the Project table.
%   Bold on light blue; no row is marked while the token filters hide it.
%   While a run is under way, the dataset it is on is marked orange.
%   The style is set on the table, not the data, so every rebuild of the
%   table (refreshDatasetsTable) marks the row again.
arguments
    obj (1,1) EphysPipelineApp
    opts.Scroll (1,1) logical = false   % also scroll the row into view
    opts.ScrollRunning (1,1) logical = false   % scroll the running dataset's row into view
end
t = obj.DatasetsTable;
if isempty(t) || ~isvalid(t); return; end
removeStyle(t);
T = t.Data;
if ~istable(T) || ~any(strcmp('DatasetIdx', T.Properties.VariableNames)); return; end
row = find(T.DatasetIdx == obj.SelectedDatasetIdx, 1);
if ~isempty(row)
    addStyle(t, uistyle("BackgroundColor", [0.85 0.92 1], "FontWeight", "bold"), "row", row);
end
runRow = [];
if obj.RunningDatasetIdx > 0   % the running dataset: orange, over the active one's blue
    runRow = find(T.DatasetIdx == obj.RunningDatasetIdx, 1);
    if ~isempty(runRow)
        addStyle(t, uistyle("BackgroundColor", [1 0.82 0.5], "FontWeight", "bold"), "row", runRow);
    end
end
if opts.Scroll && ~isempty(row)
    scroll(t, "row", row);
end
if opts.ScrollRunning && ~isempty(runRow)
    scroll(t, "row", runRow);
end
end
