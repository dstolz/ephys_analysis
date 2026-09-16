function applyArtifactConfigToProject(obj)
%applyArtifactConfigToProject  Push the Artifacts section onto every dataset.
if isempty(obj.Project) || obj.Project.NumDatasets == 0; return; end
if ~obj.Applying
    obj.Config.Artifacts = obj.gatherArtifactsSection();
end
acfg = EphysPipelineConfig.artifactConfig(obj.Config.Artifacts);
for k = 1:obj.Project.NumDatasets
    obj.Project.Datasets(k).ArtifactConfig = acfg;
end
end
