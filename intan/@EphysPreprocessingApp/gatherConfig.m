function cfg = gatherConfig(obj)
%gatherConfig  The current state of every tab as an EphysPipelineConfig.
%   Sections are gathered by the per-section helpers; the config's File /
%   LoadWarnings are kept from obj.Config.
cfg = obj.Config;
cfg.Name        = string(strtrim(obj.ConfigNameField.Value));
if cfg.Name == ""; cfg.Name = "Untitled"; end
cfg.Description = string(strtrim(obj.ConfigDescField.Value));
cfg.Project   = obj.gatherProjectSection();
cfg.Parallel  = obj.gatherParallelSection();
cfg.Probe     = obj.gatherProbeSection();
cfg.Behavior  = obj.gatherBehaviorSection();
cfg.Artifacts = obj.gatherArtifactsSection();
[cfg.Sorting, ~] = obj.gatherSortingSection();
cfg.Signals   = obj.gatherConvertConfig();
cfg.Spikes    = obj.gatherSpikesSection();
cfg.Export    = obj.gatherExportSection();
end
