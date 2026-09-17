function S = gatherProbeSection(obj)
%gatherProbeSection  Probe section from the Probe tab.
S = obj.Config.Probe;
S.DefaultProbeFile       = string(strtrim(obj.ProbeDefaultField.Value));
S.WriteDefaultToManifest = logical(obj.ProbeWriteDefaultCheckBox.Value);
end
