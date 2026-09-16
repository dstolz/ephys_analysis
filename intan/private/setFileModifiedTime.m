function ok = setFileModifiedTime(file, t)
%setFileModifiedTime  Set a file's modification time (best effort, via Java).
%   OK = setFileModifiedTime(file, t) stamps FILE with the datetime T (local
%   time when T has no time zone) and returns true when it succeeded. The
%   Intan readers date a traditional recording by its files' modification
%   times, so synthetic recordings get their nominal acquisition time this
%   way. Returns false, without an error, when Java is unavailable or the
%   file system refuses.
arguments
    file (1,1) string
    t (1,1) datetime
end
try
    if isempty(t.TimeZone); t.TimeZone = 'local'; end
    ms = int64(round(posixtime(t) * 1000));
    f = java.io.File(char(file));
    ok = logical(f.setLastModified(ms));
catch
    ok = false;
end
end
