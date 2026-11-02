classdef RunLock
    %RunLock  A lock file per dataset that tells another session it is in use.
    %   The pipeline writes a dataset's outputs (the .bin, the extracts, the
    %   detections, the sort) for hours, and two sessions - two MATLABs on
    %   this machine, or two machines on one share - that write the same
    %   files corrupt each other. RunLock keeps a small JSON file next to
    %   the dataset's outputs for the time a session works on it, and every
    %   writer asks first.
    %
    %   Two kinds, two files in the dataset's output folder:
    %     "run"   <Name>_run.lock.json   a pipeline run (EphysPipeline.run
    %             takes one for each selected dataset for the whole run and
    %             refreshes its heartbeat as the run reports progress)
    %     "sort"  <Name>_sort.lock.json  a sort run (runKilosort and
    %             runSpikeInterface take it before the .bin is written;
    %             launchSorting records the run's status file in it). A
    %             blocking run gives it up when the sort ends. A background
    %             sort outlives the session that started it, so its lock
    %             stays until the status file says the run ended.
    %
    %   Each file holds kind, host, pid, user, what (a sentence for the
    %   message), run_id, started, heartbeat, heartbeat_epoch and, for a
    %   sort, status_file. A lock is live while
    %     a run lock on this host: its process (pid) is alive;
    %     a run lock on another host: its heartbeat is less than
    %       StaleSeconds old;
    %     a sort lock on this host: the run is going (EphysDataset.
    %       sortRunState "running" with a process left, sortRunProcesses),
    %       or, before the run has a status file, the process that took it
    %       is alive;
    %     a sort lock on another host: the run is going and its log or the
    %       lock was written less than SortStaleSeconds ago.
    %   A lock that is not live is stale: heldElsewhere does not see it and
    %   acquire replaces it. A lock of this MATLAB process is never "held
    %   elsewhere".
    %
    %   Example
    %     [held, info] = RunLock.heldElsewhere(ds);
    %     if held; disp(RunLock.describe(info)); end   % in use by another session (HOST, since ...)
    %
    %   See also EphysPipeline.run, EphysDataset.runKilosort, EphysDataset.launchSorting.

    properties (Constant)
        Kinds = ["run" "sort"]
        StaleSeconds = 600          % a run lock on another host, silent this long, is stale
        SortStaleSeconds = 1800     % a sort lock on another host, silent this long, is stale
        RefreshSeconds = 20         % touch writes the heartbeat at most this often per lock
    end

    methods (Static)
        function f = file(d, kind)
            %file  The lock file of dataset D for KIND ("run" or "sort").
            kind = RunLock.checkKind(kind);
            f = string(fullfile(d.outputFolder(), d.Name + "_" + kind + ".lock.json"));
        end

        function info = read(d, kind)
            %read  The lock of dataset D for KIND as a struct, [] when there is none or it is unreadable.
            info = [];
            f = RunLock.file(d, kind);
            if ~isfile(f); return; end
            s = readJsonFile(f, ErrorOnFail=false);
            if ~(isstruct(s) && isscalar(s) && all(isfield(s, {'host', 'pid'}))); return; end
            info = struct('kind', string(kind), 'host', "", 'pid', NaN, 'user', "", 'what', "", 'run_id', "", ...
                'started', "", 'heartbeat', "", 'heartbeat_epoch', NaN, 'status_file', "");
            for n = string(fieldnames(info)).'
                if isfield(s, n) && ~isempty(s.(n))
                    if isnumeric(info.(n)); info.(n) = double(s.(n)); else; info.(n) = string(s.(n)); end
                end
            end
            info.kind = string(kind);
            info.file = f;
        end

        function [held, info] = heldElsewhere(d, kinds)
            %heldElsewhere  Whether another process holds a live lock on dataset D.
            %   [HELD, INFO] = RunLock.heldElsewhere(D) looks at both kinds
            %   (KINDS restricts it). INFO is the first live lock of another
            %   process (see describe), [] when HELD is false.
            if nargin < 2; kinds = RunLock.Kinds; end
            held = false;
            info = [];
            for kind = string(kinds)
                lk = RunLock.read(d, kind);
                if isempty(lk) || RunLock.isOurs(lk); continue; end
                if RunLock.isLive(lk)
                    held = true;
                    info = lk;
                    return
                end
            end
        end

        function s = describe(info)
            %describe  "in use by another session (HOST, since T): WHAT" for the lock INFO.
            s = "in use by another session (" + info.host + ", since " + info.started + ")";
            if info.what ~= ""; s = s + ": " + info.what; end
        end

        function info = acquire(d, kind, what, opts)
            %acquire  Take dataset D's lock of KIND; RunLock:Held when another process has a live one.
            %   INFO = RunLock.acquire(D, KIND, WHAT, RunId=...): WHAT is the
            %   sentence the other session reads ("pipeline run 'name'"). A
            %   stale lock, or one of this process, is replaced.
            arguments
                d (1,1) EphysDataset
                kind (1,1) string
                what (1,1) string = ""
                opts.RunId (1,1) string = ""
            end
            kind = RunLock.checkKind(kind);
            [held, other] = RunLock.heldElsewhere(d, kind);
            if held
                error('RunLock:Held', '%s is %s.', d.Name, RunLock.describe(other));
            end
            now0 = datetime('now');
            info = struct('kind', kind, 'host', RunLock.hostName(), 'pid', feature('getpid'), ...
                'user', string(getenv('USERNAME')), 'what', what, 'run_id', opts.RunId, ...
                'started', string(now0, 'yyyy-MM-dd HH:mm:ss'), 'heartbeat', string(now0, 'yyyy-MM-dd HH:mm:ss'), ...
                'heartbeat_epoch', RunLock.epoch(), 'status_file', "");
            RunLock.put(d, info);
            lk = RunLock.read(d, kind);   % two sessions at the same moment: the last write stands
            if isempty(lk) || ~RunLock.isOurs(lk)
                error('RunLock:Held', '%s was taken by another session at the same moment.', d.Name);
            end
        end

        function touch(d, kind)
            %touch  Refresh the heartbeat of this process's lock on D (at most every RefreshSeconds).
            persistent last
            if isempty(last); last = containers.Map('KeyType', 'char', 'ValueType', 'double'); end
            f = char(RunLock.file(d, kind));
            t = RunLock.epoch();
            if isKey(last, f) && t - last(f) < RunLock.RefreshSeconds; return; end
            lk = RunLock.read(d, kind);
            if isempty(lk) || ~RunLock.isOurs(lk); return; end
            last(f) = t;
            lk.heartbeat = string(datetime('now'), 'yyyy-MM-dd HH:mm:ss');
            lk.heartbeat_epoch = t;
            RunLock.put(d, lk);
        end

        function setStatusFile(d, statusFile)
            %setStatusFile  Record the status file of the sort run in this process's sort lock on D.
            lk = RunLock.read(d, "sort");
            if isempty(lk) || ~RunLock.isOurs(lk); return; end
            lk.status_file = string(statusFile);
            lk.heartbeat = string(datetime('now'), 'yyyy-MM-dd HH:mm:ss');
            lk.heartbeat_epoch = RunLock.epoch();
            RunLock.put(d, lk);
        end

        function release(d, kind)
            %release  Delete this process's lock of KIND on D (another process's is left).
            lk = RunLock.read(d, kind);
            if ~isempty(lk) && RunLock.isOurs(lk) && isfile(lk.file)
                try
                    delete(lk.file);
                catch
                    % a lock that cannot be removed ages out
                end
            end
        end

        function releaseEnded(d)
            %releaseEnded  Delete D's sort lock when the run it records has ended, whoever took it.
            lk = RunLock.read(d, "sort");
            if isempty(lk) || lk.status_file == ""; return; end
            if EphysDataset.sortRunState(lk.status_file) ~= "running" && isfile(lk.file)
                try
                    delete(lk.file);
                catch
                end
            end
        end
    end

    methods (Static, Access = private)
        function kind = checkKind(kind)
            kind = string(kind);
            if ~ismember(kind, RunLock.Kinds)
                error('RunLock:BadKind', 'A lock kind is "run" or "sort", not "%s".', kind);
            end
        end

        function put(d, info)
            s = rmfield(info, intersect('file', fieldnames(info)));
            writeJsonFile(RunLock.file(d, info.kind), s);
        end

        function tf = isOurs(info)
            tf = strcmpi(info.host, RunLock.hostName()) && info.pid == feature('getpid');
        end

        function tf = isLive(info)
            %isLive  Whether the lock INFO of another process is still held (see the class help).
            sameHost = strcmpi(info.host, RunLock.hostName());
            hasRun = info.kind == "sort" && info.status_file ~= "";
            if hasRun && EphysDataset.sortRunState(info.status_file) ~= "running"
                tf = false;   % the sort has ended
                return
            end
            if sameHost
                alive = RunLock.pidAlive(info.pid);
                if hasRun
                    n = EphysDataset.sortRunProcesses(info.status_file);   % NaN: the search failed, taken as going
                    alive = alive || ~(n == 0);
                end
                tf = alive;
                return
            end
            age = RunLock.epoch() - info.heartbeat_epoch;
            limit = RunLock.StaleSeconds;
            if hasRun
                limit = RunLock.SortStaleSeconds;
                logAge = RunLock.logAge(info.status_file);
                age = min(age, logAge);
            end
            tf = isfinite(age) && age < limit;
        end

        function a = logAge(statusFile)
            %logAge  Seconds since the log beside STATUSFILE was last written, Inf without one.
            a = Inf;
            folder = fileparts(char(statusFile));
            for name = ["ks4_run.log" "si_run.log"]
                L = dir(fullfile(folder, name));
                if ~isempty(L); a = min(a, (now - L(1).datenum) * 86400); end %#ok<TNOW1>
            end
        end

        function tf = pidAlive(pid)
            %pidAlive  Whether process PID exists on this machine.
            if ~(isfinite(pid) && pid > 0); tf = false; return; end
            if ispc
                [st, out] = system(sprintf('tasklist /FI "PID eq %d" /FO CSV /NH', pid));
                tf = st == 0 && contains(string(out), sprintf('"%d"', pid));
            else
                tf = system(sprintf('kill -0 %d 2>/dev/null', pid)) == 0;
            end
        end

        function t = epoch()
            %epoch  Seconds since 1970-01-01 UTC, now.
            t = posixtime(datetime('now', 'TimeZone', 'UTC'));
        end

        function h = hostName()
            %hostName  This machine's name.
            persistent name
            if isempty(name)
                name = string(getenv('COMPUTERNAME'));
                if strlength(name) == 0
                    [st, out] = system('hostname');
                    if st == 0; name = strtrim(string(out)); end
                end
                if strlength(name) == 0; name = "unknown"; end
            end
            h = name;
        end
    end
end
