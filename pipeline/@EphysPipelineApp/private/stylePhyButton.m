function stylePhyButton(b, folder)
%stylePhyButton  An "Open in phy" button B as phy left sorted-output FOLDER.
%   Curated in phy (EphysDataset.phyStatus: a save that labelled, merged or
%   split a cluster): green ("confirm"), "Open in phy (curated)", and the
%   save time in the tooltip. Otherwise, or for FOLDER "" (no sort), the
%   ordinary look and text. Used by the Sorting tab (refreshSortingLabel)
%   and the Review tab (loadReviewResults, syncReviewDataset).
if isempty(b) || ~isvalid(b); return; end
p = struct('modified', false);
if string(folder) ~= ""; p = EphysDataset.phyStatus(folder); end
if p.modified
    styleButton(b, "confirm");
    b.Text = "Open in phy (curated)";
    b.Tooltip = "Curated in phy (saved " + string(datetime(p.saved, 'Format', 'yyyy-MM-dd HH:mm')) + ...
        "). Opens the sorted output in phy's template-gui.";
else
    styleButton(b);
    b.Text = "Open in phy";
    b.Tooltip = "Not curated in phy yet. Opens the sorted output in phy's template-gui.";
end
end
