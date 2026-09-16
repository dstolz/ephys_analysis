function onArtifactControlsChanged(obj)
    % Sync RMS-only field enable state and persist the config to disk
    % whenever a detection control changes.
    isRms = string(obj.ArtMethodDropDown.Value) == "rms";
    obj.ArtRmsWindowField.Enable = matlab.lang.OnOffSwitchState(isRms);
    obj.ArtFilterCheckBox.Enable = "on";
    obj.ArtHighpassField.Enable  = matlab.lang.OnOffSwitchState( ...
        logical(obj.ArtFilterCheckBox.Value));
    obj.applyArtifactConfigToProject();
    obj.savePreferences();
end
