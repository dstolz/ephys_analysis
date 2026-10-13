function S = sessionData(obj, sp, idx, opts)
%sessionData  A session plot's data over its sessions, ready to save or hand over.
%   S = r.sessionData(SP, IDX) computes (or takes from the result cache) the
%   session plot SP over the datasets IDX (computeSessionPlot: an id of
%   Config.SessionPlots, or a session plot struct) and returns the
%   sessionData struct: the merged results, the sessions table, the
%   configuration and, as SP.data asks,
%     "results"  every session's own result (S.perSession)
%     "epochs"   epochData of every session that could draw the plot
%                (S.epochs): its spike times and binned counts, or none
%     "signals"  with "epochs": the epoched samples of a signal source too
%   The base results come from the cache when they are there and are
%   computed otherwise. Each dataset's epochs are cut through source(k) with
%   its bulk data cleared afterward (src.outputs.clearCache()), so one
%   dataset's signals and spikes are in memory at a time. The epochs of a
%   session carry its table label, subject and date (identity.label,
%   .subject, .date).
%
%   Options
%     Results     the figures' results (sessionResults, as computeSessionPlot
%                 returns them) when the caller has them already
%                 (runSessionPlot does); default: from computeSessionPlot.
%                 The figure files a run wrote are looked up in r.Results
%     Sessions, Rs, Spec
%                 computeSessionPlot's SESSIONS, RS and SPEC when the caller
%                 has them already (runSessionPlot hands over all four).
%                 Given SESSIONS and RS, nothing is computed again: a missing
%                 SPEC is Config.sessionPlotFor(SP) and missing RESULTS
%                 sessionResults(RS, SESSIONS, SP, SPEC); without them,
%                 computeSessionPlot runs (and fills in what is missing)
%     MaxMB       epochData's limit for the epoched samples (default 1024);
%                 epochData:TooLarge propagates
%     KeepActive  a dataset index whose bulk data stays loaded afterward
%                 (the app's active dataset); 0 (default) = none
%     Span        [a b]: report progress within this share of a run, one call
%                 per session; [] (default) = no progress calls, but
%                 checkpoints for the app's Cancel
%
%   See also sessionData, writeAnalysisData, epochData, epochLongTable,
%   EphysAnalysisRunner.computeSessionPlot, EphysAnalysisRunner.runSessionPlot.
arguments
    obj (1,1) EphysAnalysisRunner
    sp
    idx = []
    opts.Results = []
    opts.Sessions = []
    opts.Spec = []
    opts.Rs = []
    opts.MaxMB (1,1) double {mustBePositive} = 1024
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
span = opts.Span;
phase1 = [];
if ~isempty(span); phase1 = [span(1), span(1) + 0.3 * diff(span)]; end   % computing what is missing: the rest is for the epochs
res = opts.Results;
sessions = opts.Sessions;
spec = opts.Spec;
Rs = opts.Rs;
if ~istable(sessions) || ~iscell(Rs)          % the per-session results are missing: compute them all
    [res1, sessions, spec1, Rs] = obj.computeSessionPlot(sp, idx, KeepActive=opts.KeepActive, Span=phase1);
    if ~isstruct(res); res = res1; end
    if ~isstruct(spec); spec = spec1; end
else                                            % handed over: make only what is missing
    if ~isstruct(spec); spec = cfg.sessionPlotFor(sp); end
    if ~isstruct(res); res = sessionResults(Rs, sessions, sp, spec); end
end

what = string(sp.data);
n = height(sessions);
Epochs = cell(1, n);
prov = ephysProvenance();   % once: it asks git
if any(what == "epochs")
    withSignals = any(what == "signals");
    chk = [];
    if ~isempty(obj.PollFcn); chk = @() obj.checkpoint(); end
    for j = 1:n
        if ~isempty(span)
            obj.progress(span(1) + diff(span) * (0.3 + 0.7 * (j - 1) / max(n, 1)), "epochs: " + sessions.name(j));
        end
        obj.checkpoint();
        if sessions.status(j) ~= "done"; continue; end
        k = sessions.index(j);
        src = obj.source(k);
        try
            D = epochData(src, spec, Signals=withSignals, MaxMB=opts.MaxMB, Check=chk, Provenance=prov);
        catch ME
            if k ~= opts.KeepActive; src.outputs.clearCache(); end
            rethrow(ME);
        end
        if k ~= opts.KeepActive; src.outputs.clearCache(); end
        D.identity.label = sessions.label(j);
        if sessions.subject(j) ~= ""; D.identity.subject = sessions.subject(j); end
        if ~isnat(sessions.date(j)); D.identity.date = sessions.date(j); end
        Epochs{j} = D;
    end
end

files = cell(1, numel(res));
if ~isempty(obj.Results)
    for i = 1:numel(res)
        row = find(obj.Results.Plot == sp.id & obj.Results.Dataset == "sessions: " + res(i).label, 1, 'last');
        if ~isempty(row) && obj.Results.Files(row) ~= ""
            files{i} = strsplit(obj.Results.Files(row), "; ");
        end
    end
end
S = sessionData(sp, spec, sessions, Rs, res, Config=cfg.toStruct(), Epochs=Epochs, Files=files, Provenance=prov);
end
