function refreshReferencePanel(obj)
%refreshReferencePanel  The Artifacts tab's common-reference panel for the
%   active dataset: its channels left out of the reference, where they came
%   from, and how many channels the reference is taken over. The bounds and
%   the Left out field are live only while a reference is chosen.
%
%   See also buildArtifactsTab, onSuggestReferenceExclude, onReferenceExcludeEdited.

if isempty(obj.ArtRefExcludeField) || ~isvalid(obj.ArtRefExcludeField); return; end
on = string(obj.ArtRefDropDown.Value) ~= "none";
obj.ArtRefLowField.Enable  = matlab.lang.OnOffSwitchState(on);
obj.ArtRefHighField.Enable = matlab.lang.OnOffSwitchState(on);

d = obj.currentDataset();
hasData = ~isempty(d);
obj.ArtRefExcludeField.Enable  = matlab.lang.OnOffSwitchState(on && hasData);
obj.ArtRefSuggestButton.Enable = matlab.lang.OnOffSwitchState(on && hasData);
if ~hasData
    obj.ArtRefExcludeField.Value = "";
    obj.ArtRefStatusLabel.Text = "";
    return
end

obj.ArtRefExcludeField.Value = EphysDataset.formatChannelList(d.ReferenceExclude);
if ~on
    obj.ArtRefStatusLabel.Text = "Channels are read as recorded.";
    return
end
switch d.ReferenceExcludeSource
    case "suggested", src = "suggested";
    case "manual",    src = "set by hand";
    otherwise,        src = "not set yet: suggested on the first run or preview";
end
txt = sprintf("%s: %s.", d.Name, src);
if ~isnan(d.NumChannels)
    txt = txt + sprintf(" Reference over %d of %d channels", numel(d.referenceChannels()), d.NumChannels);
    if ~isempty(d.ExcludeChannels)
        txt = txt + sprintf(" (Probe-tab exclusions %s left out too)", ...
            EphysDataset.formatChannelList(d.ExcludeChannels));
    end
    txt = txt + ".";
end
obj.ArtRefStatusLabel.Text = txt;
end
