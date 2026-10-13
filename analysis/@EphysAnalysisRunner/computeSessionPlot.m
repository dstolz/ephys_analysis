function [res, sessions, spec, Rs] = computeSessionPlot(obj, sp, idx, opts)
%computeSessionPlot  Compute a session plot: its base plot on every session, merged.
%   [RES, SESSIONS, SPEC, RS] = r.computeSessionPlot(SP, IDX) for the
%   session plot SP (an id of Config.SessionPlots, or a session plot
%   struct, which need not be in the config) over the datasets IDX
%   (indices, keys or names; default all) -- or, with SP.datasets "list",
%   over SP.datasetKeys (keys not found are left out):
%     SPEC = Config.sessionPlotFor(SP)          the effective spec
%     SESSIONS = r.sessionTable(IDX)           by date, then name
%     per session: plotSkipReason(source(k), SPEC) -> status "skipped"
%       with its reason; else R = r.cachedPlot(k, SPEC) -> "done" (a
%       compute that fails -> "error", logged; the rest still run)
%     RES = sessionResults(RS, SESSIONS, SP, SPEC)
%   SESSIONS gains status ("done" | "skipped" | "error") and message; RS
%   is the per-session results ({1 x n}, [] where none), in SESSIONS'
%   order. A base plot whose trial groups the session plot pools has an
%   effective spec of its own, so its results are computed again rather
%   than taken from the per-dataset run (logged). For site matching, a
%   session whose probe channel map differs from the first's is logged
%   (sites are matched by channel number all the same).
%
%   Options
%     KeepActive  a dataset index whose bulk data stays loaded (the app's
%                 active dataset); 0 (default) = none
%     Span        [a b]: report progress within this share of a run
%                 (run passes it; [] (default) = no progress calls, but
%                 checkpoints between sessions for the app's Cancel)
%
%   See also sessionResults, combineSessions, EphysAnalysisRunner.runSessionPlot,
%   EphysAnalysisRunner.cachedPlot.
arguments
    obj (1,1) EphysAnalysisRunner
    sp
    idx = []
    opts.KeepActive (1,1) double = 0
    opts.Span double = []
end
cfg = obj.Config;
if isstring(sp) || ischar(sp)
    k = cfg.sessionPlotIndex(sp);
    if k == 0
        error('EphysAnalysisConfig:NoSessionPlot', 'No session plot "%s".', string(sp));
    end
    sp = cfg.SessionPlots(k);
else
    sp = EphysAnalysisConfig.normalizeSection("SessionPlot", sp);
end
spec = cfg.sessionPlotFor(sp);
if sp.datasets == "list"
    idx = arrayfun(@(key) obj.index(key), reshape(sp.datasetKeys, 1, []));
    missing = sp.datasetKeys(idx == 0);
    if ~isempty(missing)
        obj.log("%s: dataset key(s) not found: %s", sp.id, strjoin(missing, ", "));
    end
    idx = idx(idx > 0);
elseif isempty(idx)
    idx = 1:numel(obj.Outputs);
elseif ~isnumeric(idx)
    idx = arrayfun(@(k) obj.index(k), reshape(string(idx), 1, []));
    idx = idx(idx > 0);
end
sessions = obj.sessionTable(idx);
n = height(sessions);
sessions.status = repmat("done", n, 1);
sessions.message = strings(n, 1);
Rs = cell(1, n);
base = cfg.plotFor(sp.plot);
if sp.trialGroups == "pool" && ~isempty(base.selection.groupBy)
    obj.log("%s: the base plot %s groups its trials by %s; pooled, its results are computed again per dataset.", ...
        sp.id, sp.plot, strjoin(base.selection.groupBy, ", "));
end
chanMap = [];
for j = 1:n
    k = sessions.index(j);
    if ~isempty(opts.Span)
        obj.progress(opts.Span(1) + diff(opts.Span) * (j - 1) / max(n, 1), sprintf("sessions: %s: %s", sp.id, obj.Names(k)));
    end
    obj.checkpoint();
    try
        src = obj.source(k);
    catch ME
        sessions.status(j) = "error";
        sessions.message(j) = "cannot read the dataset: " + string(ME.message);
        obj.log("%s: %s cannot be read: %s", sp.id, obj.Names(k), ME.message);
        continue
    end
    reason = plotSkipReason(src, spec);
    if reason ~= ""
        sessions.status(j) = "skipped";
        sessions.message(j) = reason;
        continue
    end
    if sp.match == "site" && ismember(spec.source, EphysAnalysisConfig.SpikeSources) && isstruct(src.probe) ...
            && isfield(src.probe, 'chanMap')
        if isempty(chanMap)
            chanMap = src.probe.chanMap(:);
        elseif ~isequal(src.probe.chanMap(:), chanMap)
            obj.log("%s: %s's probe channel map differs from the first session's; sites are matched by channel number.", ...
                sp.id, obj.Names(k));
        end
    end
    try
        Rs{j} = obj.cachedPlot(k, spec, Keep=(k == opts.KeepActive));
    catch ME
        if ME.identifier == "EphysAnalysisRunner:Canceled"; rethrow(ME); end
        sessions.status(j) = "error";
        sessions.message(j) = string(ME.message);
        obj.log("%s: %s FAILED: %s", sp.id, obj.Names(k), ME.message);
    end
end
res = sessionResults(Rs, sessions, sp, spec);
end
