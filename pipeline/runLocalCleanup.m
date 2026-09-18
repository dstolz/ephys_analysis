function R = runLocalCleanup(T, opts)
%runLocalCleanup  Delete the files a planLocalCleanup plan marks "remove".
%   R = runLocalCleanup(T) takes the table from planLocalCleanup and deletes
%   each row whose Action is "remove". Files are deleted outright, not moved
%   to the Recycle Bin (which would free no space). Rows marked "keep" are
%   never touched.
%
%   Each file is checked again just before it is deleted, because the plan
%   may be old: it must still have the size the plan saw, and a raw file's
%   source must still exist with that size. A file that fails a check is
%   "skipped" and left in place.
%
%   Each dataset that had files removed gets <Folder>/<Name>_cleanup.json,
%   a record of what was removed and, for raw files, where their source copy
%   is (a later clean up appends a run to it).
%
%   Options
%     LogFcn  @(message) called once per file handled (default: none)
%
%   R holds the "remove" rows of T plus
%     Status   "removed" | "skipped" | "failed"
%     Message  why a file was skipped or failed ("" when removed)
%
%   See also planLocalCleanup.

arguments
    T table
    opts.LogFcn = []
end

R = T(T.Action == "remove", :);
n = height(R);
R.Status = strings(n, 1);
R.Message = strings(n, 1);
for k = 1:n
    [R.Status(k), R.Message(k)] = removeOne(R(k, :));
    if ~isempty(opts.LogFcn)
        msg = R.Status(k) + ": " + R.File(k);
        if R.Message(k) ~= ""; msg = msg + " (" + R.Message(k) + ")"; end
        opts.LogFcn(msg);
    end
end

for folder = unique(R.Folder(R.Status == "removed")).'
    rows = R(R.Folder == folder, :);
    try
        writeRecord(folder, rows);
    catch ME
        if ~isempty(opts.LogFcn)
            opts.LogFcn("Clean-up record not written in " + folder + ": " + ME.message);
        end
    end
end
end


function [status, msg] = removeOne(r)
f = r.File;
s = dir(f);
if ~isscalar(s) || s.isdir
    status = "skipped"; msg = "no longer there";
    return
end
if s.bytes ~= r.Bytes
    status = "skipped"; msg = "its size changed since the preview";
    return
end
if r.Source ~= ""
    src = dir(r.Source);
    if ~isscalar(src) || src.isdir || src.bytes ~= s.bytes
        status = "skipped"; msg = "its source copy is no longer there with the same size";
        return
    end
end
if java.io.File(char(f)).delete()
    status = "removed"; msg = "";
else
    status = "failed"; msg = "could not be deleted (open in another program?)";
end
end


function writeRecord(folder, rows)
%writeRecord  Append this run to <Folder>/<Name>_cleanup.json.
file = fullfile(folder, rows.Dataset(1) + "_cleanup.json");
rec = readJsonFile(file, ErrorOnFail=false);
runs = {};
if isstruct(rec) && isfield(rec, 'runs')
    runs = rec.runs;
    if isstruct(runs); runs = num2cell(runs(:)).'; end
end
done = rows(rows.Status == "removed", :);
removed = struct('file', cellstr(done.File), 'category', cellstr(done.Category), ...
    'bytes', num2cell(int64(done.Bytes)), 'source', cellstr(done.Source));
run = struct('time', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
    'host', string(getenv('COMPUTERNAME')), 'user', string(getenv('USERNAME')), ...
    'bytesRemoved', int64(sum(done.Bytes)), 'removed', {num2cell(removed(:)).'});
runs{end+1} = run;
writeJsonFile(file, struct('schema', "ephys-local-cleanup/1", 'dataset', rows.Dataset(1), ...
    'folder', folder, 'runs', {runs}));
end
