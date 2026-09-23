function applyAcquisitionSection(obj, A)
%applyAcquisitionSection  Acquisition section (reader options) -> Project tab.
A = EphysPipelineConfig.normalizeSection("Acquisition", A);
obj.setDropIfMember(obj.OERecordingsDropDown, A.OpenEphys.Recordings, "Acquisition.OpenEphys.Recordings");
obj.OERecordNodeField.Value = char(A.OpenEphys.RecordNode);
obj.OEStreamField.Value = char(A.OpenEphys.Stream);
end
