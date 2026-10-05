function onReferenceExcludeEdited(obj)
%onReferenceExcludeEdited  Set the active dataset's channels left out of the
%   common reference from the Artifacts tab's Left out field ("3,7,12-14").
%   Channels past the dataset's channel count are dropped. The list is marked
%   "manual" (EphysDataset.ReferenceExcludeSource), so no run replaces it
%   with a suggestion, and saved in the dataset's manifest. Text that does
%   not parse (EphysPipelineConfig.parseOrderedList) changes nothing: an
%   alert says why and the field shows the list in force again.
%
%   See also onSuggestReferenceExclude, EphysDataset.applyReference.

d = obj.currentDataset();
if isempty(d); return; end
if obj.refuseWhileRunning("Left out")
    obj.refreshReferencePanel();
    return
end
try
    ch = reshape(unique(EphysPipelineConfig.parseOrderedList(obj.ArtRefExcludeField.Value, "Left out")), 1, []);
catch ME
    obj.refreshReferencePanel();
    uialert(obj.Fig, string(ME.message) + newline + "The channels left out are unchanged.", "Common reference");
    return
end
if ~isnan(d.NumChannels)
    ch = ch(ch <= d.NumChannels);
end
d.ReferenceExclude = ch;
d.ReferenceExcludeSource = "manual";
obj.saveManifests(d);
obj.refreshReferencePanel();
obj.setStatus(sprintf("%s: %d channel(s) left out of the common reference.", d.Name, numel(ch)), ...
    "Press Detect / Preview to see the artifacts with this reference.");
end
