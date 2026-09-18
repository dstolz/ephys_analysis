function syncSIEnableStates(obj)
    % Enable the filter-band + reference-operator + bad-channel controls
    % only when their master checkbox is ticked, and none of the
    % SpikeInterface preprocessing when the native Kilosort4 engine is picked.
    if isempty(obj.SIFilterCheckBox) || ~isvalid(obj.SIFilterCheckBox); return; end
    si = isempty(obj.SortEngineDropDown) || ~isvalid(obj.SortEngineDropDown) || ...
        string(obj.SortEngineDropDown.Value) == "spikeinterface";
    obj.SIFilterCheckBox.Enable    = matlab.lang.OnOffSwitchState(si);
    obj.SICommonRefCheckBox.Enable = matlab.lang.OnOffSwitchState(si);
    obj.SIDetectBadCheckBox.Enable = matlab.lang.OnOffSwitchState(si);
    onFilter = si && logical(obj.SIFilterCheckBox.Value);
    obj.SIFilterMinField.Enable = matlab.lang.OnOffSwitchState(onFilter);
    obj.SIFilterMaxField.Enable = matlab.lang.OnOffSwitchState(onFilter);
    obj.SIRefOperatorDropDown.Enable = ...
        matlab.lang.OnOffSwitchState(si && logical(obj.SICommonRefCheckBox.Value));
    onBad = si && logical(obj.SIDetectBadCheckBox.Value);
    obj.SIBadMethodDropDown.Enable = matlab.lang.OnOffSwitchState(onBad);
    obj.SIBadActionDropDown.Enable = matlab.lang.OnOffSwitchState(onBad);
end
