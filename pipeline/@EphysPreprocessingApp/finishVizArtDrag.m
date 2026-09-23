function finishVizArtDrag(obj)
    % End an artifact gesture: a drag defines a period, a click deletes one.
    D = obj.VizArtDrag;
    obj.VizArtDrag = struct('active', false);
    if isvalid(obj.Fig); obj.Fig.WindowButtonMotionFcn = ''; end
    if ~isempty(obj.VizArtPreview) && isvalid(obj.VizArtPreview)
        delete(obj.VizArtPreview);
    end
    obj.VizArtPreview = gobjects(0, 1);

    if obj.refuseWhileRunning("Mark Artifacts"); return; end
    d = obj.currentVizDataset();
    if isempty(d); return; end

    x0 = D.x0;
    x1 = obj.VizAxes.CurrentPoint(1, 1);
    tOff = obj.VizTimeOffset;

    % Treat a sub-few-pixel move as a click (delete) rather than a drag.
    tWin = 1;
    if ~isempty(obj.Viewer) && isvalid(obj.Viewer); tWin = obj.Viewer.TimeWindowDuration; end
    secPerPix = tWin / max(D.axPix(3), 1);
    changed = false;
    if abs(x1 - x0) >= 4 * secPerPix
        d.addArtifact(min(x0, x1) + tOff, max(x0, x1) + tOff);
        changed = true;
    else
        iv = d.ManualArtifacts;
        if ~isempty(iv)
            hit = find((x0 + tOff) >= iv(:, 1) & (x0 + tOff) <= iv(:, 2), 1);
            if ~isempty(hit)
                iv(hit, :) = [];
                d.ManualArtifacts = iv;
                changed = true;
            end
        end
    end
    if changed
        obj.saveManifests(d);          % periods persist in the manifest
    end
    if ~isempty(obj.Viewer) && isvalid(obj.Viewer); obj.Viewer.render(); end
    obj.updateVizArtStatus();
end
