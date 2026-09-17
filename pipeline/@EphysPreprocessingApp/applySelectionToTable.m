function applySelectionToTable(obj, P)
%applySelectionToTable  Tick the dataset rows named in a Project section.
%   Datasets hidden by the token filters keep their tick in HiddenSelectedKeys.
if nargin < 2; P = obj.Config.Project; end
if isempty(obj.Project) || obj.Project.NumDatasets == 0; return; end
T = obj.DatasetsTable.Data;
if ~istable(T) || ~any(strcmp('Select', T.Properties.VariableNames)); return; end
listed = P.Selection == "list" && ~isempty(P.Datasets);
sel = false(height(T), 1);
hidden = string.empty(1, 0);
for i = 1:obj.Project.NumDatasets
    key = obj.Project.datasetKey(i);
    ticked = listed && any(strcmpi(key, P.Datasets));
    r = find(T.DatasetIdx == i, 1);
    if ~isempty(r)
        sel(r) = ticked;
    elseif ticked
        hidden(end + 1) = key; %#ok<AGROW>
    end
end
T.Select = sel;
obj.HiddenSelectedKeys = hidden;
obj.DatasetsTable.Data = T;
end
