function onSpikesControlsChanged(obj)
%onSpikesControlsChanged  Sync enable states, then the config.
obj.syncSpikesEnableStates();
obj.onConfigChanged();
end
