function R = copyNasSessions(T, opts)
%copyNasSessions  Copy paired NAS sessions (Intan folder + ePsych file) to local session folders.
%   R = copyNasSessions(T) takes a findNasSessions table and, for each row
%   it is allowed to copy, copies the Intan recording folder's contents and
%   the ePsych .mat (original file name kept) into
%     <DestRoot>/<Subject>/<Intan folder name>/
%   then verifies every file and writes session_manifest.json there. The
%   source is only ever read: nothing on the NAS is modified, renamed, moved
%   or deleted, and nothing already in a destination is overwritten.
%
%   THE DEFAULT IS A DRY RUN: pass DryRun=false to copy.
%
%   Which rows are copied
%     paired                     always
%     intan_only / epsych_only   only with IncludeUnpaired=true (an ePsych-only
%                                row goes to <DestRoot>/<Subject>/<file name without .mat>)
%     ambiguous                  never
%   Pass only the rows you want (e.g. T(sel, :)).
%
%   Destination checks. A destination folder that exists and is not empty
%   is compared with the source: when every source file is there with the
%   same size (and SHA-256 with Verify="hash"; a dry run compares sizes
%   only) the row is "already_present" and left untouched. Otherwise
%   IfExists decides: "skip" (default) reports "skipped", "error" reports
%   "failed". There is no overwrite option. Before copying, the free space
%   under DestRoot is checked against the total size of the rows to copy;
%   too little space throws copyNasSessions:InsufficientSpace before any
%   file is written (a dry run reports it in the log and Message instead).
%
%   Copying uses robocopy (Windows) once per file:
%     robocopy <src folder> <dest folder> <file> /Z /R:3 /W:5 /NP /LOG+:<log>
%   (restartable mode, 3 retries, never /MIR, /MOV or /PURGE; /E is not
%   used because each file is named and every source subfolder is created
%   explicitly), so progress and cancellation happen between files. Exit
%   codes 0-7 are success, 8 and above failure. The robocopy log is
%   session_copy_robocopy.log in the destination folder.
%
%   Verification after the copy: every source file must have a destination
%   file of identical size (plus identical SHA-256 with Verify="hash",
%   streamed in 64 MB chunks) and must not have changed size since it was
%   listed. Any mismatch marks the row "failed"; the partial copy is kept
%   and the manifest records what did not match.
%
%   Each row is handled in its own try/catch so one failure does not stop
%   the batch.
%
%   Options
%     DestRoot         (default "D:/EPHYS")
%     DryRun           (default true) report what would happen, write nothing
%     IfExists         "skip" (default) | "error"
%     IncludeUnpaired  (default false)
%     Verify           "size" (default) | "hash"
%     ProgressFcn      @(fraction, message), called between files
%     LogFcn           @(message) (default: print it)
%     CancelFcn        @() logical, polled between files; true stops the batch
%                      (the current session is kept as copied so far and marked
%                      "cancelled", the rest "cancelled")
%     BeforeVerifyFcn  @(destDir), called after a session's files are copied
%                      and before they are verified (for tests)
%
%   R is T with DestDir recomputed from DestRoot and these columns added:
%     CopyStatus    "planned" (dry run) | "copied" | "already_present" |
%                   "skipped" | "failed" | "cancelled"
%     Message       what happened, or why not
%     NumFiles      source files in the session
%     TotalBytes    their total size
%     ManifestFile  session_manifest.json written ("" when none)
%
%   session_manifest.json holds the source and destination paths, the
%   session times, DeltaT, the pairing status, every file's size (and
%   hashes when computed), the copy start / finish times, host name, user
%   name, this function's version and the git commit of this code when git
%   can tell.
%
%   Examples
%     T = findNasSessions("SUBJ-ID-1255", "260916");
%     R = copyNasSessions(T);                                    % dry run
%     R = copyNasSessions(T, DryRun=false, Verify="hash");       % copy
%     R = copyNasSessions(T(3, :), DryRun=false, IncludeUnpaired=true);
%
%   See also findNasSessions.

arguments
    T table
    opts.DestRoot (1,1) string {mustBeNonzeroLengthText} = "D:/EPHYS"
    opts.DryRun (1,1) logical = true
    opts.IfExists (1,1) string {mustBeMember(opts.IfExists, ["skip", "error"])} = "skip"
    opts.IncludeUnpaired (1,1) logical = false
    opts.Verify (1,1) string {mustBeMember(opts.Verify, ["size", "hash"])} = "size"
    opts.ProgressFcn = []
    opts.LogFcn = []
    opts.CancelFcn = []
    opts.BeforeVerifyFcn = []
end

VERSION = "1.0.0";
MANIFEST = "session_manifest.json";
ROBOLOG = "session_copy_robocopy.log";

need = ["Subject", "IntanDir", "IntanTime", "EpsychFile", "EpsychTime", "DeltaT", "Status"];
missing = need(~ismember(need, string(T.Properties.VariableNames)));
if ~isempty(missing)
    error('copyNasSessions:BadTable', 'The session table is missing column(s): %s.', strjoin(missing, ", "));
end

logFcn = opts.LogFcn;
if isempty(logFcn); logFcn = @(msg) fprintf('%s\n', msg); end
progress = @(f, msg) [];
if ~isempty(opts.ProgressFcn); progress = opts.ProgressFcn; end
cancelled = @() false;
if ~isempty(opts.CancelFcn); cancelled = opts.CancelFcn; end

n = height(T);
R = T;
R.Subject = string(R.Subject);
R.IntanDir = string(R.IntanDir);
R.EpsychFile = string(R.EpsychFile);
R.Status = string(R.Status);
R.DestDir = strings(n, 1);
R.CopyStatus = strings(n, 1);
R.Message = strings(n, 1);
R.NumFiles = zeros(n, 1);
R.TotalBytes = zeros(n, 1);
R.ManifestFile = strings(n, 1);

% --- plan: sources, destinations, what each row will do --------------------------
items = cell(n, 1);
subdirs = cell(n, 1);
for r = 1:n
    try
        if R.IntanDir(r) ~= ""
            [~, name] = fileparts(R.IntanDir(r));
        else
            [~, name] = fileparts(R.EpsychFile(r));
        end
        R.DestDir(r) = string(fullfile(opts.DestRoot, R.Subject(r), name));

        st = R.Status(r);
        if st == "ambiguous"
            setRow(r, "skipped", "ambiguous pairing: resolve it by hand, never copied");
            continue
        elseif any(st == ["intan_only", "epsych_only"]) && ~opts.IncludeUnpaired
            setRow(r, "skipped", st + " row (IncludeUnpaired is false)");
            continue
        elseif ~any(st == ["paired", "intan_only", "epsych_only"])
            setRow(r, "skipped", "unknown pairing status """ + st + """");
            continue
        end
        if (st == "paired" && (R.IntanDir(r) == "" || R.EpsychFile(r) == "")) ...
                || (st == "intan_only" && R.IntanDir(r) == "") || (st == "epsych_only" && R.EpsychFile(r) == "")
            setRow(r, "failed", "the row's paths do not match its status " + st);
            continue
        end

        [items{r}, subdirs{r}, err] = listSources(R.IntanDir(r), R.EpsychFile(r), st);
        if err ~= ""
            setRow(r, "failed", err);
            continue
        end
        rel = [items{r}.rel];
        if any(ismember(lower(rel), lower([MANIFEST, ROBOLOG])))
            setRow(r, "failed", "the source holds a file named " + MANIFEST + " or " + ROBOLOG + " at its top level");
            continue
        end
        R.NumFiles(r) = numel(items{r});
        R.TotalBytes(r) = sum([items{r}.bytes]);

        dest = R.DestDir(r);
        if isfile(dest)
            setRow(r, "failed", "the destination is a file: " + dest);
        elseif isfolder(dest) && numel(dir(dest)) > 2
            mode = opts.Verify;
            if opts.DryRun; mode = "size"; end
            [same, why] = verifyItems(items{r}, dest, mode, false);
            if same
                setRow(r, "already_present", "destination already holds an identical copy (" + mode + " check)");
            elseif opts.IfExists == "skip"
                setRow(r, "skipped", "destination exists and differs from the source (" + why + "); nothing overwritten");
            else
                setRow(r, "failed", "destination exists and differs from the source (" + why + "); IfExists is ""error""");
            end
        else
            setRow(r, "planned", sprintf("would copy %d file(s), %s, to %s", R.NumFiles(r), bytesText(R.TotalBytes(r)), dest));
        end
    catch ME
        setRow(r, "failed", "planning failed: " + ME.message);
    end
end

toCopy = find(R.CopyStatus == "planned");
total = sum(R.TotalBytes(toCopy));

% --- free space ------------------------------------------------------------------
if ~isempty(toCopy)
    free = usableBytes(opts.DestRoot);
    if isfinite(free) && total > free
        msg = sprintf("Not enough space under %s: %s to copy, %s free.", opts.DestRoot, bytesText(total), bytesText(free));
        if opts.DryRun
            logFcn("WARNING: " + msg);
            R.Message(toCopy) = R.Message(toCopy) + " (WARNING: not enough free space)";
        else
            error('copyNasSessions:InsufficientSpace', '%s Nothing was copied.', msg);
        end
    end
end

for r = 1:n
    logFcn(sprintf("%s: %s - %s", rowName(r), R.CopyStatus(r), R.Message(r)));
end
if opts.DryRun || isempty(toCopy)
    logFcn(sprintf("%s: %d session(s) to copy (%s).", ternary(opts.DryRun, "Dry run", "Copy"), numel(toCopy), bytesText(total)));
    return
end
if ~ispc
    error('copyNasSessions:NotWindows', 'Copying uses robocopy and needs Windows.');
end

% --- copy ------------------------------------------------------------------------
tool = struct('name', "copyNasSessions", 'version', VERSION, 'gitCommit', gitCommit());
host = hostName();
user = string(getenv('USERNAME'));
if user == ""; user = string(getenv('USER')); end

done = 0;
stop = false;
for r = toCopy.'
    if stop || cancelled()
        stop = true;
        setRow(r, "cancelled", "cancelled before this session started");
        continue
    end
    dest = R.DestDir(r);
    started = datetime('now', 'TimeZone', 'local');
    files = [];
    try
        logFcn(sprintf("Copying %s -> %s", rowName(r), dest));
        makeFolder(dest);
        logFile = fullfile(dest, ROBOLOG);
        for s = subdirs{r}
            makeFolder(fullfile(dest, s));
        end
        it = items{r};
        for k = 1:numel(it)
            if cancelled()
                stop = true;
                break
            end
            progress(min(done / max(total, 1), 1), sprintf("%s: file %d/%d, %s (%s)", ...
                rowName(r), k, numel(it), it(k).rel, bytesText(it(k).bytes)));
            robocopyFile(it(k).src, fullfile(dest, it(k).rel), logFile);
            done = done + it(k).bytes;
        end
        if stop
            setRow(r, "cancelled", "cancelled during the copy; the partial copy is kept in " + dest);
        else
            if ~isempty(opts.BeforeVerifyFcn)
                opts.BeforeVerifyFcn(dest);
            end
            progress(min(done / max(total, 1), 1), sprintf("%s: verifying (%s)", rowName(r), opts.Verify));
            [same, why, files] = verifyItems(it, dest, opts.Verify, true);
            if same
                setRow(r, "copied", sprintf("copied and verified %d file(s), %s (%s check)", ...
                    numel(it), bytesText(R.TotalBytes(r)), opts.Verify));
            else
                setRow(r, "failed", "VERIFICATION FAILED (" + why + "); the partial copy is kept in " + dest);
            end
        end
    catch ME
        setRow(r, "failed", ME.message + " (anything copied is kept in " + dest + ")");
    end

    if isfolder(dest)
        try
            R.ManifestFile(r) = writeManifest(r, dest, started, files);
        catch ME
            R.Message(r) = R.Message(r) + "; manifest not written: " + ME.message;
            if R.CopyStatus(r) == "copied"; R.CopyStatus(r) = "failed"; end
        end
    end
    logFcn(sprintf("%s: %s - %s", rowName(r), R.CopyStatus(r), R.Message(r)));
end
progress(1, "Done.");
counts = arrayfun(@(s) nnz(R.CopyStatus == s), ["copied", "already_present", "skipped", "failed", "cancelled"]);
logFcn(sprintf("Copy finished: %d copied, %d already present, %d skipped, %d failed, %d cancelled.", counts));


    function setRow(r, status, msg)
        R.CopyStatus(r) = status;
        R.Message(r) = string(msg);
    end

    function s = rowName(r)
        s = R.DestDir(r);
        [~, s] = fileparts(s);
    end

    function f = writeManifest(r, dest, started, files)
        if isempty(files)
            files = fileRecords(items{r}, dest);
        end
        isEpsych = [files.isEpsych];
        m = struct();
        m.manifestVersion = 1;
        m.subject = R.Subject(r);
        m.pairingStatus = R.Status(r);
        m.deltaT_s = durSeconds(R.DeltaT(r));
        m.intan = struct('sourceDir', R.IntanDir(r), 'destDir', dest, 'time', isoTime(R.IntanTime(r)), ...
            'files', {num2cell(rmfield(files(~isEpsych), 'isEpsych'))});
        eDest = "";
        if R.EpsychFile(r) ~= ""
            [~, en, ex] = fileparts(R.EpsychFile(r));
            eDest = string(fullfile(dest, en + ex));
        end
        m.epsych = struct('sourceFile', R.EpsychFile(r), 'destFile', eDest, 'time', isoTime(R.EpsychTime(r)), ...
            'files', {num2cell(rmfield(files(isEpsych), 'isEpsych'))});
        m.copy = struct('status', R.CopyStatus(r), 'message', R.Message(r), 'verify', opts.Verify, ...
            'numFiles', R.NumFiles(r), 'totalBytes', int64(R.TotalBytes(r)), ...
            'startedAt', isoTime(started), 'finishedAt', isoTime(datetime('now', 'TimeZone', 'local')), ...
            'host', host, 'user', user, 'robocopyLog', string(fullfile(dest, ROBOLOG)));
        m.tool = tool;
        f = string(fullfile(dest, MANIFEST));
        writeJsonFile(f, m);
    end
end


function [items, subdirs, err] = listSources(intanDir, epsychFile, status)
%listSources  Source files (src, rel, bytes, isEpsych) and Intan subfolders to create.
items = struct('src', {}, 'rel', {}, 'bytes', {}, 'isEpsych', {});
subdirs = strings(1, 0);
err = "";
if status ~= "epsych_only"
    if ~isfolder(intanDir)
        err = "Intan folder not found: " + intanDir + " (is the NAS drive mounted?)";
        return
    end
    D = dir(fullfile(intanDir, '**', '*'));
    top = dir(intanDir);
    base = top(1).folder;   % as dir spells it, so it prefixes every entry's folder
    for k = 1:numel(D)
        if any(strcmp(D(k).name, {'.', '..'})); continue; end
        full = fullfile(D(k).folder, D(k).name);
        rel = string(full(numel(base) + 2:end));
        if D(k).isdir
            subdirs(end+1) = rel; %#ok<AGROW>
        else
            items(end+1) = struct('src', string(full), 'rel', rel, 'bytes', D(k).bytes, 'isEpsych', false); %#ok<AGROW>
        end
    end
    if isempty(items)
        err = "the Intan folder holds no files: " + intanDir;
        return
    end
end
if status ~= "intan_only"
    if ~isfile(epsychFile)
        err = "ePsych file not found: " + epsychFile + " (is the NAS drive mounted?)";
        return
    end
    D = dir(epsychFile);
    [~, n, x] = fileparts(epsychFile);
    rel = n + x;
    if any(strcmpi([items.rel], rel))
        err = "the Intan folder already holds a file named " + rel;
        return
    end
    items(end+1) = struct('src', string(fullfile(D.folder, D.name)), 'rel', rel, 'bytes', D.bytes, 'isEpsych', true);
end
end


function [same, why, files] = verifyItems(items, dest, mode, checkSource)
%verifyItems  Compare source files with their destination copies.
%   SAME is true when every file exists at the destination with the same size
%   (and SHA-256 when MODE is "hash"). CHECKSOURCE also requires each source
%   file still to have the size it was listed with. FILES are the manifest
%   records. Size checks run on every file before any hashing.
files = fileRecords(items, dest);
bad = strings(0, 1);
for k = 1:numel(items)
    s = dir(items(k).src);
    srcBytes = NaN;
    if isscalar(s); srcBytes = s.bytes; end
    if isfinite(srcBytes); files(k).sourceSizeBytes = int64(srcBytes); end
    d = dir(files(k).destination);
    if ~isscalar(d) || d.isdir
        bad(end+1) = items(k).rel + " missing"; %#ok<AGROW>
        continue
    end
    files(k).destSizeBytes = int64(d.bytes);
    if checkSource && srcBytes ~= items(k).bytes
        bad(end+1) = items(k).rel + " changed on the source during the copy"; %#ok<AGROW>
    elseif d.bytes ~= srcBytes
        bad(end+1) = sprintf("%s size %d, source %d", items(k).rel, d.bytes, srcBytes); %#ok<AGROW>
    end
end
if isempty(bad) && mode == "hash"
    for k = 1:numel(items)
        files(k).sha256Source = sha256File(items(k).src);
        files(k).sha256Destination = sha256File(files(k).destination);
        if files(k).sha256Source ~= files(k).sha256Destination
            bad(end+1) = items(k).rel + " SHA-256 differs"; %#ok<AGROW>
        end
    end
end
same = isempty(bad);
why = "";
if ~same
    why = strjoin(bad(1:min(3, end)), "; ");
    if numel(bad) > 3; why = why + sprintf("; and %d more", numel(bad) - 3); end
end
end


function files = fileRecords(items, dest)
files = struct('relativePath', {}, 'source', {}, 'destination', {}, 'sizeBytes', {}, ...
    'sourceSizeBytes', {}, 'destSizeBytes', {}, 'sha256Source', {}, 'sha256Destination', {}, 'isEpsych', {});
for k = 1:numel(items)
    files(k) = struct('relativePath', items(k).rel, 'source', items(k).src, ...
        'destination', string(fullfile(dest, items(k).rel)), 'sizeBytes', int64(items(k).bytes), ...
        'sourceSizeBytes', [], 'destSizeBytes', [], 'sha256Source', "", 'sha256Destination', "", ...
        'isEpsych', items(k).isEpsych);
end
end


function robocopyFile(src, dst, logFile)
%robocopyFile  Copy one file with robocopy; error on exit code 8 or above.
[srcDir, n, x] = fileparts(src);
dstDir = fileparts(dst);
cmd = sprintf('robocopy %s %s %s /Z /R:3 /W:5 /NP /LOG+:%s', ...
    quoteArg(srcDir), quoteArg(dstDir), quoteArg(n + x), quoteArg(logFile));
[code, out] = system(cmd);
if code >= 8
    error('copyNasSessions:RobocopyFailed', 'robocopy failed (exit code %d) for %s: %s', ...
        code, src, lastLines(out, logFile));
end
if ~isfile(dst)
    error('copyNasSessions:RobocopyFailed', 'robocopy reported exit code %d but %s is missing: %s', ...
        code, dst, lastLines(out, logFile));
end
end


function q = quoteArg(p)
%quoteArg  Quote a path for robocopy (native separators; a trailing separator
%   would escape the closing quote, so a drive root becomes "D:\.").
p = strrep(char(p), '/', filesep);
if endsWith(p, filesep); p = [p '.']; end
q = ['"' p '"'];
end


function s = lastLines(out, logFile)
txt = string(out);
if strlength(strtrim(txt)) == 0 && isfile(logFile)
    try txt = string(fileread(logFile)); catch; end
end
lines = strtrim(splitlines(txt));
lines = lines(lines ~= "");
s = strjoin(lines(max(1, end - 5):end), " | ");
end


function makeFolder(p)
if isfolder(p); return; end
[ok, msg] = mkdir(p);
if ~ok
    error('copyNasSessions:CannotCreate', 'Cannot create %s: %s', p, msg);
end
end


function h = sha256File(file)
%sha256File  SHA-256 of a file as lowercase hex, streamed in 64 MB chunks.
fid = fopen(file, 'r');
if fid < 0
    error('copyNasSessions:CannotRead', 'Cannot open %s to hash it.', file);
end
closer = onCleanup(@() fclose(fid));
md = java.security.MessageDigest.getInstance('SHA-256');
while true
    b = fread(fid, 64 * 2^20, '*uint8');
    if isempty(b); break; end
    md.update(typecast(b, 'int8'));
end
h = string(lower(reshape(dec2hex(typecast(md.digest(), 'uint8'), 2).', 1, [])));
end


function b = usableBytes(p)
%usableBytes  Free space available at P, or its nearest existing parent (Inf when unknown).
b = Inf;
p = char(p);
while ~isfolder(p)
    parent = fileparts(p);
    if isempty(parent) || strcmp(parent, p); return; end
    p = parent;
end
try
    b = double(java.io.File(p).getUsableSpace());
    if b <= 0; b = Inf; end   % 0 also means "unknown" to Java
catch
end
end


function c = gitCommit()
c = "";
try
    here = fileparts(mfilename('fullpath'));
    [s, out] = system(sprintf('git -C "%s" rev-parse --short HEAD', here));
    out = strtrim(string(out));
    if s == 0 && ~isempty(regexp(out, '^[0-9a-f]{7,40}$', 'once'))
        c = out;
        [s, dirty] = system(sprintf('git -C "%s" status --porcelain -- "%s"', here, [mfilename('fullpath') '.m']));
        if s == 0 && strlength(strtrim(string(dirty))) > 0
            c = c + " (copyNasSessions.m modified)";
        end
    end
catch
end
end


function h = hostName()
h = string(getenv('COMPUTERNAME'));
if h == ""; h = string(getenv('HOSTNAME')); end
if h == ""
    try h = string(java.net.InetAddress.getLocalHost().getHostName()); catch; end
end
end


function s = isoTime(t)
s = "";
if isdatetime(t) && ~isnat(t)
    if isempty(t.TimeZone)
        s = string(t, 'yyyy-MM-dd''T''HH:mm:ss');
    else
        s = string(t, 'yyyy-MM-dd''T''HH:mm:ssZZZZZ');
    end
end
end


function v = durSeconds(d)
v = [];
if isduration(d) && ~isnan(d); v = seconds(d); end
end


function s = bytesText(b)
units = ["B", "KB", "MB", "GB", "TB"];
k = 1;
while b >= 1024 && k < numel(units)
    b = b / 1024; k = k + 1;
end
if k == 1
    s = sprintf("%d B", b);
else
    s = sprintf("%.1f %s", b, units(k));
end
end


function v = ternary(tf, a, b)
if tf; v = a; else; v = b; end
end
