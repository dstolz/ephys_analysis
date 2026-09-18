function [R, job] = copySessions(T, varargin)
%copySessions  Copy paired source sessions (Intan folder + ePsych file) to local session folders.
%   R = copySessions(T) takes a findCopySessions table and, for each row
%   it is allowed to copy, copies the Intan recording folder's contents and
%   the ePsych .mat (original file name kept) into
%     <DestRoot>/<Subject>/<Intan folder name>/
%   then verifies every file and writes session_manifest.json there. The
%   source is only ever read: nothing in the source tree is modified, renamed,
%   moved or deleted, and no file already in a destination is overwritten
%   unless it is a partial or mismatched copy of its own source (see IfExists).
%
%   THE DEFAULT IS A DRY RUN: pass DryRun=false to copy.
%
%   Which rows are copied
%     paired                     always
%     stitched                   always (see stitchCopySessions and below)
%     intan_only / epsych_only   only with IncludeUnpaired=true (an ePsych-only
%                                row goes to <DestRoot>/<Subject>/<file name without .mat>)
%     ambiguous                  never
%   Pass only the rows you want (e.g. T(sel, :)).
%
%   Stitched rows. The Intan folder is copied as usual, but the row's ePsych
%   files (StitchFiles) are not: they are joined, in chronological order,
%   into one Epsych2 session written as <earliest file name>_stitched.mat
%   (stitchEpsychSessions), so the session folder holds a single behavior
%   file, as for a paired row. Planning (a dry run too) stitches the files in
%   memory, so files that cannot be stitched fail the row before anything is
%   copied. The file is checked right after it is
%   written: it must list the same source file names and sizes and hold as
%   many trials as they do; with Verify="hash" its Data and Info must also
%   equal a fresh stitch of the sources, and the SHA-256 of each source and
%   of the file are recorded. A stitched file that is already there and passes
%   those checks is left as it is rather than written again.
%
%   The copy engine. The copying and the checksumming do not run in MATLAB.
%   copySessions plans the batch, writes it as a job file and launches
%   copy_engine.ps1 (Windows PowerShell, detached), which runs robocopy once
%   per source folder rather than once per file:
%     robocopy <src> <dest> [files] /E /Z /MT:8 /R:3 /W:5 /NP /LOG+:<log>
%   Never /MIR, /MOV or /PURGE, so a file in the destination that is not in
%   the source is left alone; /E keeps empty source subfolders; /Z resumes a
%   partially transferred file; robocopy skips a file that is already there
%   with the same size and timestamp. Exit codes 0-7 are success, 8 and above
%   failure. The robocopy log is session_copy_robocopy.log in the destination.
%   Because the whole folder is handed to robocopy, a file that appears in the
%   source between planning and copying is copied but is not verified or
%   listed in the manifest.
%
%   Background. Copying blocks by default. With Background=true the call
%   returns as soon as the engine is launched, with the rows it is copying
%   marked "copying" and JOB describing the batch; pass JOB back to advance it:
%
%     [R, job] = copySessions(T, DryRun=false, Background=true);
%     while ~job.Done
%         [R, job] = copySessions(job);       % poll: reports progress, no waiting
%     end
%
%   A background job survives this MATLAB session: the engine keeps copying if
%   MATLAB closes, and the partial copy can be completed later (IfExists
%   "resume"). copySessions(job, ...) takes no options: they were fixed when
%   the job was made. Cancel a background job with copySessions(job) after
%   its CancelFcn starts returning true, or by creating job.CancelFile.
%
%   Destination checks. A destination folder that exists and is not empty is
%   compared with the source by size (a checksum is never read at planning
%   time). When every source file is there with the same size, and a stitched
%   row's file passes the checks above, the row is "already_present" and left
%   untouched. Otherwise IfExists decides what happens to the files that are
%   missing or differ:
%     "resume" (default)  complete the copy: robocopy copies the missing files
%                         and finishes or replaces the ones whose size differs,
%                         and everything already correct is left untouched.
%                         The row reports "copied" with how many files it
%                         already held. Files in the destination that are not
%                         in the source are never touched or removed.
%     "skip"              report "skipped" and write nothing
%     "error"             report "failed" and write nothing
%   There is no overwrite option: no destination file is replaced except one
%   whose own source says it is incomplete or different. Before copying, the
%   free space under DestRoot is checked against the total size of the rows to
%   copy; too little space throws copySessions:InsufficientSpace before any
%   file is written (a dry run reports it in the log and Message instead).
%
%   Sessions that are still changing. With MinQuietTime, a row whose source
%   changed more recently than that (any file or folder of the Intan
%   recording, or its ePsych file) is "skipped": it may still be being
%   recorded, or synced to the source, and a later copy takes it. A row
%   whose session folder another batch is writing at that moment (a copy
%   running in this MATLAB, in another one, or a scheduled copy) is "skipped"
%   too, so two copies never write one folder at once. Batches in flight
%   keep a job folder under %LOCALAPPDATA%\ephys_analysis\copy_jobs, which
%   is how they see each other.
%
%   Verification. Once the engine has copied a session, MATLAB checks every
%   file itself: the destination file must have the source's size, and the
%   source must not have changed size since it was listed. With Verify="hash"
%   the engine is then run a second time to take the SHA-256 of every source
%   and destination file, which reads each of them once more, and the two must
%   match. Every file of a session is copied before any of them is checked, so
%   a session that fails verification keeps its whole partial copy and is
%   marked "failed"; the manifest records the sizes and checksums seen.
%
%   Each row is handled on its own so one failure does not stop the batch.
%
%   Options
%     DestRoot         (default "D:/EPHYS")
%     DryRun           (default true) report what would happen, write nothing
%     IfExists         "resume" (default) | "skip" | "error"
%     IncludeUnpaired  (default false)
%     Verify           "size" (default) | "hash" (SHA-256 checksum of each file)
%     MinQuietTime     duration (default 0: off). Skip a row whose source
%                      changed less than this long ago (see above)
%     Background       (default false) return as soon as the engine is launched
%     ProgressFcn      @(fraction, message, info), called as the engine reports
%                      its progress. INFO says what the fraction is made of, so
%                      a caller can show it as more than a percentage: Phase
%                      ("copying" | "verifying" | "stitching" | "done"), Session
%                      (the row of R being worked on, 0 for none), Sessions
%                      ([done total]) and Bytes ([done total] of the batch, each
%                      file counted once)
%     LogFcn           @(message) (default: print it)
%     CancelFcn        @() logical, polled while copying; true stops the batch
%                      (a session being copied keeps what it has and is marked
%                      "cancelled", the rest "cancelled")
%     BeforeVerifyFcn  @(destFile), called for each copied file after its
%                      session is copied and before it is verified (for tests)
%
%   R is T with DestDir recomputed from DestRoot and these columns added:
%     CopyStatus    "planned" (dry run) | "copying" (in flight) | "copied" |
%                   "already_present" | "skipped" | "failed" | "cancelled"
%     Message       what happened, or why not
%     NumFiles      files the session folder receives (a stitched row's
%                   ePsych files count as its one stitched file)
%     TotalBytes    the size of their sources
%     ManifestFile  session_manifest.json written ("" when none)
%
%   JOB describes a batch in flight: Done, State, CancelFile, Result (R) and
%   the plan the engine was given. It is only useful for Background=true.
%
%   session_manifest.json holds the source and destination paths, the
%   session times, DeltaT, the pairing status, every file's size (and
%   hashes when computed), for a stitched row the stitched file and each
%   source ePsych file (epsych.stitch), the copy start / finish times, host
%   name, user name, this function's version and the git commit of this
%   code when git can tell.
%
%   Examples
%     T = findCopySessions("SUBJ-ID-1255", "260916");
%     R = copySessions(T);                                    % dry run
%     R = copySessions(T, DryRun=false, Verify="hash");       % copy
%     R = copySessions(T(3, :), DryRun=false, IncludeUnpaired=true);
%     R = copySessions(stitchCopySessions(T, [1 2]), DryRun=false);
%
%   See also findCopySessions, stitchCopySessions, stitchEpsychSessions,
%   CopySchedule, copy_engine.ps1.

% The options are parsed by copyOptions rather than by an arguments block here:
% the first input is either a session table or a background job, and only an
% untouched varargin says reliably that no options came with a job.
if isstruct(T) && isfield(T, 'IsCopyJob')
    if ~isempty(varargin)
        error('copySessions:JobTakesNoOptions', ...
            'copySessions(job) takes no options: they were fixed when the job was made.');
    end
    job = advance(T);
    R = job.Result;
    return
end
if ~istable(T)
    error('copySessions:BadTable', 'The first input must be a findCopySessions table or a background job.');
end
opts = copyOptions(varargin{:});

job = planBatch(T, opts);
if job.Done
    R = job.Result;
    return
end

if job.CancelFcn()   % already cancelled: do not launch an engine at all
    job.R.CopyStatus(job.ToCopy) = "cancelled";
    job.R.Message(job.ToCopy) = "cancelled before the copy started";
    job.Cancelled = true;
    job = finishBatch(job);
    R = job.Result;
    return
end

startPhase(job, "copy");
job.State = "copying";
job.Launched = tic;
if opts.Background
    R = job.Result;
    return
end

while ~job.Done
    pause(0.1);
    job = advance(job);
end
R = job.Result;
end


function opts = copyOptions(opts)
%copyOptions  Validate and default the name-value options of a new batch.
arguments
    opts.DestRoot (1,1) string {mustBeNonzeroLengthText} = "D:/EPHYS"
    opts.DryRun (1,1) logical = true
    opts.IfExists (1,1) string {mustBeMember(opts.IfExists, ["resume", "skip", "error"])} = "resume"
    opts.IncludeUnpaired (1,1) logical = false
    opts.Verify (1,1) string {mustBeMember(opts.Verify, ["size", "hash"])} = "size"
    opts.MinQuietTime (1,1) duration = seconds(0)
    opts.Background (1,1) logical = false
    opts.ProgressFcn = []
    opts.LogFcn = []
    opts.CancelFcn = []
    opts.BeforeVerifyFcn = []
end
end


% =============================================================================
% planning
% =============================================================================

function job = planBatch(T, opts)
%planBatch  Decide what every row will do and build the engine's job spec.
MANIFEST = "session_manifest.json";
ROBOLOG = "session_copy_robocopy.log";

need = ["Subject", "IntanDir", "IntanTime", "EpsychFile", "EpsychTime", "DeltaT", "Status", "StitchFiles"];
missing = need(~ismember(need, string(T.Properties.VariableNames)));
if ~isempty(missing)
    error('copySessions:BadTable', 'The session table is missing column(s): %s.', strjoin(missing, ", "));
end

job = struct();
job.IsCopyJob = true;
job.Opts = opts;
job.Manifest = MANIFEST;
job.Robolog = ROBOLOG;
job.Version = "2.0.0";
job.State = "planning";
job.Done = false;
job.Dir = "";
job.CancelFile = "";
job.Pos = 0;
job.Cancelled = false;
job.Started = datetime('now', 'TimeZone', 'local');
job.LogFcn = opts.LogFcn;
if isempty(job.LogFcn); job.LogFcn = @(msg) fprintf('%s\n', msg); end
job.ProgressFcn = opts.ProgressFcn;
if isempty(job.ProgressFcn); job.ProgressFcn = @(f, msg, info) []; end
job.CancelFcn = opts.CancelFcn;
if isempty(job.CancelFcn); job.CancelFcn = @() false; end

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

items = cell(n, 1);
subdirs = cell(n, 1);
stitches = cell(n, 1);
groups = cell(n, 1);
present = zeros(n, 1);       % files already correct in the destination
wasPresent = false(n, 1);    % every file was already there

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
            [R.CopyStatus(r), R.Message(r)] = deal("skipped", "ambiguous pairing: resolve it by hand, never copied");
            continue
        elseif any(st == ["intan_only", "epsych_only"]) && ~opts.IncludeUnpaired
            [R.CopyStatus(r), R.Message(r)] = deal("skipped", st + " row (IncludeUnpaired is false)");
            continue
        elseif ~any(st == ["paired", "stitched", "intan_only", "epsych_only"])
            [R.CopyStatus(r), R.Message(r)] = deal("skipped", "unknown pairing status """ + st + """");
            continue
        end
        parts = string(R.StitchFiles{r});
        if (st == "paired" && (R.IntanDir(r) == "" || R.EpsychFile(r) == "")) ...
                || (st == "stitched" && (R.IntanDir(r) == "" || numel(parts) < 2)) ...
                || (st == "intan_only" && R.IntanDir(r) == "") || (st == "epsych_only" && R.EpsychFile(r) == "")
            [R.CopyStatus(r), R.Message(r)] = deal("failed", "the row's paths do not match its status " + st);
            continue
        end

        [items{r}, subdirs{r}, stitches{r}, groups{r}, err] = listSources(R.IntanDir(r), R.EpsychFile(r), parts, st);
        if err ~= ""
            [R.CopyStatus(r), R.Message(r)] = deal("failed", err);
            continue
        end
        rel = [items{r}.rel];
        if any(ismember(lower(rel), lower([MANIFEST, ROBOLOG])))
            [R.CopyStatus(r), R.Message(r)] = deal("failed", ...
                "the source holds a file named " + MANIFEST + " or " + ROBOLOG + " at its top level");
            continue
        end
        R.NumFiles(r) = numel(items{r}) + ~isempty(stitches{r});
        R.TotalBytes(r) = sum([items{r}.bytes]);
        if ~isempty(stitches{r})
            R.TotalBytes(r) = R.TotalBytes(r) + sum(stitches{r}.bytes);
        end
        if opts.MinQuietTime > 0
            % a source clock ahead of this one reads as "just now"
            age = max(seconds(0), datetime('now') - sourceChanged(items{r}, subdirs{r}, groups{r}, stitches{r}));
            if age < opts.MinQuietTime   % false for an unknown (NaT) time
                [R.CopyStatus(r), R.Message(r)] = deal("skipped", sprintf( ...
                    "the source changed %s ago, within the %s quiet time (still being written?); left for a later copy", ...
                    durationText(age), durationText(opts.MinQuietTime)));
                continue
            end
        end
        if ~isempty(stitches{r})
            try
                stitchEpsychSessions(parts);   % in memory: a preview reports files that cannot be stitched
            catch ME
                [R.CopyStatus(r), R.Message(r)] = deal("failed", "the ePsych files cannot be stitched: " + ME.message);
                continue
            end
        end

        dest = R.DestDir(r);
        if isfile(dest)
            [R.CopyStatus(r), R.Message(r)] = deal("failed", "the destination is a file: " + dest);
            continue
        end
        if ~isfolder(dest) || numel(dir(dest)) <= 2
            [R.CopyStatus(r), R.Message(r)] = deal("planned", ...
                plannedMessage(items{r}, stitches{r}, parts, R.NumFiles(r), R.TotalBytes(r), dest));
            continue
        end

        % The destination exists: compare it with the source by size only.
        [same, why, ~, nOK] = verifySizes(items{r}, dest, false);
        present(r) = nOK;
        if same && ~isempty(stitches{r})
            [same, why] = verifyStitch(stitches{r}, dest, "size", false);
        end
        if same
            wasPresent(r) = true;
            if opts.Verify == "size" || opts.DryRun
                [R.CopyStatus(r), R.Message(r)] = deal("already_present", ...
                    "destination already holds an identical copy (size check)");
            else
                % Nothing to copy, but the checksums still have to be taken.
                [R.CopyStatus(r), R.Message(r)] = deal("planned", ...
                    "destination already holds every file; checking their SHA-256");
            end
        elseif opts.IfExists == "resume"
            [R.CopyStatus(r), R.Message(r)] = deal("planned", sprintf( ...
                "would complete a partial copy in %s: %d of %d file(s) already there (%s)", ...
                dest, nOK, numel(items{r}), why));
        elseif opts.IfExists == "skip"
            [R.CopyStatus(r), R.Message(r)] = deal("skipped", ...
                "destination exists and differs from the source (" + why + "); nothing overwritten");
        else
            [R.CopyStatus(r), R.Message(r)] = deal("failed", ...
                "destination exists and differs from the source (" + why + "); IfExists is ""error""");
        end
    catch ME
        [R.CopyStatus(r), R.Message(r)] = deal("failed", "planning failed: " + ME.message);
    end
end

% --- session folders another batch is writing now ------------------------------------
planned = find(R.CopyStatus == "planned");
if ~isempty(planned)
    busy = sessionsInFlight();
    for r = planned.'
        k = find(busy.Dest == normPath(R.DestDir(r)), 1);
        if ~isempty(k)
            [R.CopyStatus(r), R.Message(r)] = deal("skipped", ...
                "another copy (started " + busy.Started(k) + ") is writing this session now; left for a later copy");
        end
    end
end

job.R = R;
job.Items = items;
job.Subdirs = subdirs;
job.Stitches = stitches;
job.Groups = groups;
job.Files = cell(n, 1);
job.StitchRecs = cell(n, 1);
job.Hashes = struct('index', {}, 'rel', {}, 'src', {}, 'dst', {}, 'err', {});
job.Errors = struct('index', {}, 'message', {});
job.Launched = tic;
job.Present = present;
job.WasPresent = wasPresent;
job.ToCopy = find(R.CopyStatus == "planned");
job.SessionNow = 0;      % row of R the engine is working on (0: none yet)
job.SessionsDone = 0;    % sessions it has finished in this phase
job.PhaseBytes = 0;      % bytes of the batch it has copied (or checksummed) in this phase
job.Total = sum(R.TotalBytes(job.ToCopy));
job.Work = max(job.Total * (1 + 2 * (opts.Verify == "hash")), 1);
job.BytesBase = 0;
job.Result = R;

% --- free space ------------------------------------------------------------------
if ~isempty(job.ToCopy)
    free = usableBytes(opts.DestRoot);
    if isfinite(free) && job.Total > free
        msg = sprintf("Not enough space under %s: %s to copy, %s free.", ...
            opts.DestRoot, bytesText(job.Total), bytesText(free));
        if opts.DryRun
            job.LogFcn("WARNING: " + msg);
            job.R.Message(job.ToCopy) = job.R.Message(job.ToCopy) + " (WARNING: not enough free space)";
        else
            error('copySessions:InsufficientSpace', '%s Nothing was copied.', msg);
        end
    end
end

for r = 1:n
    job.LogFcn(sprintf("%s: %s - %s", rowName(job.R, r), job.R.CopyStatus(r), job.R.Message(r)));
end
if opts.DryRun || isempty(job.ToCopy)
    job.LogFcn(sprintf("%s: %d session(s) to copy (%s).", ...
        ternary(opts.DryRun, "Dry run", "Copy"), numel(job.ToCopy), bytesText(job.Total)));
    job.Done = true;
    job.State = "done";
    job.Result = job.R;
    return
end
if ~ispc
    error('copySessions:NotWindows', 'Copying uses robocopy and needs Windows.');
end

pruneJobFolders();
job.Dir = string(tempname(char(jobsFolder())));
makeFolder(job.Dir);
job.CancelFile = fullfile(job.Dir, "cancel.flag");
job.R.CopyStatus(job.ToCopy) = "copying";
job.R.Message(job.ToCopy) = "copying...";
job.Result = job.R;
end


function msg = plannedMessage(items, stitch, parts, nFiles, nBytes, dest)
if isempty(stitch)
    msg = sprintf("would copy %d file(s), %s, to %s", nFiles, bytesText(nBytes), dest);
else
    msg = sprintf("would copy %d file(s) and stitch %d ePsych files into %s, %s, to %s", ...
        numel(items), numel(parts), stitch.rel, bytesText(nBytes), dest);
end
end


% =============================================================================
% the engine
% =============================================================================

function startPhase(job, phase)
%startPhase  Write the job spec for PHASE and launch copy_engine.ps1 detached.
sessions = cell(1, 0);
for r = job.ToCopy.'
    if job.R.CopyStatus(r) ~= "copying"; continue; end
    it = job.Items{r};
    expect = cell(1, numel(it));
    for k = 1:numel(it)
        expect{k} = struct('rel', it(k).rel, 'src', it(k).src, 'bytes', it(k).bytes);
    end
    g = job.Groups{r};
    grp = cell(1, numel(g));
    for k = 1:numel(g)
        grp{k} = struct('src', g(k).src, 'recurse', g(k).recurse, 'files', {cellRow(g(k).files)});
    end
    sessions{end+1} = struct('index', r, 'dest', job.R.DestDir(r), ...
        'log', string(fullfile(job.R.DestDir(r), job.Robolog)), ...
        'subdirs', {cellRow(job.Subdirs{r})}, 'groups', {grp}, 'expect', {expect}); %#ok<AGROW>
end
spec = struct('version', 1, 'verify', job.Opts.Verify, ...
    'started', string(job.Started, 'yyyy-MM-dd HH:mm'), 'pid', feature('getpid'), ...
    'progressFile', phaseFile(job, phase, "progress.jsonl"), ...
    'statusFile', phaseFile(job, phase, "status.json"), ...
    'heartbeatFile', phaseFile(job, phase, "heartbeat"), ...
    'cancelFile', job.CancelFile, 'sessions', {sessions});
specFile = phaseFile(job, phase, "job.json");
writeJsonFile(specFile, spec);

here = fileparts(mfilename('fullpath'));
engine = fullfile(here, 'copy_engine.ps1');
if ~isfile(engine)
    error('copySessions:EngineMissing', 'The copy engine is missing: %s', engine);
end
cmd = sprintf('start "copySessions" /b powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%s" -Job "%s" -Phase %s', ...
    engine, specFile, phase);
status = system(cmd);
if status ~= 0
    error('copySessions:EngineLaunchFailed', ...
        'Could not launch the copy engine (exit code %d): %s', status, cmd);
end
end


function f = phaseFile(job, phase, name)
f = string(fullfile(job.Dir, phase + "_" + name));
end


function c = cellRow(s)
%cellRow  A 1xN cell of char, so jsonencode always writes a JSON array.
s = string(s(:)).';
c = cell(1, numel(s));
for k = 1:numel(s)
    c{k} = char(s(k));
end
end


function job = advance(job)
%advance  One step of a batch in flight: drain the engine's events, and when a
%   phase is over verify it, stitch, start the next phase or finish.
if job.Done; return; end

if ~job.Cancelled && job.CancelFcn()
    job = cancelJob(job);
end

phase = ternary(job.State == "hashing", "hash", "copy");
job = drainEvents(job, phase);

statusFile = phaseFile(job, phase, "status.json");
if ~isfile(statusFile)
    quiet = engineSilentFor(job, phase);
    if quiet > seconds(120)
        job = failBatch(job, sprintf( ...
            "the copy engine stopped responding (nothing for %.0f s); anything copied is kept", seconds(quiet)));
    end
    return
end
S = readEngineStatus(statusFile);
job = drainEvents(job, phase);   % anything written between the last read and the status file

if S.state == "error"
    job = failBatch(job, "the copy engine failed: " + S.message);
    return
end
if S.state == "cancelled"; job.Cancelled = true; end

if phase == "copy"
    job = finishCopyPhase(job);
    if ~job.Done && job.Opts.Verify == "hash" && any(job.R.CopyStatus == "copying")
        job.BytesBase = job.Total;
        job.Pos = 0;
        job.SessionsDone = 0;
        job.PhaseBytes = 0;
        startPhase(job, "hash");
        job.State = "hashing";
        job.Launched = tic;
        return
    end
    job = finishBatch(job);
else
    job = finishHashPhase(job);
    job = finishBatch(job);
end
end


function job = drainEvents(job, phase)
%drainEvents  Read new JSON lines from the engine's progress file.
%   Only whole lines are consumed; a partial trailing line waits for the next
%   poll. Sizes and checksums are kept per session; everything else is progress.
%   "file" events arrive once a session's robocopy is over, so the percentage
%   between them comes from the engine's "progress" events.
f = phaseFile(job, phase, "progress.jsonl");
if ~isfile(f); return; end
fid = fopen(f, 'r');
if fid < 0; return; end
try
    fseek(fid, job.Pos, 'bof');
    chunk = fread(fid, inf, '*char').';
catch
    fclose(fid);
    return
end
fclose(fid);
nl = find(chunk == newline, 1, 'last');
if isempty(nl); return; end
job.Pos = job.Pos + nl;

lines = splitlines(string(chunk(1:nl)));
lines = strtrim(lines(strlength(strtrim(lines)) > 0));
weight = ternary(phase == "hash", 2, 1);
phaseName = ternary(phase == "hash", "verifying", "copying");
for k = 1:numel(lines)
    try
        e = jsondecode(lines(k));
    catch
        continue
    end
    if ~isfield(e, 'event'); continue; end
    switch string(e.event)
        case "session"
            switch string(e.state)
                case "copying"
                    job.SessionNow = e.index;
                    job.ProgressFcn(min(job.BytesBase / job.Work, 1), sprintf("%s: copying %d file(s), %s", ...
                        rowName(job.R, e.index), e.files, bytesText(e.bytes)), ...
                        progressInfo(job, phaseName, [0 e.bytes]));
                case "hashing"
                    job.SessionNow = e.index;
                    job.ProgressFcn(min(job.BytesBase / job.Work, 1), sprintf("%s: SHA-256 checksum of %d file(s)", ...
                        rowName(job.R, e.index), e.files), progressInfo(job, phaseName));
                case "cancelled"
                    job.SessionsDone = job.SessionsDone + 1;
                    job.Errors(end+1) = struct('index', e.index, 'message', "cancelled");
                case "done"
                    job.SessionsDone = job.SessionsDone + 1;
                    if isfield(e, 'error') && strlength(string(e.error)) > 0
                        job.Errors(end+1) = struct('index', e.index, 'message', string(e.error));
                    end
            end
        case "progress"
            % Where the engine has got to inside a session: the destination
            % files sized while robocopy runs, or how far a SHA-256 has read.
            % Without it the percentage would only move between sessions.
            done = job.BytesBase + weight * e.bytesDone;
            job.SessionNow = e.index;
            job.PhaseBytes = e.bytesDone;
            if isfield(e, 'rel')
                msg = sprintf("%s: SHA-256 of %s, %s of %s", rowName(job.R, e.index), e.rel, ...
                    bytesText(e.bytes), bytesText(e.bytesTotal));
            else
                msg = sprintf("%s: %d of %d file(s), %s of %s", rowName(job.R, e.index), ...
                    e.files, e.filesTotal, bytesText(e.bytes), bytesText(e.bytesTotal));
            end
            job.ProgressFcn(min(done / job.Work, 1), msg, progressInfo(job, phaseName, [e.bytes e.bytesTotal]));
        case "robocopy"
            if e.exit >= 8
                job.LogFcn(sprintf("%s: robocopy exit code %d", rowName(job.R, e.index), e.exit));
            end
        case "file"
            done = job.BytesBase + weight * e.bytesDone;
            job.SessionNow = e.index;
            job.PhaseBytes = e.bytesDone;
            job.ProgressFcn(min(done / job.Work, 1), sprintf("%s: %s", rowName(job.R, e.index), e.rel), ...
                progressInfo(job, phaseName));
            if isfield(e, 'sha256Source')
                err = "";
                if isfield(e, 'hashError'); err = string(e.hashError); end
                job.Hashes(end+1) = struct('index', e.index, 'rel', string(e.rel), ...
                    'src', string(e.sha256Source), 'dst', string(e.sha256Destination), 'err', err);
            end
    end
end
end


function d = engineSilentFor(job, phase)
%engineSilentFor  How long since the engine last said anything.
%   The engine beats every couple of seconds, including while robocopy is
%   working on one big file, so a stale beat means it is gone rather than busy.
hb = phaseFile(job, phase, "heartbeat");
info = dir(hb);
if isscalar(info)
    d = max(seconds(0), datetime('now') - datetime(info.datenum, 'ConvertFrom', 'datenum'));
else
    d = seconds(toc(job.Launched));   % it has not started yet
end
end


function S = readEngineStatus(f)
S = struct('state', "error", 'message', "the engine's status file cannot be read");
last = "";
for k = 1:5   % it may be caught mid-write
    try
        s = jsondecode(stripBOM(fileread(f)));
        S.state = string(s.state);
        S.message = string(s.message);
        return
    catch ME
        last = string(ME.message);
        pause(0.05);
    end
end
if last ~= ""; S.message = S.message + ": " + last; end
end


function txt = stripBOM(txt)
%stripBOM  Drop a leading byte-order mark, which jsondecode refuses.
if ~isempty(txt) && double(txt(1)) == 65279
    txt(1) = [];
end
end


% =============================================================================
% finishing a phase
% =============================================================================

function job = finishCopyPhase(job)
%finishCopyPhase  Check the sizes of everything the engine copied and stitch.
for r = job.ToCopy.'
    if job.R.CopyStatus(r) ~= "copying"; continue; end
    dest = job.R.DestDir(r);
    why = engineError(job, r);
    if why == "cancelled"
        job.R.CopyStatus(r) = "cancelled";
        job.R.Message(r) = "cancelled during the copy; the partial copy is kept in " + dest;
        continue
    end
    try
        it = job.Items{r};
        if ~isempty(job.Opts.BeforeVerifyFcn)
            for k = 1:numel(it)
                job.Opts.BeforeVerifyFcn(string(fullfile(dest, it(k).rel)));
            end
        end
        if why == ""
            [~, why, files] = verifySizes(it, dest, true);
        else
            files = fileRecords(it, dest);
        end
        job.Files{r} = files;
        if why ~= ""
            job.R.CopyStatus(r) = "failed";
            job.R.Message(r) = "VERIFICATION FAILED (" + why + "); the partial copy is kept in " + dest;
            continue
        end
        stitch = job.Stitches{r};
        if ~isempty(stitch)
            job = stitchInto(job, r, dest, stitch);
        end
    catch ME
        job.R.CopyStatus(r) = "failed";
        job.R.Message(r) = ME.message + " (anything copied is kept in " + dest + ")";
    end
end
job.Result = job.R;
end


function job = stitchInto(job, r, dest, stitch)
%stitchInto  Write the row's stitched ePsych file unless a good one is there.
out = string(fullfile(dest, stitch.rel));
[ok, ~] = verifyStitch(stitch, dest, "size", false);
if ~ok
    job.SessionNow = r;
    job.ProgressFcn(min(job.BytesBase / job.Work, 1), sprintf("%s: stitching %d ePsych files into %s", ...
        rowName(job.R, r), numel(stitch.files), stitch.rel), progressInfo(job, "stitching"));
    stitchEpsychSessions(stitch.files, OutFile=out);
end
if ~isempty(job.Opts.BeforeVerifyFcn)
    job.Opts.BeforeVerifyFcn(out);
end
[~, why, rec] = verifyStitch(stitch, dest, job.Opts.Verify, true);
job.StitchRecs{r} = rec;
if why ~= ""
    job.R.CopyStatus(r) = "failed";
    job.R.Message(r) = "VERIFICATION FAILED (" + why + "); the partial copy is kept in " + dest;
end
end


function job = finishHashPhase(job)
%finishHashPhase  Compare the SHA-256 the engine took of each source and copy.
for r = job.ToCopy.'
    if job.R.CopyStatus(r) ~= "copying"; continue; end
    dest = job.R.DestDir(r);
    why = engineError(job, r);
    if why == "cancelled"
        job.R.CopyStatus(r) = "cancelled";
        job.R.Message(r) = "cancelled while checksumming; the copy is kept in " + dest;
        continue
    end
    files = job.Files{r};
    bad = strings(0, 1);
    for k = 1:numel(files)
        h = findHash(job, r, files(k).relativePath);
        if isempty(h)
            bad(end+1) = files(k).relativePath + " was not checksummed"; %#ok<AGROW>
            continue
        end
        files(k).sha256Source = h.src;
        files(k).sha256Destination = h.dst;
        if h.src == "" || h.dst == ""
            bad(end+1) = files(k).relativePath + " could not be read to checksum it" ...
                + ternary(h.err == "", "", " (" + h.err + ")"); %#ok<AGROW>
        elseif h.src ~= h.dst
            bad(end+1) = files(k).relativePath + " SHA-256 differs"; %#ok<AGROW>
        end
    end
    job.Files{r} = files;
    if ~isempty(bad)
        why = strjoin(bad(1:min(3, end)), "; ");
        if numel(bad) > 3; why = why + sprintf("; and %d more", numel(bad) - 3); end
        job.R.CopyStatus(r) = "failed";
        job.R.Message(r) = "VERIFICATION FAILED (" + why + "); the copy is kept in " + dest;
    end
end
job.Result = job.R;
end


function h = findHash(job, r, rel)
h = [];
if isempty(job.Hashes); return; end
ix = find([job.Hashes.index] == r & [job.Hashes.rel] == rel, 1, 'last');
if ~isempty(ix); h = job.Hashes(ix); end
end


function why = engineError(job, r)
why = "";
if isempty(job.Errors); return; end
ix = find([job.Errors.index] == r, 1, 'last');
if ~isempty(ix); why = job.Errors(ix).message; end
end


function job = finishBatch(job)
%finishBatch  Set every row's final status, write the manifests and clean up.
tool = struct('name', "copySessions", 'version', job.Version, 'gitCommit', gitCommit());
host = hostName();
user = string(getenv('USERNAME'));
if user == ""; user = string(getenv('USER')); end

rows = union(job.ToCopy(:).', find(job.R.CopyStatus == "already_present").');
for r = rows
    dest = job.R.DestDir(r);
    if job.R.CopyStatus(r) == "already_present" && isfile(fullfile(dest, job.Manifest))
        continue   % it already has its manifest; do not replace a fuller one
    end
    if job.R.CopyStatus(r) == "copying"
        it = job.Items{r};
        stitch = job.Stitches{r};
        if job.WasPresent(r)
            job.R.CopyStatus(r) = "already_present";
            job.R.Message(r) = "destination already held an identical copy (hash check)";
        elseif isempty(stitch)
            job.R.CopyStatus(r) = "copied";
            job.R.Message(r) = sprintf("copied and verified %d file(s), %s (%s check of each file)%s", ...
                numel(it), bytesText(job.R.TotalBytes(r)), job.Opts.Verify, resumeNote(job, r, numel(it)));
        else
            rec = job.StitchRecs{r};
            nTrials = NaN;
            if ~isempty(rec); nTrials = rec.nTrials; end
            job.R.CopyStatus(r) = "copied";
            job.R.Message(r) = sprintf( ...
                "copied and verified %d file(s) and stitched %d ePsych files (%d trials) into %s, %s (%s check of each file)%s", ...
                numel(it), numel(stitch.files), nTrials, stitch.rel, bytesText(job.R.TotalBytes(r)), ...
                job.Opts.Verify, resumeNote(job, r, numel(it)));
        end
    end
    if isfolder(dest)
        try
            job.R.ManifestFile(r) = writeManifest(job, r, dest, tool, host, user);
        catch ME
            job.R.Message(r) = job.R.Message(r) + "; manifest not written: " + ME.message;
            if job.R.CopyStatus(r) == "copied"; job.R.CopyStatus(r) = "failed"; end
        end
    end
    if ismember(r, job.ToCopy)   % the others were reported when the batch was planned
        job.LogFcn(sprintf("%s: %s - %s", rowName(job.R, r), job.R.CopyStatus(r), job.R.Message(r)));
    end
end

job.SessionNow = 0;
job.SessionsDone = numel(job.ToCopy);
job.PhaseBytes = job.Total;
job.ProgressFcn(1, "Done.", progressInfo(job, "done"));
counts = arrayfun(@(s) nnz(job.R.CopyStatus == s), ["copied", "already_present", "skipped", "failed", "cancelled"]);
job.LogFcn(sprintf("Copy finished: %d copied, %d already present, %d skipped, %d failed, %d cancelled.", counts));

if job.Dir ~= "" && isfolder(job.Dir)
    try rmdir(job.Dir, 's'); catch; end
end
job.Done = true;
job.State = "done";
job.Result = job.R;
end


function s = resumeNote(job, r, nFiles)
s = "";
if job.Present(r) > 0 && job.Present(r) < nFiles
    s = sprintf("; %d of them were already there", job.Present(r));
end
end


function job = cancelJob(job)
%cancelJob  Ask the engine to stop between files; it keeps what it has copied.
job.Cancelled = true;
if job.CancelFile ~= "" && ~isfile(job.CancelFile)
    try
        fid = fopen(job.CancelFile, 'w');
        if fid >= 0; fclose(fid); end
    catch
    end
end
end


function job = failBatch(job, why)
%failBatch  The engine itself failed: every session still in flight fails.
in = job.R.CopyStatus == "copying";
job.R.CopyStatus(in) = "failed";
job.R.Message(in) = why;
job = finishBatch(job);
end


% =============================================================================
% the plan of one row
% =============================================================================

function [items, subdirs, stitch, groups, err] = listSources(intanDir, epsychFile, stitchFiles, status)
%listSources  Source files (src, rel, bytes, isEpsych), Intan subfolders to create,
%   the stitch to write for a stitched row ([] otherwise), and the robocopy
%   groups (one source folder each) that copy them.
items = struct('src', {}, 'rel', {}, 'bytes', {}, 'isEpsych', {});
subdirs = strings(1, 0);
groups = struct('src', {}, 'recurse', {}, 'files', {});
stitch = [];
err = "";
if status ~= "epsych_only"
    if ~isfolder(intanDir)
        err = "Intan folder not found: " + intanDir + " (is the source drive mounted?)";
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
    groups(end+1) = struct('src', string(base), 'recurse', true, 'files', strings(1, 0));
end
if status == "stitched"
    bytes = zeros(numel(stitchFiles), 1);
    for k = 1:numel(stitchFiles)
        if ~isfile(stitchFiles(k))
            err = "ePsych file not found: " + stitchFiles(k) + " (is the source drive mounted?)";
            return
        end
        D = dir(stitchFiles(k));
        bytes(k) = D.bytes;
    end
    [~, n] = fileparts(stitchFiles(1));
    rel = n + "_stitched.mat";
    if any(strcmpi([items.rel], rel))
        err = "the Intan folder already holds a file named " + rel;
        return
    end
    stitch = struct('rel', rel, 'files', stitchFiles(:), 'bytes', bytes);
elseif status ~= "intan_only"
    if ~isfile(epsychFile)
        err = "ePsych file not found: " + epsychFile + " (is the source drive mounted?)";
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
    groups(end+1) = struct('src', string(D.folder), 'recurse', false, 'files', string(rel));
end
end


function t = sourceChanged(items, subdirs, groups, stitch)
%sourceChanged  When a row's sources last changed (NaT when unknown).
%   The newest of its files and folders: a folder changes when a file is
%   added to it or taken out, even when the file itself keeps an old time
%   (a sync that restores times). Each one is asked for its own time; a
%   folder listing reports what the folder last noted for its entries,
%   which lags behind a folder that changed, and can lag behind a file
%   that is still being written.
paths = [items.src];
if ~isempty(groups) && groups(1).recurse   % the Intan folder and its subfolders
    paths = [paths, groups(1).src, groups(1).src + filesep + subdirs];
end
if ~isempty(stitch)
    paths = [paths, stitch.files(:).'];
end
ms = 0;
for p = paths
    ms = max(ms, double(java.io.File(char(p)).lastModified()));   % 0 when it cannot be read
end
t = NaT;
if ms > 0
    t = datetime(ms / 1000, 'ConvertFrom', 'posixtime', 'TimeZone', 'local');
    t.TimeZone = '';
end
end


% =============================================================================
% verification
% =============================================================================

function [same, why, files, nOK] = verifySizes(items, dest, checkSource)
%verifySizes  Compare source files with their destination copies by size.
%   SAME is true when every file is there with the size it was listed with.
%   CHECKSOURCE also requires each source file still to have that size.
%   FILES are the manifest records and NOK the number of files already correct.
files = fileRecords(items, dest);
bad = strings(0, 1);
nOK = 0;
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
    else
        nOK = nOK + 1;
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


function [same, why, rec] = verifyStitch(stitch, dest, mode, checkSource)
%verifyStitch  Check a stitched ePsych file against the ePsych files it is made from.
%   SAME is true when the file exists, its Info.Stitch.Parts list the same
%   source file names with their current sizes, and it holds as many trials
%   as those parts. CHECKSOURCE also requires each source still to have the
%   size it was listed with. With MODE "hash" its Data and Info must equal a
%   fresh stitch of the sources (apart from Stitch.Created and the source
%   paths), and the SHA-256 of the sources and of the file are recorded.
%   REC is the manifest record.
rec = stitchRecord(stitch, dest);
bad = strings(0, 1);
for k = 1:numel(stitch.files)
    s = dir(stitch.files(k));
    if ~isscalar(s)
        bad(end+1) = rec.parts(k).name + " missing on the source"; %#ok<AGROW>
        continue
    end
    rec.parts(k).sourceSizeBytes = int64(s.bytes);
    if checkSource && s.bytes ~= stitch.bytes(k)
        bad(end+1) = rec.parts(k).name + " changed on the source during the copy"; %#ok<AGROW>
    end
end
if ~isfile(rec.file)
    bad(end+1) = stitch.rel + " missing";
elseif isempty(bad)
    try
        d = dir(rec.file);
        rec.sizeBytes = int64(d.bytes);
        L = load(rec.file, 'Info');
        P = L.Info.Stitch.Parts;
        w = whos('-file', rec.file, 'Data');
        [found, loc] = ismember([rec.parts.name], string({P.Name}));
        if numel(P) ~= numel(stitch.files) || ~all(found) ...
                || ~isequal([P(loc).Bytes], double([rec.parts.sourceSizeBytes]))
            bad(end+1) = stitch.rel + " was stitched from other ePsych files or other versions of them";
        elseif prod(w.size) ~= sum([P.NTrials])
            bad(end+1) = sprintf("%s holds %d trials, its parts %d", stitch.rel, prod(w.size), sum([P.NTrials]));
        else
            rec.nTrials = prod(w.size);
            nt = num2cell([P(loc).NTrials]);
            [rec.parts.nTrials] = nt{:};
            if mode == "hash"
                L = load(rec.file, 'Data', 'Info');
                [D2, I2] = stitchEpsychSessions(stitch.files);
                if ~isequaln(L.Data, D2) || ~isequaln(comparableInfo(L.Info), comparableInfo(I2))
                    bad(end+1) = stitch.rel + " differs from a fresh stitch of its ePsych files";
                end
                for k = 1:numel(stitch.files)
                    rec.parts(k).sha256Source = sha256File(stitch.files(k));
                end
                rec.sha256 = sha256File(rec.file);
            end
        end
    catch ME
        bad(end+1) = stitch.rel + " cannot be read as a stitched ePsych file: " + ME.message;
    end
end
same = isempty(bad);
why = "";
if ~same; why = strjoin(bad, "; "); end
end


function rec = stitchRecord(stitch, dest)
%stitchRecord  Manifest record of a stitched ePsych file and its source files.
parts = struct('source', {}, 'name', {}, 'sizeBytes', {}, 'sourceSizeBytes', {}, 'nTrials', {}, 'sha256Source', {});
for k = 1:numel(stitch.files)
    [~, n, x] = fileparts(stitch.files(k));
    parts(k) = struct('source', stitch.files(k), 'name', n + x, 'sizeBytes', int64(stitch.bytes(k)), ...
        'sourceSizeBytes', [], 'nTrials', [], 'sha256Source', "");
end
rec = struct('file', string(fullfile(dest, stitch.rel)), 'sizeBytes', [], 'nTrials', [], 'sha256', "", ...
    'parts', parts);
end


function I = comparableInfo(I)
%comparableInfo  A stitched Info without what differs between two stitches of the same files.
I.Stitch = rmfield(I.Stitch, 'Created');
I.Stitch.Parts = rmfield(I.Stitch.Parts, 'File');
end


% =============================================================================
% the manifest
% =============================================================================

function f = writeManifest(job, r, dest, tool, host, user)
R = job.R;
files = job.Files{r};
if isempty(files)
    files = fileRecords(job.Items{r}, dest);
end
isEpsych = [files.isEpsych];
m = struct();
m.manifestVersion = 2;
m.subject = R.Subject(r);
m.pairingStatus = R.Status(r);
m.deltaT_s = durSeconds(R.DeltaT(r));
m.intan = struct('sourceDir', R.IntanDir(r), 'destDir', dest, 'time', isoTime(R.IntanTime(r)), ...
    'files', {num2cell(rmfield(files(~isEpsych), 'isEpsych'))});
eSource = R.EpsychFile(r);
eDest = "";
stitchBlock = [];
if ~isempty(job.Stitches{r})
    % the sources are listed under stitch.parts; no single file was copied
    stitchRec = job.StitchRecs{r};
    if isempty(stitchRec); stitchRec = stitchRecord(job.Stitches{r}, dest); end
    eSource = "";
    eDest = stitchRec.file;
    stitchBlock = stitchRec;
    stitchBlock.parts = num2cell(stitchRec.parts);
elseif eSource ~= ""
    [~, en, ex] = fileparts(eSource);
    eDest = string(fullfile(dest, en + ex));
end
m.epsych = struct('sourceFile', eSource, 'destFile', eDest, 'time', isoTime(R.EpsychTime(r)), ...
    'files', {num2cell(rmfield(files(isEpsych), 'isEpsych'))}, 'stitch', stitchBlock);
m.copy = struct('status', R.CopyStatus(r), 'message', R.Message(r), 'verify', job.Opts.Verify, ...
    'ifExists', job.Opts.IfExists, 'numFiles', R.NumFiles(r), 'totalBytes', int64(R.TotalBytes(r)), ...
    'filesAlreadyPresent', job.Present(r), ...
    'startedAt', isoTime(job.Started), 'finishedAt', isoTime(datetime('now', 'TimeZone', 'local')), ...
    'host', host, 'user', user, 'robocopyLog', string(fullfile(dest, job.Robolog)));
m.tool = tool;
f = string(fullfile(dest, job.Manifest));
writeJsonFile(f, m);
end


% =============================================================================
% batches in flight
% =============================================================================

function d = jobsFolder()
%jobsFolder  Where every batch in flight keeps its job folder.
%   Per Windows user rather than tempdir, which can differ between a sign-in
%   and a scheduled task: the app's copies and scheduled ones must see each
%   other's batches.
base = string(getenv('LOCALAPPDATA'));
if base == ""; base = string(tempdir); end
d = fullfile(base, "ephys_analysis", "copy_jobs");
end


function busy = sessionsInFlight()
%sessionsInFlight  Session folders that batches still in flight are writing.
%   A batch's engine touches its heartbeat every couple of seconds, so a job
%   folder touched within the last two minutes belongs to a batch that is
%   still copying; the job file it gave its engine lists the session folders.
%   Batches that finished removed their folder; one whose MATLAB went away
%   left it behind, and it goes quiet.
busy = struct('Dest', strings(0, 1), 'Started', strings(0, 1));
root = jobsFolder();
if ~isfolder(root); return; end
D = dir(root);
D = D([D.isdir] & ~startsWith({D.name}, '.'));
nowNum = datenum(datetime('now')); %#ok<DATNM> dir reports datenums
for k = 1:numel(D)
    folder = fullfile(root, D(k).name);
    F = dir(folder);
    F = F(~[F.isdir]);
    if isempty(F) || (nowNum - max([F.datenum])) * 86400 > 120; continue; end
    specs = F(endsWith({F.name}, '_job.json'));
    if isempty(specs); continue; end
    [~, newest] = max([specs.datenum]);
    try
        spec = jsondecode(stripBOM(fileread(fullfile(folder, specs(newest).name))));
        s = spec.sessions;
        if iscell(s); s = [s{:}]; end
        dest = strings(numel(s), 1);
        for i = 1:numel(s)
            dest(i) = normPath(s(i).dest);
        end
        started = "earlier";
        if isfield(spec, 'started'); started = string(spec.started); end
    catch
        continue   % caught mid-write, or not a job file
    end
    busy.Dest = [busy.Dest; dest];
    busy.Started = [busy.Started; repmat(started, numel(dest), 1)];
end
end


function pruneJobFolders()
%pruneJobFolders  Remove job folders nothing has touched for a week.
%   Only a batch whose MATLAB closed before it finished leaves one behind; no
%   one can take such a batch up again, and the next copy completes it.
root = jobsFolder();
if ~isfolder(root); return; end
D = dir(root);
D = D([D.isdir] & ~startsWith({D.name}, '.'));
nowNum = datenum(datetime('now')); %#ok<DATNM>
for k = 1:numel(D)
    folder = fullfile(root, D(k).name);
    F = dir(folder);
    F = F(~strcmp({F.name}, '..'));   % the parent changes with every batch
    if nowNum - max([F.datenum]) > 7
        try rmdir(folder, 's'); catch; end
    end
end
end


function p = normPath(p)
%normPath  A folder path spelled one way, to compare two spellings of it.
p = lower(strip(replace(string(p), "/", "\"), "right", "\"));
end


% =============================================================================
% small helpers
% =============================================================================

function s = durationText(d)
if d < minutes(1)
    s = sprintf("%.0f s", seconds(d));
elseif d < hours(2)
    s = sprintf("%.0f min", minutes(d));
else
    s = sprintf("%.1f h", hours(d));
end
end


function info = progressInfo(job, phase, sessionBytes)
%progressInfo  What a ProgressFcn is told besides the fraction and the message.
%   The fraction alone cannot be shown as anything but a percentage; this says
%   which session the engine is on, how many are left and how many bytes of the
%   batch have moved, so a caller can put a rate and a time left beside it.
%   SessionBytes is [done total] for the session in flight, or NaN when the
%   event does not say (it is only known while the engine is inside one).
if nargin < 3; sessionBytes = [NaN NaN]; end
info = struct( ...
    'Phase', string(phase), ...
    'Session', job.SessionNow, ...
    'Sessions', [job.SessionsDone, numel(job.ToCopy)], ...
    'Bytes', [job.PhaseBytes, job.Total], ...
    'SessionBytes', sessionBytes);
end


function s = rowName(R, r)
s = R.DestDir(r);
[~, s] = fileparts(s);
end


function makeFolder(p)
if isfolder(p); return; end
[ok, msg] = mkdir(p);
if ~ok
    error('copySessions:CannotCreate', 'Cannot create %s: %s', p, msg);
end
end


function h = sha256File(file)
%sha256File  SHA-256 of a file as lowercase hex, streamed in 64 MB chunks.
%   Only the stitched ePsych file and its sources are hashed here; every
%   copied file is hashed by the engine.
fid = fopen(file, 'r');
if fid < 0
    error('copySessions:CannotRead', 'Cannot open %s to hash it.', file);
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
            c = c + " (copySessions.m modified)";
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
