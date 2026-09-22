function refreshManualArtifactsTable(obj)
%refreshManualArtifactsTable  List the active dataset's manual periods.
%   The artifact viewer is redrawn too, as it shades them.
if isempty(obj.ArtManualTable) || ~isvalid(obj.ArtManualTable); return; end
if ~isempty(obj.ArtView.win); obj.drawArtifactView(); end
d = obj.currentDataset();
if isempty(d)
    obj.ArtManualLabel.Text = "Manual periods (scan a project first)";
    obj.ArtManualTable.Data = {};
    return
end
iv = d.ManualArtifacts;
obj.ArtManualLabel.Text = sprintf("Manual periods of %s (%d, saved in its manifest)", d.Name, size(iv, 1));
if isempty(iv)
    obj.ArtManualTable.Data = {};
else
    obj.ArtManualTable.Data = [iv(:, 1), iv(:, 2), iv(:, 2) - iv(:, 1)];
end
end
