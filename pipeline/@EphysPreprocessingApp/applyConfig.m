function rejected = applyConfig(obj, cfg, opts)
%applyConfig  Push a config into every tab and make it the working config.
%   applyConfig(cfg, MarkSaved=true) also records it as the saved state
%   (no unsaved-changes marker).
%   REJECTED lists the values no control could show ("Section.Field =
%   value (shown as ...)", see setControlValue), such as a NaN or an
%   out-of-range number: the controls show another value instead, the
%   working config is what they show, and the title marks it as differing
%   from the saved state. When the config cannot be shown at all, every
%   control shows the previous config again and the error is rethrown.
%   A scanned project that is not the one under the config's root is
%   dropped (Scan loads the config's datasets); with the same root, the
%   datasets take the config's settings, unless a run is under way (it
%   pushes them when it ends), and a new default probe shows in the
%   Project table and the Artifacts viewer (as onConfigChanged).
arguments
    obj (1,1) EphysPreprocessingApp
    cfg (1,1) EphysPipelineConfig
    opts.MarkSaved (1,1) logical = false
end
prev = obj.Config;
obj.Applying = true;
restore = onCleanup(@() setApplying(obj, false));
obj.ApplyRejected = string.empty(1, 0);
try
    applySections(obj, cfg);
    obj.Config = cfg;
    if ~isempty(obj.ApplyRejected)
        obj.Config = obj.gatherConfig();   % what the controls show
    end
catch ME
    obj.Config = prev;
    applySections(obj, prev);   % every control shows the working config again
    obj.ApplyRejected = string.empty(1, 0);
    rethrow(ME);
end
rejected = obj.ApplyRejected;
if opts.MarkSaved
    obj.SavedConfigStruct = cfg.toStruct();
end
delete(restore);
obj.Applying = false;
if ~isempty(obj.Project) && ~obj.projectAtRoot(cfg.Project.Root)
    obj.Project = EphysProject.empty;   % another root's datasets
    obj.refreshDatasetsTable();
    obj.populateDatasetPickers();
    obj.ScanStatusLabel.Text = "No datasets scanned yet.";
elseif ~isempty(obj.Project) && obj.Project.NumDatasets > 0 && ~obj.RunActive
    EphysPipeline.applyConfigToDatasets(obj.Config, obj.Project);
end
if ~isempty(obj.Project) && obj.Config.Probe.DefaultProbeFile ~= prev.Probe.DefaultProbeFile
    obj.refreshDatasetsTable();
    obj.syncArtProbeControls();
end
obj.syncStepEnableStates();
obj.updateTitle();
end


function applySections(obj, cfg)
%applySections  Show every section of CFG in its tab's controls.
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
end


function setApplying(obj, tf)
obj.Applying = tf;
end
