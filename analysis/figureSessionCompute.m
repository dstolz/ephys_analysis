function [res, sessions, Fs] = figureSessionCompute(sources, sessions, spec, opts)
%figureSessionCompute  Compute a session figure for one matched observation: per session, then each layer merged.
%   [RES, SESSIONS, FS] = figureSessionCompute(SOURCES, SESSIONS, SPEC,
%   Observation=OBS, Check=CHK) draws the session figure SPEC
%   (EphysAnalysisConfig.figureFor of a figure with sessions.enabled)
%   across the datasets SOURCES (a cell {1 x n} of loadAnalysisSource
%   structs, [] where one could not be read) of the sessions SESSIONS
%   (sessionTable rows, same order) for OBS, one row of
%   figureSessionObservations(SOURCES, SPEC) (default: its first row):
%     the session spec   SPEC with the sessions' rules (figureSessionSpec):
%                        observe.perGroup off; trialGroups "pool" clears
%                        the figure's and every panel's selection.groupBy
%                        and a tuning panel's seriesParam (the sessions are
%                        the series); "combine" draws PSTH bars as lines
%     per session k      figureCompute(SOURCES{k}, that spec,
%                        Observation=OBS.perSession{1}(k, :)) where the
%                        session holds the observation (a session without
%                        it, or one figureCompute skips, is "skipped" with
%                        the reason; an error is "error"); FS{k} its F
%     per facet and trial group (as sessionResults: sessions.facet "none"
%                        | "subject"; trialGroups "each": a figure per
%                        trial group label, in first-seen order, at most
%                        selection.maxGroups), each panel's layers merged
%                        across the facet's sessions: combineSessions(RS,
%                        SESSIONS, Series=, Error=, ShowMembers=,
%                        MinSessions=sessions.minSessions, ColorOrder=,
%                        Group=, TrialGroups=, Kind=) with sessions.* and
%                        Kind "heatmap" for a
%                        heat map panel. A layer that holds one unit or
%                        channel in every session (the observed one, a
%                        line's events as a train) is merged into one tile
%                        (Match "mapping" on a one-row mapping), a layer of
%                        several (fixed units) pools them (Match "pool"),
%                        a signal's channels match by recording channel.
%                        A layer's aggregate "mean" is taken again over the
%                        merged tiles (figureLayerMean)
%   Not merged, with the reason as the layer's (or panel's) skip: events
%   drawn as marks ("event marks are not drawn across sessions"), the
%   rings of a waveforms panel's probe layout, a heat map of trials, and
%   the panel types combineSessions cannot merge
%   (EphysAnalysisConfig.FigureSessionUnmerged: probe map, unit
%   correlation, spectrum, spectrogram, coherence). A merge that fails
%   (combineSessions:TooFew, :Bins, ...) skips that layer with its message.
%
%   RES  struct array, one per figure: facet ("all" or the subject), group
%        ("" or the trial group), label ("all", the subject, or "<facet> /
%        <group>"), F (the merged figure, [] when not made), status ("done"
%        | "skipped" | "error"), message. F is shaped as figureCompute's
%        (renderFigure draws it as it draws one dataset's), with
%          panels(k).layers(j).R  the merged result (R.sessions,
%                     R.sessionSeries, R.members, R.groups = the series)
%          panels(k).groups / epochs  its first merged layer's
%          groups, epochs  the first merged layer's on the figure's
%                     selection (the series; the epochs of every session)
%          observation  OBS as a struct (figureCompute's fields; a trial
%                     group's figure: groupLabel the group)
%          sessions   the facet's SESSIONS rows with status / message /
%                     nEpochs as the first merged layer's R.sessions says:
%                     a session computed but without the trial group (or
%                     the observation) is "missing", nEpochs counts the
%                     group's epochs only
%          nSessions  how many of them were merged (status "done"); a
%                     figure merged from fewer than sessions.minSessions
%                     (or with no layer merged: mergeWhy says why) is
%                     "skipped" in RES
%          sessionSeries  the first merged layer's (mode, error, match, ...)
%          dataset    "3 sessions (SYNTH-01)" (combineSessions' subtitle)
%          perSession the facet's session indices into SESSIONS
%   SESSIONS  gains status ("done" | "skipped" | "error") and message.
%   FS        {1 x n}: each session's figureCompute result ([] where none).
%
%   Options
%     Observation  a figureSessionObservations row ([] = the first)
%     Check        a checkpoint ([] = none), called between sessions and
%                  passed into figureCompute
%     Mapping      sessions.match "mapping": the unit mapping (passed to
%                  figureSessionObservations when OBS is not given)
%
%   Pure: no runner, no graphics. EphysAnalysisRunner.computeSessionFigure
%   and EphysAnalysisScript.standalone call it alike. Errors:
%   EphysAnalysisRunner:NoObservation (no OBS and none matched),
%   EphysAnalysisRunner:Canceled from CHK.
%
%   See also figureSessionObservations, figureCompute, combineSessions,
%   sessionResults, renderFigure, EphysAnalysisRunner.runSessionFigure.

arguments
    sources cell
    sessions table
    spec (1,1) struct
    opts.Observation = []
    opts.Check = []
    opts.Mapping = []
end

sources = reshape(sources, 1, []);
n = numel(sources);
if height(sessions) ~= n
    error('figureSessionCompute:Size', 'SESSIONS has %d rows for %d sources.', height(sessions), n);
end
ss = spec.sessions;
sspec = sessionSpec(spec);
obs = opts.Observation;
if isempty(obs)
    T = figureSessionObservations(sources, sspec, Mapping=opts.Mapping);
    if height(T) == 0
        error('EphysAnalysisRunner:NoObservation', 'Figure "%s": no %s is matched across the %d session(s).', ...
            spec.id, spec.observe.kind, n);
    end
    obs = T(1, :);
end
if ~istable(obs) || ~ismember("perSession", string(obs.Properties.VariableNames))
    error('EphysAnalysisRunner:NoObservation', 'Observation is one row of figureSessionObservations.');
end
obs = obs(1, :);
per = obs.perSession{1};

% --- each session's own figure -------------------------------------------------------------
before = strings(n, 1);   % why a source is missing, when the caller said (sessionFigureObservations)
if ismember("message", string(sessions.Properties.VariableNames)); before = string(sessions.message); end
sessions.status = repmat("done", n, 1);
sessions.message = strings(n, 1);
Fs = cell(1, n);
for k = 1:n
    tick(opts.Check);
    if isempty(sources{k})
        sessions.status(k) = "error";
        sessions.message(k) = "cannot read the dataset";
        if before(k) ~= ""; sessions.message(k) = before(k); end
        continue
    end
    if k > height(per) || ~per.present(k)
        sessions.status(k) = "skipped";
        sessions.message(k) = "no " + obs.label + " here";
        continue
    end
    try
        Fs{k} = figureCompute(sources{k}, sspec, Observation=per(k, :), Check=opts.Check);
    catch ME
        if ME.identifier == "EphysAnalysisRunner:Canceled"; rethrow(ME); end
        sessions.status(k) = "error";
        if ismember(string(ME.identifier), ["EphysAnalysisRunner:FigureSkipped" "EphysAnalysisRunner:NoObservation"])
            sessions.status(k) = "skipped";
        end
        sessions.message(k) = string(ME.message);
    end
end

% --- the figures: facets x trial groups ------------------------------------------------------
res = struct('facet', {}, 'group', {}, 'label', {}, 'F', {}, 'status', {}, 'message', {});
if ss.facet == "subject"
    subj = string(sessions.subject);
    subj(subj == "") = "(no subject)";
    facets = unique(subj, 'stable');
    rowsOf = arrayfun(@(f) find(subj == f), facets, 'UniformOutput', false);
else
    facets = "all";
    rowsOf = {(1:n).'};
end
maxGroups = Inf;
if isstruct(sspec.selection) && isfield(sspec.selection, 'maxGroups'); maxGroups = sspec.selection.maxGroups; end
for f = 1:numel(facets)
    rows = reshape(rowsOf{f}, 1, []);
    groups = "";
    if ss.trialGroups == "each"
        groups = groupLabels(Fs(rows));
        groups = groups(1:min(end, maxGroups));
        if isempty(groups); groups = ""; end
    end
    for g = reshape(groups, 1, [])
        label = facets(f);
        if g ~= ""; label = label + " / " + g; end
        e = struct('facet', facets(f), 'group', g, 'label', label, 'F', [], 'status', "done", 'message', "");
        done = rows(sessions.status(rows) == "done");
        if numel(done) < max(1, ss.minSessions)
            e.status = "skipped";
            e.message = sprintf("fewer than %d session(s) draw it", max(1, ss.minSessions));
            why = sessions.label(rows(sessions.status(rows) ~= "done")) + ": " + sessions.message(rows(sessions.status(rows) ~= "done"));
            if ~isempty(why); e.message = e.message + " (" + strjoin(why, "; ") + ")"; end
        else
            try
                e.F = mergeFigure(Fs(rows), sessions(rows, :), sspec, obs, g, rows);
                if e.F.nSessions < max(1, ss.minSessions)   % the sessions that hold this group (or observation) when merged
                    S = e.F.sessions;
                    why = S.label(S.status ~= "done") + ": " + S.message(S.status ~= "done");
                    e.status = "skipped";
                    e.message = sprintf("fewer than %d session(s) hold it", max(1, ss.minSessions));
                    if ~isempty(why); e.message = e.message + " (" + strjoin(why, "; ") + ")"; end
                    if e.F.mergeWhy ~= ""; e.message = e.message + ": " + e.F.mergeWhy; end
                    e.F = [];
                end
            catch ME
                if ME.identifier == "EphysAnalysisRunner:Canceled"; rethrow(ME); end
                e.status = "error";
                e.message = string(ME.message);
            end
        end
        res(end+1) = e; %#ok<AGROW>
    end
end
end


function s = sessionSpec(spec)
%sessionSpec  The spec each session's figure is computed with (figureSessionSpec).
s = figureSessionSpec(spec);
end


function F = mergeFigure(Fk, S, spec, obs, group, rows)
%mergeFigure  One merged figure: every panel's layers merged across the sessions' figures FK (S: their rows).
ss = spec.sessions;
present = ~cellfun(@isempty, Fk);
F0 = Fk{find(present, 1)};
F = F0;
F.dataset = "";
F.epochs = [];
F.groups = [];
F.skip = "";
pass = ss.trialGroups;
grp = 0;
if group ~= ""; grp = group; pass = "pool"; end
unmerged = EphysAnalysisConfig.FigureSessionUnmerged;
first = [];   % the first merged layer on the figure's selection: the figure's groups and epochs
any1 = [];    % ... else any merged layer
for k = 1:numel(F0.panels)
    p = spec.panels(k);
    P = F0.panels(k);
    P.epochs = [];
    P.groups = [];
    P.ownSelection = false;   % the series are every panel's groups
    if ismember(p.type, unmerged)
        P.skip = "a " + p.type + " panel is not merged across sessions";
        for j = 1:numel(P.layers)
            if P.layers(j).skip ~= "disabled"; P.layers(j).skip = P.skip; end
            P.layers(j).R = [];
            P.layers(j).meta = [];
        end
        F.panels(k) = P;
        continue
    end
    if all(cellfun(@(x) x.panels(k).skip ~= "", Fk(present)))
        P.skip = Fk{find(present, 1)}.panels(k).skip;   % no session computed it
        F.panels(k) = P;
        continue
    end
    P.skip = "";
    for j = 1:numel(P.layers)
        if P.layers(j).skip == "disabled"; continue; end
        L = p.layers(j);
        Rs = cell(1, numel(Fk));
        reasons = strings(1, 0);
        for s = find(present)
            lay = Fk{s}.panels(k).layers(j);
            if lay.skip == "" && isstruct(lay.R)
                Rs{s} = lay.R;
            elseif lay.skip ~= ""
                reasons(end+1) = lay.skip; %#ok<AGROW>
            end
        end
        [R, why, name] = mergeLayer(Rs, S, p, L, spec, obs, grp, pass);
        if isempty(R)
            if why == "" && ~isempty(reasons); why = reasons(1); end
            if why == ""; why = "no session computed it"; end
            P.layers(j).skip = why;
            P.layers(j).R = [];
            P.layers(j).meta = [];
            continue
        end
        P.layers(j).skip = "";
        P.layers(j).R = R;
        P.layers(j).meta = [];
        if isfield(R, 'meta'); P.layers(j).meta = R.meta; end
        if name ~= ""; P.layers(j).name = name; end
        if isempty(P.groups) && isfield(R, 'groups')
            P.groups = R.groups;
            if isfield(R, 'epochs') && istable(R.epochs); P.epochs = R.epochs; end
        end
        if isempty(any1); any1 = R; end
        onFig = isequaln(p.ref, spec.ref) && isequaln(p.window, spec.window) ...
            && isequaln(p.selection, spec.selection);
        if isempty(first) && onFig && isfield(R, 'epochs') && istable(R.epochs); first = R; end
    end
    if all(arrayfun(@(l) l.skip ~= "", P.layers)) && ~isempty(P.layers)
        P.skip = "";   % each layer says why
    end
    F.panels(k) = P;
end
if isempty(first); first = any1; end
if ~isempty(first)
    if isfield(first, 'epochs') && istable(first.epochs); F.epochs = first.epochs; end
    F.groups = first.groups;
    F.sessionSeries = first.sessionSeries;
    F.dataset = first.dataset;
else
    F.sessionSeries = struct('mode', ss.series, 'error', ss.error, 'errorNote', "", 'match', ss.match, ...
        'minSessions', ss.minSessions, 'group', string(group), 'trialGroups', ss.trialGroups);
end
% each session's part in what was merged: the first merged layer's R.sessions (after the trial group is sliced), so a
% session that lacks the group is "missing" and its epochs are not counted
nEpochs = zeros(height(S), 1);
if ~isempty(first) && isfield(first, 'sessions') && istable(first.sessions) && height(first.sessions) == height(S)
    RS = first.sessions;
    miss = S.status == "done" & RS.status ~= "done";
    S.status(miss) = "missing";
    what = "no data";
    if group ~= ""; what = "no epoch of " + group; end
    S.message(miss) = what;
    nEpochs = double(RS.nEpochs);
else
    for s = find(present)
        if istable(Fk{s}.epochs); nEpochs(s) = height(Fk{s}.epochs); end
    end
end
S.nEpochs = nEpochs;
F.sessions = S;
F.nSessions = nnz(S.status == "done");
F.mergeWhy = "";
if isempty(first)   % no layer could be merged (too few sessions on every layer, or none mergeable): nothing to draw
    F.nSessions = 0;
    for k = 1:numel(F.panels)
        sk = [F.panels(k).layers.skip];
        sk = sk(sk ~= "" & sk ~= "disabled");
        if ~isempty(sk); F.mergeWhy = sk(1); break; end
    end
end
if F.dataset == ""
    F.dataset = sessionsText(S(S.status == "done", :), group);
end
o = observationStruct(obs);
if group ~= ""; o.groupLabel = group; end
F.observation = o;
F.perSession = rows;
F.created = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end


function [R, why, name] = mergeLayer(Rs, S, p, L, spec, obs, grp, pass)
%mergeLayer  One layer's results across the sessions, merged (combineSessions); [] and why when it cannot be.
R = [];
why = "";
name = "";
P = find(~cellfun(@isempty, Rs));
if isempty(P); return; end
R1 = Rs{P(1)};
kind = "";
if isfield(R1, 'kind'); kind = string(R1.kind); end
switch kind
    case "events"
        why = "event marks are not drawn across sessions";
        return
    case "ring"
        why = "the probe layout's rings are not drawn across sessions";
        return
end
if isfield(R1, 'trialMatrix')
    why = "a heat map of trials is not merged across sessions";
    return
end
ss = spec.sessions;
plotKind = "";
if p.type == "heatmap"; plotKind = "heatmap"; end
if kind == "waveforms"; grp = 0; pass = "pool"; end   % one group, "all"
nTiles = cellfun(@tileCount, Rs(P));
one = all(nTiles == 1) && kind ~= "waveforms" && plotKind ~= "heatmap";
name = string(L.name);
if name == "" && L.binding == "observation"; name = string(obs.label); end
match = "pool";
mapping = [];
if one
    if name == ""; name = string(firstLabel(R1)); end
    [Rs, mapping] = oneTile(Rs, P, S, kind, name);
    if kind ~= "evoked"; match = "mapping"; end
end
try
    R = combineSessions(Rs, S, Series=ss.series, Match=match, Mapping=mapping, Error=ss.error, ...
        ShowMembers=ss.showMembers, MinSessions=max(1, ss.minSessions), ColorOrder=ss.colorOrder, Group=grp, ...
        TrialGroups=pass, Kind=plotKind);
catch ME
    R = [];
    why = string(ME.message);
    return
end
R.dataset = string(R.dataset);
if one && isfield(R, 'meta') && istable(R.meta) && height(R.meta) == 1
    keep = R1.meta;
    if istable(keep) && height(keep) >= 1
        for f = intersect(["unitId" "channel"], intersect(string(keep.Properties.VariableNames), string(R.meta.Properties.VariableNames)))
            R.meta.(f)(1) = keep.(f)(1);   % the first session's own unit id / channel (made common for the merge)
        end
    end
end
if L.aggregate == "mean" && isfield(R1, 'layerMean')
    R.layerMean = layerMeanOf(R, R1.layerMean, spec);
end
if ~one; name = ""; end
end


function n = tileCount(r)
%tileCount  How many units or channels a result holds.
n = 0;
if isfield(r, 'labels'); n = numel(r.labels); end
end


function s = firstLabel(r)
s = "";
if isfield(r, 'labels') && ~isempty(r.labels); s = string(r.labels(1)); end
end


function [Rs, M] = oneTile(Rs, P, S, kind, name)
%oneTile  Make each session's one unit (or channel) the same tile: a common unit id (or channel), a one-row mapping.
M = table(name, 'VariableNames', {'cell'});
c0 = NaN;
for k = P
    r = Rs{k};
    m = [];
    if isfield(r, 'meta'); m = r.meta; end
    if ~istable(m) || height(m) ~= 1
        m = table(string(r.labels(1)), 'VariableNames', {'label'});
    end
    if kind == "evoked"
        if isnan(c0)
            c0 = 1;
            if ismember("channel", string(m.Properties.VariableNames)) && isfinite(m.channel(1)); c0 = m.channel(1); end
        end
        m.channel = c0;
        if isfield(r, 'channels'); r.channels = c0; end
    else
        m.unitId = 1;
    end
    r.meta = m;
    Rs{k} = r;
    if kind ~= "evoked"; M.(char(S.key(k))) = 1; end
end
end


function M = layerMeanOf(R, M0, spec)
%layerMeanOf  A layer's mean over its merged tiles, the band across them (figureLayerMean, the type it had).
nB = spec.style.ErrorResamples;
if isfield(R, 'rate') && isfield(R, 't')
    M = figureLayerMean(R.rate, R.t, M0.type, nB, M0.over);
elseif isfield(R, 'mean') && isfield(R, 't')
    M = figureLayerMean(R.mean, R.t, M0.type, nB, M0.over);
elseif isfield(R, 'meanRate')
    [nU, nG] = size(R.meanRate);
    M = figureLayerMean(reshape(R.meanRate, 1, nU, nG), [], M0.type, nB, M0.over);
elseif isfield(R, 'mean')
    M = figureLayerMean(R.mean, [], M0.type, nB, M0.over);
else
    M = M0;
end
end


function o = observationStruct(obs)
%observationStruct  The matched row as figureCompute's observation struct.
o = struct('kind', string(obs.kind), 'label', string(obs.label), 'unitId', NaN, 'channel', NaN, 'column', NaN, ...
    'shank', NaN, 'depth', NaN, 'meta', [], 'group', NaN, 'groupLabel', "");
for f = ["unitId" "channel" "column" "shank" "depth"]
    if ismember(f, string(obs.Properties.VariableNames)); o.(f) = double(obs.(f)(1)); end
end
m = obs.meta;
if iscell(m); m = m{1}; end
o.meta = m;
end


function L = groupLabels(Fs)
%groupLabels  The union of the session figures' trial group labels, in first-seen order.
L = strings(0, 1);
for k = 1:numel(Fs)
    F = Fs{k};
    if isempty(F) || ~istable(F.groups); continue; end
    lab = string(F.groups.label(:));
    L = [L; lab(~ismember(lab, L))]; %#ok<AGROW>
end
end


function txt = sessionsText(S, group)
%sessionsText  "3 sessions (SYNTH-01)" / "5 sessions, 2 subjects" (combineSessions' subtitle), for a figure with no merged layer.
n = height(S);
subj = unique(S.subject(S.subject ~= ""));
txt = sprintf("%d session%s", n, plural(n));
if isscalar(subj)
    txt = txt + " (" + subj + ")";
elseif numel(subj) > 1
    txt = txt + ", " + numel(subj) + " subjects";
end
if group ~= ""; txt = txt + ", " + group; end
end


function s = plural(n)
s = "";
if n ~= 1; s = "s"; end
end


function tick(chk)
if ~isempty(chk); chk(); end
end
