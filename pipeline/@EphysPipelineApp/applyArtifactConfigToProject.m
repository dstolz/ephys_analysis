function applyArtifactConfigToProject(obj)
%applyArtifactConfigToProject  Push the Artifacts and Reference sections onto every dataset.
%   Not while a run is under way: the datasets keep the settings it started
%   with.
if isempty(obj.Project) || obj.Project.NumDatasets == 0 || obj.RunActive; return; end
if ~obj.Applying
    obj.Config.Artifacts = obj.gatherArtifactsSection();
    obj.Config.Reference = obj.gatherReferenceSection();
end
acfg = EphysPipelineConfig.artifactConfig(obj.Config.Artifacts, obj.Config.Reference);
for k = 1:obj.Project.NumDatasets
    obj.Project.Datasets(k).ArtifactConfig = acfg;
end
end
