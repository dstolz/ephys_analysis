function idx = tickedDatasetIndices(obj)
%tickedDatasetIndices  Indices into obj.Project.Datasets that are ticked:
%   the shown rows' "Select" column (resolved through DatasetIdx, since
%   sorting reorders rows) plus the ticks on rows the token filters hide
%   (HiddenSelectedKeys). Ascending; empty when nothing is ticked.
idx = zeros(1, 0);
if isempty(obj.Project) || obj.Project.NumDatasets == 0; return; end
T = obj.DatasetsTable.Data;
if istable(T) && all(ismember({'Select', 'DatasetIdx'}, T.Properties.VariableNames))
    idx = reshape(T.DatasetIdx(logical(T.Select(:))), 1, []);
end
if ~isempty(obj.HiddenSelectedKeys)
    for i = 1:obj.Project.NumDatasets
        if any(strcmpi(obj.HiddenSelectedKeys, obj.Project.datasetKey(i)))
            idx(end + 1) = i; %#ok<AGROW>
        end
    end
end
idx = unique(idx);
end
