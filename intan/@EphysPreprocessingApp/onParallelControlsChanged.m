function onParallelControlsChanged(obj)
%onParallelControlsChanged  A Run-tab parallel control changed: the worker
%   cap follows the checkbox, then the config is re-gathered.
obj.RunMaxWorkersField.Enable = matlab.lang.OnOffSwitchState(logical(obj.RunParallelCheckBox.Value));
obj.onConfigChanged();
end
