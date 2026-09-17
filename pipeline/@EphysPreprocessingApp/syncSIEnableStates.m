function syncSIEnableStates(obj)
    % Enable the filter-band + reference-operator + bad-channel controls
    % only when their master checkbox is ticked.
    if isempty(obj.SIFilterCheckBox) || ~isvalid(obj.SIFilterCheckBox); return; end
    onFilter = logical(obj.SIFilterCheckBox.Value);
    obj.SIFilterMinField.Enable = matlab.lang.OnOffSwitchState(onFilter);
    obj.SIFilterMaxField.Enable = matlab.lang.OnOffSwitchState(onFilter);
    obj.SIRefOperatorDropDown.Enable = ...
        matlab.lang.OnOffSwitchState(logical(obj.SICommonRefCheckBox.Value));
    onBad = logical(obj.SIDetectBadCheckBox.Value);
    obj.SIBadMethodDropDown.Enable = matlab.lang.OnOffSwitchState(onBad);
    obj.SIBadActionDropDown.Enable = matlab.lang.OnOffSwitchState(onBad);
end
