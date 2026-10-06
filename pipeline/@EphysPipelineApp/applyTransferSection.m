function applyTransferSection(obj, X)
%applyTransferSection  Transfer section -> the Run tab's Copy outputs controls.
X = EphysPipelineConfig.normalizeSection("Transfer", X);
obj.RunTransferCheckBox.Value = logical(X.Enabled);
obj.RunTransferDestField.Value = char(X.Destination);
obj.setControlValue(obj.RunTransferMethodDropDown, char(X.Method), "Transfer.Method");
obj.setControlValue(obj.RunTransferWhenDropDown, char(X.When), "Transfer.When");
obj.setControlValue(obj.RunTransferIfExistsDropDown, char(X.IfExists), "Transfer.IfExists");
obj.RunTransferHashCheckBox.Value = X.Verify == "hash";
syncTransferControls(obj);
end
