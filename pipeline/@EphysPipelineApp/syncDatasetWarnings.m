function syncDatasetWarnings(obj)
%syncDatasetWarnings  Show the active dataset's warnings under the Project table.
%   The Warnings box between the datasets table and its hint lists what the
%   active dataset's recording headers say is amiss (EphysDataset.metadataNotes:
%   channels switched off or on during the recording, jumps of the acquisition
%   clock). The reader warns of the same when it reads the headers, and the
%   app does not print those; this is where they are shown. The box has no
%   height, and is hidden, while the active dataset has none, so the table
%   keeps the room. Called when the active dataset changes and when the table
%   is rebuilt (a scan, Refresh metadata).
%
%   See also EphysDataset.metadataNotes, syncSourcePanel, selectDataset.
if isempty(obj.DatasetWarnPanel) || ~isvalid(obj.DatasetWarnPanel); return; end
d = obj.currentDataset();
notes = strings(0, 1);
if ~isempty(d); notes = d.metadataNotes(); end
if isempty(notes)
    obj.DatasetWarnPanel.Visible = "off";
    obj.DatasetWarnArea.Value = {''};
    obj.DatasetWarnGrid.RowHeight = {'1x', 0, 18};
    return
end
obj.DatasetWarnPanel.Title = "Warnings: " + d.Name;
obj.DatasetWarnArea.Value = cellstr(notes);
obj.DatasetWarnPanel.Visible = "on";
obj.DatasetWarnGrid.RowHeight = {'1x', min(30 + 34 * numel(notes), 130), 18};   % about two lines a note
end
