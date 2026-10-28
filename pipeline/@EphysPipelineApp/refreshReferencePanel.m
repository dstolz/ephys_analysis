function refreshReferencePanel(obj)
%refreshReferencePanel  The Artifacts tab's common-reference panel for the
%   active dataset: its channels left out of the reference, where they came
%   from, and how many channels the reference is taken over. The bounds and
%   the Left out field are live only while a reference is chosen, the
%   weighted CAR's options only while it is (Q while Automatic Q is off),
%   and shown only then. The bad-channels panel above it too: the active
%   dataset's bad channels and where they came from; the bounds stay live
%   while Leave out bad channels is ticked, since they suggest those.
%
%   See also buildArtifactsTab, onSuggestReferenceExclude, onReferenceExcludeEdited,
%   onSuggestBadChannels, onBadChannelsEdited.

if isempty(obj.ArtRefExcludeField) || ~isvalid(obj.ArtRefExcludeField); return; end
refreshBadChannels(obj);
on = string(obj.ArtRefDropDown.Value) ~= "none";
bounds = on || logical(obj.ArtBadCheckBox.Value);
obj.ArtRefLowField.Enable  = matlab.lang.OnOffSwitchState(bounds);
obj.ArtRefHighField.Enable = matlab.lang.OnOffSwitchState(bounds);
wcar = string(obj.ArtRefDropDown.Value) == "wcar";
set([obj.ArtRefWCAREstimateDropDown, obj.ArtRefWCAROrderField, obj.ArtRefWCARAlphaField, ...
    obj.ArtRefWCARDriftField, obj.ArtRefWCARHighpassField, obj.ArtRefWCARQAutoCheckBox], ...
    'Enable', matlab.lang.OnOffSwitchState(wcar));
obj.ArtRefWCARQField.Enable = matlab.lang.OnOffSwitchState(wcar && ~obj.ArtRefWCARQAutoCheckBox.Value);
wg = obj.ArtRefWCAROrderField.Parent;   % their grid takes no room for the other references
wg.Visible = matlab.lang.OnOffSwitchState(wcar);
wg.Parent.RowHeight{wg.Layout.Row} = 0;
if wcar
    wg.Parent.RowHeight{wg.Layout.Row} = 'fit';
end

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
    if ~isempty(d.excludedChannels())
        txt = txt + sprintf(" (Probe-tab exclusions and bad channels %s left out too)", ...
            EphysDataset.formatChannelList(d.excludedChannels()));
    end
    txt = txt + ".";
end
if string(obj.ArtRefDropDown.Value) == "wcar"
    txt = txt + " Weighted CAR: its state is worked out on the first read of the recording " + ...
        "(once; kept in " + d.Name + "_wcar.mat).";
end
obj.ArtRefStatusLabel.Text = txt;
end


function refreshBadChannels(obj)
% The bad-channels panel for the active dataset.
on = logical(obj.ArtBadCheckBox.Value);
d = obj.currentDataset();
hasData = ~isempty(d);
obj.ArtBadField.Enable         = matlab.lang.OnOffSwitchState(hasData);
obj.ArtBadSuggestButton.Enable = matlab.lang.OnOffSwitchState(hasData);
if ~hasData
    obj.ArtBadField.Value = "";
    obj.ArtBadStatusLabel.Text = "";
    return
end
obj.ArtBadField.Value = EphysDataset.formatChannelList(d.BadChannels);
switch d.BadChannelsSource
    case "suggested", src = "suggested";
    case "manual",    src = "set by hand";
    otherwise,        src = "not set yet: suggested on the first run or preview";
end
if on
    txt = sprintf("%s: %s; left out of every step.", d.Name, src);
else
    txt = sprintf("%s: %s; not used (tick the box to leave them out).", d.Name, src);
end
obj.ArtBadStatusLabel.Text = txt;
end
