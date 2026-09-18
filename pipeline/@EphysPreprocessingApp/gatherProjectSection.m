function P = gatherProjectSection(obj)
%gatherProjectSection  Project section from the Project tab.
%   The dataset selection follows the table ticks once a project is
%   scanned (any tick, shown or filtered out -> "list" of root-relative
%   keys; none -> "all");
%   before a scan the applied config's selection is kept.
P = obj.Config.Project;
P.Root       = string(strtrim(obj.RootPathField.Value));
P.Recursive  = logical(obj.RecursiveCheckBox.Value);
P.OutputRoot = string(strtrim(obj.OutputRootField.Value));
P.NamePattern = string(obj.NamePatternField.Value);
checks = obj.NameTokenChecks;
if ~isempty(checks)
    shown = string({checks.Text});
    P.TokenColumns = strjoin(shown(logical([checks.Value])), ", ");
end
if ~isempty(obj.Project) && obj.Project.NumDatasets > 0
    T = obj.DatasetsTable.Data;
    if istable(T) && any(strcmp('Select', T.Properties.VariableNames))
        idx = obj.tickedDatasetIndices();
        if isempty(idx)
            P.Selection = "all";
            P.Datasets  = string.empty(1, 0);
        else
            P.Selection = "list";
            keys = strings(1, numel(idx));
            for k = 1:numel(idx)
                keys(k) = obj.Project.datasetKey(idx(k));
            end
            P.Datasets = keys;
        end
    end
end
end
