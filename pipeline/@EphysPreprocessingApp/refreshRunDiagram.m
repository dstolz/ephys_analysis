function refreshRunDiagram(obj)
%refreshRunDiagram  Send the run diagram's model to its page while it is shown.
%   Turns obj.RunDiagram (see resetRunDiagram) into what the page
%   (runDiagramHTML) draws, and sets it as the HTML component's Data: the
%   phase, a headline (which step of how many is underway, or how the run
%   ended), a line naming the config, the datasets and the times, and per
%   step its state and label, percentage, the dataset and message of its last
%   event and its result counts (done, dry run, skipped, to check, errors,
%   cancelled).

h = obj.RunDiagramHTML;
if isempty(h) || ~isvalid(h) || ~obj.RunDiagramCheckBox.Value; return; end
M = obj.RunDiagram;
c = arrayfun(@(s) stepData(s, M), M.steps, 'UniformOutput', false);
h.Data = struct('phase', M.phase, 'headline', headline(M), 'sub', subLine(obj, M), 'steps', [c{:}]);
end


function p = stepData(s, M)
%stepData  What the page draws for one step.
[summary, nErr] = resultCounts(M.results, s.key);
if s.state == "running" && summary ~= ""
    summary = "So far: " + summary;
elseif ~ismember(s.state, ["done" "cancelled" "failed"])
    summary = "";
end
where = "";
if s.index > 0 && ismember(s.state, ["running" "cancelled" "failed"])
    lead = "Dataset";
    if s.state ~= "running"; lead = "Stopped at dataset"; end
    where = sprintf("%s %d of %d: %s", lead, s.index, s.count, s.dataset);
end
msg = "";
if s.state == "running"; msg = s.message; end
if s.state == "failed"; msg = M.note; end
p = struct('key', s.key, 'title', s.title, 'what', s.what, 'state', s.state, ...
    'label', stateLabel(M.phase, s.state), 'inRun', s.inRun, 'pct', round(s.pct, 1), ...
    'now', where, 'msg', msg, 'summary', summary, 'errors', nErr);
end


function t = stateLabel(phase, state)
if phase == "idle"
    if state == "off"; t = "off"; else; t = "will run"; end
    return
end
switch state
    case "off";    t = "not in this run";
    case "queued"; t = "waiting";
    case "notrun"; t = "not run";
    otherwise;     t = state;   % running, done, cancelled, failed
end
end


function [t, nErr] = resultCounts(R, key)
%resultCounts  "4 done, 1 skipped, 2 errors" from the Results rows of step KEY.
t = "";
nErr = 0;
if isempty(R); return; end
st = R.Status(extractBefore(R.Step + ":", ":") == key);
if isempty(st); return; end
dry  = st == "dry run";
ok   = ismember(st, ["done" "ok" "launched" "associated" "approved" "auto-approved"]) | startsWith(st, "matched");
skip = startsWith(st, "skipped");
err  = startsWith(st, "error");
can  = ismember(st, ["cancelled" "not run"]);
look = ~(dry | ok | skip | err | can);   % no probe, unmatched, needs review, ...
nErr = nnz(err);
n = [nnz(ok) nnz(dry) nnz(skip) nnz(look) nErr nnz(can)];
words = ["done" "dry run" "skipped" "to check" "errors" "cancelled"];
if nErr == 1; words(5) = "error"; end
parts = compose("%d %s", n(:), words(:));
t = join(parts(n > 0), ", ");
end


function t = headline(M)
run = M.steps([M.steps.inRun]);
n = numel(run);
switch M.phase
    case "idle"
        t = "Ready: " + plural(n, "step") + " will run";
    case "running"
        j = find([run.state] == "running", 1);
        if isempty(j)
            t = "Starting...";
        else
            t = sprintf("Step %d of %d: %s", j, n, run(j).title);
        end
        if M.dryRun; t = "Dry run, " + lowerFirst(t); end
    case "done"
        t = "Finished " + plural(n, "step") + " in " + elapsed(M);
        nErr = nnz(startsWith(M.results.Status, "error"));
        if nErr > 0; t = t + ", " + plural(nErr, "error"); end
    case "cancelled"
        j = find([run.state] == "cancelled", 1);
        t = "Cancelled";
        if ~isempty(j); t = t + " during " + run(j).title; end
        t = t + " after " + elapsed(M);
    otherwise
        j = find([run.state] == "failed", 1);
        t = "Stopped by an error";
        if ~isempty(j); t = t + " in " + run(j).title; end
end
end


function t = subLine(obj, M)
sep = " " + string(char(183)) + " ";   % middle dot
t = "Pipeline '" + M.name + "'";
if M.phase == "idle"
    if isempty(obj.Project) || obj.Project.NumDatasets == 0
        t = t + sep + "scan a project root first";
    elseif obj.Config.Project.Selection == "list"
        t = t + sep + sprintf("%d of %d datasets ticked", numel(obj.Config.Project.Datasets), obj.Project.NumDatasets);
    else
        t = t + sep + "all " + plural(obj.Project.NumDatasets, "dataset");
    end
    return
end
t = t + sep + plural(M.nDatasets, "dataset") + sep + "started " + string(M.started, "HH:mm:ss");
if M.phase == "running"
    t = t + sep + elapsed(M) + " so far";
else
    t = t + ", ended " + string(M.finished, "HH:mm:ss");
end
if M.phase == "error" && M.note ~= ""
    t = t + sep + M.note;
end
end


function t = elapsed(M)
%elapsed  Time since the run started (to its end once it has ended).
t1 = M.finished;
if M.phase == "running" || isnat(t1); t1 = datetime('now'); end
s = max(0, floor(seconds(t1 - M.started)));
if s < 60
    t = sprintf("%d s", s);
elseif s < 3600
    t = sprintf("%d min %02d s", floor(s / 60), mod(s, 60));
else
    t = sprintf("%d h %02d min", floor(s / 3600), floor(mod(s, 3600) / 60));
end
end


function t = plural(n, word)
t = sprintf("%d %s", n, word);
if n ~= 1; t = t + "s"; end
end


function t = lowerFirst(t)
t = string(t);
if strlength(t) > 0; t = lower(extractBefore(t, 2)) + extractAfter(t, 1); end
end
