function onDatasetsTableEdited(obj, ~)
%onDatasetsTableEdited  A Run tick changed: the datasets a run (and, in project mode, the config) uses.
T = obj.DatasetsTable.Data;
if ~istable(T) || ~ismember("Run", string(T.Properties.VariableNames)); return; end
obj.Ticked = reshape(logical(T.Run), 1, []);
obj.onConfigChanged("ticks");
obj.setStatus(sprintf("%d of %d dataset(s) ticked to run.", nnz(obj.Ticked), numel(obj.Ticked)));
end
