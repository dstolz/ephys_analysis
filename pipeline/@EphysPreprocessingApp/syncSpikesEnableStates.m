function syncSpikesEnableStates(obj)
%syncSpikesEnableStates  Enable Spikes-tab controls per source / mode.
if isempty(obj.SpkSourceDropDown) || ~isvalid(obj.SpkSourceDropDown); return; end
onOff = @(tf) matlab.lang.OnOffSwitchState(logical(tf));
src = string(obj.SpkSourceDropDown.Value);
det = src ~= "sorted";
srt = src ~= "detect";
detCtrls = [obj.SpkFilterCheckBox, obj.SpkBandLoField, obj.SpkBandHiField, obj.SpkFilterOrderField, ...
    obj.SpkPolarityDropDown, obj.SpkThreshMethodDropDown, obj.SpkThresholdField, obj.SpkMaxAmpField, ...
    obj.SpkAlignDropDown, obj.SpkAlignWindowField, obj.SpkMinPeriodField, obj.SpkWaveformsCheckBox, ...
    obj.SpkWinBeforeField, obj.SpkWinAfterField, obj.SpkWaveSourceDropDown, obj.SpkEdgeDropDown, ...
    obj.SpkChannelsDropDown, obj.SpkRejectArtifactsCheckBox, obj.SpkChunkField, obj.SpkEdgePadField, ...
    obj.SpkPreviewButton];
set(detCtrls, 'Enable', onOff(det));
set([obj.SpkBandLoField, obj.SpkBandHiField, obj.SpkFilterOrderField], 'Enable', onOff(det && obj.SpkFilterCheckBox.Value));
set([obj.SpkWinBeforeField, obj.SpkWinAfterField, obj.SpkWaveSourceDropDown, obj.SpkEdgeDropDown], ...
    'Enable', onOff(det && obj.SpkWaveformsCheckBox.Value));
obj.SpkChannelListField.Enable = onOff(det && string(obj.SpkChannelsDropDown.Value) == "list");
set([obj.SpkGroupsField, obj.SpkIncludeNoiseCheckBox, obj.SpkTemplatesCheckBox], 'Enable', onOff(srt));
end
