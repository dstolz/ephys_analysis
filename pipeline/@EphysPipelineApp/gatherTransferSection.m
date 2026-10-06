function X = gatherTransferSection(obj)
%gatherTransferSection  Transfer section (copy the outputs elsewhere) from the Run tab's controls.
X = obj.Config.Transfer;
X.Enabled = logical(obj.RunTransferCheckBox.Value);
X.Destination = string(strtrim(obj.RunTransferDestField.Value));
X.Method = string(obj.RunTransferMethodDropDown.Value);
X.When = string(obj.RunTransferWhenDropDown.Value);
X.IfExists = string(obj.RunTransferIfExistsDropDown.Value);
if obj.RunTransferHashCheckBox.Value
    X.Verify = "hash";
else
    X.Verify = "size";
end
end
