function updateVizArtStatus(obj)
    % Refresh the artifact-count label under the Visualize controls,
    % reporting both auto-detected (orange) and manual (red) periods.
    if isempty(obj.VizArtStatusLabel) || ~isvalid(obj.VizArtStatusLabel); return; end

    nDet = size(obj.VizDetectedIntervals, 1);
    detTxt = "";
    if nDet > 0
        detTxt = sprintf("%d detected (orange). ", nDet);
    end

    d = obj.currentVizDataset();
    if isempty(d) || isempty(d.ManualArtifacts)
        if nDet > 0
            obj.VizArtStatusLabel.Text = detTxt + "No manual artifacts.";
        else
            obj.VizArtStatusLabel.Text = "No artifacts detected or defined.";
        end
        return
    end
    iv = d.ManualArtifacts;
    obj.VizArtStatusLabel.Text = detTxt + sprintf( ...
        "%d manual period(s), %.3f s total (blanked on .bin write).", ...
        size(iv, 1), sum(iv(:, 2) - iv(:, 1)));
end
