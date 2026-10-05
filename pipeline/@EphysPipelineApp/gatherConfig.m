function cfg = gatherConfig(obj)
%gatherConfig  The current state of every tab as an EphysPipelineConfig.
%   Sections are gathered by the per-section helpers; the config's File /
%   LoadWarnings are kept from obj.Config. Errors on a text field that does
%   not parse (a Kilosort4 parameter, a Spikes number, Max workers).
cfg = obj.Config;
cfg.Name        = string(strtrim(obj.ConfigNameField.Value));
if cfg.Name == ""; cfg.Name = "Untitled"; end
cfg.Description = string(strtrim(obj.ConfigDescField.Value));
cfg.Project   = obj.gatherProjectSection();
cfg.Acquisition = obj.gatherAcquisitionSection();
cfg.Parallel  = obj.gatherParallelSection();
cfg.Probe     = obj.gatherProbeSection();
cfg.Behavior  = obj.gatherBehaviorSection();
cfg.Artifacts = obj.gatherArtifactsSection();
[cfg.Sorting, msg] = obj.gatherSortingSection();
if msg ~= ""
    error('EphysPreprocessingApp:SortingNumber', '%s', msg);
end
cfg.Signals   = obj.gatherConvertConfig();
cfg.Spikes    = obj.gatherSpikesSection();
cfg.Export    = obj.gatherExportSection();
end
