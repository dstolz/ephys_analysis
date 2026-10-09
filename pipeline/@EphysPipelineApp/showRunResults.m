function showRunResults(obj, T)
%showRunResults  Fill the Run tab's results table with a plan or a run's results T.
%   The table gets Subject and Date columns after Dataset (the project's
%   datasets, datasetIdentity) and the rows come in the order of the
%   remembered header click (tableSort "RunResults"), so the sort holds
%   through the plan, the rows a run adds and the rows the monitors
%   restate. The rows are told apart by their Step, Dataset and Output,
%   never by position (EphysPipeline.restateResult), so any order is safe.
%
%   A last, hidden column Order numbers the rows as the pipeline lists
%   them (kept as the table is filled again): Clear sort (clearTableSort)
%   puts the rows back in that order.
arguments
    obj (1,1) EphysPipelineApp
    T table
end
if isempty(obj.RunResultsTable) || ~isvalid(obj.RunResultsTable); return; end
if ~ismember("Order", string(T.Properties.VariableNames))
    T.Order = (1:height(T)).';
end
[T, labels, widths] = identityTable(obj, "RunResults", T);
labels{end} = '';
widths{end} = 1;
t = obj.RunResultsTable;
t.ColumnName = labels;
t.ColumnWidth = widths;
t.Data = T;
end
