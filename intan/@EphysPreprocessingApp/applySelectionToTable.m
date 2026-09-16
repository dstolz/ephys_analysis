function applySelectionToTable(obj, P)
%applySelectionToTable  Tick the dataset rows named in a Project section.
if nargin < 2; P = obj.Config.Project; end
if isempty(obj.Project) || obj.Project.NumDatasets == 0; return; end
T = obj.DatasetsTable.Data;
if ~istable(T) || ~any(strcmp('Select', T.Properties.VariableNames)); return; end
sel = false(height(T), 1);
if P.Selection == "list" && ~isempty(P.Datasets)
    for r = 1:height(T)
        key = obj.Project.datasetKey(T.DatasetIdx(r));
        sel(r) = any(strcmpi(key, P.Datasets));
    end
end
T.Select = sel;
obj.DatasetsTable.Data = T;
end
