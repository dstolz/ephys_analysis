function populateDatasetMenu(obj)
    % Rebuild the figure's "Dataset" menu from the scanned project.
    %   One checkable item per dataset; picking one calls selectDataset.
    %   Keeps whatever was selected before if it still exists.
    old = obj.DatasetMenuItems;
    delete(old(isvalid(old)));
    obj.DatasetMenuItems = matlab.ui.container.Menu.empty(1, 0);

    if isempty(obj.Project) || obj.Project.NumDatasets == 0
        obj.SelectedDatasetIdx = 0;
        obj.DatasetMenuItems = uimenu(obj.DatasetMenu, ...
            "Text", "(scan first)", "Enable", "off");
        obj.VizFileDropDown.Items = {'(all)'};
        obj.updateDatasetMenuCheck();
        return
    end

    names = [obj.Project.Datasets.Name];
    items = matlab.ui.container.Menu.empty(1, 0);
    for k = 1:numel(names)
        % Double any '&' so it shows literally instead of underlining
        % the next character as a mnemonic.
        items(k) = uimenu(obj.DatasetMenu, ...
            "Text", strrep(names(k), "&", "&&"), ...
            "MenuSelectedFcn", @(~,~) obj.selectDataset(k));
    end
    obj.DatasetMenuItems = items;

    idx = obj.SelectedDatasetIdx;
    if idx < 1 || idx > numel(names); idx = 1; end
    obj.selectDataset(idx);
end
