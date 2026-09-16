function refreshManualArtifactsTable(obj)
%refreshManualArtifactsTable  List the selected dataset's manual periods.
if isempty(obj.ArtManualTable) || ~isvalid(obj.ArtManualTable); return; end
d = obj.currentDataset();
if isempty(d)
    obj.ArtManualLabel.Text = "Manual periods (select a dataset on the Project tab)";
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
