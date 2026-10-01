function syncArtProbeControls(obj)
%syncArtProbeControls  Fit the Artifacts tab's probe controls to the active
%   dataset's probe: its ProbeFile, else the config's default probe (as
%   EphysPipeline.probeFor). When the dataset or that probe changed since
%   the last call (ArtView.layoutKey) this reads the dataset's channelLayout
%   into ArtView.layout, ticks "Order channels by probe layout" when there
%   is a probe (unticked and disabled without one: that is its default, so
%   a change of dataset or probe resets it) and offers the probe's shanks in
%   the viewer's Shank box, back at All shanks. "Colour by shank" keeps its
%   value. The per-channel table and the plot are then redrawn. Called when
%   the active dataset changes (selectDataset), after a probe is assigned
%   (onAssignProbe) and when the default probe changes (onConfigChanged,
%   applyConfig).
%
%   See also EphysDataset.channelLayout, drawArtifactView, refreshArtChannelTable.

if isempty(obj.ArtProbeOrderCheckBox) || ~isvalid(obj.ArtProbeOrderCheckBox); return; end
d = obj.currentDataset();
key = "";
pf = "";
if ~isempty(d)
    pf = d.ProbeFile;
    if pf == ""; pf = obj.Config.Probe.DefaultProbeFile; end
    key = string(d.Folder) + "|" + pf;
end
if key == obj.ArtView.layoutKey && ~isempty(obj.ArtView.layout); return; end

L = [];
if ~isempty(d); L = d.channelLayout(ProbeFile=pf); end
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
