function syncProjectEmptyState(obj)
%syncProjectEmptyState  Show the "No project is loaded yet" card until a project is scanned, the datasets table after.
%   The card (buildProjectTab) offers Choose project root... and Try with
%   made-up data; the table takes its place once the project holds a dataset.
if isempty(obj.ProjectEmptyPanel) || ~isvalid(obj.ProjectEmptyPanel); return; end
empty = isempty(obj.Project) || obj.Project.NumDatasets == 0;
obj.ProjectEmptyPanel.Visible = empty;
if ~isempty(obj.DatasetsTable) && isvalid(obj.DatasetsTable)
    obj.DatasetsTable.Visible = ~empty;
end
end
