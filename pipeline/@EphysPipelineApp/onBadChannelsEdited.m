function onBadChannelsEdited(obj)
%onBadChannelsEdited  Set the active dataset's bad channels from the
%   Artifacts tab's Bad field ("3,7,12-14"; a right-click on a lane of the
%   viewer edits the field and calls this). Channels past the dataset's
%   channel count are dropped. The list is marked "manual"
%   (EphysDataset.BadChannelsSource), so no run replaces it with a
%   suggestion, and saved in the dataset's manifest. Text that does not
%   parse (EphysPipelineConfig.parseOrderedList) changes nothing: an alert
%   says why and the field shows the list in force again.
%
%   See also onSuggestBadChannels, EphysDataset.excludedChannels.

d = obj.currentDataset();
if isempty(d); return; end
if obj.refuseWhileRunning("Bad channels")
    obj.refreshReferencePanel();
    return
end
try
    ch = reshape(unique(EphysPipelineConfig.parseOrderedList(obj.ArtBadField.Value, "Bad channels")), 1, []);
catch ME
    obj.refreshReferencePanel();
    uialert(obj.Fig, string(ME.message) + newline + "The bad channels are unchanged.", "Bad channels");
    return
end
if ~isnan(d.NumChannels)
    ch = ch(ch <= d.NumChannels);
end
d.BadChannels = ch;
d.BadChannelsSource = "manual";
obj.saveManifests(d);
obj.refreshReferencePanel();
obj.drawArtifactView();          % the bad lanes gray
obj.refreshArtChannelTable();
obj.setStatus(sprintf("%s: %d bad channel(s).", d.Name, numel(ch)), ...
    "Tick Leave out bad channels to leave them out of every step.");
end
