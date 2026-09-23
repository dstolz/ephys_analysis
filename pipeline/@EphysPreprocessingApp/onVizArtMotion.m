function onVizArtMotion(obj)
    % Stretch the rubber-band region while an artifact drag is active.
    D = obj.VizArtDrag;
    if ~isstruct(D) || ~isfield(D, 'active') || ~D.active; return; end
    x1 = obj.VizAxes.CurrentPoint(1, 1);
    obj.Viewer.setSelection([min(D.x0, x1), max(D.x0, x1)]);
end
