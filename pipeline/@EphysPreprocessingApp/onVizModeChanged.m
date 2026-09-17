function onVizModeChanged(obj)
    % Switch traces <-> heatmap without re-reading/re-filtering.
    if isempty(obj.Viewer) || ~isvalid(obj.Viewer); return; end
    obj.Viewer.setMode(string(obj.VizModeDropDown.Value));
end
