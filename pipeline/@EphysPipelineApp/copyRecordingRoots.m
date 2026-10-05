function roots = copyRecordingRoots(obj)
%copyRecordingRoots  The Copy tab's recording roots, as a row of strings.
%   The field holds one or more folders separated by ";" (blanks dropped).
roots = strtrim(split(string(obj.CopyRecordingRootsField.Value), ";")).';
roots = roots(roots ~= "");
end
