function onConvertControlsChanged(obj)
%onConvertControlsChanged  Sync enable states, the config and the plan preview.
%   A new Label field names the digital lines anew: the Trials tab's lines
%   table is filled again with those names.
obj.syncConvertEnableStates();
labelField = obj.Config.Signals.LabelField;
obj.onConfigChanged();
if obj.Config.Signals.LabelField ~= labelField
    obj.fillTrialsLines();
end
if ~obj.Applying && ~isempty(obj.Tabs) && isvalid(obj.Tabs) && obj.Tabs.SelectedTab == obj.TabSignals
    obj.refreshStepPlan("signals");
end
end
