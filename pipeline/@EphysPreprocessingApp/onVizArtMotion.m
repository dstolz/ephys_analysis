function onVizArtMotion(obj)
    % Stretch the rubber-band region while an artifact drag is active.
    D = obj.VizArtDrag;
    if ~isstruct(D) || ~isfield(D, 'active') || ~D.active; return; end
    x1 = obj.VizAxes.CurrentPoint(1, 1);
    lo = min(D.x0, x1); hi = max(D.x0, x1);
    if isempty(obj.VizArtPreview) || ~isvalid(obj.VizArtPreview)
        obj.VizArtPreview = xregion(obj.VizAxes, lo, hi, ...
            'FaceColor', [0.85 0.2 0.2], 'FaceAlpha', 0.15);
    else
        obj.VizArtPreview.Value = [lo hi];
    end
end
