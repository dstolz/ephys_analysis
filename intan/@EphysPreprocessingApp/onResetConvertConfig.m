function onResetConvertConfig(obj)
    % Restore the Convert tab to its defaults.
    obj.applyConvertConfig(obj.defaultConvertConfig());
    obj.onConvertControlsChanged();
end
