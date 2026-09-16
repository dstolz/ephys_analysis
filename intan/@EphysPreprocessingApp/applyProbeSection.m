function applyProbeSection(obj, S)
%applyProbeSection  Probe section -> Probe tab.
S = EphysPipelineConfig.normalizeSection("Probe", S);
obj.ProbeDefaultField.Value = char(S.DefaultProbeFile);
obj.ProbeWriteDefaultCheckBox.Value = logical(S.WriteDefaultToManifest);
end
