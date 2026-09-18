function refreshCopySchedule(obj, opts)
%refreshCopySchedule  Show the scheduled copy's state on the Copy tab.
%   One line says whether a schedule is set up, when it runs next and how
%   its last run went (CopySchedule.status); its tooltip has the details:
%   the saved settings, what the last run did with each session it did not
%   find already copied, and where the log is. Called when the app starts,
%   when the Copy tab is shown and after each schedule button. With
%   Fill=true the schedule's own controls also take the saved settings (at
%   startup and after Save), so that they show what is scheduled.
%
%   The scheduled copy is a Windows task and runs whether or not the app
%   is open; while one of its runs is under way a timer calls this every
%   few seconds, and stops when the run is over.
arguments
    obj
    opts.Fill (1,1) logical = false
end
lbl = obj.CopyScheduleStatusLabel;
if isempty(lbl) || ~isvalid(lbl); return; end
sch = obj.CopyScheduler;
try
    st = sch.status();
catch ME
    lbl.Text = "Scheduled copy: its state cannot be read: " + ME.message;
    lbl.FontColor = [0.75 0.1 0.1];
    stopTimer(obj);
    return
end

s = st.Settings;
if opts.Fill && ~isempty(s)
    obj.CopyScheduleSubjectsField.Value = char(strjoin(s.Subjects, " "));
    obj.CopyScheduleEveryField.Value = s.EveryMin;
    obj.CopyScheduleDaysField.Value = s.LookBackDays;
    obj.CopyScheduleQuietField.Value = s.QuietMin;
    obj.CopyScheduleRunWhenDropDown.Value = s.RunWhen;
end

[txt, tip, bad] = describe(st, sch);
lbl.Text = txt;
lbl.Tooltip = tip;
if bad
    lbl.FontColor = [0.75 0.1 0.1];
elseif st.Running
    lbl.FontColor = [0.15 0.45 0.80];
else
    lbl.FontColor = [0.35 0.35 0.35];
end
obj.CopyScheduleRemoveButton.Enable = st.Scheduled || ~isempty(s);
obj.CopyScheduleRunNowButton.Enable = st.Scheduled && st.Enabled && ~st.Running;
obj.CopyScheduleLogButton.Enable = isfile(sch.logFile());

if st.Running
    startTimer(obj);
else
    stopTimer(obj);
end
end


function [txt, tip, bad] = describe(st, sch)
%describe  The status line, its tooltip, and whether something needs the user.
s = st.Settings;
L = st.LastRun;
bad = st.Problem ~= "";
if ~st.Scheduled
    if bad
        txt = "Not scheduled: " + st.Problem + ".";
    else
        txt = "Not scheduled. Name the subjects and how often, then Save schedule: it copies with the roots, " + ...
            "destination, pairing and copy options above, as they are when you save.";
    end
    tip = "";
    return
end

parts = strings(1, 0);
when = "while you are signed in";
if st.RunWhen == "always"; when = "signed in or not"; end
head = sprintf("Every %g min, %s", st.EveryMin, when);
if ~isempty(s)
    head = head + ": " + strjoin(s.Subjects, ", ") + " to " + s.DestRoot;
end
parts(end+1) = head + ".";
if st.Running
    parts(end+1) = "Running now" + ternary(~isempty(L) && L.State == "running", ...
        " (started " + timeText(L.Started) + ")", "") + ".";
elseif ~isnat(st.NextRun)
    parts(end+1) = "Next run " + timeText(st.NextRun) + ".";
end
if isempty(L)
    parts(end+1) = "Not run yet.";
elseif L.State == "running"
    if ~st.Running
        parts(end+1) = "The run started " + timeText(L.Started) + " stopped before it finished (see matlab.log).";
        bad = true;
    end
else
    parts(end+1) = "Last run " + timeText(L.Started) + ": " + ...
        ternary(L.State == "failed", "FAILED. ", "") + lastRunText(L);
    bad = bad || L.State == "failed";
end
if st.Problem ~= ""
    parts(end+1) = "Problem: " + st.Problem + ".";
end
txt = strjoin(parts, " ");

% --- the tooltip: the settings, then the last run in detail ---------------------------
lines = strings(0, 1);
if ~isempty(s)
    lines(end+1) = "Subjects: " + strjoin(s.Subjects, ", ");
    lines(end+1) = "From: " + s.EpsychRoot + " (ePsych), " + s.IntanRoot + " (Intan)";
    lines(end+1) = "To: " + s.DestRoot;
    lines(end+1) = sprintf("Sessions of the last %d day(s), quiet for %g min; Verify %s; If it exists %s%s", ...
        s.LookBackDays, s.QuietMin, s.Verify, s.IfExists, ternary(s.IncludeUnpaired, "; unpaired included", ""));
end
lines(end+1) = "Windows task: " + sch.TaskName;
if ~isempty(L) && L.State ~= "running"
    lines(end+1) = "";
    lines(end+1) = "Last run: " + timeText(L.Started) + " to " + timeText(L.Finished) + ...
        ternary(isempty(L.Days), "", " (sessions of " + strjoin(unique(L.Days, 'stable'), " to ") + ")");
    for e = L.Errors(:).'
        lines(end+1) = "  " + e; %#ok<AGROW>
    end
    other = L.Sessions(L.Sessions.Status ~= "already_present", :);
    for k = 1:min(height(other), 12)
        lines(end+1) = "  " + other.Session(k) + ": " + replace(other.Status(k), "_", " ") + " - " + other.Message(k); %#ok<AGROW>
    end
    if height(other) > 12
        lines(end+1) = sprintf("  and %d more (see the log)", height(other) - 12);
    end
end
lines(end+1) = "Log: " + sch.logFile();
tip = strjoin(lines, newline);
end


function s = lastRunText(L)
%lastRunText  What the last run did, e.g. "1 copied, 3 already present."
s = "";
if ~isempty(L.Errors)
    s = strjoin(L.Errors, "; ") + ". ";
end
if height(L.Sessions) > 0 || isempty(L.Errors)
    s = s + CopySchedule.countText(L.Sessions.Status);
end
s = strtrim(s);
end


function s = timeText(t)
%timeText  "14:00" today, "Sep 17 14:00" on another day.
if isnat(t)
    s = "?";
elseif dateshift(t, 'start', 'day') == datetime('today')
    s = string(t, 'HH:mm');
else
    s = string(t, 'MMM d HH:mm');
end
end


function startTimer(obj)
t = obj.CopyScheduleTimer;
if ~isempty(t) && isvalid(t) && strcmp(t.Running, 'on'); return; end
stopTimer(obj);
obj.CopyScheduleTimer = timer("Name", "EphysPreprocessingAppCopySchedule", ...
    "ExecutionMode", "fixedSpacing", "Period", 5, "StartDelay", 5, "BusyMode", "drop", ...
    "TimerFcn", @(tm, ~) tick(obj, tm));
start(obj.CopyScheduleTimer);
end


function stopTimer(obj)
t = obj.CopyScheduleTimer;
if ~isempty(t) && isvalid(t)
    stop(t);
    delete(t);
end
obj.CopyScheduleTimer = [];
end


function tick(obj, tm)
%tick  Timer callback; the app may have gone without closing through onClose.
if ~isvalid(obj) || isempty(obj.Fig) || ~isvalid(obj.Fig)
    stop(tm);
    delete(tm);
    return
end
obj.refreshCopySchedule();
end


function v = ternary(c, a, b)
if c; v = a; else; v = b; end
end
