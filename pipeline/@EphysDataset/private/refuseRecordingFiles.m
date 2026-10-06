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
             'recording. Choose another BinFile or set OutputDir (or BinDir).'], t, obj.Folder);
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
        q = normalizeDots(q);   % no JVM: resolve . and .. by hand, so the guard still holds
    end
    p(k) = string(q);
end
end


function q = normalizeDots(q)
%normalizeDots  Resolve "." and ".." segments and repeated separators (no file-system access).
q = char(q);
lead = regexp(q, '^([A-Za-z]:|[\\/]{2}|[\\/])', 'match', 'once');   % drive, UNC or root
parts = regexp(q(numel(lead) + 1:end), '[\\/]+', 'split');
out = {};
for k = 1:numel(parts)
    s = parts{k};
    if isempty(s) || strcmp(s, '.'); continue; end
    if strcmp(s, '..')
        if ~isempty(out); out(end) = []; end   % never above the root
        continue
    end
    out{end + 1} = s; %#ok<AGROW>
end
lead = strrep(strrep(lead, '/', filesep), '\', filesep);
if ~isempty(regexp(lead, '^[A-Za-z]:$', 'once')); lead = [lead filesep]; end
q = [lead strjoin(out, filesep)];
end


function tf = samePath(p, list)
if ispc
    tf = strcmpi(p, list);
else
    tf = strcmp(p, list);
end
end
