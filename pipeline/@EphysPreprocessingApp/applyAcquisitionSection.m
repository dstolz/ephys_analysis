function applyAcquisitionSection(obj, A)
%applyAcquisitionSection  Acquisition section (reader options) -> Source settings panel.
A = EphysPipelineConfig.normalizeSection("Acquisition", A);
obj.setDropIfMember(obj.OERecordingsDropDown, A.OpenEphys.Recordings, "Acquisition.OpenEphys.Recordings");
obj.OERecordNodeField.Value = char(A.OpenEphys.RecordNode);
obj.OEStreamField.Value = char(A.OpenEphys.Stream);
s = A.TDT.Stream;
if s == ""; s = "automatic"; end
if ~any(strcmp(obj.TDTStreamDropDown.Items, s))
    obj.TDTStreamDropDown.Items = [obj.TDTStreamDropDown.Items {char(s)}];
end
obj.TDTStreamDropDown.Value = char(s);
if isnan(A.TDT.GainToMicrovolts)
    obj.TDTGainField.Value = '';
else
    obj.TDTGainField.Value = obj.numberText(A.TDT.GainToMicrovolts);
end
end
