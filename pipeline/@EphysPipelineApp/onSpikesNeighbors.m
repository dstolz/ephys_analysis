function onSpikesNeighbors(obj)
%onSpikesNeighbors  Open the Spike neighbors window on the active dataset's probe.
%   The window (SpikeNeighborsDialog) draws the sites of the channels the
%   Spikes step detects on, on the probe the step would use (its own, a
%   rule's or the default: EphysPipeline.resolveProbe), with each site's
%   neighbors at the tab's radius. Editing the radius there sets the tab's
%   (Spikes.CoincidenceRadiusUm). An open window is shown again with the
%   active dataset's sites.
%
%   See also SpikeNeighborsDialog, siteNeighbors, buildSpikesTab.

d = obj.currentDataset();
if isempty(d)
    uialert(obj.Fig, "Scan a project first.", "Spike neighbors");
    return
end
pf = EphysPipeline.resolveProbe(obj.Config.Probe, d);
L = d.channelLayout(ProbeFile=pf);
if ~L.hasProbe
    if pf == ""
        why = d.Name + " has no probe, and the config has no default probe";
    else
        why = "No channel of " + d.Name + " is on the probe " + pf;
    end
    uialert(obj.Fig, why + ", so the Spikes step keeps every channel's copy of a spike. " + ...
        "Assign a probe on the Probe tab.", "Spike neighbors", "Icon", "warning");
    return
end
K = obj.gatherSpikesSection();
ch = EphysPipelineConfig.spikeChannels(K, d);
if isempty(ch); ch = 1:numel(L.x); end
ch = ch(ch <= numel(L.x));
names = "ch" + string(ch);
okName = ch <= numel(d.ChannelNames);
names(okName) = d.ChannelNames(ch(okName));
[~, probeName, ext] = fileparts(pf);
pos = [L.x(ch); L.y(ch)].';
heading = d.Name + " on " + probeName + ext;

dlg = obj.SpkNeighborsDialog;
if ~isempty(dlg) && isvalid(dlg) && isvalid(dlg.Fig)
    dlg.setSites(pos, Channels=ch, Names=names, Title=heading);
    dlg.setRadius(obj.SpkCoincRadiusField.Value);
    figure(dlg.Fig);
    return
end
obj.SpkNeighborsDialog = SpikeNeighborsDialog(pos, Channels=ch, Names=names, Title=heading, ...
    RadiusUm=obj.SpkCoincRadiusField.Value, Parent=obj.Fig, OnChange=@(r) radiusEdited(obj, r));
end


function radiusEdited(obj, r)
%radiusEdited  The window's radius into the tab and the config.
obj.SpkCoincRadiusField.Value = r;
obj.onSpikesControlsChanged();
end
