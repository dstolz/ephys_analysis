function refreshDatasetMenu(obj)
%refreshDatasetMenu  List the ticked datasets at the top of the Dataset menu.
%   One item per dataset ticked in the Project table's Select column
%   (including ticked rows the token filters hide), in project order, above
%   the "All datasets" submenu that holds every dataset (filled by
%   populateDatasetPickers). An item makes its dataset active (selectDataset);
%   the active one is checked here and in the submenu. Every tab's Dataset
%   box is limited to the same datasets (refreshDatasetPickers). Called
%   whenever the ticks change.
delete(obj.DatasetTickedItems(isvalid(obj.DatasetTickedItems)));
obj.DatasetTickedItems = matlab.ui.container.Menu.empty(1, 0);

if isempty(obj.Project) || obj.Project.NumDatasets == 0
    obj.DatasetTickedItems = uimenu(obj.DatasetMenu, "Text", "(scan first)", "Enable", "off");
else
    idx = obj.tickedDatasetIndices();
    if isempty(idx)
        obj.DatasetTickedItems = uimenu(obj.DatasetMenu, "Text", "(no datasets ticked)", "Enable", "off");
    end
    for k = 1:numel(idx)
        i = idx(k);
        % Double any '&' so it shows literally instead of underlining the next
        % character as a mnemonic.
        obj.DatasetTickedItems(k) = uimenu(obj.DatasetMenu, ...
            "Text", strrep(obj.Project.Datasets(i).Name, "&", "&&"), ...
            "UserData", i, "Checked", i == obj.SelectedDatasetIdx, ...
            "MenuSelectedFcn", @(~,~) obj.selectDataset(i));
    end
end

% New items land below "All datasets": move it back to the bottom
% (Children lists the menu bottom-up).
obj.DatasetMenu.Children = [obj.DatasetAllMenu; flipud(obj.DatasetTickedItems(:))];

obj.refreshDatasetPickers();
end
