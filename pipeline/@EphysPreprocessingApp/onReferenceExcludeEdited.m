function onReferenceExcludeEdited(obj)
%onReferenceExcludeEdited  Set the active dataset's channels left out of the
%   common reference from the Artifacts tab's Left out field ("3,7,12-14").
%   Channels past the dataset's channel count are dropped. The list is marked
%   "manual" (EphysDataset.ReferenceExcludeSource), so no run replaces it
%   with a suggestion, and saved in the dataset's manifest.
%
%   See also onSuggestReferenceExclude, EphysDataset.applyReference.

d = obj.currentDataset();
if isempty(d); return; end
ch = EphysDataset.parseChannelList(obj.ArtRefExcludeField.Value);
if ~isnan(d.NumChannels)
    ch = ch(ch <= d.NumChannels);
end
d.ReferenceExclude = ch;
d.ReferenceExcludeSource = "manual";
d.writeManifest();
obj.refreshReferencePanel();
obj.setStatus(sprintf("%s: %d channel(s) left out of the common reference.", d.Name, numel(ch)), ...
    "Press Detect / Preview to see the artifacts with this reference.");
end
