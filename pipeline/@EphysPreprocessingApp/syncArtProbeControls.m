function syncArtProbeControls(obj)
%syncArtProbeControls  Fit the Artifacts tab's probe controls to the active
%   dataset's probe. When the dataset or its ProbeFile changed since the last
%   call (ArtView.layoutKey) this reads the dataset's channelLayout into
%   ArtView.layout, ticks "Order channels by probe layout" when the dataset
%   has a probe (unticked and disabled without one: that is its default, so
%   a change of dataset or probe resets it) and offers the probe's shanks in
%   the viewer's Shank box, back at All shanks. "Colour by shank" keeps its
%   value. The per-channel table and the plot are then redrawn. Called when
%   the active dataset changes (selectDataset) and after a probe is assigned
%   (onAssignProbe).
%
%   See also EphysDataset.channelLayout, drawArtifactView, refreshArtChannelTable.

if isempty(obj.ArtProbeOrderCheckBox) || ~isvalid(obj.ArtProbeOrderCheckBox); return; end
d = obj.currentDataset();
key = "";
if ~isempty(d); key = string(d.Folder) + "|" + d.ProbeFile; end
if key == obj.ArtView.layoutKey && ~isempty(obj.ArtView.layout); return; end

L = [];
if ~isempty(d); L = d.channelLayout(); end
obj.ArtView.layout = L;
obj.ArtView.layoutKey = key;
has = ~isempty(L) && L.hasProbe;

obj.ArtProbeOrderCheckBox.Value = has;
obj.ArtProbeOrderCheckBox.Enable = matlab.lang.OnOffSwitchState(has);
items = "All shanks";
data = "all";
if has
    items = [items, "Shank " + string(L.shanks)];
    data = [data, string(L.shanks)];
end
dd = obj.ArtViewShankDropDown;
dd.Items = cellstr(items);
dd.ItemsData = cellstr(data);
dd.Value = 'all';

obj.refreshArtChannelTable();
obj.drawArtifactView();
end
