function populateDatasetPickers(obj)
%populateDatasetPickers  Fill the Dataset menu and every tab's Dataset box from the scanned project.
%   One "All datasets" menu item and one dropdown entry per dataset; the
%   ticked datasets at the top of the menu are listed again
%   (refreshDatasetMenu), since the datasets changed. The active dataset
%   stays active when it still exists (else the first one does), and the
%   views of per-dataset results are reset, since the datasets were rebuilt.
delete(obj.DatasetMenuItems(isvalid(obj.DatasetMenuItems)));
obj.DatasetMenuItems = matlab.ui.container.Menu.empty(1, 0);
pickers = obj.DatasetPickers(isvalid(obj.DatasetPickers));

n = 0;
if ~isempty(obj.Project); n = obj.Project.NumDatasets; end
if n == 0
    obj.DatasetAllMenu.Enable = "off";
    obj.refreshDatasetMenu();
    for dd = pickers
        dd.ItemsData = {};
        dd.Items = {'(scan first)'};
        dd.Enable = "off";
    end
    obj.selectDataset(0, Reset=true);
    return
end

names = [obj.Project.Datasets.Name];
for k = 1:n
    % Double any '&' so it shows literally instead of underlining the next
    % character as a mnemonic.
    obj.DatasetMenuItems(k) = uimenu(obj.DatasetAllMenu, "Text", strrep(names(k), "&", "&&"), ...
        "MenuSelectedFcn", @(~,~) obj.selectDataset(k));
end
obj.DatasetAllMenu.Enable = "on";
obj.refreshDatasetMenu();
for dd = pickers
    dd.ItemsData = {};
    dd.Items = cellstr(names);
    dd.ItemsData = num2cell(1:n);
    dd.Enable = "on";
end

idx = obj.SelectedDatasetIdx;
if idx < 1 || idx > n; idx = 1; end
obj.selectDataset(idx, Reset=true);
end
