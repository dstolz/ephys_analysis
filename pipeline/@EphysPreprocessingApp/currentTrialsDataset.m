function d = currentTrialsDataset(obj)
%currentTrialsDataset  Dataset selected on the Trials tab ([] if none).
d = EphysDataset.empty;
idx = obj.TrialsDatasetDropDown.Value;
if isempty(idx) || ~isnumeric(idx) || isempty(obj.Project) || idx > obj.Project.NumDatasets
    return
end
d = obj.Project.Datasets(idx);
end
