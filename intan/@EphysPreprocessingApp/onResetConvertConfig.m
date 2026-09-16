function onResetConvertConfig(obj)
%onResetConvertConfig  Restore the Signals tab to the section defaults (step stays as is).
def = EphysPipelineConfig.defaults("Signals");
def.Enabled = logical(obj.SigEnableCheckBox.Value);
obj.applyConvertConfig(def);
obj.onConvertControlsChanged();
end
