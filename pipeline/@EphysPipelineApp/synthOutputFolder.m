function [folder, why] = synthOutputFolder(obj, acq)
%synthOutputFolder  The recording folder Generate writes: <root>\<Subject>\<Subject>_<start>.
%   ACQ is the recording's start (synthGeneratorArgs); the leaf is named
%   from it as RHX names its folders (yymmdd_HHmmss) or, for the Open Ephys
%   formats, as the GUI does (yyyy-MM-dd_HH-mm-ss). FOLDER is "" when it
%   cannot be named, WHY says why.
folder = ""; why = "";
root = obj.synthOutputRoot();
if root == ""
    why = "Choose an output folder (Output: Folder) or scan a project first.";
    return
end
subject = strtrim(string(obj.SynthSubjectField.Value));
if subject == "" || ~isempty(regexp(subject, '[^\w\-]', 'once'))
    why = "The subject must be letters, digits, _ and - only (it names the folder and files).";
    return
end
if startsWith(string(obj.SynthFormatDropDown.Value), "openephys-")
    acq.Format = 'yyyy-MM-dd_HH-mm-ss';
else
    acq.Format = 'yyMMdd_HHmmss';
end
folder = string(fullfile(root, subject, subject + "_" + string(acq)));
end
