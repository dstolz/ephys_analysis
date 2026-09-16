function onArtifactControlsChanged(obj)
%onArtifactControlsChanged  Sync enable states, then the config.
isRms = string(obj.ArtMethodDropDown.Value) == "rms";
obj.ArtRmsWindowField.Enable = matlab.lang.OnOffSwitchState(isRms);
obj.ArtHighpassField.Enable  = matlab.lang.OnOffSwitchState(logical(obj.ArtFilterCheckBox.Value));
obj.onConfigChanged();
end
