function syncTransferControls(obj)
%syncTransferControls  The Run tab's Copy outputs settings follow its box.
on = matlab.lang.OnOffSwitchState(logical(obj.RunTransferCheckBox.Value));
set([obj.RunTransferDestField, obj.RunTransferBrowseButton, obj.RunTransferMethodDropDown, ...
    obj.RunTransferWhenDropDown, obj.RunTransferIfExistsDropDown, obj.RunTransferHashCheckBox], "Enable", on);
end
