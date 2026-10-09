classdef OutputTransfer < handle
    % OutputTransfer  Copy or move datasets' output files to another folder, in the background.
    %   An OutputTransfer puts each dataset's files in <Destination>/<key>,
    %   where KEY is the dataset's folder below the project root
    %   (subject/session), so the destination has the raw data's folder
    %   structure. The files are copied outside MATLAB by copy_engine.ps1
    %   (robocopy, as copySessions copies sessions), one job at a time, so
    %   nothing waits for them: add() queues a batch of files, poll()
    %   advances the copy without waiting, wait() polls until it is over.
    %   EphysPipeline makes one per run when its Transfer section is on
    %   (EphysPipeline.run); the app follows it on its Run tab.
    %
    %     X = OutputTransfer("S:\backup\EXTRACT", Method="copy", IfExists="version");
    %     X.add("SUBJ-1/SUBJ-1_260916_110907", ["D:\out\rec\rec_extract_LFP.mat" "D:\out\rec\kilosort4"], ...
    %         Base="D:\out\rec", Dataset="rec", Label="outputs");
    %     X.close();            % no more batches
    %     X.wait();             % poll until every batch is finished
    %     disp(X.table())
    %
    %   Where the files go. A file below BASE (the dataset's output folder)
    %   keeps its path below it (<Destination>/<key>/kilosort4/params.py);
    %   one that is not keeps its name only. A folder is copied whole, with
    %   its subfolders but without hidden ones (phy's .phy cache). The
    %   files are listed when their batch starts, and only those are copied.
    %
    %   IfExists, for the dataset's folder <Destination>/<key>:
    %     "version"    (default) when the folder already holds anything,
    %                  this transfer puts the dataset's files in a new
    %                  version folder instead, <key>_v2 (_v3, ...: the first
    %                  free one), so the earlier copy stays as it is and the
    %                  new one stays whole. Decided once per dataset, at its
    %                  first batch: its later batches go to the same folder
    %     "overwrite"  files already there are replaced (robocopy leaves a
    %                  file that has the size and time of its source)
    %     "skip"       files already there are left as they are; only the
    %                  missing ones are copied
    %   Files in the folder that the transfer does not copy are never
    %   touched.
    %
    %   Method "move" copies, verifies, then removes the copied files here,
    %   but only once the transfer is closed (close: nothing adds or
    %   rewrites them any more; EphysPipeline closes it when the run ends),
    %   and only a file that has not changed since it was copied. Paths
    %   given as Keep= are copied and never removed. Once a folder given
    %   whole holds none of the files a transfer copies (hidden ones may
    %   stay), its empty subfolders go and the batch's OnMoved(folder,
    %   newFolder) is called (EphysPipeline records a moved sort folder as
    %   the dataset's sorting folder).
    %
    %   Verification: once a job is copied, every file must have its
    %   source's size and modified time (to 2 s); with Verify="hash" the
    %   engine then takes the SHA-256 of each source and copy, which must
    %   match. A batch with a file that fails is "failed" and keeps what
    %   was copied. A file whose source changed while it was copied (or,
    %   for a batch copied before close(), has changed or appeared in a
    %   folder since) is copied again in a batch of its own, at most
    %   MaxGeneration times in all.
    %
    %   A batch with WaitFor= (the status file of a background sort run,
    %   EphysDataset.sortRunState) waits until that sort has ended; a status
    %   file older than Since= is an earlier run's. A sort that failed or
    %   was stopped skips its batch.
    %
    %   Batch states: "waiting" (for its sort), "queued", "copying",
    %   "verifying" (SHA-256), "copied" (a move whose files go once the
    %   transfer is closed), "done", "failed", "canceled", "skipped".
    %
    %   Properties
    %     Destination, Method, IfExists, Verify   as constructed
    %     Batches      one struct per batch (fields: see newBatch)
    %     Closed       close() was called: no more batches
    %     Canceled    cancel() was called
    %     Done         closed, and every batch has finished
    %     LogFcn       @(msg), one line per batch queued and ended
    %     ProgressFcn  @(info) as the copy moves (info: see progress)
    %     BatchFcn     @(batch) whenever a batch changes state
    %
    %   Methods: add, poll, close, cancel, wait, progress, statusOf, table,
    %   datasetFolder; static versionFolder (where a new transfer would put
    %   a dataset, for a plan). Windows only (robocopy, PowerShell): see
    %   platformSupport("copy").
    %
    %   See also EphysPipeline.run, copySessions, copy_engine.ps1.

    properties
        LogFcn = @(msg) fprintf('%s\n', msg)   % one line per batch queued and ended
        ProgressFcn = []   % ProgressFcn(info) as the copy moves (info: see progress)
        BatchFcn = []      % BatchFcn(batch) whenever a batch changes state
    end

    properties (SetAccess = private)
        Destination (1,1) string = ""          % the folder the dataset folders go in
        Method      (1,1) string = "copy"      % "copy" | "move" (removed here once closed)
        IfExists    (1,1) string = "version"   % "version" | "overwrite" | "skip"
        Verify      (1,1) string = "size"      % "size" (and time) | "hash" (SHA-256)
        Batches     struct = OutputTransfer.emptyBatches()   % one per batch (fields: see newBatch)
        Closed      (1,1) logical = false      % close() was called: no more batches
        Canceled   (1,1) logical = false      % cancel() was called
        Message     (1,1) string = ""          % what the copy engine said last
    end

    properties (Dependent)
        Done        % closed, and every batch finished
    end

    properties (Constant)
        % A file that changes while it is copied is copied again, in a batch
        % of its own, at most this many times in all.
        MaxGeneration = 3
    end

    properties (Constant, Access = private)
        Final = ["done" "failed" "canceled" "skipped"]
    end

    properties (Access = private)
        Folders           % containers.Map: lower-case key -> the dataset's folder in Destination
        Moved             % containers.Map: lower-case source folders whose OnMoved was called
        Job = []          % the copy engine's job in flight
        Polling (1,1) logical = false
    end

    methods
        function obj = OutputTransfer(destination, opts)
            %OutputTransfer  A transfer into DESTINATION (a full path; created when needed).
            arguments
                destination (1,1) string
                opts.Method (1,1) string {mustBeMember(opts.Method, ["copy" "move"])} = "copy"
                opts.IfExists (1,1) string {mustBeMember(opts.IfExists, ["version" "overwrite" "skip"])} = "version"
                opts.Verify (1,1) string {mustBeMember(opts.Verify, ["size" "hash"])} = "size"
                opts.LogFcn = []
            end
            platformSupport("copy", Require=true, ErrorId="OutputTransfer:NotWindows");
            dest = replace(strtrim(destination), "/", filesep);
            if ~OutputTransfer.isFullPath(dest)
                error('OutputTransfer:BadDestination', ...
                    'The destination must be a full path (a drive letter, or \\\\server\\share): "%s".', destination);
            end
            obj.Destination = dest;
            obj.Method = opts.Method;
            obj.IfExists = opts.IfExists;
            obj.Verify = opts.Verify;
            if ~isempty(opts.LogFcn); obj.LogFcn = opts.LogFcn; end
            obj.Folders = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.Moved = containers.Map('KeyType', 'char', 'ValueType', 'logical');
        end

        function tf = get.Done(obj)
            tf = obj.Closed && isempty(obj.Job) && all(ismember(obj.states(), OutputTransfer.Final));
        end

        function id = add(obj, key, paths, opts)
            %add  Queue a batch: PATHS (files or folders) into the dataset folder of KEY.
            %   ID = X.add(KEY, PATHS, Base=, Dataset=, Label=, Keep=,
            %   WaitFor=, Since=, OnMoved=) returns the batch's Id. KEY is
            %   the dataset's folder below the project root ("subj/session",
            %   either separator); BASE the dataset's output folder (the
            %   files' paths below it are kept); DATASET and LABEL name the
            %   batch in messages; KEEP lists the paths a move copies but
            %   never removes; WAITFOR is a background sort's status file to
            %   wait for, SINCE when that sort was started (default now);
            %   ONMOVED is called as ONMOVED(folder, newFolder) for each
            %   folder of PATHS once a move has taken its files, and may
            %   return a note for the batch's message. Paths that are not
            %   there when the batch starts are left out.
            arguments
                obj (1,1) OutputTransfer
                key (1,1) string
                paths (1,:) string
                opts.Base (1,1) string = ""
                opts.Dataset (1,1) string = ""
                opts.Label (1,1) string = ""
                opts.Keep (1,:) string = string.empty(1, 0)
                opts.WaitFor (1,1) string = ""
                opts.Since (1,1) datetime = datetime('now')
                opts.OnMoved = []
            end
            if obj.Closed && ~obj.Canceled
                error('OutputTransfer:Closed', 'The transfer is closed: no batch can be added to it.');
            end
            key = OutputTransfer.cleanKey(key);
            paths = paths(strtrim(paths) ~= "");
            b = OutputTransfer.newBatch();
            b.Id = numel(obj.Batches) + 1;
            b.Key = key;
            b.Dataset = opts.Dataset;
            if b.Dataset == ""; b.Dataset = regexprep(key, '^.*/', ''); end
            b.Label = opts.Label;
            b.Paths = unique(paths, 'stable');
            b.Base = opts.Base;
            b.Keep = opts.Keep;
            b.WaitFor = opts.WaitFor;
            b.Since = opts.Since;
            b.OnMoved = opts.OnMoved;
            b.Added = datetime('now');
            if obj.Canceled
                b.State = "canceled";
                b.Message = "not copied: the transfer was canceled";
            else
                b.DestDir = obj.datasetFolder(key);
                if b.WaitFor ~= ""
                    b.State = "waiting";
                    b.Message = "waiting for the sort to finish";
                else
                    b.State = "queued";
                    b.Bytes = OutputTransfer.sizeOf(b.Paths);
                end
            end
            obj.Batches(end+1) = b;
            id = b.Id;
            if b.State ~= "canceled"
                obj.say(b, sprintf("%d path(s), %s, to %s", numel(b.Paths), OutputTransfer.bytesText(b.Bytes), b.DestDir), b.State);
            end
            obj.changed(id);
        end

        function poll(obj)
            %poll  Advance the transfer, never waiting: read what the engine
            %   reported, check a job once it is over, queue the batches whose
            %   sort has ended, start the next job and, once closed, look at
            %   the batches copied before and remove what a move copied.
            if obj.Polling; return; end
            obj.Polling = true;
            restore = onCleanup(@() obj.endPoll());
            if ~isempty(obj.Job)
                obj.advanceJob();
            end
            obj.checkWaiting();
            if obj.Closed && ~obj.Canceled
                obj.sweep();
            end
            if isempty(obj.Job) && ~obj.Canceled
                obj.startJob();
            end
            if obj.Closed && ~obj.Canceled
                obj.removeMoved();
            end
            obj.report();
            delete(restore);
        end

        function close(obj)
            %close  No more batches: nothing adds or rewrites the files now.
            %   A move removes what it copied from here on, and each batch
            %   copied before is looked at once more (files changed or added
            %   since are copied in a batch of their own).
            obj.Closed = true;
        end

        function cancel(obj)
            %cancel  Stop copying; what is copied stays, and a move removes nothing more.
            %   The job in flight stops between files (what it copied
            %   stays), the batches not started are "canceled", and a move
            %   removes nothing more. A canceled transfer is closed.
            if obj.Canceled; return; end
            obj.Canceled = true;
            obj.Closed = true;
            for i = 1:numel(obj.Batches)
                switch obj.Batches(i).State
                    case {"waiting", "queued"}
                        obj.setState(i, "canceled", "not copied: the transfer was canceled");
                    case "copied"
                        obj.setState(i, "done", erase(obj.Batches(i).Message, OutputTransfer.LaterNote) + ...
                            "; nothing removed here: the transfer was canceled");
                end
            end
            if ~isempty(obj.Job)
                obj.sendCancel();
            end
            obj.report();
        end

        function wait(obj, opts)
            %wait  Poll until every batch has finished (and, once closed, the moves are done).
            %   X.wait(LogEvery=30) logs where the transfer is every LogEvery
            %   seconds (Inf: never). A batch waiting for a background sort
            %   waits for it. X.wait(Timeout=T) gives up after T seconds
            %   (OutputTransfer:Timeout; the transfer goes on when polled).
            arguments
                obj (1,1) OutputTransfer
                opts.LogEvery (1,1) double = 30
                opts.Timeout (1,1) double = Inf
            end
            last = tic;
            t0 = tic;
            while true
                obj.poll();
                if obj.idle(); break; end
                if toc(t0) > opts.Timeout
                    error('OutputTransfer:Timeout', 'The transfer is not done after %g s: %s', opts.Timeout, ...
                        OutputTransfer.progressText(obj.progress()));
                end
                if toc(last) >= opts.LogEvery
                    obj.LogFcn(OutputTransfer.progressText(obj.progress()));
                    last = tic;
                end
                pause(0.25);
            end
        end

        function info = progress(obj)
            %progress  Where the transfer is: a struct for a progress display.
            %   Fraction (0 to 1, of the bytes of every batch not waiting,
            %   canceled or skipped; a SHA-256 pass counts as two more
            %   reads), BytesDone / BytesTotal (copied so far / to copy),
            %   Batches ([finished total]), Waiting (batches waiting for a
            %   sort), Failed, Phase ("copying", "verifying", "waiting",
            %   "idle" or "done"), Current ("<key>: <label>" of the batch in
            %   flight, "" for none) and Message (what the engine said last).
            B = obj.Batches;
            st = obj.states();
            w = 1 + 2 * (obj.Verify == "hash");
            counted = ~ismember(st, ["waiting" "canceled" "skipped"]);
            bytes = [B.Bytes];
            total = sum(bytes(counted));
            finished = ismember(st, [OutputTransfer.Final "copied"]);
            doneBytes = sum(bytes(finished & counted));
            work = doneBytes * w;
            current = "";
            phase = "idle";
            if ~isempty(obj.Job)
                job = obj.Job;
                if job.Phase == "hash"
                    doneBytes = doneBytes + job.Total;
                    work = work + job.Total + 2 * job.PhaseBytes;
                    phase = "verifying";
                else
                    doneBytes = doneBytes + min(job.PhaseBytes, job.Total);
                    work = work + job.PhaseBytes;
                    phase = "copying";
                end
                if job.Now > 0 && job.Now <= numel(job.Sessions)
                    b = B(job.Sessions(job.Now).batch);
                    current = b.Key + ": " + b.Label;
                end
            elseif any(st == "waiting")
                phase = "waiting";
            elseif obj.Done
                phase = "done";
            end
            frac = min(work / max(total * w, 1), 1);
            if obj.Done; frac = 1; end
            info = struct('Phase', phase, 'Fraction', frac, ...
                'BytesDone', min(doneBytes, total), 'BytesTotal', total, ...
                'Batches', [nnz(finished), numel(B)], ...
                'Waiting', nnz(st == "waiting"), 'Failed', nnz(st == "failed"), ...
                'Current', current, 'Message', obj.Message);
        end

        function [status, message, folder] = statusOf(obj, key)
            %statusOf  One dataset's transfer, for a result row: STATUS, MESSAGE, FOLDER.
            %   STATUS is "waiting" (for a sort), "queued", "copying",
            %   "copied" (a move whose files go once the run is over),
            %   "done", "error" (a batch failed), "canceled" or "skipped";
            %   "" when KEY has no batch. FOLDER is the dataset's folder in
            %   the destination.
            status = "";
            message = "";
            folder = "";
            if isempty(obj.Batches); return; end
            k = OutputTransfer.cleanKey(key);
            B = obj.Batches(lower([obj.Batches.Key]) == lower(k));
            if isempty(B); return; end
            folder = B(end).DestDir;
            st = [B.State];
            moved = arrayfun(@(b) nnz(b.Files.State == "removed"), B);
            files = arrayfun(@(b) nnz(ismember(b.Files.State, ["copied" "removed"])), B);
            bytes = arrayfun(@(b) sum(b.Files.Bytes(ismember(b.Files.State, ["copied" "removed"]))), B);
            kept = sum(arrayfun(@(b) nnz(b.Files.State == "kept"), B));
            what = sprintf("%d file(s), %s", sum(files), OutputTransfer.bytesText(sum(bytes)));
            if kept > 0; what = what + sprintf(" (%d already there, left as they were)", kept); end
            if any(ismember(st, ["copying" "verifying"]))
                status = "copying";
            elseif any(st == "queued")
                status = "queued";
            elseif any(st == "waiting")
                status = "waiting";
            elseif any(st == "copied")
                status = "copied";
            elseif any(st == "failed")
                status = "error";
            elseif all(st == "canceled")
                status = "canceled";
            elseif all(ismember(st, ["skipped" "canceled"]))
                status = "skipped";
            else
                status = "done";
            end
            switch status
                case "error"
                    bad = B(find(st == "failed", 1));
                    message = bad.Label + ": " + bad.Message;
                case {"canceled", "skipped"}
                    message = B(end).Message;
                case "done"
                    verb = "copied";
                    if sum(moved) > 0; verb = "moved"; end
                    message = verb + " " + what + " to " + folder;
                    other = st ~= "done";
                    if any(other)
                        message = message + sprintf("; %d batch(es) %s", nnz(other), strjoin(unique(st(other)), ", "));
                    end
                case "copied"
                    message = "copied " + what + " to " + folder + "; removed here once the run is over";
                otherwise
                    message = sprintf("%s: %d of %d batch(es) finished, %s copied so far", status, ...
                        nnz(ismember(st, [OutputTransfer.Final "copied"])), numel(B), what);
                    if any(st == "waiting")
                        message = message + sprintf("; %d waiting for the sort", nnz(st == "waiting"));
                    end
            end
        end

        function T = table(obj)
            %table  One row per batch: Key, Dataset, Label, State, Message, DestDir, Files, Bytes.
            names = {'Key', 'Dataset', 'Label', 'State', 'Message', 'DestDir', 'Files', 'Bytes'};
            B = obj.Batches;
            if isempty(B)
                T = table(strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), ...
                    strings(0, 1), zeros(0, 1), zeros(0, 1), 'VariableNames', names);
                return
            end
            T = table([B.Key].', [B.Dataset].', [B.Label].', [B.State].', [B.Message].', [B.DestDir].', ...
                arrayfun(@(b) numel(b.Files.Src), B).', [B.Bytes].', 'VariableNames', names);
        end

        function f = datasetFolder(obj, key)
            %datasetFolder  The folder KEY's files go to: <Destination>/<key>, or its version folder.
            %   Decided at the first call for KEY and kept (see IfExists).
            key = OutputTransfer.cleanKey(key);
            k = char(lower(key));
            if isKey(obj.Folders, k)
                f = obj.Folders(k);
                return
            end
            f = OutputTransfer.versionFolder(obj.Destination, key, obj.IfExists);
            if f == ""
                error('OutputTransfer:NoVersion', 'No free version folder for %s in %s (up to _v999).', key, obj.Destination);
            end
            obj.Folders(k) = f;
        end
    end

    methods (Static)
        function f = versionFolder(destination, key, ifExists)
            %versionFolder  Where a new transfer would put KEY's files.
            %   F = OutputTransfer.versionFolder(DESTINATION, KEY, IFEXISTS):
            %   <DESTINATION>/<KEY>, or with IFEXISTS "version" and that folder
            %   holding anything, its first free version folder (<KEY>_v2,
            %   _v3, ...; "" when there is none up to _v999). It only looks.
            f = string(fullfile(replace(strtrim(destination), "/", filesep), ...
                replace(OutputTransfer.cleanKey(key), "/", filesep)));
            if ifExists == "version" && OutputTransfer.taken(f)
                f = OutputTransfer.freeVersion(f);
            end
        end

        function tf = isFullPath(p)
            %isFullPath  A drive letter and a separator, or a \\server\share path.
            tf = ~isempty(regexp(char(p), '^([A-Za-z]:[\\/]|\\\\[^\\/]+[\\/][^\\/]+)', 'once'));
        end

        function key = cleanKey(key)
            %cleanKey  A dataset key with "/" separators; an error for one that could leave the destination.
            key = strtrim(replace(string(key), "\", "/"));
            key = regexprep(key, '^/+|/+$', '');
            parts = split(key, "/");
            if key == "" || any(parts == "" | parts == "." | parts == "..") || contains(key, ":")
                error('OutputTransfer:BadKey', 'A dataset key must be a relative folder such as "subject/session": "%s".', key);
            end
        end

        function s = progressText(info)
            %progressText  One line for a log: how far a transfer is (progress).
            s = sprintf("%.0f%%, %s of %s, %d of %d batch(es)", 100 * info.Fraction, ...
                OutputTransfer.bytesText(info.BytesDone), OutputTransfer.bytesText(info.BytesTotal), ...
                info.Batches(1), info.Batches(2));
            if info.Waiting > 0; s = s + sprintf(", %d waiting for a sort", info.Waiting); end
            if info.Failed > 0; s = s + sprintf(", %d failed", info.Failed); end
            if info.Current ~= ""; s = s + " - " + info.Current; end
        end

        function s = bytesText(b)
            %bytesText  "1.2 GB" and the like.
            units = ["B", "KB", "MB", "GB", "TB"];
            k = 1;
            while b >= 1024 && k < numel(units)
                b = b / 1024; k = k + 1;
            end
            if k == 1
                s = sprintf("%d B", round(b));
            else
                s = sprintf("%.1f %s", b, units(k));
            end
        end
    end

    properties (Constant, Access = private)
        LaterNote = "; removed here once the run is over"
    end

    methods (Access = private)
        function endPoll(obj)
            obj.Polling = false;
        end

        function st = states(obj)
            st = strings(1, 0);
            if ~isempty(obj.Batches); st = [obj.Batches.State]; end
        end

        function tf = idle(obj)
            %idle  Nothing left to do now: every batch finished (a move's
            %   "copied" too while not closed) and no job in flight.
            if obj.Closed
                tf = obj.Done;
            else
                tf = isempty(obj.Job) && all(ismember(obj.states(), [OutputTransfer.Final "copied"]));
            end
        end

        function changed(obj, i)
            if isempty(obj.BatchFcn); return; end
            try
                obj.BatchFcn(obj.Batches(i));
            catch ME
                warning('OutputTransfer:BatchFcn', 'BatchFcn failed: %s', ME.message);
            end
        end

        function report(obj)
            if isempty(obj.ProgressFcn); return; end
            try
                obj.ProgressFcn(obj.progress());
            catch ME
                warning('OutputTransfer:ProgressFcn', 'ProgressFcn failed: %s', ME.message);
            end
        end

        function say(obj, b, msg, what)
            %say  One log line about batch B.
            line = b.Key + " (" + b.Label + "): " + what;
            if strlength(msg) > 0; line = line + " - " + msg; end
            obj.LogFcn(line);
        end

        function setState(obj, i, state, message)
            obj.Batches(i).State = state;
            if nargin > 3; obj.Batches(i).Message = message; end
            if ismember(state, OutputTransfer.Final) || state == "copied"
                obj.Batches(i).Finished = datetime('now');
                obj.say(obj.Batches(i), obj.Batches(i).Message, state);
            end
            obj.changed(i);
        end

        % ------------------------------------------------------------- waiting
        function checkWaiting(obj)
            %checkWaiting  Batches waiting for a sort: queued once it has ended.
            for i = find(obj.states() == "waiting")
                b = obj.Batches(i);
                [state, msg] = EphysDataset.sortRunState(b.WaitFor);
                if state ~= "running" && OutputTransfer.olderThan(b.WaitFor, b.Since)
                    state = "running";   % an earlier run's status: this run has not ended
                end
                switch state
                    case "running"
                        continue
                    case "done"
                        obj.Batches(i).Bytes = OutputTransfer.sizeOf(b.Paths);
                        obj.setState(i, "queued", "");
                    otherwise
                        why = "the sort " + ternary(state == "canceled", "was stopped", "failed");
                        if msg ~= ""; why = why + " (" + msg + ")"; end
                        obj.setState(i, "skipped", "not copied: " + why);
                end
            end
        end

        % ------------------------------------------------------------- starting a job
        function startJob(obj)
            %startJob  List the queued batches' files and hand them to the engine as one job.
            ready = find(obj.states() == "queued");
            if isempty(ready); return; end
            sessions = struct('batch', {}, 'files', {}, 'dest', {}, 'src', {});
            inJob = zeros(1, 0);
            for i = ready
                b = obj.Batches(i);
                try
                    if b.Listed
                        F = OutputTransfer.restat(b.Files);
                    else
                        [F, b.Folders] = OutputTransfer.listFiles(b);
                        b.Listed = true;
                    end
                    b.Swept = b.Swept || obj.Closed;   % listed after the run: nothing changes them now
                    F.State(:) = "";
                    F.State(isnan(F.Bytes)) = "gone";   % removed since it was listed
                    [~, first] = unique(lower(F.Rel), 'stable');
                    dup = setdiff(1:numel(F.Rel), first);
                    F.State(dup) = "failed";            % one file per place: the first keeps it
                    if ~isempty(dup)
                        b.Note = sprintf("%d file(s) left out: another file of the batch goes to the same place", numel(dup));
                    end
                    if obj.IfExists == "skip"
                        there = OutputTransfer.existsAt(b.DestDir, F.Rel);
                        F.State(there & F.State == "") = "kept";
                    end
                    b.Files = F;
                    b.Bytes = sum(F.Bytes(F.State == ""));
                    b.Started = datetime('now');
                    obj.Batches(i) = b;
                catch ME
                    obj.Batches(i) = b;
                    obj.setState(i, "failed", "its files could not be listed: " + ME.message);
                    continue
                end
                if all(F.State == "gone")   % none of its paths is there (none at all, too)
                    obj.setState(i, "skipped", "nothing to copy: " + strjoin(b.Paths, ", ") + " not there");
                    continue
                end
                todo = find(F.State == "");
                if isempty(todo)
                    obj.finishBatch(i);
                    continue
                end
                % one engine session per source folder and destination folder
                srcDir = OutputTransfer.parentOf(F.Src(todo));
                relDir = OutputTransfer.parentOf(F.Rel(todo));
                [~, ~, g] = unique(lower(srcDir + "|" + relDir), 'stable');
                for k = 1:max(g)
                    m = todo(g == k);
                    at = find(g == k, 1);
                    sessions(end+1) = struct('batch', i, 'files', m(:).', ...
                        'dest', string(fullfile(b.DestDir, relDir(at))), 'src', srcDir(at)); %#ok<AGROW>
                end
                inJob(end+1) = i; %#ok<AGROW>
                obj.setState(i, "copying");
            end
            if isempty(sessions); return; end

            need = sum(arrayfun(@(s) sum(obj.Batches(s.batch).Files.Bytes(s.files)), sessions));
            free = OutputTransfer.usableBytes(obj.Destination);
            if isfinite(free) && need > free
                for i = inJob
                    obj.failFiles(i);
                    obj.setState(i, "failed", sprintf("not copied: not enough space at %s (%s to copy, %s free)", ...
                        obj.Destination, OutputTransfer.bytesText(need), OutputTransfer.bytesText(free)));
                end
                return
            end

            job = struct();
            job.Dir = string(tempname(char(OutputTransfer.jobsFolder())));
            job.Phase = "copy";
            job.Sessions = sessions;
            job.Batches = inJob;
            job.Total = need;
            job.PhaseBytes = 0;
            job.Pos = 0;
            job.Now = 0;
            job.Polled = tic;
            job.Beat = -1;
            job.Quiet = 0;
            job.CancelFile = string(fullfile(job.Dir, "cancel.flag"));
            job.CancelSent = false;
            job.Errors = strings(1, numel(sessions));
            job.Hashes = containers.Map('KeyType', 'char', 'ValueType', 'any');
            job.Failed = false;
            obj.Job = job;
            try
                OutputTransfer.makeFolder(job.Dir);
                obj.launch("copy");
            catch ME
                obj.Job = [];
                for i = inJob
                    obj.failFiles(i);
                    obj.setState(i, "failed", "the copy engine could not be started: " + ME.message);
                end
            end
        end

        function launch(obj, phase)
            %launch  Write the job spec for PHASE and start copy_engine.ps1 detached.
            job = obj.Job;
            sessions = cell(1, numel(job.Sessions));
            for s = 1:numel(job.Sessions)
                S = job.Sessions(s);
                F = obj.Batches(S.batch).Files;
                names = OutputTransfer.nameOf(F.Src(S.files));
                expect = cell(1, numel(S.files));
                for j = 1:numel(S.files)
                    expect{j} = struct('rel', char(names(j)), 'src', char(F.Src(S.files(j))), 'bytes', F.Bytes(S.files(j)));
                end
                groups = {};
                for g0 = 1:200:numel(names)   % keeps each robocopy command line short
                    groups{end+1} = struct('src', char(S.src), 'recurse', false, ...
                        'files', {cellRow(names(g0:min(g0 + 199, end)))}); %#ok<AGROW>
                end
                sessions{s} = struct('index', s, 'dest', char(S.dest), ...
                    'log', char(fullfile(job.Dir, sprintf("%s_%d_robocopy.log", phase, s))), ...
                    'subdirs', {cell(1, 0)}, 'groups', {groups}, 'expect', {expect});
            end
            spec = struct('version', 1, 'verify', char(obj.Verify), ...
                'started', char(string(datetime('now'), 'yyyy-MM-dd HH:mm')), 'pid', feature('getpid'), ...
                'progressFile', char(obj.phaseFile(phase, "progress.jsonl")), ...
                'statusFile', char(obj.phaseFile(phase, "status.json")), ...
                'heartbeatFile', char(obj.phaseFile(phase, "heartbeat")), ...
                'cancelFile', char(job.CancelFile), 'sessions', {sessions});
            specFile = obj.phaseFile(phase, "job.json");
            writeJsonFile(specFile, spec);
            engine = fullfile(fileparts(mfilename('fullpath')), 'copy_engine.ps1');
            if ~isfile(engine)
                error('OutputTransfer:EngineMissing', 'The copy engine is missing: %s', engine);
            end
            cmd = sprintf('start "OutputTransfer" /b powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%s" -Job "%s" -Phase %s', ...
                engine, specFile, phase);
            status = system(cmd);
            if status ~= 0
                error('OutputTransfer:EngineLaunchFailed', 'Could not launch the copy engine (exit code %d): %s', status, cmd);
            end
            obj.Job.Phase = phase;
            obj.Job.Pos = 0;
            obj.Job.PhaseBytes = 0;
            obj.Job.Polled = tic;
            obj.Job.Beat = -1;
            obj.Job.Quiet = 0;
        end

        function f = phaseFile(obj, phase, name)
            f = string(fullfile(obj.Job.Dir, phase + "_" + name));
        end

        % ------------------------------------------------------------- the job in flight
        function advanceJob(obj)
            %advanceJob  Read the engine's events; once its phase is over, check it.
            if obj.Canceled && ~obj.Job.CancelSent
                obj.sendCancel();
            end
            phase = obj.Job.Phase;
            obj.drainEvents();
            statusFile = obj.phaseFile(phase, "status.json");
            if ~isfile(statusFile)
                obj.watchHeartbeat();
                if obj.Job.Quiet > 120
                    obj.failJob(sprintf("the copy engine stopped responding (nothing for %.0f s); anything copied is kept", obj.Job.Quiet));
                end
                return
            end
            S = OutputTransfer.readEngineStatus(statusFile);
            obj.drainEvents();   % anything written between the last read and the status file
            if S.state == "error"
                obj.failJob("the copy engine failed: " + S.message);
                return
            end
            stopped = S.state == "canceled" || obj.Canceled;
            if phase == "copy"
                obj.finishCopyPhase(stopped);
                verify = obj.states() == "verifying";
                if any(verify)
                    keep = ismember([obj.Job.Sessions.batch], find(verify));
                    obj.Job.Sessions = obj.Job.Sessions(keep);
                    obj.Job.Errors = strings(1, nnz(keep));
                    obj.Job.Total = sum(arrayfun(@(s) sum(obj.Batches(s.batch).Files.Bytes(s.files)), obj.Job.Sessions));
                    obj.Job.Now = 0;
                    try
                        obj.launch("hash");
                        return
                    catch ME
                        for i = find(verify)
                            obj.setState(i, "failed", "the SHA-256 check could not be started: " + ME.message);
                        end
                        obj.Job.Failed = true;
                    end
                end
            else
                obj.finishHashPhase(stopped);
            end
            obj.endJob();
        end

        function drainEvents(obj)
            %drainEvents  Read the engine's new progress lines (whole lines only).
            f = obj.phaseFile(obj.Job.Phase, "progress.jsonl");
            if ~isfile(f); return; end
            fid = fopen(f, 'r');
            if fid < 0; return; end
            try
                fseek(fid, obj.Job.Pos, 'bof');
                chunk = fread(fid, inf, '*char').';
            catch
                fclose(fid);
                return
            end
            fclose(fid);
            nl = find(chunk == newline, 1, 'last');
            if isempty(nl); return; end
            obj.Job.Pos = obj.Job.Pos + nl;
            lines = splitlines(string(chunk(1:nl)));
            lines = strtrim(lines(strlength(strtrim(lines)) > 0));
            n = numel(obj.Job.Sessions);
            moved = false;
            for k = 1:numel(lines)
                try
                    e = jsondecode(lines(k));
                catch
                    continue
                end
                if ~isfield(e, 'event'); continue; end
                if isfield(e, 'index') && (e.index < 1 || e.index > n); continue; end
                switch string(e.event)
                    case "session"
                        obj.Job.Now = e.index;
                        if string(e.state) == "canceled"
                            obj.Job.Errors(e.index) = "canceled";
                        elseif string(e.state) == "done" && isfield(e, 'error') && strlength(string(e.error)) > 0
                            obj.Job.Errors(e.index) = string(e.error);
                        end
                    case "progress"
                        obj.Job.Now = e.index;
                        obj.Job.PhaseBytes = e.bytesDone;
                        if isfield(e, 'rel')
                            obj.Message = sprintf("SHA-256 of %s, %s of %s", e.rel, ...
                                OutputTransfer.bytesText(e.bytes), OutputTransfer.bytesText(e.bytesTotal));
                        else
                            obj.Message = sprintf("%d of %d file(s), %s of %s", e.files, e.filesTotal, ...
                                OutputTransfer.bytesText(e.bytes), OutputTransfer.bytesText(e.bytesTotal));
                        end
                        moved = true;
                    case "file"
                        obj.Job.Now = e.index;
                        obj.Job.PhaseBytes = e.bytesDone;
                        obj.Message = string(e.rel);
                        if isfield(e, 'sha256Source')
                            h = struct('src', string(e.sha256Source), 'dst', "", 'err', "");
                            if isfield(e, 'sha256Destination'); h.dst = string(e.sha256Destination); end
                            if isfield(e, 'hashError'); h.err = string(e.hashError); end
                            obj.Job.Hashes(OutputTransfer.hashKey(e.index, string(e.rel))) = h;
                        end
                        moved = true;
                    case "robocopy"
                        if e.exit >= 8
                            obj.Message = sprintf("robocopy exit code %d", e.exit);
                        end
                end
            end
            if moved; obj.report(); end
        end

        function watchHeartbeat(obj)
            %watchHeartbeat  How long the engine has not beaten, in MATLAB's own
            %   time between polls (a gap counts 10 s at most), as copySessions.
            info = dir(obj.phaseFile(obj.Job.Phase, "heartbeat"));
            beat = -1;   % none yet: the engine has not started
            if isscalar(info); beat = info.datenum; end
            gap = min(toc(obj.Job.Polled), 10);
            obj.Job.Polled = tic;
            if beat ~= obj.Job.Beat
                obj.Job.Beat = beat;
                obj.Job.Quiet = 0;
            else
                obj.Job.Quiet = obj.Job.Quiet + gap;
            end
        end

        function sendCancel(obj)
            obj.Job.CancelSent = true;
            if isfile(obj.Job.CancelFile); return; end
            [fid, msg] = fopen(obj.Job.CancelFile, 'w');
            if fid >= 0
                fclose(fid);
            else
                warning('OutputTransfer:CancelFailed', ...
                    'Cannot write the cancel file %s (%s); the copy engine was not told to stop.', obj.Job.CancelFile, msg);
            end
        end

        function finishCopyPhase(obj, stopped)
            %finishCopyPhase  Each batch of the job, once the engine has copied it.
            for i = obj.Job.Batches
                if obj.Batches(i).State ~= "copying"; continue; end
                errs = obj.Job.Errors([obj.Job.Sessions.batch] == i);
                if stopped || any(errs == "canceled")
                    obj.failFiles(i);
                    obj.setState(i, "canceled", "canceled during the copy; what was copied is kept in " + obj.Batches(i).DestDir);
                elseif any(errs ~= "")
                    obj.failFiles(i);
                    obj.Job.Failed = true;
                    obj.setState(i, "failed", errs(find(errs ~= "", 1)) + "; what was copied is kept in " + obj.Batches(i).DestDir);
                else
                    obj.checkCopies(i);
                end
            end
        end

        function checkCopies(obj, i)
            %checkCopies  Batch I's copies against their sources: size and time.
            b = obj.Batches(i);
            F = b.Files;
            todo = find(F.State == "");
            cur = OutputTransfer.restat(F);
            dst = OutputTransfer.statAt(b.DestDir, F.Rel(todo));
            bad = strings(0, 1);
            for j = 1:numel(todo)
                m = todo(j);
                if ~OutputTransfer.sameFile(cur.Bytes(m), cur.Time(m), F.Bytes(m), F.Time(m))
                    F.State(m) = "changed";   % rewritten (or removed) while it was copied
                elseif OutputTransfer.sameFile(dst.Bytes(j), dst.Time(j), F.Bytes(m), F.Time(m))
                    F.State(m) = "copied";
                else
                    F.State(m) = "failed";
                    bad(end+1) = F.Rel(m) + ternary(isnan(dst.Bytes(j)), " is missing", " differs from its source"); %#ok<AGROW>
                end
            end
            obj.Batches(i).Files = F;
            if ~isempty(bad)
                obj.Job.Failed = true;
                obj.setState(i, "failed", "VERIFICATION FAILED (" + OutputTransfer.listText(bad) + ...
                    "); what was copied is kept in " + b.DestDir + "; robocopy's log is in " + obj.Job.Dir);
            elseif obj.Verify == "hash" && any(F.State == "copied")
                obj.setState(i, "verifying");
            else
                obj.finishBatch(i);
            end
        end

        function finishHashPhase(obj, stopped)
            %finishHashPhase  Compare the SHA-256 the engine took of each source and copy.
            for i = obj.Job.Batches
                if obj.Batches(i).State ~= "verifying"; continue; end
                if stopped
                    obj.setState(i, "canceled", "canceled while checksumming; the copy is kept in " + obj.Batches(i).DestDir);
                    continue
                end
                F = obj.Batches(i).Files;
                bad = strings(0, 1);
                for s = find([obj.Job.Sessions.batch] == i)
                    for m = obj.Job.Sessions(s).files
                        if F.State(m) ~= "copied"; continue; end
                        k = OutputTransfer.hashKey(s, OutputTransfer.nameOf(F.Src(m)));
                        if ~isKey(obj.Job.Hashes, k)
                            bad(end+1) = F.Rel(m) + " was not checksummed"; %#ok<AGROW>
                            F.State(m) = "failed";
                            continue
                        end
                        h = obj.Job.Hashes(k);
                        if h.src == "" || h.dst == ""
                            bad(end+1) = F.Rel(m) + " could not be read to checksum it" + ternary(h.err == "", "", " (" + h.err + ")"); %#ok<AGROW>
                            F.State(m) = "failed";
                        elseif h.src ~= h.dst
                            bad(end+1) = F.Rel(m) + " SHA-256 differs"; %#ok<AGROW>
                            F.State(m) = "failed";
                        end
                    end
                end
                obj.Batches(i).Files = F;
                if isempty(bad)
                    obj.finishBatch(i);
                else
                    obj.Job.Failed = true;
                    obj.setState(i, "failed", "VERIFICATION FAILED (" + OutputTransfer.listText(bad) + ...
                        "); the copy is kept in " + obj.Batches(i).DestDir);
                end
            end
        end

        function failJob(obj, why)
            %failJob  The engine itself failed: every batch still in the job fails.
            for i = obj.Job.Batches
                if ismember(obj.Batches(i).State, ["copying" "verifying"])
                    obj.failFiles(i);
                    obj.setState(i, "failed", why);
                end
            end
            obj.Job.Failed = true;
            obj.endJob();
        end

        function endJob(obj)
            %endJob  Forget the job; its folder goes unless something failed (robocopy's logs are there).
            if ~obj.Job.Failed && isfolder(obj.Job.Dir)
                try rmdir(obj.Job.Dir, 's'); catch; end
            end
            obj.Job = [];
            obj.Message = "";
        end

        function failFiles(obj, i)
            %failFiles  The files of batch I still to be copied are not copied.
            obj.Batches(i).Files.State(obj.Batches(i).Files.State == "") = "failed";
        end

        function finishBatch(obj, i)
            %finishBatch  Batch I is copied: "done" (a copy) or "copied" (a move,
            %   whose files go once closed). Its changed files go in a batch of
            %   their own.
            b = obj.Batches(i);
            F = b.Files;
            n = nnz(F.State == "copied");
            msg = sprintf("copied %d file(s), %s, to %s", n, OutputTransfer.bytesText(sum(F.Bytes(F.State == "copied"))), b.DestDir);
            kept = nnz(F.State == "kept");
            if kept > 0
                msg = msg + sprintf("; %d already there, left as they were", kept);
            end
            if b.Note ~= ""
                msg = msg + "; " + b.Note;
            end
            again = find(F.State == "changed");
            if ~isempty(again)
                if b.Generation < OutputTransfer.MaxGeneration && ~obj.Canceled
                    obj.followUp(i, OutputTransfer.pick(F, again), "changed while they were copied");
                    msg = msg + sprintf("; %d changed while they were copied and are copied again", numel(again));
                else
                    obj.Batches(i).Files.State(again) = "failed";
                    obj.setState(i, "failed", msg + sprintf("; %d kept changing while they were copied and were not copied", numel(again)));
                    return
                end
            end
            if obj.Method == "move" && n > 0
                obj.setState(i, "copied", msg + OutputTransfer.LaterNote);
            else
                obj.setState(i, "done", msg);
            end
        end

        function followUp(obj, i, F, why)
            %followUp  A batch of its own for files F of batch I (their places kept), copied again.
            b = obj.Batches(i);
            c = OutputTransfer.newBatch();
            c.Id = numel(obj.Batches) + 1;
            c.Key = b.Key;
            c.Dataset = b.Dataset;
            c.Label = b.Label + " (again)";
            c.Base = b.Base;
            c.Keep = b.Keep;
            c.Folders = b.Folders;
            c.OnMoved = b.OnMoved;
            c.DestDir = b.DestDir;
            c.Generation = b.Generation + 1;
            c.Swept = true;
            c.Listed = true;
            c.Files = OutputTransfer.restat(F);
            c.Bytes = sum(c.Files.Bytes, 'omitnan');
            c.Added = datetime('now');
            c.State = "queued";
            obj.Batches(end+1) = c;
            obj.say(c, sprintf("%d file(s) %s", numel(F.Src), why), "queued");
            obj.changed(c.Id);
        end

        % ------------------------------------------------------------- after close
        function sweep(obj)
            %sweep  Once closed, each batch copied before is looked at once
            %   more: its files that changed since, and new files in a folder
            %   it copied, go in a batch of their own.
            for i = find(~[obj.Batches.Swept] & ismember(obj.states(), ["done" "copied"]))
                obj.Batches(i).Swept = true;
                b = obj.Batches(i);
                if b.Generation >= OutputTransfer.MaxGeneration; continue; end
                try
                    cur = OutputTransfer.listFiles(b);
                catch
                    continue
                end
                F = b.Files;
                [isOld, at] = ismember(lower(cur.Src), lower(F.Src));
                again = false(numel(cur.Src), 1);
                for j = find(isOld).'
                    m = at(j);
                    if ismember(F.State(m), ["copied" "removed"])
                        again(j) = ~OutputTransfer.sameFile(cur.Bytes(j), cur.Time(j), F.Bytes(m), F.Time(m));
                    end
                end
                fresh = ~isOld;
                if obj.IfExists == "skip"
                    fresh = fresh & ~OutputTransfer.existsAt(b.DestDir, cur.Rel);
                end
                rows = find(again | fresh);
                if ~isempty(rows)
                    obj.followUp(i, OutputTransfer.pick(cur, rows), "changed or added since the batch was copied");
                end
            end
        end

        function removeMoved(obj)
            %removeMoved  The files a move copied go from here (the transfer is closed).
            for i = find(obj.states() == "copied")
                b = obj.Batches(i);
                F = b.Files;
                cur = OutputTransfer.restat(F);
                keep = ismember(lower(F.Src), lower(b.Keep));
                removed = 0;
                left = 0;
                for m = find(F.State == "copied").'
                    if keep(m); continue; end
                    if ~OutputTransfer.sameFile(cur.Bytes(m), cur.Time(m), F.Bytes(m), F.Time(m))
                        left = left + 1;   % changed since it was copied: it stays
                        continue
                    end
                    try
                        delete(F.Src(m));
                        F.State(m) = "removed";
                        removed = removed + 1;
                    catch
                        left = left + 1;
                    end
                end
                obj.Batches(i).Files = F;
                note = "";
                for folder = b.Folders
                    k = char(lower(folder));
                    if isKey(obj.Moved, k) || ~isempty(OutputTransfer.listFiles(struct('Paths', folder, 'Base', "")).Src)
                        continue   % done before, or some of its files are still here
                    end
                    obj.Moved(k) = true;
                    OutputTransfer.removeEmptyFolders(folder);
                    if isempty(b.OnMoved); continue; end
                    try
                        r = b.OnMoved(folder, string(fullfile(b.DestDir, OutputTransfer.below(folder, b.Base))));
                        if (isstring(r) || ischar(r)) && strlength(string(r)) > 0
                            note = note + "; " + string(r);
                        end
                    catch ME
                        note = note + "; " + string(ME.message);
                    end
                end
                msg = "moved" + extractAfter(erase(b.Message, OutputTransfer.LaterNote), "copied") + ...
                    sprintf(" (%d removed here)", removed);
                if left > 0
                    msg = msg + sprintf("; %d not removed here (changed since they were copied, or in use)", left);
                end
                obj.setState(i, "done", msg + note);
            end
        end
    end

    methods (Static, Access = private)
        function b = newBatch()
            %newBatch  An empty batch: every field a batch has, in order.
            %   Id, Key, Dataset, Label; Paths (as added), Base, Keep;
            %   WaitFor, Since; OnMoved; DestDir (the dataset's folder in the
            %   destination); State, Message, Note; Files (Src, Rel: its path
            %   in DestDir, Bytes and Time as listed, State: "" to copy,
            %   "copied", "kept" (already there), "changed", "failed",
            %   "gone", "removed"); Folders (the folders of Paths); Bytes (to
            %   copy); Listed, Generation, Swept; Added, Started, Finished.
            b = struct('Id', 0, 'Key', "", 'Dataset', "", 'Label', "", ...
                'Paths', strings(1, 0), 'Base', "", 'Keep', strings(1, 0), ...
                'WaitFor', "", 'Since', NaT, 'OnMoved', [], 'DestDir', "", ...
                'State', "", 'Message', "", 'Note', "", 'Files', OutputTransfer.noFiles(), ...
                'Folders', strings(1, 0), 'Bytes', 0, 'Listed', false, 'Generation', 1, ...
                'Swept', false, 'Added', NaT, 'Started', NaT, 'Finished', NaT);
        end

        function s = emptyBatches()
            s = OutputTransfer.newBatch();
            s = s([]);
        end

        function F = noFiles()
            F = struct('Src', strings(0, 1), 'Rel', strings(0, 1), 'Bytes', zeros(0, 1), ...
                'Time', zeros(0, 1), 'State', strings(0, 1));
        end

        function F = pick(F, rows)
            F = struct('Src', F.Src(rows), 'Rel', F.Rel(rows), 'Bytes', F.Bytes(rows), ...
                'Time', F.Time(rows), 'State', F.State(rows));
        end

        function F = append(F, G)
            F = struct('Src', [F.Src; G.Src(:)], 'Rel', [F.Rel; G.Rel(:)], 'Bytes', [F.Bytes; G.Bytes(:)], ...
                'Time', [F.Time; G.Time(:)], 'State', [F.State; strings(numel(G.Src), 1)]);
        end

        function [F, folders] = listFiles(b)
            %listFiles  Every file of B's paths, with its place in the dataset folder (Rel).
            %   B needs Paths and Base. A folder's hidden subfolders are left out.
            F = OutputTransfer.noFiles();
            folders = strings(1, 0);
            for p = reshape(string(b.Paths), 1, [])
                if isfolder(p)
                    folders(end+1) = p; %#ok<AGROW>
                    L = dir(fullfile(p, '**'));
                    L = L(~[L.isdir]);
                    if isempty(L); continue; end
                    sub = string({L.folder}).';
                    below = OutputTransfer.below(sub, p);
                    shown = ~(startsWith(below, ".") | contains(below, filesep + "."));
                    L = L(shown);
                    if isempty(L); continue; end
                    top = OutputTransfer.below(p, b.Base);
                    src = strings(numel(L), 1);
                    rel = strings(numel(L), 1);
                    sub = sub(shown);
                    below = below(shown);
                    for j = 1:numel(L)
                        src(j) = string(fullfile(sub(j), L(j).name));
                        rel(j) = string(fullfile(top, below(j), L(j).name));
                    end
                    F = OutputTransfer.append(F, struct('Src', src, 'Rel', rel, ...
                        'Bytes', [L.bytes].', 'Time', [L.datenum].'));
                elseif isfile(p)
                    L = dir(p);
                    F = OutputTransfer.append(F, struct('Src', p, 'Rel', OutputTransfer.below(p, b.Base), ...
                        'Bytes', L.bytes, 'Time', L.datenum));
                end
            end
        end

        function rel = below(p, base)
            %below  P's path below BASE ("" for BASE itself), or its name when it is not below BASE.
            p = string(p);
            rel = strings(size(p));
            b = strip(replace(string(base), "/", filesep), 'right', filesep);
            for j = 1:numel(p)
                q = strip(replace(p(j), "/", filesep), 'right', filesep);
                if b ~= "" && strcmpi(q, b)
                    rel(j) = "";
                elseif b ~= "" && startsWith(lower(q), lower(b) + filesep)
                    rel(j) = extractAfter(q, strlength(b) + 1);
                else
                    rel(j) = OutputTransfer.nameOf(q);
                end
            end
        end

        function F = restat(F)
            %restat  F with the size and time its sources have now (NaN for one that is gone).
            [folders, ~, g] = unique(OutputTransfer.parentOf(F.Src), 'stable');
            names = lower(OutputTransfer.nameOf(F.Src));
            F.Bytes(:) = NaN;
            F.Time(:) = NaN;
            for k = 1:numel(folders)
                rows = find(g == k);
                L = dir(folders(k));
                L = L(~[L.isdir]);
                [hit, at] = ismember(names(rows), lower(string({L.name})));
                F.Bytes(rows(hit)) = [L(at(hit)).bytes];
                F.Time(rows(hit)) = [L(at(hit)).datenum];
            end
        end

        function S = statAt(destDir, rel)
            %statAt  Size and time of DESTDIR/REL (NaN where there is no file), one listing per folder.
            S = struct('Bytes', nan(numel(rel), 1), 'Time', nan(numel(rel), 1));
            if isempty(rel); return; end
            full = OutputTransfer.joined(destDir, rel);
            [folders, ~, g] = unique(OutputTransfer.parentOf(full), 'stable');
            names = lower(OutputTransfer.nameOf(full));
            for k = 1:numel(folders)
                if ~isfolder(folders(k)); continue; end
                rows = find(g == k);
                L = dir(folders(k));
                L = L(~[L.isdir]);
                [hit, at] = ismember(names(rows), lower(string({L.name})));
                S.Bytes(rows(hit)) = [L(at(hit)).bytes];
                S.Time(rows(hit)) = [L(at(hit)).datenum];
            end
        end

        function tf = existsAt(destDir, rel)
            %existsAt  Whether DESTDIR/REL is already there (a file or a folder).
            tf = false(numel(rel), 1);
            if isempty(rel); return; end
            full = OutputTransfer.joined(destDir, rel);
            [folders, ~, g] = unique(OutputTransfer.parentOf(full), 'stable');
            names = lower(OutputTransfer.nameOf(full));
            for k = 1:numel(folders)
                if ~isfolder(folders(k)); continue; end
                rows = find(g == k);
                L = dir(folders(k));
                tf(rows) = ismember(names(rows), lower(string({L.name})));
            end
        end

        function f = joined(folder, rel)
            f = strings(numel(rel), 1);
            for j = 1:numel(rel)
                f(j) = string(fullfile(folder, rel(j)));
            end
        end

        function p = parentOf(f)
            p = strings(numel(f), 1);
            for j = 1:numel(f)
                p(j) = string(fileparts(f(j)));
            end
        end

        function n = nameOf(f)
            n = strings(numel(f), 1);
            for j = 1:numel(f)
                [~, a, x] = fileparts(f(j));
                n(j) = a + x;
            end
        end

        function tf = sameFile(bytes, time, bytes0, time0)
            %sameFile  The size and the time (to 2 s) are those listed.
            tf = bytes == bytes0 && abs(time - time0) * 86400 <= 2;
        end

        function k = hashKey(session, name)
            k = sprintf('%d|%s', session, lower(name));
        end

        function s = listText(items)
            s = strjoin(items(1:min(3, end)), "; ");
            if numel(items) > 3; s = s + sprintf("; and %d more", numel(items) - 3); end
        end

        function b = sizeOf(paths)
            %sizeOf  The bytes of PATHS (folders without their hidden subfolders), for progress.
            F = OutputTransfer.listFiles(struct('Paths', paths, 'Base', ""));
            b = sum(F.Bytes);
        end

        function removeEmptyFolders(folder)
            %removeEmptyFolders  FOLDER's empty subfolders, deepest first, then FOLDER if it is empty.
            if ~isfolder(folder); return; end
            L = dir(fullfile(folder, '**'));
            L = L([L.isdir] & ~ismember({L.name}, {'.', '..'}));
            sub = string(fullfile({L.folder}, {L.name}));
            [~, order] = sort(strlength(sub), 'descend');
            for s = sub(order)
                if numel(dir(s)) <= 2
                    try rmdir(s); catch; end
                end
            end
            if numel(dir(folder)) <= 2
                try rmdir(folder); catch; end
            end
        end

        function tf = taken(p)
            %taken  P is a file, or a folder that holds anything.
            tf = isfile(p) || (isfolder(p) && numel(dir(p)) > 2);
        end

        function v = freeVersion(f)
            %freeVersion  The first of F_v2, F_v3, ... that is neither a file nor a folder ("" when none up to _v999).
            v = "";
            for n = 2:999
                p = f + "_v" + n;
                if ~isfolder(p) && ~isfile(p)
                    v = p;
                    return
                end
            end
        end

        function tf = olderThan(statusFile, since)
            %olderThan  Whether a sort's status file and exit marker predate SINCE: an earlier run's.
            tf = false;
            if isnat(since); return; end
            files = [string(statusFile), string(fullfile(fileparts(statusFile), EphysDataset.SortExitMarker))];
            t = -Inf;
            for f = files
                L = dir(f);
                if isscalar(L); t = max(t, L.datenum); end
            end
            tf = isfinite(t) && t < datenum(since) - 2 / 86400; %#ok<DATNM> dir reports datenums
        end

        function S = readEngineStatus(f)
            S = struct('state', "error", 'message', "the engine's status file cannot be read");
            for k = 1:5   % it may be caught mid-write
                try
                    txt = fileread(f);
                    if ~isempty(txt) && double(txt(1)) == 65279; txt(1) = []; end
                    s = jsondecode(txt);
                    S.state = string(s.state);
                    S.message = string(s.message);
                    return
                catch
                    pause(0.05);
                end
            end
        end

        function d = jobsFolder()
            %jobsFolder  Where the job folders live: the one copySessions uses,
            %   so its batches see the folders a transfer is writing.
            base = string(getenv('LOCALAPPDATA'));
            if base == ""; base = string(tempdir); end
            d = fullfile(base, "ephys_analysis", "copy_jobs");
        end

        function makeFolder(p)
            if isfolder(p); return; end
            [ok, msg] = mkdir(p);
            if ~ok
                error('OutputTransfer:CannotCreate', 'Cannot create %s: %s', p, msg);
            end
        end

        function b = usableBytes(p)
            %usableBytes  Free space at P, or its nearest existing parent (Inf when unknown).
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
    end
end


function c = cellRow(s)
%cellRow  A 1xN cell of char, so jsonencode always writes a JSON array.
s = string(s(:)).';
c = cell(1, numel(s));
for k = 1:numel(s)
    c{k} = char(s(k));
end
end


function out = ternary(cond, a, b)
if cond; out = string(a); else; out = string(b); end
end
