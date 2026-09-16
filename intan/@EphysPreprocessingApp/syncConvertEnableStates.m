function syncConvertEnableStates(obj)
    % Enable each option only when the signal/mode it belongs to is on.
    if isempty(obj.ConvLFPCheckBox) || ~isvalid(obj.ConvLFPCheckBox); return; end
    onOff = @(tf) matlab.lang.OnOffSwitchState(logical(tf));
    lfp = obj.ConvLFPCheckBox.Value;
    mua = obj.ConvMUACheckBox.Value;
    spk = obj.ConvSPIKECheckBox.Value;
    obj.ConvLFPFsField.Enable = onOff(lfp);
    set([obj.ConvLFPHighpassCheckBox, obj.ConvLFPLowpassCheckBox, ...
        obj.ConvLFPNotchCheckBox], 'Enable', onOff(lfp));
    obj.ConvLFPHighpassField.Enable = onOff(lfp && obj.ConvLFPHighpassCheckBox.Value);
    obj.ConvLFPLowpassField.Enable  = onOff(lfp && obj.ConvLFPLowpassCheckBox.Value);
    set([obj.ConvLFPNotchField, obj.ConvLFPNotchBWField], ...
        'Enable', onOff(lfp && obj.ConvLFPNotchCheckBox.Value));
    set([obj.ConvMUAFsField, obj.ConvMUAIntegrationField, ...
        obj.ConvMUALoField, obj.ConvMUAHiField], 'Enable', onOff(mua));
    obj.ConvSpikeOrigCheckBox.Enable = onOff(spk);
    obj.ConvSpikeFsField.Enable = onOff(spk && ~obj.ConvSpikeOrigCheckBox.Value);
    set([obj.ConvSpikeLoField, obj.ConvSpikeHiField], 'Enable', onOff(spk));
    mode = string(obj.ConvBadModeDropDown.Value);
    obj.ConvBadThresholdField.Enable = onOff(mode == "auto");
    obj.ConvBadListField.Enable = onOff(mode == "manual");
end
