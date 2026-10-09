function onDatasetsTableEdited(obj, ~)
%onDatasetsTableEdited  A Run tick changed: the datasets a run (and, in project mode, the config) uses.
T = obj.DatasetsTable.Data;
if ~istable(T) || ~ismember("Run", string(T.Properties.VariableNames)); return; end
ticked = false(1, numel(obj.Ticked));   % a row's Idx is its dataset, whatever order the rows are in
ticked(T.Idx) = logical(T.Run);
obj.Ticked = ticked;
obj.onConfigChanged("ticks");
obj.setStatus(sprintf("%d of %d dataset(s) ticked to run.", nnz(obj.Ticked), numel(obj.Ticked)));
end
