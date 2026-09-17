function onConvertControlsChanged(obj)
%onConvertControlsChanged  Sync enable states, the config and the plan preview.
obj.syncConvertEnableStates();
obj.onConfigChanged();
if ~obj.Applying && ~isempty(obj.Tabs) && isvalid(obj.Tabs) && obj.Tabs.SelectedTab == obj.TabSignals
    obj.refreshStepPlan("signals");
end
end
