function refreshDatasetPickers(obj)
%refreshDatasetPickers  List the Project tab's selected datasets in every tab's Dataset box.
%   One entry per dataset ticked in the Project table's Select column
%   (including ticked rows the token filters hide), or every dataset when
%   none is ticked (selectedDatasetIndices), in project order. The active
%   dataset is always listed and shown, even when it is not ticked (a click
%   on an unticked table row or the "All datasets" menu can make it active).
%   Called whenever the ticks (refreshDatasetMenu) or the active dataset
%   (selectDataset) change.
pickers = obj.DatasetPickers(isvalid(obj.DatasetPickers));
if isempty(pickers); return; end

n = 0;
if ~isempty(obj.Project); n = obj.Project.NumDatasets; end
if n == 0
    for dd = pickers
        dd.ItemsData = {};
        dd.Items = {'(scan first)'};
        dd.Enable = "off";
    end
    return
end

idx = obj.selectedDatasetIndices();
active = obj.SelectedDatasetIdx;
if active >= 1 && active <= n && ~ismember(active, idx)
    idx = sort([idx active]);
end
names = cellstr([obj.Project.Datasets(idx).Name]);
for dd = pickers
    if ~isequal(dd.ItemsData, num2cell(idx)) || ~isequal(dd.Items, names)
        dd.ItemsData = {};
        dd.Items = names;
        dd.ItemsData = num2cell(idx);
    end
    dd.Enable = "on";
    if active >= 1 && active <= n
        dd.Value = active;
    end
end
end
