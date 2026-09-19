classdef CopySchedule
    %CopySchedule  Copy new sessions from the source at an interval, without MATLAB open.
    %   A schedule is the Copy tab's settings (the subjects, the source roots
    %   and the destination, the pairing and copy options) plus how often to
    %   run and how many days back to look. CopySchedule saves them as a JSON
    %   file and creates a Windows Task Scheduler task that starts MATLAB in
    %   the background (MATLAB -batch: no desktop, no window) at that interval.
    %   Each run finds the subjects' sessions of the last few days
    %   (findCopySessions), copies the ones that are not there yet
    %   (copySessions) and exits. Neither the app nor any MATLAB has to be
    %   open: the copies go on for as long as the computer is on (and, by
    %   default, someone is signed in; see RunWhen). The app's Copy tab edits
    %   the schedule and shows how its last run went.
    %
    %     sch = CopySchedule;                   % this Windows user's schedule
    %     s = CopySchedule.defaults();
    %     s.Subjects = "SUBJ-ID-1255";
    %     sch.save(s);                          % write the settings, create the task
    %     st = sch.status();                    % the task, its next run, the last run
    %     sch.startNow();                       % a run now, in the background
    %     sch.remove();                         % delete the task (copies are kept)
    %
    %     out = CopySchedule.copyNew(s);        % one run's work, in this MATLAB
    %
    %   What a run copies. For each subject, the sessions of the days
    %   [today - LookBackDays + 1, today] are found and paired as Find sessions
    %   pairs them, and the paired ones are copied (IncludeUnpaired adds the
    %   recording-only and ePsych-only ones) with IfExists and Verify as set: a
    %   session already copied is recognised by its sizes and left alone, and
    %   one copied part way is completed. A run leaves alone, and reports:
    %     ambiguous         a pairing that is ambiguous (never copied
    %                       automatically, as on the Copy tab)
    %     needs_stitching   a paired recording with another ePsych file that
    %                       starts during it: ePsych was restarted, and the
    %                       files are to be stitched by hand on the Copy tab
    %     stitched_by_hand  a session whose copy was made by hand, stitched
    %                       (its session_manifest.json says so)
    %     unpaired          a recording-only or ePsych-only session, unless
    %                       IncludeUnpaired
    %     skipped           a session whose source changed within the last
    %                       QuietMin minutes (still being recorded, or synced
    %                       to the source?), or that another copy is writing
    %                       at that moment (copySessions); a later run takes it
    %
    %   Settings (CopySchedule.defaults)
    %     Subjects          subject IDs (string array)
    %     EpsychRoot, DestRoot
    %     RecordingRoots    roots of the recording folders (string array, or one
    %                       string of them separated by semicolons); the folder
    %                       names are matched with findCopySessions' default
    %                       NamePatterns (Intan RHX and Open Ephys GUI)
    %     MaxLeadMin, MaxLagMin, MarginSec, MinDurationMin
    %                       pairing, as findCopySessions (minutes / seconds)
    %     Verify            "size" (default) | "hash"
    %     IfExists          "resume" (default) | "skip" | "error"
    %     IncludeUnpaired   (default false)
    %     EveryMin          minutes between runs, 5 to 1440 (default 60). Runs
    %                       are on the clock: every 60 min is on the hour
    %     LookBackDays      days each run searches, ending today (default 3)
    %     QuietMin          minutes a session's source must have been unchanged
    %                       before it is copied (default 15)
    %     RunWhen           "signed_in" (default): runs while this Windows user
    %                       is signed in, with the screen locked or not; no
    %                       password is needed. "always": also while signed out
    %                       and after a restart; Windows asks for the user's
    %                       password once, in a console window of its own, and
    %                       keeps it with the task (save again after a password
    %                       change). Some accounts are not allowed to run tasks
    %                       while signed out, and Windows then refuses it. Drive
    %                       letters of network shares exist only inside a
    %                       sign-in, so they are saved as UNC paths
    %   save also records Start (the first run), Code (the pipeline folder the
    %   task runs), Matlab (the MATLAB it starts), Saved and SavedBy.
    %
    %   The task. "\ephys_analysis\Copy sessions (<user>)" starts at the
    %   interval, never twice at once, also on battery; a run missed while the
    %   computer was off or asleep starts as soon as it is back, and a run is
    %   stopped after 12 h. It runs
    %     <Matlab>\bin\win64\MATLAB.exe -sd <Folder> -batch "addpath('<Code>');
    %       exit(CopySchedule.runTask('<Folder>\schedule.json'))" -logfile <Folder>\matlab.log
    %   Starting in Folder, MATLAB runs the empty startup.m kept there rather
    %   than the user's own. Save the schedule again after moving the code or
    %   changing MATLAB.
    %
    %   Files, in Folder (default %LOCALAPPDATA%\ephys_analysis\copy_schedule)
    %     schedule.json       the settings
    %     copy_schedule.log   every run's log, appended (the previous 5 MB are
    %                         kept in copy_schedule.1.log)
    %     last_run.json       the last run: state, start and finish, what it
    %                         did with each session
    %     matlab.log          MATLAB's own output of the last run
    %     task.xml            the task definition, as created
    %     startup.m           see above
    %
    %   See also findCopySessions, copySessions, EphysPreprocessingApp.

    properties (SetAccess = immutable)
        Folder (1,1) string     % the settings, the log and the last run's summary
        TaskName (1,1) string   % the Windows Task Scheduler task, with its folder
    end

    properties (Constant)
        TaskFolder = "\ephys_analysis"
        % What a run can do with a session: copySessions' CopyStatus values,
        % then the reasons a run leaves one alone.
        Statuses = ["copied", "already_present", "skipped", "failed", "cancelled", ...
            "ambiguous", "unpaired", "needs_stitching", "stitched_by_hand"]
    end

    methods
        function obj = CopySchedule(opts)
            %CopySchedule  This Windows user's schedule, or one elsewhere (for tests).
            arguments
                opts.Folder (1,1) string = CopySchedule.defaultFolder()
                opts.TaskName (1,1) string = CopySchedule.defaultTaskName()
            end
            obj.Folder = opts.Folder;
            obj.TaskName = opts.TaskName;
        end

        function f = settingsFile(obj)
            %settingsFile  The saved settings: schedule.json in Folder.
            f = fullfile(obj.Folder, "schedule.json");
        end

        function f = logFile(obj)
            %logFile  Every run's log: copy_schedule.log in Folder.
            f = fullfile(obj.Folder, "copy_schedule.log");
        end

        function s = read(obj)
            %read  The saved settings, or [] when none are saved.
            s = [];
            if isfile(obj.settingsFile())
                s = CopySchedule.normalize(readJsonFile(obj.settingsFile()));
            end
        end

        function s = save(obj, s)
            %save  Save the settings and create (or replace) the Windows task.
            %   Returns S as saved: normalized, network drive letters turned
            %   into UNC paths for RunWhen "always", and Start, Code, Matlab,
            %   Saved and SavedBy filled in. The settings file is replaced only
            %   once Windows has accepted the task, so a refused password leaves
            %   an earlier schedule as it was.
            if ~ispc
                error('CopySchedule:NotWindows', 'A scheduled copy needs Windows Task Scheduler.');
            end
            s = CopySchedule.normalize(s);
            if s.RunWhen == "always"
                for f = ["EpsychRoot", "DestRoot"]
                    s.(f) = CopySchedule.uncPath(s.(f));
                end
                s.RecordingRoots = arrayfun(@CopySchedule.uncPath, s.RecordingRoots);
            end
            now_ = datetime('now');
            s.Start = isoText(nextStart(now_, s.EveryMin));
            s.Code = string(fileparts(mfilename('fullpath')));
            s.Matlab = string(matlabroot);
            s.Saved = isoText(now_);
            s.SavedBy = windowsUser() + " on " + hostName();

            makeFolder(obj.Folder);
            writeStartup(obj.Folder);
            pending = obj.settingsFile() + ".new";
            writeJsonFile(pending, s);
            cleanup = onCleanup(@() deleteIfFile(pending));
            xmlFile = fullfile(obj.Folder, "task.xml");
            writeUtf16(xmlFile, CopySchedule.taskXml(s, obj.TaskName, obj.settingsFile()));
            if s.RunWhen == "always"
                registerWithPassword(obj, xmlFile);
            else
                [status, out] = system(sprintf('schtasks /Create /TN "%s" /XML "%s" /F', obj.TaskName, xmlFile));
                if status ~= 0
                    error('CopySchedule:NotCreated', 'Windows Task Scheduler did not create the task: %s', strtrim(out));
                end
            end
            [ok, msg] = movefile(pending, obj.settingsFile(), 'f');
            if ~ok
                error('CopySchedule:CannotWrite', 'The task was created, but its settings could not be saved: %s', msg);
            end
        end

        function remove(obj)
            %remove  Delete the task and the saved settings.
            %   Copies already made are not touched, and the log and the last
            %   run's summary are kept.
            if ispc
                [t, folder] = findTask(obj.TaskName);
                if ~isempty(t)
                    folder.DeleteTask(t.Name, 0);
                end
                removeEmptyTaskFolder(obj.TaskName);
            end
            deleteIfFile(obj.settingsFile());
            deleteIfFile(fullfile(obj.Folder, "task.xml"));
        end

        function st = status(obj)
            %status  Whether the task exists, when it runs next and how the last run went.
            %   ST has
            %     Scheduled   the task exists
            %     Enabled     it is enabled
            %     Running     a run is under way
            %     RunWhen     "signed_in" | "always" (from the task; "" without one)
            %     EveryMin    minutes between runs (from the task; NaN without one)
            %     NextRun     datetime of the next run (NaT when none)
            %     LastResult  Task Scheduler's last result code (NaN without a task)
            %     Problem     what keeps the schedule from working, in words ("" when nothing)
            %     Settings    the saved settings ([] when none)
            %     LastRun     the last run's summary ([] when there has been none):
            %                 State ("running" | "done" | "failed"), Started, Finished
            %                 (datetimes), Days, Errors, Sessions (a table as copyNew's)
            st = struct('Scheduled', false, 'Enabled', false, 'Running', false, 'RunWhen', "", ...
                'EveryMin', NaN, 'NextRun', NaT, 'LastResult', NaN, 'Problem', "", ...
                'Settings', [], 'LastRun', readLastRun(obj.Folder));
            try
                st.Settings = obj.read();
            catch ME
                st.Problem = "its settings cannot be read (" + ME.message + "); Save schedule again";
            end
            if ~ispc
                st.Problem = "a scheduled copy needs Windows Task Scheduler";
                return
            end
            t = findTask(obj.TaskName);
            if isempty(t)
                if ~isempty(st.Settings)
                    st.Problem = "its Windows task is missing (deleted outside the app?); Save schedule creates it again";
                end
                return
            end
            st.Scheduled = true;
            st.Enabled = logical(t.Enabled);
            st.Running = double(t.State) == 4;        % TASK_STATE_RUNNING
            st.LastResult = double(t.LastTaskResult);
            def = t.Definition;
            switch double(def.Principal.LogonType)
                case 1; st.RunWhen = "always";        % TASK_LOGON_PASSWORD
                case 3; st.RunWhen = "signed_in";     % TASK_LOGON_INTERACTIVE_TOKEN
            end
            [start, st.EveryMin] = triggerTimes(def);
            if st.Enabled && ~isnat(start)
                st.NextRun = nextRun(start, st.EveryMin, datetime('now'));
            end
            if st.Problem == ""
                st.Problem = problemText(st);
            end
        end

        function startNow(obj)
            %startNow  Start a run now, as the task (returns at once).
            if ~ispc
                error('CopySchedule:NotWindows', 'A scheduled copy needs Windows Task Scheduler.');
            end
            t = findTask(obj.TaskName);
            if isempty(t)
                error('CopySchedule:NotScheduled', 'There is no scheduled copy to run: save the schedule first.');
            end
            if double(t.State) == 4
                error('CopySchedule:Running', 'A scheduled run is already under way.');
            end
            if ~t.Enabled
                error('CopySchedule:Disabled', 'The scheduled copy''s task is disabled in Windows Task Scheduler.');
            end
            t.Run('');
        end
    end

    methods (Static)
        function s = defaults()
            %defaults  The settings of a new schedule (see the class help).
            s = struct( ...
                'Subjects', strings(1, 0), ...
                'EpsychRoot', "S:/RIG3_Backup_2025/epsych_files/Data", ...
                'RecordingRoots', "S:/RIG3_Backup_2025/intan_files/Data", ...
                'DestRoot', "D:/EPHYS", ...
                'MaxLeadMin', 10, 'MaxLagMin', 2, 'MarginSec', 30, 'MinDurationMin', 2, ...
                'Verify', "size", 'IfExists', "resume", 'IncludeUnpaired', false, ...
                'EveryMin', 60, 'LookBackDays', 3, 'QuietMin', 15, 'RunWhen', "signed_in", ...
                'Start', "", 'Code', "", 'Matlab', "", 'Saved', "", 'SavedBy', "");
        end

        function s = normalize(s)
            %normalize  Settings with the defaults filled in, types fixed and values checked.
            %   Errors with CopySchedule:BadSettings naming the first bad value.
            %   Subjects may be one string of IDs separated by commas, semicolons
            %   or spaces. Fields that are not settings are dropped.
            if ~isstruct(s) || ~isscalar(s)
                error('CopySchedule:BadSettings', 'The settings must be a scalar struct.');
            end
            d = CopySchedule.defaults();
            for f = string(fieldnames(d)).'
                if isfield(s, f) && ~(isnumeric(s.(f)) && isempty(s.(f)))
                    d.(f) = s.(f);
                end
            end
            s = d;
            s.Subjects = subjectList(s.Subjects);
            if isempty(s.Subjects)
                error('CopySchedule:BadSettings', 'Name at least one subject to copy.');
            end
            for f = ["EpsychRoot", "DestRoot"]
                s.(f) = strtrim(string(s.(f)));
                if ~isscalar(s.(f)) || s.(f) == ""
                    error('CopySchedule:BadSettings', '%s must be a folder.', f);
                end
            end
            s.RecordingRoots = rootList(s.RecordingRoots);
            if isempty(s.RecordingRoots)
                error('CopySchedule:BadSettings', 'RecordingRoots must name at least one folder.');
            end
            s.MaxLeadMin = number(s.MaxLeadMin, "MaxLeadMin", 0, Inf, false);
            s.MaxLagMin = number(s.MaxLagMin, "MaxLagMin", 0, Inf, false);
            s.MarginSec = number(s.MarginSec, "MarginSec", 0, Inf, false);
            s.MinDurationMin = number(s.MinDurationMin, "MinDurationMin", 0, Inf, false);
            s.EveryMin = number(s.EveryMin, "EveryMin", 5, 1440, true);
            s.LookBackDays = number(s.LookBackDays, "LookBackDays", 1, 366, true);
            s.QuietMin = number(s.QuietMin, "QuietMin", 0, 1440, false);
            s.Verify = member(s.Verify, "Verify", ["size", "hash"]);
            s.IfExists = member(s.IfExists, "IfExists", ["resume", "skip", "error"]);
            s.RunWhen = member(s.RunWhen, "RunWhen", ["signed_in", "always"]);
            if ~(islogical(s.IncludeUnpaired) || isnumeric(s.IncludeUnpaired)) || ~isscalar(s.IncludeUnpaired)
                error('CopySchedule:BadSettings', 'IncludeUnpaired must be true or false.');
            end
            s.IncludeUnpaired = logical(s.IncludeUnpaired);
            for f = ["Start", "Code", "Matlab", "Saved", "SavedBy"]
                s.(f) = strjoin(string(s.(f)), "");
            end
        end

        function out = copyNew(s, opts)
            %copyNew  One run's work, in this MATLAB: find the new sessions and copy them.
            %   OUT = CopySchedule.copyNew(S) searches each subject of S over
            %   the last S.LookBackDays days and copies what a scheduled run
            %   copies (see the class help). It asks nothing and opens nothing.
            %   OUT has
            %     Days      [first last] day searched
            %     Sessions  table (Subject, Session, DestDir, Status, Message),
            %               one row per session found; Status is one of
            %               CopySchedule.Statuses
            %     Errors    what stopped a subject, or the whole run (strings)
            %   Options: LogFcn (default: print), Today (default: today).
            arguments
                s (1,1) struct
                opts.LogFcn = []
                opts.Today (1,1) datetime = datetime('today')
            end
            logFcn = opts.LogFcn;
            if isempty(logFcn); logFcn = @(m) fprintf('%s\n', m); end
            s = CopySchedule.normalize(s);
            day1 = dateshift(opts.Today, 'start', 'day');
            day0 = day1 - days(s.LookBackDays - 1);
            out = struct('Days', [day0 day1], 'Sessions', emptySessions(), 'Errors', strings(0, 1));
            if ~isfolder(s.DestRoot)
                out.Errors(end+1, 1) = "the destination " + s.DestRoot + " does not exist (is its disk connected?); nothing was copied";
                logFcn("ERROR: " + out.Errors(end));
                return
            end
            for subj = s.Subjects
                try
                    T = findCopySessions(subj, [day0 day1], EpsychRoot=s.EpsychRoot, RecordingRoots=s.RecordingRoots, ...
                        DestRoot=s.DestRoot, MaxLeadTime=minutes(s.MaxLeadMin), MaxLagTime=minutes(s.MaxLagMin), ...
                        AmbiguityMargin=seconds(s.MarginSec), MinRecordingDuration=minutes(s.MinDurationMin), ...
                        LogFcn=logFcn);
                catch ME
                    out.Errors(end+1, 1) = subj + ": " + ME.message;
                    logFcn("ERROR: " + out.Errors(end));
                    continue
                end
                [status, message] = withheld(T, s);
                take = status == "";
                for r = find(~take).'
                    logFcn(sprintf("%s: %s - %s", leafName(T.DestDir(r)), status(r), message(r)));
                end
                if any(take)
                    try
                        R = copySessions(T(take, :), DestRoot=s.DestRoot, DryRun=false, IfExists=s.IfExists, ...
                            IncludeUnpaired=s.IncludeUnpaired, Verify=s.Verify, MinQuietTime=minutes(s.QuietMin), ...
                            LogFcn=logFcn);
                        status(take) = R.CopyStatus;
                        message(take) = R.Message;
                        T.DestDir(take) = R.DestDir;
                    catch ME
                        out.Errors(end+1, 1) = subj + ": " + ME.message;
                        logFcn("ERROR: " + out.Errors(end));
                        status(take) = "failed";
                        message(take) = "not copied: " + ME.message;
                    end
                end
                n = height(T);
                out.Sessions = [out.Sessions; table(repmat(subj, n, 1), leafName(T.DestDir), T.DestDir, ...
                    status, message, 'VariableNames', out.Sessions.Properties.VariableNames)];
            end
        end

        function code = runTask(file)
            %runTask  One scheduled run, as the task runs it: returns MATLAB's exit code.
            %   Reads the settings in FILE, runs copyNew and keeps its record
            %   next to FILE: every line in copy_schedule.log, the outcome in
            %   last_run.json (written once when the run starts, with State
            %   "running", and again when it ends). Returns 0 when everything
            %   went through and 1 when a session failed or the run could not
            %   do its work (the source or the destination not there, bad
            %   settings); Task Scheduler shows it as the task's last result.
            arguments
                file (1,1) string
            end
            folder = fileparts(file);
            logFile = fullfile(folder, "copy_schedule.log");
            lastFile = fullfile(folder, "last_run.json");
            rotateLog(logFile);
            logFcn = @(m) appendLine(logFile, m);
            info = struct('State', "running", 'Started', isoText(datetime('now')), 'Finished', "", ...
                'Host', hostName(), 'User', windowsUser(), 'Pid', feature('getpid'), ...
                'Days', strings(1, 0), 'Errors', strings(0, 1), 'Sessions', []);
            writeJsonFile(lastFile, info);
            code = 1;
            try
                s = CopySchedule.normalize(readJsonFile(file));
                logFcn(sprintf("Scheduled copy started: %s, the last %d day(s), to %s (process %d on %s).", ...
                    strjoin(s.Subjects, ", "), s.LookBackDays, s.DestRoot, info.Pid, info.Host));
                out = CopySchedule.copyNew(s, LogFcn=logFcn);
                info.Days = string(out.Days, 'yyyy-MM-dd');
                info.Errors = out.Errors;
                if height(out.Sessions) > 0
                    info.Sessions = table2struct(out.Sessions);
                end
                failed = ~isempty(out.Errors) || any(out.Sessions.Status == "failed");
                info.State = ternary(failed, "failed", "done");
                code = double(failed);
                summary = CopySchedule.countText(out.Sessions.Status);
                if ~isempty(out.Errors)
                    summary = strtrim(strjoin(out.Errors, "; ") + ". " + ternary(height(out.Sessions) > 0, summary, ""));
                end
            catch ME
                info.State = "failed";
                info.Errors = string(ME.message);
                summary = "the run stopped: " + ME.message;
                logFcn("ERROR: " + getReport(ME, 'basic', 'hyperlinks', 'off'));
            end
            info.Finished = isoText(datetime('now'));
            writeJsonFile(lastFile, info);
            logFcn(sprintf("Scheduled copy %s: %s", info.State, summary));
        end

        function s = countText(status)
            %countText  "2 copied, 1 already present" for a list of session statuses.
            status = string(status);
            names = CopySchedule.Statuses;
            n = arrayfun(@(x) nnz(status == x), names);
            if ~any(n)
                s = "no sessions in those days.";
                return
            end
            s = strjoin(compose("%d %s", n(n > 0).', replace(names(n > 0).', "_", " ")), ", ") + ".";
        end

        function xml = taskXml(s, taskName, settingsFile)
            %taskXml  The Task Scheduler definition (XML, schema 1.2) of a schedule.
            arguments
                s (1,1) struct
                taskName (1,1) string
                settingsFile (1,1) string
            end
            s = CopySchedule.normalize(s);
            folder = string(fileparts(settingsFile));
            ml = s.Matlab;
            if ml == ""; ml = string(matlabroot); end
            code = s.Code;
            if code == ""; code = string(fileparts(mfilename('fullpath'))); end
            start = s.Start;
            if start == ""; start = isoText(nextStart(datetime('now'), s.EveryMin)); end
            statement = sprintf("addpath('%s'); exit(CopySchedule.runTask('%s'))", ...
                replace(code, "'", "''"), replace(settingsFile, "'", "''"));
            args = sprintf('-sd "%s" -batch "%s" -logfile "%s"', folder, statement, fullfile(folder, "matlab.log"));
            logon = ternary(s.RunWhen == "always", "Password", "InteractiveToken");
            user = windowsUser();
            description = sprintf("Copies new recording sessions of %s to %s every %d min. " + ...
                "Made by ephys_analysis (CopySchedule); change it on the Copy tab of EphysPreprocessingApp.", ...
                strjoin(s.Subjects, ", "), s.DestRoot, s.EveryMin);
            lines = [
                "<?xml version=""1.0"" encoding=""UTF-16""?>"
                "<Task version=""1.2"" xmlns=""http://schemas.microsoft.com/windows/2004/02/mit/task"">"
                "  <RegistrationInfo>"
                "    <Author>" + esc(user) + "</Author>"
                "    <Description>" + esc(description) + "</Description>"
                "    <URI>" + esc(taskName) + "</URI>"
                "  </RegistrationInfo>"
                "  <Triggers>"
                "    <TimeTrigger>"
                "      <Repetition>"
                "        <Interval>PT" + s.EveryMin + "M</Interval>"
                "        <StopAtDurationEnd>false</StopAtDurationEnd>"
                "      </Repetition>"
                "      <StartBoundary>" + start + "</StartBoundary>"
                "      <Enabled>true</Enabled>"
                "    </TimeTrigger>"
                "  </Triggers>"
                "  <Principals>"
                "    <Principal id=""Author"">"
                "      <UserId>" + esc(user) + "</UserId>"
                "      <LogonType>" + logon + "</LogonType>"
                "      <RunLevel>LeastPrivilege</RunLevel>"
                "    </Principal>"
                "  </Principals>"
                "  <Settings>"
                "    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>"
                "    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>"
                "    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>"
                "    <AllowHardTerminate>true</AllowHardTerminate>"
                "    <StartWhenAvailable>true</StartWhenAvailable>"
                "    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>"
                "    <IdleSettings>"
                "      <StopOnIdleEnd>false</StopOnIdleEnd>"
                "      <RestartOnIdle>false</RestartOnIdle>"
                "    </IdleSettings>"
                "    <AllowStartOnDemand>true</AllowStartOnDemand>"
                "    <Enabled>true</Enabled>"
                "    <Hidden>false</Hidden>"
                "    <RunOnlyIfIdle>false</RunOnlyIfIdle>"
                "    <WakeToRun>false</WakeToRun>"
                "    <ExecutionTimeLimit>PT12H</ExecutionTimeLimit>"
                "    <Priority>7</Priority>"
                "  </Settings>"
                "  <Actions Context=""Author"">"
                "    <Exec>"
                "      <Command>" + esc(fullfile(ml, "bin", "win64", "MATLAB.exe")) + "</Command>"
                "      <Arguments>" + esc(args) + "</Arguments>"
                "      <WorkingDirectory>" + esc(folder) + "</WorkingDirectory>"
                "    </Exec>"
                "  </Actions>"
                "</Task>"];
            xml = char(strjoin(lines, newline) + newline);
        end

        function p = uncPath(p)
            %uncPath  A path on a mapped network drive, spelled with the share's UNC path.
            %   "S:/data" becomes "\\server\share\data" when S: is a mapped
            %   network drive; any other path comes back as it is. A drive
            %   letter exists only inside a sign-in, so a task that runs signed
            %   out has to name the share itself.
            p = string(p);
            tok = regexp(p, '^([A-Za-z]):(.*)$', 'tokens', 'once');
            if isempty(tok) || ~ispc; return; end
            remote = mappedDrive(upper(tok(1)));
            if remote == ""; return; end
            rest = replace(tok(2), "/", "\");
            if rest ~= "" && ~startsWith(rest, "\"); rest = "\" + rest; end
            p = strip(remote, "right", "\") + rest;
        end

        function f = defaultFolder()
            %defaultFolder  %LOCALAPPDATA%\ephys_analysis\copy_schedule (tempdir without LOCALAPPDATA).
            base = string(getenv('LOCALAPPDATA'));
            if base == ""; base = string(tempdir); end
            f = fullfile(base, "ephys_analysis", "copy_schedule");
        end

        function n = defaultTaskName()
            %defaultTaskName  "\ephys_analysis\Copy sessions (<user>)": one task per Windows user.
            user = string(getenv('USERNAME'));
            if user == ""; user = string(getenv('USER')); end
            n = CopySchedule.TaskFolder + "\Copy sessions (" + user + ")";
        end
    end
end


% =============================================================================
% what a run leaves alone
% =============================================================================

function [status, message] = withheld(T, s)
%withheld  Why a scheduled run leaves each row alone ("" for the rows it copies).
n = height(T);
status = strings(n, 1);
message = strings(n, 1);
st = T.Status;

amb = st == "ambiguous";
status(amb) = "ambiguous";
message(amb) = regexprep(T.Note(amb), "^ambiguous: ", "") + "; pair it by hand on the Copy tab";
unpaired = ismember(st, ["recording_only", "epsych_only"]);
if ~s.IncludeUnpaired
    status(unpaired) = "unpaired";
    message(unpaired) = T.Note(unpaired) + "; not copied automatically";
end

% An ePsych file that starts during a paired recording: ePsych was
% restarted, and its files belong stitched together, which a person decides.
for p = find(st == "paired").'
    if isnan(T.RecordingDuration(p)); continue; end
    during = find(st == "epsych_only" & T.EpsychTime >= T.RecordingTime(p) ...
        & T.EpsychTime <= T.RecordingTime(p) + T.RecordingDuration(p));
    if isempty(during); continue; end
    rows = [p; during];
    status(rows) = "needs_stitching";
    message(rows) = leafName(T.RecordingDir(p)) + " has more than one ePsych file (" + ...
        strjoin(leafName(T.EpsychFile(rows)), ", ") + "): stitch them on the Copy tab, then copy";
end

% A session copied by hand with stitched ePsych files keeps that copy:
% copying its paired row would add a second behavior file to the folder.
for r = find(status == "").'
    if stitchedCopy(T.DestDir(r))
        status(r) = "stitched_by_hand";
        message(r) = "copied by hand with stitched ePsych files; left as it is";
    end
end
end


function tf = stitchedCopy(dest)
tf = false;
f = fullfile(dest, "session_manifest.json");
if ~isfile(f); return; end
try
    m = jsondecode(fileread(f));
    tf = isfield(m, 'pairingStatus') && string(m.pairingStatus) == "stitched";
catch
end
end


function T = emptySessions()
T = table(strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), ...
    'VariableNames', {'Subject', 'Session', 'DestDir', 'Status', 'Message'});
end


% =============================================================================
% the task
% =============================================================================

function registerWithPassword(obj, xmlFile)
%registerWithPassword  Create the task to run signed in or not: Windows asks for the password.
%   schtasks prompts for it (/RP *) in a console window of its own, so the
%   password goes from the keyboard to Windows and never passes through
%   MATLAB or a file. MATLAB waits until the window is closed.
cmdFile = fullfile(obj.Folder, "register_task.cmd");
resultFile = fullfile(obj.Folder, "register_task.result");
deleteIfFile(resultFile);
lines = [
    "@echo off"
    "chcp 65001 >nul"
    "title Scheduled copy: your Windows password"
    "echo The scheduled copy is set to run even while you are signed out of Windows."
    "echo Windows needs your password once to allow that. Task Scheduler keeps it"
    "echo with the task; the ephys_analysis app never sees it."
    "echo."
    sprintf("schtasks /Create /TN ""%s"" /XML ""%s"" /RU ""%s"" /RP * /F", obj.TaskName, xmlFile, windowsUser())
    "set RESULT=%ERRORLEVEL%"
    sprintf(">""%s"" echo %%RESULT%%", resultFile)
    "if not ""%RESULT%""==""0"" pause"];
writeText(cmdFile, strjoin(lines, char([13 10])) + char([13 10]));
cleanup = onCleanup(@() cellfun(@deleteIfFile, {cmdFile, resultFile}));
system(sprintf('start "Scheduled copy" /wait cmd /c ""%s""', cmdFile));
result = "";
if isfile(resultFile)
    result = strtrim(string(fileread(resultFile)));
end
if result ~= "0"
    error('CopySchedule:NotCreated', ['Windows did not create the task: the password window was closed, ' ...
        'or the password, or this account running tasks while signed out, was refused.']);
end
end


function [t, folder] = findTask(taskName)
%findTask  The registered task (COM IRegisteredTask) and its folder; [] when missing.
%   Folders and tasks are looked up by listing them, so a missing one is
%   told from a failure without reading a (translated) error message.
t = [];
[folderPath, name] = splitTaskName(taskName);
svc = actxserver('Schedule.Service');
svc.Connect();
folder = svc.GetFolder('\');
for part = split(strip(folderPath, "\"), "\").'
    if part == ""; continue; end
    subs = folder.GetFolders(0);
    found = [];
    for i = 1:subs.Count
        f = subs.Item(i);
        if strcmpi(f.Name, part); found = f; break; end
    end
    if isempty(found)
        folder = [];
        return
    end
    folder = found;
end
tasks = folder.GetTasks(1);   % TASK_ENUM_HIDDEN: every task
for i = 1:tasks.Count
    x = tasks.Item(i);
    if strcmpi(x.Name, name)
        t = x;
        return
    end
end
end


function removeEmptyTaskFolder(taskName)
%removeEmptyTaskFolder  Delete the task's folder once nothing is left in it.
folderPath = splitTaskName(taskName);
if strip(folderPath, "\") == ""; return; end
[~, folder] = findTask(taskName);
if isempty(folder); return; end
tasks = folder.GetTasks(1);
subs = folder.GetFolders(0);
if tasks.Count > 0 || subs.Count > 0; return; end
[parentPath, leaf] = splitTaskName(folderPath);
try
    svc = actxserver('Schedule.Service');
    svc.Connect();
    parent = svc.GetFolder(char(ternary(parentPath == "", "\", parentPath)));
    parent.DeleteFolder(char(leaf), 0);
catch
end
end


function [folderPath, name] = splitTaskName(taskName)
k = find(char(taskName) == '\', 1, 'last');
if isempty(k)
    folderPath = "";
    name = taskName;
else
    folderPath = extractBefore(taskName, k);
    name = extractAfter(taskName, k);
end
end


function [start, everyMin] = triggerTimes(def)
%triggerTimes  First run and minutes between runs of a task's first trigger.
start = NaT;
everyMin = NaN;
try
    trigs = def.Triggers;
    trig = trigs.Item(1);
    tok = regexp(string(trig.StartBoundary), '^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})', 'tokens', 'once');
    if ~isempty(tok)
        start = datetime(tok, 'InputFormat', "yyyy-MM-dd'T'HH:mm:ss");
    end
    rep = trig.Repetition;
    everyMin = isoMinutes(string(rep.Interval));
catch
end
end


function m = isoMinutes(d)
%isoMinutes  Minutes in an ISO 8601 duration such as PT1H30M or P1D (NaN when none).
%   Task Scheduler writes intervals this way, and rewrites PT720M as PT12H.
m = NaN;
d = char(d);
if isempty(regexp(d, '^P(\d+D)?(T(\d+H)?(\d+M)?(\d+S)?)?$', 'once')); return; end
m = 1440 * unitValue(d, 'D') + 60 * unitValue(d, 'H') + unitValue(d, 'M') + unitValue(d, 'S') / 60;
if m <= 0; m = NaN; end
end


function v = unitValue(d, unit)
tok = regexp(d, ['(\d+)' unit], 'tokens', 'once');
v = 0;
if ~isempty(tok); v = str2double(tok{1}); end
end


function t = nextStart(now_, everyMin)
%nextStart  The first run: the next multiple of the interval since midnight.
day0 = dateshift(now_, 'start', 'day');
t = day0 + minutes(everyMin * (floor(minutes(now_ - day0) / everyMin) + 1));
end


function t = nextRun(start, everyMin, now_)
if now_ < start || isnan(everyMin)
    t = start;
    if now_ >= start; t = NaT; end
    return
end
t = start + minutes(everyMin * (floor(minutes(now_ - start) / everyMin) + 1));
end


function p = problemText(st)
%problemText  What keeps a scheduled copy from working, in words ("" when nothing).
p = "";
s = st.Settings;
if ~st.Enabled
    p = "its Windows task is disabled (in Task Scheduler)";
elseif ~isempty(s) && s.Code ~= "" && ~isfile(fullfile(s.Code, "CopySchedule.m"))
    p = "the code it runs is no longer in " + s.Code + "; Save schedule again";
elseif ~isempty(s) && s.Matlab ~= "" && ~isfile(fullfile(s.Matlab, "bin", "win64", "MATLAB.exe"))
    p = "the MATLAB it starts is no longer in " + s.Matlab + "; Save schedule again from this MATLAB";
else
    switch st.LastResult
        case {0, 1, 267008, 267009, 267010, 267011}
            % done, a run that reported its own failure (see LastRun), ready,
            % running, disabled, has not run yet
        case 267014   % SCHED_S_TASK_TERMINATED
            p = "the last run was stopped before it finished";
        case -2147023570   % 0x8007052E: unknown user name or bad password
            p = "Windows could not sign in with the saved password (changed since?); Save schedule again";
        case -2147023511   % 0x80070569: logon type not granted
            p = "Windows does not let this account run tasks while signed out; choose ""while I am signed in""";
        case -2147024894   % 0x80070002: file not found
            p = "Windows could not find MATLAB or the schedule's files; Save schedule again";
        case {-1073741510, 3221225786}   % 0xC000013A: closed (Ctrl+C, shutdown)
            p = "the last run was stopped (the computer shut down, or MATLAB was closed)";
        otherwise
            if isfinite(st.LastResult)
                p = sprintf("Windows reports code 0x%08X for the last run; see matlab.log", ...
                    typecast(int32(st.LastResult), 'uint32'));
            end
    end
end
end


% =============================================================================
% the record of a run
% =============================================================================

function L = readLastRun(folder)
%readLastRun  last_run.json with times as datetimes and Sessions as a table ([] when none).
L = readJsonFile(fullfile(folder, "last_run.json"), ErrorOnFail=false);
if ~isstruct(L); L = []; return; end
try
    L.State = string(L.State);
    L.Started = isoDatetime(L.Started);
    L.Finished = isoDatetime(L.Finished);
    L.Days = string(L.Days);
    L.Errors = string(L.Errors);
    S = emptySessions();
    if ~isempty(L.Sessions)
        x = L.Sessions;
        if iscell(x); x = [x{:}]; end
        S = table(string({x.Subject}).', string({x.Session}).', string({x.DestDir}).', ...
            string({x.Status}).', string({x.Message}).', 'VariableNames', S.Properties.VariableNames);
    end
    L.Sessions = S;
catch
    L = [];   % not a summary this code wrote
end
end


function rotateLog(f)
d = dir(f);
if isscalar(d) && d.bytes > 5 * 2^20
    movefile(f, regexprep(f, '\.log$', '.1.log'), 'f');
end
end


function appendLine(f, msg)
%appendLine  Add one time-stamped line to a log, opening and closing it each time.
fid = fopen(f, 'a', 'n', 'UTF-8');
if fid < 0; return; end
fprintf(fid, '%s  %s\r\n', string(datetime('now'), 'yyyy-MM-dd HH:mm:ss'), msg);
fclose(fid);
end


% =============================================================================
% small helpers
% =============================================================================

function list = rootList(x)
%rootList  Folders as a row of strings, from a list or one string of them separated by semicolons.
x = strjoin(string(x), ";");
list = strtrim(split(x, ";")).';
list = unique(list(list ~= ""), 'stable');
end


function list = subjectList(x)
%subjectList  Subject IDs as a row of strings, from a list or one string of them.
x = strjoin(string(x), " ");
list = split(strtrim(x), regexpPattern("[,;\s]+")).';
list = unique(list(list ~= ""), 'stable');
bad = list(contains(list, ["\", "/", ":", "*", "?", """", "<", ">", "|"]));
if ~isempty(bad)
    error('CopySchedule:BadSettings', 'Not a subject ID: %s', bad(1));
end
end


function v = number(v, name, lo, hi, whole)
if ischar(v) || isstring(v); v = str2double(v); end
if ~isnumeric(v) || ~isscalar(v) || ~isfinite(v) || v < lo || v > hi || (whole && v ~= round(v))
    what = ternary(whole, "a whole number", "a number");
    if isinf(hi)
        error('CopySchedule:BadSettings', '%s must be %s of at least %g.', name, what, lo);
    end
    error('CopySchedule:BadSettings', '%s must be %s from %g to %g.', name, what, lo, hi);
end
v = double(v);
end


function v = member(v, name, allowed)
v = string(v);
if ~isscalar(v) || ~ismember(v, allowed)
    error('CopySchedule:BadSettings', '%s must be one of: %s.', name, strjoin(allowed, ", "));
end
end


function s = isoText(t)
s = string(t, "yyyy-MM-dd'T'HH:mm:ss");
end


function t = isoDatetime(s)
t = NaT;
s = string(s);
if isscalar(s) && strlength(s) >= 19
    try
        t = datetime(extractBefore(s, 20), 'InputFormat', "yyyy-MM-dd'T'HH:mm:ss");
    catch
    end
end
end


function x = esc(x)
x = replace(string(x), ["&", "<", ">"], ["&amp;", "&lt;", "&gt;"]);
end


function s = leafName(p)
s = strings(size(p));
for k = 1:numel(p)
    [~, n, e] = fileparts(p(k));
    s(k) = n + e;
end
end


function r = mappedDrive(letter)
%mappedDrive  The UNC path mapped to a drive letter ("" when it is not a network drive).
r = "";
try
    net = actxserver('WScript.Network');
    drives = net.EnumNetworkDrives;
    for k = 0:2:drives.Count - 1
        if strcmpi(drives.Item(k), letter + ":")
            r = string(drives.Item(k + 1));
            return
        end
    end
catch
end
try
    r = string(winqueryreg('HKEY_CURRENT_USER', char("Network\" + letter), 'RemotePath'));
catch
end
end


function u = windowsUser()
u = string(getenv('USERNAME'));
dom = string(getenv('USERDOMAIN'));
if dom ~= ""; u = dom + "\" + u; end
end


function h = hostName()
h = string(getenv('COMPUTERNAME'));
if h == ""; h = string(getenv('HOSTNAME')); end
end


function writeStartup(folder)
writeText(fullfile(folder, "startup.m"), strjoin([
    "% startup.m of the scheduled copy (CopySchedule)."
    "% Its task starts MATLAB in this folder (-sd), so MATLAB runs this file"
    "% instead of the user's own startup.m: an unattended copy needs nothing"
    "% from it, and must not depend on it."], newline) + newline);
end


function writeUtf16(f, text)
%writeUtf16  Task Scheduler reads a task's XML file only as UTF-16.
fid = fopen(f, 'w');
if fid < 0
    error('CopySchedule:CannotWrite', 'Cannot write %s.', f);
end
fwrite(fid, [uint8([255 254]), unicode2native(char(text), 'UTF-16LE')], 'uint8');
fclose(fid);
end


function writeText(f, text)
fid = fopen(f, 'w', 'n', 'UTF-8');
if fid < 0
    error('CopySchedule:CannotWrite', 'Cannot write %s.', f);
end
fwrite(fid, char(text), 'char');
fclose(fid);
end


function makeFolder(p)
if isfolder(p); return; end
[ok, msg] = mkdir(p);
if ~ok
    error('CopySchedule:CannotWrite', 'Cannot create %s: %s', p, msg);
end
end


function deleteIfFile(f)
if isfile(f)
    try delete(f); catch; end
end
end


function v = ternary(tf, a, b)
if tf; v = a; else; v = b; end
end
