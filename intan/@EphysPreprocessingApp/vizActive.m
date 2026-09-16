function tf = vizActive(obj)
    % True when there is a cached viewer and the Visualize tab is showing.
    tf = ~isempty(obj.Viewer) && isvalid(obj.Viewer) ...
        && isvalid(obj.Fig) && obj.Tabs.SelectedTab == obj.TabVisualize;
end
