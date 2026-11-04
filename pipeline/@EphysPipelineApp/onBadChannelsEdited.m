function onBadChannelsEdited(obj, scope)
%onBadChannelsEdited  Set bad channels from the Artifacts tab's Bad field
%   ("3,7,12-14"; a right-click on a lane of the viewer edits the field and
%   calls this).
%   scope = "active" -> the active dataset (the default: committing the
%                       field, the viewer's right-click)
%   scope = "ticked" -> the datasets ticked in the Project table (Apply to
%                       ticked datasets); with none ticked it asks you to
%                       tick some and changes nothing
%   Channels past a dataset's channel count are dropped. The list is marked
%   "manual" (EphysDataset.BadChannelsSource), so no run replaces it with a
%   suggestion, and saved in the dataset's manifest. Text that does not
%   parse (EphysPipelineConfig.parseOrderedList) changes nothing: an alert
%   says why and the field shows the list in force again.
%
%   See also onSuggestBadChannels, EphysDataset.excludedChannels.

if nargin < 2; scope = "active"; end
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
if scope == "ticked"
    idx = obj.tickedDatasetIndices();
    if isempty(idx)
        uialert(obj.Fig, "Tick the datasets to set these bad channels on in the Select column of the Project tab.", ...
            "Bad channels");
        return
    end
    targets = obj.Project.Datasets(idx);
else
    targets = d;
end
nTrim = 0;
for k = 1:numel(targets)
    t = targets(k);
    keep = ch;
    if ~isnan(t.NumChannels)
        keep = ch(ch <= t.NumChannels);
        nTrim = nTrim + (numel(ch) - numel(keep));
    end
    t.BadChannels = keep;
    t.BadChannelsSource = "manual";
end
obj.saveManifests(targets);
obj.refreshReferencePanel();
obj.drawArtifactView();          % the bad lanes gray
obj.refreshArtChannelTable();
if scope == "ticked"
    msg = sprintf("%d bad channel(s) set on %d ticked dataset(s).", numel(ch), numel(targets));
    if nTrim > 0
        msg = msg + sprintf(" (%d out-of-range entr(y/ies) ignored.)", nTrim);
    end
else
    msg = sprintf("%s: %d bad channel(s).", d.Name, numel(d.BadChannels));
end
obj.setStatus(msg, "Tick Leave out bad channels to leave them out of every step.");
end
