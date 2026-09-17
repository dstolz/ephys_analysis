function populateDatasetPickers(obj)
%populateDatasetPickers  Fill the Dataset menu and every tab's Dataset box from the scanned project.
%   One "All datasets" menu item per dataset; the ticked datasets at the
%   top of the menu and in every tab's Dataset box are listed again
%   (refreshDatasetMenu, refreshDatasetPickers), since the datasets changed. The active dataset
%   stays active when it still exists (else the first one does), and the
%   views of per-dataset results are reset, since the datasets were rebuilt.
delete(obj.DatasetMenuItems(isvalid(obj.DatasetMenuItems)));
obj.DatasetMenuItems = matlab.ui.container.Menu.empty(1, 0);

n = 0;
if ~isempty(obj.Project); n = obj.Project.NumDatasets; end
if n == 0
    obj.DatasetAllMenu.Enable = "off";
    obj.refreshDatasetMenu();
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

idx = obj.SelectedDatasetIdx;
if idx < 1 || idx > n; idx = 1; end
obj.selectDataset(idx, Reset=true);
end
