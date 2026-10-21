function syncSpikesEnableStates(obj)
%syncSpikesEnableStates  Enable Spikes-tab controls per mode.
if isempty(obj.SpkFilterCheckBox) || ~isvalid(obj.SpkFilterCheckBox); return; end
onOff = @(tf) matlab.lang.OnOffSwitchState(logical(tf));
set([obj.SpkBandLoField, obj.SpkBandHiField, obj.SpkFilterOrderField], 'Enable', onOff(obj.SpkFilterCheckBox.Value));
set([obj.SpkWinBeforeField, obj.SpkWinAfterField, obj.SpkWaveSourceDropDown, obj.SpkEdgeDropDown], ...
    'Enable', onOff(obj.SpkWaveformsCheckBox.Value));
obj.SpkChannelListField.Enable = onOff(string(obj.SpkChannelsDropDown.Value) == "list");
obj.SpkThreshScopeDropDown.Enable = onOff(string(obj.SpkThreshMethodDropDown.Value) ~= "absolute");
set([obj.SpkCoincRadiusField, obj.SpkCoincJitterField], 'Enable', onOff(string(obj.SpkCoincModeDropDown.Value) ~= "none"));
% The waveform window is centered on the sample each event is aligned to.
switch string(obj.SpkAlignDropDown.Value)
    case "none"; at = "the threshold crossing";
    otherwise;   at = "the " + string(obj.SpkAlignDropDown.Value);
end
obj.SpkWaveformsCheckBox.Text = "Save waveforms, centered on " + at;
end
