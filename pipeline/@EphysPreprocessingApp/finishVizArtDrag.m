function finishVizArtDrag(obj)
    % End an artifact gesture: a drag defines a period, a click deletes one.
    % The plot's time axis is the recording's (seconds from its start), so
    % the times go to the dataset as they are.
    D = obj.VizArtDrag;
    obj.VizArtDrag = struct('active', false);
    if ~isempty(obj.Viewer) && isvalid(obj.Viewer); obj.Viewer.setSelection([]); end
    if ~isstruct(D) || ~isfield(D, 'active') || ~D.active; return; end

    if obj.refuseWhileRunning("Mark Artifacts"); return; end
    d = obj.currentVizDataset();
    if isempty(d); return; end

    x0 = D.x0;
    x1 = obj.VizAxes.CurrentPoint(1, 1);

    % Treat a sub-few-pixel move as a click (delete) rather than a drag.
    secPerPix = obj.Viewer.TWidth / max(D.axPix(3), 1);
    changed = false;
    if abs(x1 - x0) >= 4 * secPerPix
        d.addArtifact(min(x0, x1), max(x0, x1));
        changed = true;
    else
        iv = d.ManualArtifacts;
        if ~isempty(iv)
            hit = find(x0 >= iv(:, 1) & x0 <= iv(:, 2), 1);
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
    obj.refreshVizShading();
    obj.updateVizArtStatus();
end
