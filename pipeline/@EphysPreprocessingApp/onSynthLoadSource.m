function ok = onSynthLoadSource(obj)
%onSynthLoadSource  Load source: read the schedule the Synthetic tab generates from.
%   Built-in task: a task schedule (for the Event and Parameter lists; the
%   preview draws it again from the seed). Dataset sources: the active
%   dataset's Epsych2 session through syntheticSessionSchedule, with its
%   recorded lines ("recording": digitalEvents, cached next to its
%   outputs, so the first read of a long recording takes a while) or rebuilt
%   from its parameters ("session": the tab's trial duration and lines,
%   automatic when blank; the ones used are filled in when the fields are
%   empty). A dataset source also sets Fs, Channels and Subject (the
%   session's subject + "-SYN") to the dataset's. OK is false when nothing
%   could be read (the status line says why).
ok = false;
mode = string(obj.SynthSourceDropDown.Value);
obj.SynthModel = [];
if mode == "task"
    state = rng;
    restore = onCleanup(@() rng(state));
    S = syntheticTaskSchedule(NumTrials=obj.SynthTrialsSpinner.Value, Scenario=string(obj.SynthScenarioDropDown.Value));
    delete(restore);
    obj.SynthSource = S;
    obj.SynthSourceKey = obj.synthSourceKey();
    obj.syncSynthControls();
    setStatus(obj, sprintf("Built-in task: %d trials, lines %s (the trials are drawn from the seed at Preview).", ...
        height(S.trials), strjoin(S.lineNames, ", ")), false);
    ok = true;
    return
end

d = obj.currentDataset();
if isempty(d)
    setStatus(obj, "Scan a project and choose a dataset with an Epsych2 session (Dataset box above).", true);
    return
end
if d.BehaviorFile == "" || ~isfile(d.BehaviorFile)
    setStatus(obj, d.Name + " has no Epsych2 session: associate one on the Project tab, or use the built-in task.", true);
    return
end

args = {'Timing', mode, 'ProbeFile', obj.Config.Probe.DefaultProbeFile};
if mode == "session"
    args = [args, {'TrialDuration', string(obj.SynthTrialDurField.Value)}];
    rules = synthLinesRules(obj.SynthLinesTable.Data);
    if height(rules) > 0; args = [args, {'Lines', rules}]; end
end
dlg = uiprogressdlg(obj.Fig, "Title", "Synthetic dataset", "Message", "Reading " + d.Name + " ...", "Indeterminate", "on");
closer = onCleanup(@() closeDialog(dlg));
try
    S = syntheticSessionSchedule(d, args{:}, ProgressFcn=@(i, n, name) progress(dlg, i, n, name));
catch ME
    delete(closer);
    setStatus(obj, "Could not read the source: " + string(ME.message), true);
    return
end
delete(closer);

obj.SynthSource = S;
obj.SynthSourceKey = obj.synthSourceKey();
if isfinite(S.Fs) && S.Fs >= obj.SynthFsField.Limits(1) && S.Fs <= obj.SynthFsField.Limits(2)
    obj.SynthFsField.Value = S.Fs;
end
if isfinite(S.nChannels) && S.nChannels >= 2
    obj.SynthChannelsField.Value = S.nChannels;
end
obj.SynthSubjectField.Value = char(regexprep(S.subject, '[^\w\-]', '-') + "-SYN");
if mode == "session"
    if strtrim(obj.SynthTrialDurField.Value) == ""
        obj.SynthTrialDurField.Placeholder = char("automatic: " + S.trialDuration);
    end
    if isempty(obj.SynthLinesTable.Data)
        obj.SynthLinesTable.Data = [cellstr(S.rules.Name), cellstr(S.rules.Onset), cellstr(S.rules.Duration)];
    end
end
if ~isempty(S.trials) && any(isfinite(S.trials.Onset))
    obj.SynthTimelineStartField.Value = max(0, floor(min(S.trials.Onset(isfinite(S.trials.Onset))) - 1));
end
obj.syncSynthControls();
[lines, params] = obj.synthSourceLists();
issues = obj.gatherSynthDesign().validate(lines, params, []);
msg = S.summary + ".";
if S.note ~= ""; msg = msg + " " + S.note; end
if ~isempty(issues)
    msg = msg + " Design: " + issues(1) + ternary(numel(issues) > 1, sprintf(" (+%d more)", numel(issues) - 1), "");
end
setStatus(obj, msg, ~isempty(issues));
ok = true;
end


function setStatus(obj, msg, warn)
obj.SynthStatusLabel.Text = msg;
if warn
    obj.SynthStatusLabel.FontColor = [0.70 0.15 0.10];
else
    obj.SynthStatusLabel.FontColor = [0.3 0.3 0.3];
end
end


function rules = synthLinesRules(C)
%synthLinesRules  The rebuilt-lines table (cells: Line, Onset, Duration) as a table; blank rows dropped.
rules = table(strings(0, 1), strings(0, 1), strings(0, 1), 'VariableNames', {'Name', 'Onset', 'Duration'});
for i = 1:size(C, 1)
    r = strtrim(string(C(i, :)));
    r(ismissing(r)) = "";
    if r(1) ~= ""; rules(end+1, :) = {r(1), r(2), r(3)}; end %#ok<AGROW>
end
end


function progress(dlg, i, n, name)
if ~isvalid(dlg); return; end
dlg.Indeterminate = "off";
dlg.Value = min(max(i / max(n, 1), 0), 1);
dlg.Message = sprintf('Reading the digital lines: %s (%d of %d)', name, i, n);
drawnow limitrate;
end


function closeDialog(dlg)
try
    if isvalid(dlg); close(dlg); end
catch
end
end


function s = ternary(tf, a, b)
if tf; s = a; else; s = b; end
end
