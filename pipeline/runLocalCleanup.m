function R = runLocalCleanup(T, opts)
%runLocalCleanup  Remove the files a planLocalCleanup plan marks "remove": delete, recycle or move them.
%   R = runLocalCleanup(T) takes the table from planLocalCleanup and deletes
%   each row whose Action is "remove". Rows marked "keep" are never touched.
%   R = runLocalCleanup(T, Method="recycle") sends them to the Recycle Bin
%   instead, and R = runLocalCleanup(T, Method="move", Destination=D) moves
%   them into folder D.
%
%   Methods
%     "delete"   delete for good (the default): the space is free at once.
%     "recycle"  send to the Recycle Bin of the file's drive (Windows only),
%                from where each file can be restored; the space is freed
%                only when the bin is emptied. Windows keeps a file there
%                only on a local fixed drive whose bin is not set to remove
%                files at once, and only when the file fits the bin's
%                Maximum size (the bin's Properties); otherwise it would
%                delete the file for good without asking, so such a file is
%                skipped instead. Afterwards each file is looked up in the
%                bin, and one not found there is reported.
%     "move"     move to Destination (created if missing), each file to
%                <Destination>/<Key>/<its path below Root> (see
%                planLocalCleanup), so every dataset keeps its layout. A file
%                already at that place is skipped, never overwritten. Between
%                drives a file is copied, the copy's size checked, and only
%                then the local file deleted. Destination may not be inside a
%                dataset's folders, where the next preview would list the
%                files again.
%
%   Each file is checked again just before it is removed, because the plan
%   may be old: it must still have the size the plan saw, and a raw file's
%   source must still exist with that size. A file that fails a check is
%   "skipped" and left in place.
%
%   Folders that the removal leaves empty are removed too, up to (not
%   including) each file's Root, so removing the Sorting step's output
%   leaves no kilosort4 folder behind.
%
%   Each dataset that had files removed gets <Folder>/<Name>_cleanup.json,
%   a record of what was removed, how, and where it went (a later clean up
%   appends a run to it).
%
%   Options
%     Method       "delete" | "recycle" | "move" (default "delete")
%     Destination  the folder for Method "move" (a full path)
%     LogFcn       @(message) called once per file handled (default: none)
%     ProgressFcn  @(evt) called before each file, evt = struct(index,
%                  count, bytesDone, bytesTotal, file) (default: none)
%     CancelFcn    @() returning true to stop: the files not handled yet are
%                  "skipped" (default: none)
%
%   R holds the "remove" rows of T plus
%     Status   "removed" | "skipped" | "failed"
%     Message  why a file was skipped or failed; for a removed file, a note
%              ("" when it went as asked)
%     To       where the file went: its new path (move), "Recycle Bin"
%              (recycle, found there afterwards) or "" (deleted)
%
%   See also planLocalCleanup.

arguments
    T table
    opts.Method (1,1) string {mustBeMember(opts.Method, ["delete" "recycle" "move"])} = "delete"
    opts.Destination (1,1) string = ""
    opts.LogFcn = []
    opts.ProgressFcn = []
    opts.CancelFcn = []
end

R = T(T.Action == "remove", :);
n = height(R);
R.Status = strings(n, 1);
R.Message = strings(n, 1);
R.To = strings(n, 1);
dest = checkDestination(opts, T);
if opts.Method == "recycle"
    if ~ispc
        error('runLocalCleanup:Recycle', 'Method "recycle" needs Windows; use "delete" or "move".');
    end
    prev = recycle('on');
    restoreRecycle = onCleanup(@() recycle(prev));
    bins = containers.Map('KeyType', 'char', 'ValueType', 'any');   % what each drive's bin takes
end
t0 = datetime('now');
total = sum(R.Bytes);
done = 0;
for k = 1:n
    if ~isempty(opts.CancelFcn) && opts.CancelFcn()
        R.Status(k:n) = "skipped";
        R.Message(k:n) = "cancelled";
        say(opts.LogFcn, sprintf("Cancelled: %d file(s) not handled.", n - k + 1));
        break
    end
    if ~isempty(opts.ProgressFcn)
        opts.ProgressFcn(struct('index', k, 'count', n, 'bytesDone', done, 'bytesTotal', total, 'file', R.File(k)));
    end
    [R.Status(k), R.Message(k)] = checkOne(R(k, :));
    if R.Status(k) == ""
        switch opts.Method
            case "delete";  [R.Status(k), R.Message(k)] = deleteOne(R.File(k));
            case "recycle"; [R.Status(k), R.Message(k)] = recycleOne(R(k, :), bins);
            case "move";    [R.Status(k), R.Message(k), R.To(k)] = moveOne(R(k, :), dest);
        end
    end
    done = done + R.Bytes(k);
    if ~(opts.Method == "recycle" && R.Status(k) == "removed")   % recycled files are logged once found in the bin
        logRow(opts.LogFcn, R(k, :), opts.Method);
    end
end
if opts.Method == "recycle"
    R = confirmRecycled(R, t0, opts.LogFcn);
end
pruneEmptyFolders(R);

for folder = unique(R.Folder(R.Status == "removed")).'
    rows = R(R.Folder == folder, :);
    try
        writeRecord(folder, rows, opts.Method, dest);
    catch ME
        say(opts.LogFcn, "Clean-up record not written in " + folder + ": " + ME.message);
    end
end
end


function dest = checkDestination(opts, T)
%checkDestination  The Destination of a move, checked: a full path outside every dataset folder.
dest = "";
if opts.Method ~= "move"; return; end
dest = stripSep(strtrim(opts.Destination));
if dest == ""
    error('runLocalCleanup:Destination', 'Method "move" needs a Destination folder.');
end
if isempty(regexp(dest, '^([A-Za-z]:([\\/]|$)|\\\\)', 'once'))
    error('runLocalCleanup:Destination', 'The destination must be a full path: %s', dest);
end
for f = unique([T.Folder; T.Root]).'
    if f ~= "" && under(dest, f)
        error('runLocalCleanup:Destination', ['The destination %s is inside the dataset folder %s, ' ...
            'where the files would be listed again. Choose a folder outside the datasets.'], dest, f);
    end
end
end


function [status, msg] = checkOne(r)
%checkOne  "" when file R is still as the plan saw it, else why it is skipped.
status = ""; msg = "";
s = dir(r.File);
if ~isscalar(s) || s.isdir
    status = "skipped"; msg = "no longer there";
elseif s.bytes ~= r.Bytes
    status = "skipped"; msg = "its size changed since the preview";
elseif r.Source ~= ""
    src = dir(r.Source);
    if ~isscalar(src) || src.isdir || src.bytes ~= s.bytes
        status = "skipped"; msg = "its source copy is no longer there with the same size";
    end
end
end


function [status, msg] = deleteOne(f)
if java.io.File(char(f)).delete()
    status = "removed"; msg = "";
else
    status = "failed"; msg = "could not be deleted (open in another program?)";
end
end


function [status, msg] = recycleOne(r, bins)
%recycleOne  Send one file to the Recycle Bin (recycle is on), unless the bin would not keep it.
[ok, why] = recyclable(r.File, r.Bytes, bins);
if ~ok
    status = "skipped"; msg = why + "; delete or move it instead";
    return
end
ws = warning('off', 'MATLAB:DELETE:Permission');
restoreWarning = onCleanup(@() warning(ws));
delete(char(r.File));
if isfile(r.File)
    status = "failed"; msg = "could not be moved to the Recycle Bin (open in another program?)";
else
    status = "removed"; msg = "";
end
end


function [ok, why] = recyclable(file, bytes, bins)
%recyclable  True when the Recycle Bin of FILE's drive would keep it (else WHY not).
root = volumeRoot(file);
if ~isKey(bins, char(lower(root)))
    bins(char(lower(root))) = binOf(root);
end
b = bins(char(lower(root)));
ok = false;
why = b.why;
if why ~= ""; return; end
if strlength(file) >= 260
    why = "its path is too long for the Recycle Bin";
elseif bytes > b.capacity
    why = sprintf("it is larger than the Recycle Bin of %s holds (%s, the bin's Maximum size)", root, sizeText(b.capacity));
else
    ok = true;
end
end


function b = binOf(root)
%binOf  What the Recycle Bin of the drive at ROOT takes: its capacity in bytes, and why it takes nothing ("" when it does).
b = struct('capacity', 0, 'why', "");
if startsWith(root, "\\")
    b.why = "a network folder has no Recycle Bin";
    return
end
try
    di = System.IO.DriveInfo(char(root));
    type = string(char(di.DriveType.ToString()));
    total = double(di.TotalSize);
catch
    type = "Unknown"; total = 0;
end
if type ~= "Fixed"
    b.why = sprintf("%s is a %s drive, which has no Recycle Bin", root, lower(type));
    return
end
if regValue("Software\Microsoft\Windows\CurrentVersion\Policies\Explorer", 'NoRecycleFiles', 0) == 1
    b.why = "a policy on this computer turns the Recycle Bin off";
    return
end
[~, out] = system(sprintf('mountvol %s /L', root));
guid = string(regexp(out, '\{[0-9a-fA-F-]+\}', 'match', 'once'));
key = "Software\Microsoft\Windows\CurrentVersion\Explorer\BitBucket\Volume\" + guid;
if guid ~= "" && regValue(key, 'NukeOnDelete', 0) == 1
    b.why = "the Recycle Bin of " + root + " is set to remove files at once";
    return
end
% Windows' size for a bin never set by hand: 10% of the first 40 GB and 5% of the rest (in MB)
mb = floor((0.10 * min(total, 40 * 2^30) + 0.05 * max(total - 40 * 2^30, 0)) / 2^20);
if guid ~= ""; mb = regValue(key, 'MaxCapacity', mb); end
b.capacity = mb * 2^20;
end


function v = regValue(key, name, default)
try
    v = double(winqueryreg('HKEY_CURRENT_USER', char(key), name));
catch
    v = default;
end
end


function R = confirmRecycled(R, t0, logFcn)
%confirmRecycled  Look each recycled file up in the Recycle Bin and log it; note those not there.
gone = find(R.Status == "removed");
if isempty(gone); return; end
roots = strings(numel(gone), 1);
for k = 1:numel(gone); roots(k) = volumeRoot(R.File(gone(k))); end
sid = "";
try
    sid = string(char(System.Security.Principal.WindowsIdentity.GetCurrent().User.Value));
catch
end
for root = unique(roots).'
    rows = gone(roots == root);
    binDir = fullfile(root, "$RECYCLE.BIN", sid);
    if sid == "" || ~isfolder(binDir)
        R.To(rows) = "Recycle Bin";
        R.Message(rows) = "sent to the Recycle Bin, which could not be read to check it";
        continue
    end
    in = ismember(lower(R.File(rows)), lower(binnedSince(binDir, t0)));
    R.To(rows(in)) = "Recycle Bin";
    R.Message(rows(~in)) = "not found in the Recycle Bin afterwards: Windows may have deleted it for good";
end
for k = gone.'
    logRow(logFcn, R(k, :), "recycle");
end
end


function paths = binnedSince(binDir, t0)
%binnedSince  Original paths of what went into the Recycle Bin folder BINDIR since T0 (from its $I records).
paths = strings(0, 1);
D = dir(fullfile(binDir, '$I*'));
D = D(~[D.isdir]);
D = D(datetime([D.datenum], 'ConvertFrom', 'datenum') >= t0 - seconds(5));
for k = 1:numel(D)
    fid = fopen(fullfile(D(k).folder, D(k).name), 'r', 'ieee-le');
    if fid < 0; continue; end
    b = fread(fid, inf, '*uint8');
    fclose(fid);
    if numel(b) < 30; continue; end
    if typecast(b(1:8), 'int64') >= 2
        b = b(29:end);   % version 2: size, time, a character count, then the path
    else
        b = b(25:end);   % version 1: size, time, then a 520-byte path
    end
    b = b(1:2 * floor(numel(b) / 2));
    p = char(typecast(b(:).', 'uint16'));
    paths(end+1, 1) = string(strtok(p, char(0))); %#ok<AGROW>
end
end


function [status, msg, to] = moveOne(r, dest)
%moveOne  Move one file to <dest>/<Key>/<its path below Root>, never over an existing one.
status = "removed"; msg = ""; to = "";
target = string(fullfile(dest, r.Key, relativePath(r.File, r.Root)));
if isfile(target) || isfolder(target)
    status = "skipped"; msg = "a file is already at " + target + " (never overwritten)";
    return
end
parent = fileparts(target);
if ~isfolder(parent)
    [ok, m] = mkdir(parent);
    if ~ok
        status = "failed"; msg = "could not create " + parent + ": " + m;
        return
    end
end
if strcmpi(volumeRoot(r.File), volumeRoot(target))
    [ok, m] = movefile(r.File, target);
    if ~ok
        status = "failed"; msg = "could not be moved: " + m;
        return
    end
else
    [ok, m] = copyfile(r.File, target);
    s = dir(target);
    if ~ok || ~isscalar(s) || s.bytes ~= r.Bytes
        if isfile(target); delete(target); end
        status = "failed"; msg = "could not be copied to " + target;
        if ~ok; msg = msg + ": " + m; end
        return
    end
    if ~java.io.File(char(r.File)).delete()
        delete(target);
        status = "failed"; msg = "copied, but the local file could not be deleted (open in another program?), so the copy was removed";
        return
    end
end
to = target;
end


function pruneEmptyFolders(R)
%pruneEmptyFolders  Remove the folders that removing R's files left empty, below each file's Root.
tops = strings(0, 1);
for k = find(R.Status == "removed").'
    root = stripSep(R.Root(k));
    p = stripSep(fileparts(R.File(k)));
    if root == "" || ~startsWith(lower(p), lower(root) + filesep); continue; end
    first = extractBefore(extractAfter(p, strlength(root) + 1) + filesep, filesep);
    tops(end+1, 1) = fullfile(root, first); %#ok<AGROW>
end
for top = unique(tops).'
    removeEmpty(top);
end
end


function removeEmpty(folder)
%removeEmpty  Remove every empty folder in FOLDER, then FOLDER itself if that leaves it empty.
if ~isfolder(folder); return; end
D = dir(folder);
D = D([D.isdir] & ~ismember({D.name}, {'.', '..'}));
for k = 1:numel(D)
    removeEmpty(fullfile(folder, D(k).name));
end
if numel(dir(folder)) <= 2   % only . and ..
    [~, ~] = rmdir(char(folder));
end
end


function rel = relativePath(file, root)
%relativePath  FILE's path below ROOT (its name alone when it is not below ROOT).
root = stripSep(root);
if root ~= "" && startsWith(lower(file), lower(root) + filesep)
    rel = extractAfter(file, strlength(root) + 1);
else
    [~, b, e] = fileparts(file);
    rel = b + e;
end
end


function root = volumeRoot(file)
%volumeRoot  "D:\" or "\\server\share\": the drive FILE is on.
f = strrep(string(file), "/", "\");
if startsWith(f, "\\")
    parts = split(extractAfter(f, 2), "\");
    root = "\\" + strjoin(parts(1:min(2, end)), "\") + "\";
else
    root = upper(extractBefore(f, 3)) + "\";
end
end


function writeRecord(folder, rows, method, dest)
%writeRecord  Append this run to <Folder>/<Name>_cleanup.json.
file = fullfile(folder, rows.Dataset(1) + "_cleanup.json");
rec = readJsonFile(file, ErrorOnFail=false);
runs = {};
if isstruct(rec) && isfield(rec, 'runs')
    runs = rec.runs;
    if isstruct(runs); runs = num2cell(runs(:)).'; end
end
done = rows(rows.Status == "removed", :);
removed = struct('file', cellstr(done.File), 'category', cellstr(done.Category), 'step', cellstr(done.Step), ...
    'bytes', num2cell(int64(done.Bytes)), 'source', cellstr(done.Source), 'to', cellstr(done.To), ...
    'note', cellstr(done.Message));
run = struct('time', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
    'host', string(getenv('COMPUTERNAME')), 'user', string(getenv('USERNAME')), ...
    'method', method, 'destination', dest, ...
    'bytesRemoved', int64(sum(done.Bytes)), 'removed', {num2cell(removed(:)).'});
runs{end+1} = run;
writeJsonFile(file, struct('schema', "ephys-local-cleanup/2", 'dataset', rows.Dataset(1), ...
    'folder', folder, 'runs', {runs}));
end


function logRow(logFcn, r, method)
%logRow  One log line for a handled file: what happened, where it went, and why.
if isempty(logFcn); return; end
verb = r.Status;
if verb == "removed"
    verb = struct('delete', "deleted", 'recycle', "recycled", 'move', "moved").(method);
end
msg = verb + ": " + r.File;
if method == "move" && r.To ~= ""; msg = msg + " -> " + r.To; end
if r.Message ~= ""; msg = msg + " (" + r.Message + ")"; end
logFcn(msg);
end


function say(logFcn, msg)
if ~isempty(logFcn); logFcn(msg); end
end


function tf = under(p, root)
%under  True when folder P is ROOT or inside it.
p = stripSep(p); root = stripSep(root);
tf = root ~= "" && (strcmpi(p, root) || startsWith(lower(p), lower(root) + filesep));
end


function s = stripSep(s)
s = string(s);
s = strip(strrep(s, "/", filesep), 'right', filesep);
end


function s = sizeText(bytes)
if bytes >= 1024^3;     s = sprintf("%.1f GB", bytes / 1024^3);
elseif bytes >= 1024^2; s = sprintf("%.1f MB", bytes / 1024^2);
else;                   s = sprintf("%d bytes", bytes);
end
end
