function updateDatasetMenuCheck(obj)
    % Tick the active menu item and mirror its name onto the Visualize tab.
    items = obj.DatasetMenuItems;
    for k = 1:numel(items)
        if isvalid(items(k))
            items(k).Checked = (k == obj.SelectedDatasetIdx);
        end
    end
    if isempty(obj.VizDatasetLabel) || ~isvalid(obj.VizDatasetLabel)
        return
    end
    if obj.SelectedDatasetIdx >= 1
        obj.VizDatasetLabel.Text = obj.Project.Datasets(obj.SelectedDatasetIdx).Name;
        obj.VizDatasetLabel.FontColor = [0.15 0.15 0.15];
    else
        obj.VizDatasetLabel.Text = "(none - scan, then pick from the Dataset menu)";
        obj.VizDatasetLabel.FontColor = [0.5 0.5 0.5];
    end
end
