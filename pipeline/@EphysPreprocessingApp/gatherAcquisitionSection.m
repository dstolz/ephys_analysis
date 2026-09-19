function A = gatherAcquisitionSection(obj)
%gatherAcquisitionSection  Acquisition section (reader options) from the Project tab.
A = obj.Config.Acquisition;
A.OpenEphys.Recordings = string(obj.OERecordingsDropDown.Value);
A.OpenEphys.RecordNode = string(strtrim(obj.OERecordNodeField.Value));
A.OpenEphys.Stream     = string(strtrim(obj.OEStreamField.Value));
end
