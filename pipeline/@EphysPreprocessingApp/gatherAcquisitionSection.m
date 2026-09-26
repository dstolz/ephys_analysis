function A = gatherAcquisitionSection(obj)
%gatherAcquisitionSection  Acquisition section (reader options) from the Source settings panel.
%   The TDT stream "automatic" is ""; a blank gain (or "automatic" / "NaN")
%   is NaN. Errors (EphysPreprocessingApp:TDTGain) on a gain that is not a
%   number; validate() checks that it is positive.
A = obj.Config.Acquisition;
A.OpenEphys.Recordings = string(obj.OERecordingsDropDown.Value);
A.OpenEphys.RecordNode = string(strtrim(obj.OERecordNodeField.Value));
A.OpenEphys.Stream     = string(strtrim(obj.OEStreamField.Value));
s = strtrim(string(obj.TDTStreamDropDown.Value));
if strcmpi(s, "automatic"); s = ""; end
A.TDT.Stream = s;
t = strtrim(string(obj.TDTGainField.Value));
if t == "" || any(lower(t) == ["automatic" "auto" "nan"])
    A.TDT.GainToMicrovolts = NaN;
else
    v = str2double(t);
    if isnan(v)
        error('EphysPreprocessingApp:TDTGain', 'TDT gain "%s" is not a number.', t);
    end
    A.TDT.GainToMicrovolts = v;
end
end
