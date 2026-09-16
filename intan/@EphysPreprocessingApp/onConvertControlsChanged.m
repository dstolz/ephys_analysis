function onConvertControlsChanged(obj)
    % Sync enable states, refresh the output-file preview, persist.
    obj.syncConvertEnableStates();
    obj.refreshConvertTargets();
    obj.savePreferences();
end
