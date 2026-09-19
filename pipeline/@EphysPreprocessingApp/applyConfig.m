function applyConfig(obj, cfg, opts)
%applyConfig  Push a config into every tab and make it the working config.
%   applyConfig(cfg, MarkSaved=true) also records it as the saved state
%   (no unsaved-changes marker).
arguments
    obj (1,1) EphysPreprocessingApp
    cfg (1,1) EphysPipelineConfig
    opts.MarkSaved (1,1) logical = false
end
obj.Applying = true;
restore = onCleanup(@() setApplying(obj, false));
obj.ConfigNameField.Value = char(cfg.Name);
obj.ConfigDescField.Value = char(cfg.Description);
obj.applyProjectSection(cfg.Project);
obj.applyAcquisitionSection(cfg.Acquisition);
obj.applyParallelSection(cfg.Parallel);
obj.applyProbeSection(cfg.Probe);
obj.applyBehaviorSection(cfg.Behavior);
obj.applyArtifactsSection(cfg.Artifacts);
obj.applySortingSection(cfg.Sorting);
obj.applyConvertConfig(cfg.Signals);
obj.applySpikesSection(cfg.Spikes);
obj.applyExportSection(cfg.Export);
obj.Config = cfg;
if opts.MarkSaved
    obj.SavedConfigStruct = cfg.toStruct();
end
delete(restore);
obj.Applying = false;
if ~isempty(obj.Project) && obj.Project.NumDatasets > 0
    EphysPipeline.applyConfigToDatasets(obj.Config, obj.Project);
end
obj.syncStepEnableStates();
obj.updateTitle();
end


function setApplying(obj, tf)
obj.Applying = tf;
end
