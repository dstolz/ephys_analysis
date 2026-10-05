function onConfigChanged(obj)
%onConfigChanged  A control changed: re-gather the config, push it to the
%   datasets, sync enable states and the unsaved-changes marker. While a run
%   is under way the datasets keep the settings the run started with (the
%   run pushes the working config onto them when it ends). A new default
%   probe shows in the Project table and, for a dataset without a probe of
%   its own, in the Artifacts viewer.
if obj.Applying; return; end
defaultProbe = obj.Config.Probe.DefaultProbeFile;
try
    obj.Config = obj.gatherConfig();
catch ME
    obj.setStatus("Config: " + string(ME.message), "");
    return
end
if ~isempty(obj.Project) && obj.Project.NumDatasets > 0 && ~obj.RunActive
    EphysPipeline.applyConfigToDatasets(obj.Config, obj.Project);
end
if obj.Config.Probe.DefaultProbeFile ~= defaultProbe
    obj.refreshDatasetsTable();
    obj.syncArtProbeControls();
end
obj.syncStepEnableStates();
obj.updateTitle();
end
