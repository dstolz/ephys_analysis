function onUseSelectedProbeAsDefault(obj)
%onUseSelectedProbeAsDefault  Copy the selected probe file into the config's default.
pf = obj.selectedProbeFile();
if pf == ""
    uialert(obj.Fig, "Select a probe in the table first.", "Probe");
    return
end
obj.ProbeDefaultField.Value = char(pf);
obj.onConfigChanged();
end
