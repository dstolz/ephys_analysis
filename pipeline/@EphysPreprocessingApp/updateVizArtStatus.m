function updateVizArtStatus(obj)
    % Refresh the artifact-count label under the Visualize controls,
    % reporting both the detected (orange, the Artifacts tab's preview;
    % whether a run removes them) and the manual (red) periods.
    if isempty(obj.VizArtStatusLabel) || ~isvalid(obj.VizArtStatusLabel); return; end

    [det, why] = obj.vizDetectedIntervals();
    nDet = size(det, 1);
    if why ~= ""
        detTxt = why + " ";
    elseif nDet == 0
        detTxt = "No artifacts detected with these settings. ";
    elseif logical(obj.ArtEnableCheckBox.Value) && (logical(obj.ArtApplySortingCheckBox.Value) ...
            || logical(obj.ArtApplySpikesCheckBox.Value))
        detTxt = sprintf("%d detected (orange; a run removes them). ", nDet);
    else
        detTxt = sprintf("%d detected (orange; a run keeps them: detection or its uses are off). ", nDet);
    end

    d = obj.currentVizDataset();
    if isempty(d) || isempty(d.ManualArtifacts)
        obj.VizArtStatusLabel.Text = detTxt + "No manual artifacts.";
        return
    end
    iv = d.ManualArtifacts;
    obj.VizArtStatusLabel.Text = detTxt + sprintf( ...
        "%d manual period(s), %.3f s total (blanked on .bin write).", ...
        size(iv, 1), sum(iv(:, 2) - iv(:, 1)));
end
