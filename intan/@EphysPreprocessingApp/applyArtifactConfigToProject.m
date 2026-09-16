function applyArtifactConfigToProject(obj)
    % Push the tab's detection config onto every scanned dataset so the
    % .bin write (onRunBatch) blanks consistently across the batch.
    if isempty(obj.Project) || obj.Project.NumDatasets == 0; return; end
    cfg = obj.artifactConfigFromControls();
    for k = 1:obj.Project.NumDatasets
        obj.Project.Datasets(k).ArtifactConfig = cfg;
    end
end
