function onConfigChanged(obj)
%onConfigChanged  A control changed: re-gather the config, push it to the
%   datasets, sync enable states and the unsaved-changes marker.
if obj.Applying; return; end
try
    obj.Config = obj.gatherConfig();
catch ME
    obj.setStatus("Config: " + string(ME.message), "");
    return
end
if ~isempty(obj.Project) && obj.Project.NumDatasets > 0
    EphysPipeline.applyConfigToDatasets(obj.Config, obj.Project);
end
obj.syncStepEnableStates();
obj.updateTitle();
end
