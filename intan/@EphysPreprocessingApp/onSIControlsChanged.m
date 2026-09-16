function onSIControlsChanged(obj)
%onSIControlsChanged  Sync enable states, then the config.
obj.syncSIEnableStates();
obj.onConfigChanged();
end
