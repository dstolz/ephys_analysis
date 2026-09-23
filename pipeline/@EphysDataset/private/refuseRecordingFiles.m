function refuseRecordingFiles(obj, targets, who)
%refuseRecordingFiles  Error before a writer would open one of the recording's files.
%   refuseRecordingFiles(DS, TARGETS, WHO) raises
%   EphysDataset:<WHO>:WouldOverwriteRecording when any path in TARGETS (the
%   files a writer is about to open for writing) is one of the recording's
%   own files, fullfile(DS.Folder, DS.Files). A universal-format recording's
%   data file can be <Name>.bin in the very folder the .bin goes to by
%   default, and opening it for writing truncates it. Paths are compared
%   absolute and normalised (relative ones against the current folder, as
%   FOPEN resolves them), ignoring case on Windows.
%
%   See also EphysDataset.toBin, EphysDataset.matrixToBin.

if obj.Folder == "" || isempty(obj.Files)
    return
end
recording = absolutePath(fullfile(obj.Folder, obj.Files));
for t = reshape(string(targets), 1, [])
    if any(samePath(absolutePath(t), recording))
        error(char("EphysDataset:" + who + ":WouldOverwriteRecording"), ...
            ['%s is one of the recording''s own files (%s); writing it would destroy the ' ...
             'recording. Choose another BinFile or set OutputDir.'], t, obj.Folder);
    end
end
end


function p = absolutePath(p)
%absolutePath  Absolute, normalised form of each path (. and .. resolved).
p = string(p);
for k = 1:numel(p)
    q = char(p(k));
    if isempty(regexp(q, '^([A-Za-z]:[\\/]|[\\/])', 'once'))
        q = fullfile(pwd, q);
    end
    try
        q = char(java.io.File(q).getCanonicalPath());
    catch
        % No JVM: the absolute path as given.
    end
    p(k) = string(q);
end
end


function tf = samePath(p, list)
if ispc
    tf = strcmpi(p, list);
else
    tf = strcmp(p, list);
end
end
