function onArtifactControlsChanged(obj)
%onArtifactControlsChanged  Sync enable states, then the config and the viewer
%   (what a run removes follows Enable and the two uses; a changed detection
%   setting marks the preview stale).
isRms = string(obj.ArtMethodDropDown.Value) == "rms";
obj.ArtRmsWindowField.Enable = matlab.lang.OnOffSwitchState(isRms);
obj.ArtHighpassField.Enable  = matlab.lang.OnOffSwitchState(logical(obj.ArtFilterCheckBox.Value));
obj.onConfigChanged();
obj.drawArtifactView();
end
