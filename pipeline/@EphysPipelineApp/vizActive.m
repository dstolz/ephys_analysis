function tf = vizActive(obj)
    % True when the Visualize tab is showing a loaded dataset.
    tf = ~isempty(obj.Viewer) && isvalid(obj.Viewer) && ~isempty(obj.VizDataset) ...
        && isvalid(obj.Fig) && obj.Tabs.SelectedTab == obj.TabVisualize;
end
