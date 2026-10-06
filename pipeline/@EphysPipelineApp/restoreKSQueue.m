function T = restoreKSQueue(obj, action)
%restoreKSQueue  Queue again, or drop, the sorting runs kept for the scanned project's root.
%   T = obj.restoreKSQueue(ACTION) works on the queued runs keepKSRuns kept
%   (the preference KeptSortingQueue) for the root of the scanned project:
%     "check"    T only; nothing changes
%     "requeue"  each run that can go back in the queue does (queueKSRun,
%                with the scanned project's dataset), and the monitor
%                starts it as a slot frees; the log names each run and
%                why one was not queued again. The kept runs of this root
%                are then forgotten.
%     "drop"     the kept runs of this root are forgotten.
%   T has one row per kept run: Dataset (its name), Key (its folder
%   relative to the root), Problem (why it cannot go back in the queue:
%   its dataset is no longer in the project, a run file (settings.json,
%   its driver script, the .bin, the probe) is not there, or its sorter is already
%   queued or going in its folder; "" when it can) and Queued (it went
%   back in the queue). T is empty when nothing is kept for this root, or
%   no project is scanned. The kept runs of other roots stay.
%
%   See also offerKeptKSQueue, keepKSRuns, queueKSRun.

arguments
    obj (1,1) EphysPipelineApp
    action (1,1) string {mustBeMember(action, ["check" "requeue" "drop"])}
end

T = table('Size', [0 4], 'VariableTypes', {'string', 'string', 'string', 'logical'}, ...
    'VariableNames', {'Dataset', 'Key', 'Problem', 'Queued'});
if isempty(obj.Project); return; end
P = obj.Project;
g = obj.PrefGroup;
store = keptSortingQueue(g);
i = find(EphysDataset.pathKey([store.root]) == EphysDataset.pathKey(P.Root), 1);
if isempty(i); return; end

for r = reshape(store(i).runs, 1, [])
    [problem, ix] = whyNot(obj, P, r);
    T(end+1, :) = {string(r.Name), string(r.key), problem, false}; %#ok<AGROW>
    if action ~= "requeue"; continue; end
    if problem == ""
        obj.queueKSRun(P.Datasets(ix), r.prepared);
        T.Queued(end) = true;
        obj.log("[sorting] %s: queued again (kept when the app last closed) -> %s", r.Name, r.prepared.resultsDir);
    else
        obj.log("[sorting] %s: kept when the app last closed, not queued again: %s", r.Name, problem);
    end
end
if action == "check"; return; end

store(i) = [];
if isempty(store)
    AppPrefs.rmpref(g, 'KeptSortingQueue');
else
    AppPrefs.setpref(g, 'KeptSortingQueue', store);
end
if action == "drop"
    obj.log("[sorting] dropped the %d sorting run(s) queued for %s when the app last closed", height(T), P.Root);
end
end


function [why, ix] = whyNot(obj, P, r)
%whyNot  Why kept run R cannot go back in the queue ("" when it can), and
%   the index of its dataset in project P.
why = "";
ix = P.findByKey(string(r.key));
if ix == 0
    why = "its dataset is no longer in the project";
    return
end
p = r.prepared;
fields = ["settingsPath" "scriptPath" "binFile" "probeFile" "resultsDir" "statusFile"];
if ~isstruct(p) || ~all(isfield(p, fields))
    why = "what was kept of it is incomplete";
    return
end
files = [string(p.settingsPath), string(p.scriptPath), string(p.binFile), string(p.probeFile)];
missing = files(~isfile(files));
if ~isempty(missing)
    why = "run files missing: " + strjoin(regexprep(missing, '^.*[\\/]', ''), ", ");
    return
end
busy = strings(1, 0);   % the sort run folders of the runs queued or going
for q = obj.KSQueue
    busy(end+1) = q.prepared.resultsDir; %#ok<AGROW>
end
for k = find(~[obj.KSRuns.done])
    busy(end+1) = obj.KSRuns(k).resultsDir; %#ok<AGROW>
end
if any(EphysDataset.pathKey(busy) == EphysDataset.pathKey(p.resultsDir))
    why = sortersLabel(p.resultsDir) + " is already queued or running for it";
end
end
