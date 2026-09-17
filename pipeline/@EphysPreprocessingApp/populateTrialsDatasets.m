function populateTrialsDatasets(obj)
%populateTrialsDatasets  Fill the Trials dataset dropdown from the scanned project.
if isempty(obj.Project) || obj.Project.NumDatasets == 0
    obj.TrialsDatasetDropDown.Items = {'(scan first)'};
    obj.TrialsDatasetDropDown.ItemsData = {};
else
    names = cellstr([obj.Project.Datasets.Name]);
    obj.TrialsDatasetDropDown.Items = names;
    obj.TrialsDatasetDropDown.ItemsData = num2cell(1:numel(names));
end
obj.clearTrialsView();
end
