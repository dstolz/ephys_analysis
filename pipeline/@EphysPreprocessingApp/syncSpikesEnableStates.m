function syncSpikesEnableStates(obj)
%syncSpikesEnableStates  Enable Spikes-tab controls per mode.
if isempty(obj.SpkFilterCheckBox) || ~isvalid(obj.SpkFilterCheckBox); return; end
onOff = @(tf) matlab.lang.OnOffSwitchState(logical(tf));
set([obj.SpkBandLoField, obj.SpkBandHiField, obj.SpkFilterOrderField], 'Enable', onOff(obj.SpkFilterCheckBox.Value));
set([obj.SpkWinBeforeField, obj.SpkWinAfterField, obj.SpkWaveSourceDropDown, obj.SpkEdgeDropDown], ...
    'Enable', onOff(obj.SpkWaveformsCheckBox.Value));
obj.SpkChannelListField.Enable = onOff(string(obj.SpkChannelsDropDown.Value) == "list");
obj.SpkThreshScopeDropDown.Enable = onOff(string(obj.SpkThreshMethodDropDown.Value) ~= "absolute");
end
