function onVizColormapChanged(obj)
    % Re-render so a new heatmap colormap takes effect immediately.
    if isempty(obj.Viewer) || ~isvalid(obj.Viewer); return; end
    obj.Viewer.Colormap = string(obj.VizColormapDropDown.Value);
    obj.Viewer.render();
end
