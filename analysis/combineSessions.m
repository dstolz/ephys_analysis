function R = combineSessions(Rs, sessions, opts)
%combineSessions  Merge one plot's per-session results into one result of the same kind.
%   R = combineSessions(RS, SESSIONS, Name=Value) merges the results RS (a
%   cell {1 x nSessions} of computePlot / compute-function results of one
%   kind, made with the same effective spec; [] = that session has none)
%   of the sessions SESSIONS (sessionTable rows, in the same order) into
%   one result R of the same kind. The series (sessions, subjects or all
%   sessions) are R.groups and the matched tiles (units, sites, cells or
%   channels) are R's units / channels, so every renderer draws R as it
%   draws one session's result. Nothing is computed from spike or event
%   times: epochs are renumbered and concatenated, arrays are copied,
%   averaged or summed. Pure: no I/O, no graphics.
%
%   Options
%     Series       "session" (default; one series per session) | "subject"
%                  (one per subject, its sessions averaged) | "all" (one,
%                  every session averaged)
%     Match        spike results: how units are matched across sessions
%                  into tiles. "pool" (default): every session-unit is its
%                  own tile; "site": one tile per recording channel, a
%                  session's units on it averaged; "mapping": one tile per
%                  row of Mapping. Signal results match channels by
%                  recording channel; heatmap and waveforms results always
%                  pool; behavior has no tiles
%     Mapping      Match "mapping": a table with a column "cell" (the tile
%                  names) and one column per session key (SESSIONS.key,
%                  names kept as they are) holding that session's unit
%                  id(s): a number, or text such as "3 7" (two units,
%                  averaged); missing / empty / NaN = no unit there
%     Error        Series subject / all: the band across sessions, "sem"
%                  (default) | "sd" | "ci95" (t quantile, tinv, from the
%                  Statistics and Machine Learning Toolbox; 1.96 x SEM
%                  without it) | "none"
%     ShowMembers  Series subject / all: keep each member session's values
%                  (R.members) to draw faintly under its summary
%     MinSessions  site / mapping / signal channels: a tile is kept only
%                  when at least this many sessions have data on it; other
%                  matchings (and behavior): at least this many sessions
%                  must have a result (default 1)
%     ColorOrder   "palette" (default; groupColors(1:n, false)) |
%                  "sequential" (groupColors(1:n, true): in table order,
%                  i.e. by date; a design's sequential map follows,
%                  isOrdinalGroups)
%     Group        0 (default): each result must hold one trial group
%                  (combineSessions:Groups otherwise); a label: that trial
%                  group, matched by R.groups.label (not by index), is
%                  sliced from each result (sliceGroup: every epoch-indexed
%                  field follows); a session without it counts as missing
%     TrialGroups  "pool" (default) | "each" (the caller passes Group= per
%                  group; a heatmap keeps every group as its tiles) |
%                  "combine" (every trial group kept: a series per session
%                  (or subject / all) and trial group, labeled
%                  "<series> · <group>", colored by the session, line style
%                  by the group)
%     Kind         the plot kind ("" = RS' spec.kind, else R.kind): a
%                  heatmap's results are psth / evoked results
%
%   Output contract (every kind)
%     kind, units, params, measure   from the first result (a merged
%                  heatmap keeps "psth" or "evoked")
%     groups       table, one row per series (nS rows): index (1..nS),
%                  label (session labels | subject ids ("(no subject)" for
%                  "") | "All sessions" | "<series> · <trial group>" for
%                  combine | a heatmap's trial-group labels), color [nS x 3]
%                  (palette groupColors((1:nB)', false), sequential
%                  groupColors((1:nB)', true), [0.15 0.15 0.15] for one
%                  series; nB = the number of session / subject / all
%                  series; combine: the color of its session series; a
%                  heatmap's groups: the first session's group colors), n
%                  (epochs; waveforms: units), nSessions (sessions in it),
%                  nTrials (summed over its members; NaN when the results
%                  have none), and for combine lineStyle ("-" "--" ":" "-."
%                  cycling by trial group), group (the trial group's label)
%                  and base (the index of its session / subject / all
%                  series: color the series by base, not by row)
%     sessions     SESSIONS plus series (the base series of the session, NaN
%                  when it has no result), status ("done" | "missing"; a
%                  status SESSIONS already holds is kept for a session
%                  without a result), nItems (units or channels of its
%                  result; behavior: its epochs with a value; 0 when
%                  missing) and nEpochs (rows of its epochs, after Group
%                  slicing; 0 when missing)
%     sessionSeries  struct (named so, not "series", which tuning and
%                  behavior results hold as their series labels): mode (the
%                  series used: "all" for a heatmap,
%                  "session" for waveforms), error (Error), errorNote ("95%
%                  CI, t" | "1.96 × SEM" for ci95 across sessions, else ""),
%                  match (the matching used: "pool" | "site" | "mapping" |
%                  "channel" (signals) | "none" (behavior)), minSessions,
%                  group (Group's label, "" for none), trialGroups
%     epochs       vertcat of each session's epochs (session order) with
%                  epoch renumbered 1..N and new columns session (the row of
%                  R.sessions) and sessionKey; trial stays the session's own
%                  trial row; groupIndex / group the session's own trial
%                  group; trial columns are unioned (a column a session
%                  lacks is NaN / ""). UserData: the first session's, with
%                  nEvents, nDroppedNoValue, nDroppedNoSequence,
%                  nDroppedNoStop, nDroppedEdge, nDroppedArtifact, nTrials
%                  and nTrialsSelected summed, sessions (the count with a
%                  result) and dataset (R.dataset). A waveforms result has
%                  epochs []. Tuning and behavior keep every epoch of each
%                  session even when Group slices their series
%     tiles        struct: match, key [nT x 1] ("<sessionKey>|<unitId>" for
%                  pool, "ch<channel>" for site and signals, the cell for
%                  mapping, "all" for behavior), units {nT x nSessions} (row
%                  indices into each session's meta, i.e. its result's
%                  unit / channel columns; [] where the session has none
%                  there), nUnits [nT x nSessions], labels and meta (as R's),
%                  channel (site / signals / mapping: each tile's recording
%                  channel; pool: empty)
%     labels, meta one row per tile (behavior: none). labels: pool
%                  "<label before its first _> · <session label>" (e.g. "su12
%                  · SYNTH-01 2026-09-08"); site the channel name, else
%                  "ch<channel>"; mapping the cell; signals the first
%                  holder's channel label. meta: pool, each session's meta
%                  rows stacked (variables unioned) with a session column
%                  (the row of R.sessions) and the full label; site /
%                  mapping / signals, the row of the first session holding
%                  the tile (its first unit), label replaced, plus
%                  nSessions and nUnits (and cell for mapping; unitId NaN
%                  for site)
%     members      only with ShowMembers and series subject / all (psth,
%                  evoked, tuning): series [nM x 1] (the series of each
%                  member), session (its row of R.sessions), group (its
%                  trial group label), label (the session label; combine:
%                  "<session> · <group>"), and rate (psth) / mean (evoked,
%                  tuning) [nRows x nT x nM], the member's own values (NaN
%                  where it has no data on the tile)
%     dataset      the subtitle: "3 sessions (SYNTH-01)", "5 sessions, 2
%                  subjects" or "3 sessions" (+ ", <group>" with Group)
%     spec         the first result's spec (sessionResults sets it)
%     err          type (series session: the results' own type, over
%                  "epochs", their nBoot; series subject / all: "sem" |
%                  "std" | "ci95" | "none", over "sessions", nBoot NaN), lo,
%                  hi (the band's edges, shaped like the mean)
%   NaN rules: a series has NaN on a tile where none of its member sessions
%   has data there (pool: every series but the tile's own session's); the
%   across-session mean ignores NaN; its band is NaN where fewer than two
%   sessions have a value; a site's units are averaged with their SEM
%   (and the band's half widths) combined as sqrt(sum(sem.^2)) / k.
%
%   Per kind (nB bins / samples / levels, nT tiles, nS series, nE epochs)
%     psth / raster  t, edges, window (from the first; the bins must agree,
%                  combineSessions:Bins); rate / sem / count [nB x nT x nS]
%                  (series session: copies of each session's own; subject /
%                  all: the mean over member sessions and the across-session
%                  half width; count summed); nEpochs, n [nS x 1];
%                  raster (1 x nT: times, epoch (rows of R.epochs), group
%                  (the epoch's series); site: the units' spikes pooled);
%                  epochGroup [nE x 1] (the series of each epoch),
%                  epochStop [nE x 1]; stopMean [nS x 1] (over the series'
%                  epochs); baselineRate / baselineSD [nT x nS] (mean over
%                  the members); rasterEvents (by label: epoch offset, t
%                  concatenated) and rasterSortEvent (label, t [nE x 1],
%                  NaN for a session without) when any session has them;
%                  waveforms (pool: per tile, concatenated; dropped for site
%                  / mapping); auroc []; aux is not merged
%     evoked       t, fs, sampleOffsets, onsetRule (the time base must
%                  agree, combineSessions:TimeBase; no resampling); channels
%                  [nT x 1] (recording channels: meta.channel); mean / sem
%                  [nTime x nT x nS] as psth's rate / sem; nEpochs, n [nS];
%                  keptEpochs (rows of R.epochs); data []; droppedEdge,
%                  droppedNonFinite summed; labels / channelLabels
%     rate         series session: rate / count / rawRate / baseline
%                  [nE x nT] (NaN where the epoch's session has no unit on
%                  the tile; a site's units averaged, their counts summed),
%                  duration [nE x 1], epochIndex (rows of R.epochs),
%                  groupIndex (the epoch's series), rowsAre "epochs";
%                  series subject / all: one row per member session (and
%                  trial group): rate / rawRate = its meanRate, count its
%                  spikes summed over its epochs, baseline its baselineRate,
%                  duration NaN, epochIndex its row of R.sessions,
%                  groupIndex its series, rowsAre "sessions". Either way
%                  meanRate / sem / median / baselineRate [nT x nS] (subject
%                  / all: mean, across-session half width, median over the
%                  members' means, mean)
%     tuning       x (the union of every session's levels, sorted; numeric
%                  or text in all, combineSessions:MixedLevels), xIsNumeric,
%                  mean / sem [nX x nT x nS], n [nX x nS] (epochs, summed),
%                  series / seriesValues (the series labels), seriesParam
%                  ("session" | "subject" | ""; combine: "<that>, <the base
%                  plot's seriesParam>"), param
%     behavior     x (union), xIsNumeric, values (one row per value: epoch
%                  (row of R.epochs), xIndex (into x), seriesIndex (its
%                  session's series), y, session (row of R.sessions)), mean
%                  / sem / median / n [nX x nS] (series subject / all:
%                  across the member sessions' means), nEpochs, nMissing
%                  (summed), yName, units, param, series, seriesValues,
%                  seriesParam
%     heatmap      (Kind "heatmap") a psth result: pool matching and one
%                  series ("All sessions"; with TrialGroups "each" or
%                  "combine" the trial groups, by label, are the series, so
%                  the base plot's groups are its tiles); rows are the
%                  session-units in session order (meta.session). An
%                  evoked result: the evoked merge, channels averaged over
%                  the sessions, the same series
%     waveforms    pool only: meta stacked with session, waveforms
%                  concatenated (timeMs, mean, spikes, from, units, total
%                  per tile; note joined), n = nT, probe from the first;
%                  groups = the sessions (series session), so meta.session
%                  picks a tile's color
%
%   Errors: combineSessions:Kind (results of different kinds),
%   combineSessions:Bins (PSTH bins differ), combineSessions:TimeBase
%   (evoked t / fs differ), combineSessions:MixedLevels (a tuning / behavior
%   x numeric in some sessions, text in others), combineSessions:Mapping
%   (no Mapping, no cell column, or no column for a session key),
%   combineSessions:TooFew (no session has a result, or no tile reaches
%   MinSessions), combineSessions:Groups (several trial groups and no
%   Group), combineSessions:Auroc (an auROC result), combineSessions:Size
%   (SESSIONS and RS differ in length).
%
%   See also sessionResults, sessionTable, EphysAnalysisRunner.computeSessionPlot,
%   populationAnalysis.

arguments
    Rs cell
    sessions table
    opts.Series (1,1) string {mustBeMember(opts.Series, ["session" "subject" "all"])} = "session"
    opts.Match (1,1) string {mustBeMember(opts.Match, ["pool" "site" "mapping"])} = "pool"
    opts.Mapping = []
    opts.Error (1,1) string {mustBeMember(opts.Error, ["sem" "sd" "ci95" "none"])} = "sem"
    opts.ShowMembers (1,1) logical = false
    opts.MinSessions (1,1) double {mustBePositive, mustBeInteger} = 1
    opts.ColorOrder (1,1) string {mustBeMember(opts.ColorOrder, ["palette" "sequential"])} = "palette"
    opts.Group = 0
    opts.TrialGroups (1,1) string {mustBeMember(opts.TrialGroups, ["pool" "each" "combine"])} = "pool"
    opts.Kind (1,1) string = ""
end

Rs = reshape(Rs, 1, []);
nAll = numel(Rs);
if height(sessions) ~= nAll
    error('combineSessions:Size', 'SESSIONS has %d rows for %d results.', height(sessions), nAll);
end
sessions = normalizeSessions(sessions);
present = ~cellfun(@isempty, Rs);
first = find(present, 1);
if isempty(first)
    error('combineSessions:TooFew', 'No session has a result to merge.');
end
kinds = cellfun(@(r) string(r.kind), Rs(present));
if numel(unique(kinds)) > 1
    error('combineSessions:Kind', 'The sessions'' results are of different kinds (%s).', strjoin(unique(kinds), ", "));
end
rkind = kinds(1);
plotKind = opts.Kind;
if plotKind == ""
    plotKind = rkind;
    if isfield(Rs{first}, 'spec') && isstruct(Rs{first}.spec) && isfield(Rs{first}.spec, 'kind')
        plotKind = string(Rs{first}.spec.kind);
    end
end
if rkind == "psth" && any(cellfun(@(r) isfield(r, 'auroc') && ~isempty(r.auroc), Rs(present)))
    error('combineSessions:Auroc', 'auROC curves (baseline Mode "auroc") are not merged across sessions.');
end
spec = [];
if isfield(Rs{first}, 'spec'); spec = Rs{first}.spec; end

isHeat = plotKind == "heatmap";
isWave = rkind == "waveforms";
groupLabel = "";
if ~(isnumeric(opts.Group) && isscalar(opts.Group) && opts.Group == 0)
    groupLabel = string(opts.Group);
end
combine = opts.TrialGroups == "combine" && ~isWave;
keepGroups = combine || (isHeat && opts.TrialGroups == "each");

% --- trial groups: slice one, or check there is one ---------------------------------
if groupLabel ~= ""
    for k = find(present)
        Rs{k} = sliceGroup(Rs{k}, groupLabel);
    end
elseif ~keepGroups
    for k = find(present)
        G = Rs{k}.groups;
        if height(G) ~= 1
            error('combineSessions:Groups', ['%s has %d trial groups (%s): pass Group= (one of them) or ' ...
                'TrialGroups="combine".'], sessions.label(k), height(G), strjoin(string(G.label), ", "));
        end
    end
end
present = ~cellfun(@isempty, Rs);
P = find(present);
if isempty(P)
    error('combineSessions:TooFew', 'No session has the trial group "%s".', groupLabel);
end

% --- series ---------------------------------------------------------------------------
mode = opts.Series;
if isHeat; mode = "all"; end
if isWave; mode = "session"; end
[pairs, S] = seriesOf(Rs, P, sessions, mode, keepGroups, combine, isHeat, opts.ColorOrder);
single = mode == "session";

% --- sessions, epochs ----------------------------------------------------------------
[E, off, epochSeriesOf] = concatEpochs(Rs, P, sessions, pairs);
match = opts.Match;
if isHeat || isWave; match = "pool"; end
if rkind == "evoked"; match = "channel"; end
if rkind == "behavior"; match = "none"; end
if ismember(match, ["pool" "none"]) && numel(P) < opts.MinSessions
    error('combineSessions:TooFew', '%d session(s) have a result; MinSessions is %d.', numel(P), opts.MinSessions);
end
info = struct('P', P, 'nAll', nAll, 'pairs', pairs, 'S', S, 'single', single, 'error', opts.Error, ...
    'members', opts.ShowMembers && ~single, 'off', off, 'epochSeries', epochSeriesOf, 'sessions', sessions);

switch rkind
    case "psth"
        tiles = tileMap(Rs, P, sessions, match, opts.Mapping, opts.MinSessions);
        R = mergePSTH(Rs, tiles, info);
    case "evoked"
        tiles = tileMap(Rs, P, sessions, "channel", [], opts.MinSessions);
        R = mergeEvoked(Rs, tiles, info);
    case "rate"
        tiles = tileMap(Rs, P, sessions, match, opts.Mapping, opts.MinSessions);
        R = mergeRate(Rs, tiles, info);
    case "tuning"
        tiles = tileMap(Rs, P, sessions, match, opts.Mapping, opts.MinSessions);
        R = mergeTuning(Rs, tiles, info, opts.Series, combine);
    case "behavior"
        tiles = oneTile(P, nAll);
        R = mergeBehavior(Rs, tiles, info, opts.Series, combine);
    case "waveforms"
        tiles = tileMap(Rs, P, sessions, "pool", [], opts.MinSessions);
        R = mergeWaveforms(Rs, tiles, info);
    otherwise
        error('combineSessions:Kind', 'A %s result is not merged across sessions.', rkind);
end

% --- what every kind carries ----------------------------------------------------------
[et, over, nb] = errorKind(Rs{P(1)}, single, opts.Error);
note = "";
if ~single && opts.Error == "ci95"
    if hasTinv(); note = "95% CI, t"; else; note = "1.96 × SEM"; end
end
R.groups = S;
R.sessions = sessionRows(Rs, P, sessions, pairs);
R.sessionSeries = struct('mode', mode, 'error', opts.Error, 'errorNote', note, 'match', match, ...
    'minSessions', opts.MinSessions, 'group', groupLabel, 'trialGroups', opts.TrialGroups);
if isfield(R, 'err') && isstruct(R.err)
    R.err.type = et; R.err.over = over; R.err.nBoot = nb;
end
R.dataset = datasetText(sessions, P, groupLabel);
if istable(E)
    U = E.Properties.UserData;
    if ~isstruct(U); U = struct('sessions', numel(P)); end
    U.dataset = R.dataset;
    E.Properties.UserData = U;
end
R.epochs = E;
R.tiles = tiles;
R.spec = spec;
R.created = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end


%% =====================================================================================
%  kinds
%  =====================================================================================

function R = mergePSTH(Rs, tiles, info)
%mergePSTH  psth / raster (and a heatmap of spikes): rates per bin, rasters, events.
P = info.P;
R1 = Rs{P(1)};
for k = P(2:end)
    e = Rs{k}.edges;
    if numel(e) ~= numel(R1.edges) || max(abs(e(:) - R1.edges(:))) > 1e-9
        error('combineSessions:Bins', '%s: the PSTH bins differ from the first session''s.', info.sessions.label(k));
    end
end
nB = numel(R1.t);
[M, H, LO, HI, V] = seriesArrays(Rs, tiles, info, @(r) arrays3(r, 'rate'), nB);
C = pairCombine(Rs, tiles, info, @(r) r.count, nB, "sum");
nS = height(info.S);
count = zeros(nB, numel(tiles.key), nS);
for s = 1:nS
    count(:, :, s) = sum(C(:, :, info.pairs.s == s), 3, 'omitnan');
end
[BR, ~] = seriesMean(Rs, tiles, info, @(r) reshape(r.baselineRate, 1, size(r.baselineRate, 1), []));
[BS, ~] = seriesMean(Rs, tiles, info, @(r) reshape(r.baselineSD, 1, size(r.baselineSD, 1), []));
nEp = seriesEpochs(Rs, info, @(r, g) r.nEpochs(g));

R = struct();
R.kind = "psth";
R.t = R1.t;
R.edges = R1.edges;
R.window = R1.window;
R.rate = M;
R.sem = H;
R.err = struct('type', "", 'lo', LO, 'hi', HI, 'over', "", 'nBoot', NaN);
R.count = count;
R.nEpochs = nEp;
[R.raster, hasRaster] = mergeRaster(Rs, tiles, info);
if ~hasRaster; R.raster = struct('times', {}, 'epoch', {}, 'group', {}); end
R.epochGroup = info.epochSeries;
R.epochStop = concatField(Rs, P, @(r) r.epochStop(:));
R.stopMean = NaN(nS, 1);
for s = 1:nS
    v = R.epochStop(R.epochGroup == s);
    if any(isfinite(v)); R.stopMean(s) = mean(v, 'omitnan'); end
end
R.baselineRate = reshape(BR, [], nS);
R.baselineSD = reshape(BS, [], nS);
[R.labels, R.meta] = deal(tiles.labels, tiles.meta);
R.n = nEp;
R.units = R1.units;
R.measure = R1.measure;
R.params = R1.params;
R.auroc = [];
ev = mergeRasterEvents(Rs, P, info.off);
if ~isempty(ev); R.rasterEvents = ev; end
se = mergeSortEvent(Rs, P, info.off, numel(R.epochGroup));
if ~isempty(se); R.rasterSortEvent = se; end
if tiles.match == "pool" && all(cellfun(@(r) isfield(r, 'waveforms') && isstruct(r.waveforms), Rs(P)))
    R.waveforms = mergeWaveformStructs(Rs, tiles);
end
if info.members; R.members = membersOf(info, 'rate', V); end
end


function R = mergeEvoked(Rs, tiles, info)
%mergeEvoked  evoked (and a heatmap of a signal): event-locked means per recording channel.
P = info.P;
R1 = Rs{P(1)};
for k = P(2:end)
    r = Rs{k};
    if numel(r.t) ~= numel(R1.t) || max(abs(r.t(:) - R1.t(:))) > 1e-12 || r.fs ~= R1.fs
        error('combineSessions:TimeBase', '%s: the time base (%g Hz, %d samples) differs from the first session''s (%g Hz, %d samples).', ...
            info.sessions.label(k), r.fs, numel(r.t), R1.fs, numel(R1.t));
    end
end
nB = numel(R1.t);
[M, H, LO, HI, V] = seriesArrays(Rs, tiles, info, @(r) arrays3(r, 'mean'), nB);
nEp = seriesEpochs(Rs, info, @(r, g) r.nEpochs(g));
R = struct();
R.kind = "evoked";
R.t = R1.t;
R.mean = M;
R.sem = H;
R.err = struct('type', "", 'lo', LO, 'hi', HI, 'over', "", 'nBoot', NaN);
R.nEpochs = nEp;
R.data = [];
R.channels = tiles.channel;
R.labels = tiles.labels;
R.channelLabels = tiles.labels;
R.magnitude = fieldOr(R1, 'magnitude', false);
R.statistic = fieldOr(R1, 'statistic', "mean");
R.rectified = fieldOr(R1, 'rectified', false);
R.fs = R1.fs;
R.units = R1.units;
R.sampleOffsets = R1.sampleOffsets;
R.onsetRule = R1.onsetRule;
R.keptEpochs = concatField(Rs, P, @(r) r.keptEpochs(:), info.off);
R.droppedEdge = sum(cellfun(@(r) r.droppedEdge, Rs(P)));
R.droppedNonFinite = sum(cellfun(@(r) r.droppedNonFinite, Rs(P)));
R.meta = tiles.meta;
R.n = nEp;
R.params = R1.params;
if info.members; R.members = membersOf(info, 'mean', V); end
end


function R = mergeRate(Rs, tiles, info)
%mergeRate  rate: per-epoch rates (series session) or per-session means (subject / all), and the means.
P = info.P;
R1 = Rs{P(1)};
nT = numel(tiles.key);
nS = height(info.S);
pairs = info.pairs;
asRow = @(f) @(r) reshape(r.(f), 1, size(r.(f), 1), []);
[M, H, LO, HI, V] = seriesArrays(Rs, tiles, info, @(r) arrays3(r, 'meanRate', true), 1);
M = reshape(M, nT, nS); H = reshape(H, nT, nS); LO = reshape(LO, nT, nS); HI = reshape(HI, nT, nS);
Vm = reshape(V, nT, []);   % [nT x nPairs]: each member's mean rate
MD = pairCombine(Rs, tiles, info, asRow('median'), 1, "mean");
MD = reshape(MD, nT, []);
[BR, ~] = seriesMean(Rs, tiles, info, asRow('baselineRate'));
R = struct();
R.kind = "rate";
R.measure = R1.measure;
if info.single
    nE = numel(info.epochSeries);
    rate = NaN(nE, nT); count = rate; raw = rate; base = rate;
    for k = P
        r = Rs{k};
        rows = info.off(k) + (1:size(r.rate, 1));
        for t = 1:nT
            u = tiles.units{t, k};
            if isempty(u); continue; end
            rate(rows, t) = mean(r.rate(:, u), 2, 'omitnan');
            raw(rows, t) = mean(r.rawRate(:, u), 2, 'omitnan');
            base(rows, t) = mean(r.baseline(:, u), 2, 'omitnan');
            count(rows, t) = sum(r.count(:, u), 2);
        end
    end
    R.rate = rate;
    R.count = count;
    R.rawRate = raw;
    R.duration = concatField(Rs, P, @(r) r.duration(:));
    R.baseline = base;
    R.meanRate = M;
    R.sem = H;
    R.err = struct('type', "", 'lo', LO, 'hi', HI, 'over', "", 'nBoot', NaN);
    R.median = zeros(nT, nS);
    for s = 1:nS
        R.median(:, s) = MD(:, pairs.s == s);
    end
    R.baselineRate = reshape(BR, nT, nS);
    R.epochIndex = concatField(Rs, P, @(r) r.epochIndex(:), info.off);
    R.groupIndex = info.epochSeries;
    R.rowsAre = "epochs";
else
    nPr = height(pairs);
    cnt = NaN(nPr, nT);
    BRp = pairCombine(Rs, tiles, info, asRow('baselineRate'), 1, "mean");
    for p = 1:nPr
        r = Rs{pairs.k(p)};
        rows = r.groupIndex == pairs.g(p);
        for t = 1:nT
            u = tiles.units{t, pairs.k(p)};
            if isempty(u); continue; end
            cnt(p, t) = sum(r.count(rows, u), 'all');
        end
    end
    R.rate = Vm.';
    R.count = cnt;
    R.rawRate = Vm.';
    R.duration = NaN(nPr, 1);
    R.baseline = reshape(BRp, nT, []).';
    R.meanRate = M;
    R.sem = H;
    R.err = struct('type', "", 'lo', LO, 'hi', HI, 'over', "", 'nBoot', NaN);
    R.median = NaN(nT, nS);
    for s = 1:nS
        R.median(:, s) = median(Vm(:, pairs.s == s), 2, 'omitnan');
    end
    R.baselineRate = reshape(BR, nT, nS);
    R.epochIndex = pairs.k;
    R.groupIndex = pairs.s;
    R.rowsAre = "sessions";
end
R.labels = tiles.labels;
R.meta = tiles.meta;
R.n = seriesEpochs(Rs, info, @(r, g) r.n(g));
R.units = R1.units;
R.params = R1.params;
end


function R = mergeTuning(Rs, tiles, info, seriesMode, combine)
%mergeTuning  tuning: the curves on the union of every session's levels.
P = info.P;
R1 = Rs{P(1)};
[ux, isNum, rowMaps] = levelUnion(Rs, P, @(r) r.x, @(r) r.xIsNumeric, R1.param, info.sessions);
nX = numel(ux);
nS = height(info.S);
[M, H, LO, HI, V] = seriesArrays(Rs, tiles, info, @(r) arrays3(r, 'mean'), nX, rowMaps);
N = zeros(nX, nS);
for p = 1:height(info.pairs)
    k = info.pairs.k(p);
    N(rowMaps{k}, info.pairs.s(p)) = N(rowMaps{k}, info.pairs.s(p)) + Rs{k}.n(:, info.pairs.g(p));
end
R = struct();
R.kind = "tuning";
R.x = ux;
R.xIsNumeric = isNum;
R.series = info.S.label;
R.seriesValues = info.S.label;
R.mean = M;
R.sem = H;
R.err = struct('type', "", 'lo', LO, 'hi', HI, 'over', "", 'nBoot', NaN);
R.n = N;
R.param = R1.param;
R.seriesParam = seriesParamOf(seriesMode, combine, R1.seriesParam);
R.labels = tiles.labels;
R.meta = tiles.meta;
R.units = R1.units;
R.params = R1.params;
if info.members; R.members = membersOf(info, 'mean', V); end
end


function R = mergeBehavior(Rs, tiles, info, seriesMode, combine)
%mergeBehavior  behavior: every value, on the union of the levels; the means per series.
P = info.P;
R1 = Rs{P(1)};
[ux, isNum, rowMaps] = levelUnion(Rs, P, @(r) r.x, @(r) r.xIsNumeric, R1.param, info.sessions);
nX = numel(ux);
nS = height(info.S);
pairs = info.pairs;
asCol = @(f) @(r) reshape(r.(f), size(r.(f), 1), 1, []);
[M, H, LO, HI] = seriesArrays(Rs, tiles, info, @(r) arrays3(r, 'mean', false, true), nX, rowMaps);
M = reshape(M, nX, nS); H = reshape(H, nX, nS); LO = reshape(LO, nX, nS); HI = reshape(HI, nX, nS);
MD = reshape(pairCombine(Rs, tiles, info, asCol('median'), nX, "mean", rowMaps), nX, []);
Vm = reshape(pairCombine(Rs, tiles, info, asCol('mean'), nX, "mean", rowMaps), nX, []);   % each member's means
N = zeros(nX, nS);
med = NaN(nX, nS);
for s = 1:nS
    ps = find(pairs.s == s);
    for p = ps.'
        k = pairs.k(p);
        N(rowMaps{k}, s) = N(rowMaps{k}, s) + Rs{k}.n(:, pairs.g(p));
    end
    if info.single
        med(:, s) = MD(:, ps(1));
    else
        med(:, s) = median(Vm(:, ps), 2, 'omitnan');
    end
end
vals = cell(numel(P), 1);
pairOf = pairIndex(pairs, info.nAll);
for j = 1:numel(P)
    k = P(j);
    T = Rs{k}.values;
    sIdx = zeros(height(T), 1);
    for i = 1:height(T)
        sIdx(i) = pairs.s(pairOf(k, T.seriesIndex(i)));
    end
    vals{j} = table(info.off(k) + T.epoch, reshape(rowMaps{k}(T.xIndex), [], 1), sIdx, T.y, repmat(k, height(T), 1), ...
        'VariableNames', {'epoch', 'xIndex', 'seriesIndex', 'y', 'session'});
end
R = struct();
R.kind = "behavior";
R.x = ux;
R.xIsNumeric = isNum;
R.series = info.S.label;
R.seriesValues = info.S.label;
R.mean = M;
R.sem = H;
R.err = struct('type', "", 'lo', LO, 'hi', HI, 'over', "", 'nBoot', NaN);
R.median = med;
R.n = N;
R.values = vertcat(vals{:});
R.nEpochs = sum(cellfun(@(r) r.nEpochs, Rs(P)));
R.nMissing = sum(cellfun(@(r) r.nMissing, Rs(P)));
R.param = R1.param;
R.seriesParam = seriesParamOf(seriesMode, combine, R1.seriesParam);
R.yName = R1.yName;
R.units = R1.units;
R.params = R1.params;
end


function R = mergeWaveforms(Rs, tiles, info)
%mergeWaveforms  waveforms: every session's units side by side, a series per session.
P = info.P;
R1 = Rs{P(1)};
R = struct();
R.kind = "waveforms";
R.meta = tiles.meta;
R.labels = tiles.labels;
R.n = numel(tiles.key);
R.probe = fieldOr(R1, 'probe', []);
if all(cellfun(@(r) isfield(r, 'waveforms') && isstruct(r.waveforms), Rs(P)))
    R.waveforms = mergeWaveformStructs(Rs, tiles);
end
end


%% =====================================================================================
%  series, tiles, epochs
%  =====================================================================================

function [pairs, S] = seriesOf(Rs, P, sessions, mode, keepGroups, combine, isHeat, colorOrder)
%seriesOf  The member pairs (session k, its trial group g) and the series table they make up.
%   PAIRS: table k, g (the group's row in Rs{k}.groups), gu (in the union of
%   the group labels), b (the base series: session / subject / all), s (the
%   series). S: the groups table of the merged result.
groupLabels = strings(0, 1);
k = zeros(0, 1); g = k; gu = k;
for kk = P
    G = Rs{kk}.groups;
    lab = string(G.label(:));
    for gg = 1:numel(lab)
        j = find(groupLabels == lab(gg), 1);
        if isempty(j); groupLabels(end+1, 1) = lab(gg); j = numel(groupLabels); end %#ok<AGROW>
        k(end+1, 1) = kk; g(end+1, 1) = gg; gu(end+1, 1) = j; %#ok<AGROW>
    end
end
% the base series of each session
switch mode
    case "session"
        baseOfSession = zeros(height(sessions), 1);
        baseOfSession(P) = 1:numel(P);
        baseLabels = sessions.label(P);
    case "subject"
        subj = sessions.subject(P);
        subj(subj == "") = "(no subject)";
        [baseLabels, ~, ib] = unique(subj, 'stable');
        baseOfSession = zeros(height(sessions), 1);
        baseOfSession(P) = ib;
    otherwise
        baseOfSession = zeros(height(sessions), 1);
        baseOfSession(P) = 1;
        baseLabels = "All sessions";
end
baseLabels = reshape(string(baseLabels), [], 1);
b = baseOfSession(k);
nB = numel(baseLabels);
if nB == 1
    baseColors = [0.15 0.15 0.15];
else
    baseColors = groupColors((1:nB).', colorOrder == "sequential");
end
if isHeat && keepGroups
    % a heatmap's tiles are the trial groups: one series per group label
    s = gu;
    label = groupLabels;
    color = zeros(numel(label), 3);
    for j = 1:numel(label)
        p = find(gu == j, 1);
        color(j, :) = Rs{k(p)}.groups.color(g(p), :);
    end
    S = table((1:numel(label)).', label, color, 'VariableNames', {'index', 'label', 'color'});
elseif combine
    combos = unique([b gu], 'rows');   % by base series, then group
    [~, s] = ismember([b gu], combos, 'rows');
    styles = ["-" "--" ":" "-."];
    label = baseLabels(combos(:, 1)) + " · " + groupLabels(combos(:, 2));
    S = table((1:size(combos, 1)).', label, baseColors(combos(:, 1), :), ...
        'VariableNames', {'index', 'label', 'color'});
    S.lineStyle = reshape(styles(mod(combos(:, 2) - 1, numel(styles)) + 1), [], 1);
    S.group = groupLabels(combos(:, 2));
    S.base = combos(:, 1);
else
    s = b;
    S = table((1:nB).', baseLabels, baseColors, 'VariableNames', {'index', 'label', 'color'});
end
pairs = table(k, g, gu, b, s);
nS = height(S);
n = zeros(nS, 1); nSess = zeros(nS, 1); nTr = NaN(nS, 1);
for j = 1:nS
    ps = find(pairs.s == j);
    nSess(j) = numel(unique(pairs.k(ps)));
    for p = ps.'
        G = Rs{pairs.k(p)}.groups;
        if ismember("n", string(G.Properties.VariableNames)); n(j) = n(j) + G.n(pairs.g(p)); end
        if ismember("nTrials", string(G.Properties.VariableNames))
            if isnan(nTr(j)); nTr(j) = 0; end
            nTr(j) = nTr(j) + G.nTrials(pairs.g(p));
        end
    end
end
S = addvars(S, n, nSess, nTr, 'After', 'color', 'NewVariableNames', {'n', 'nSessions', 'nTrials'});
end


function tiles = tileMap(Rs, P, sessions, match, mapping, minSessions)
%tileMap  The tiles: which of each session's units (or channels) go on each.
nAll = numel(Rs);
metas = cell(1, nAll);
for k = P
    metas{k} = metaOf(Rs{k});
end
units = cell(0, nAll);
key = strings(0, 1);
labels = strings(0, 1);
rows = cell(0, 1);   % [k u] of the row each tile's meta comes from
chan = zeros(0, 1);
switch match
    case "pool"
        for k = P
            m = metas{k};
            for u = 1:height(m)
                units(end+1, :) = cell(1, nAll); %#ok<AGROW>
                units{end, k} = u;
                id = string(u);
                if ismember("unitId", string(m.Properties.VariableNames)); id = string(m.unitId(u)); end
                key(end+1, 1) = sessions.key(k) + "|" + id; %#ok<AGROW>
                lab = string(m.label(u));
                if contains(lab, "_") && ~startsWith(lab, "_"); lab = extractBefore(lab, "_"); end
                labels(end+1, 1) = lab + " · " + sessions.label(k); %#ok<AGROW>
                rows{end+1, 1} = [k u]; %#ok<AGROW>
            end
        end
    case {"site" "channel"}
        chs = cell(1, nAll);
        allCh = zeros(0, 1);
        for k = P
            chs{k} = channelsOf(Rs{k}, metas{k});
            allCh = [allCh; chs{k}(:)]; %#ok<AGROW>
        end
        for c = unique(allCh(isfinite(allCh))).'
            uk = cell(1, nAll);
            for k = P
                uk{k} = reshape(find(chs{k} == c), 1, []);
                if match == "channel" && numel(uk{k}) > 1; uk{k} = uk{k}(1); end
            end
            holders = P(~cellfun(@isempty, uk(P)));
            if numel(holders) < minSessions; continue; end
            units(end+1, :) = uk; %#ok<AGROW>
            key(end+1, 1) = "ch" + c; %#ok<AGROW>
            k1 = holders(1);
            m = metas{k1};
            lab = "ch" + c;
            if match == "channel"
                lab = string(m.label(uk{k1}(1)));
            elseif ismember("channelName", string(m.Properties.VariableNames)) && strtrim(string(m.channelName(uk{k1}(1)))) ~= ""
                lab = string(m.channelName(uk{k1}(1)));
            end
            labels(end+1, 1) = lab; %#ok<AGROW>
            rows{end+1, 1} = [k1 uk{k1}(1)]; %#ok<AGROW>
            chan(end+1, 1) = c; %#ok<AGROW>
        end
    case "mapping"
        M = mapping;
        if isempty(M) || ~istable(M)
            error('combineSessions:Mapping', 'Match "mapping" needs a Mapping table (a cell column, then one column per session key).');
        end
        cols = string(M.Properties.VariableNames);
        if ~ismember("cell", cols)
            error('combineSessions:Mapping', 'The unit mapping has no "cell" column.');
        end
        for k = P
            if ~ismember(sessions.key(k), cols)
                error('combineSessions:Mapping', 'The unit mapping has no column for %s (%s).', sessions.key(k), sessions.label(k));
            end
        end
        for r = 1:height(M)
            uk = cell(1, nAll);
            for k = P
                ids = parseIds(M.(char(sessions.key(k)))(r));
                m = metas{k};
                if isempty(ids) || ~ismember("unitId", string(m.Properties.VariableNames)); continue; end
                uk{k} = reshape(find(ismember(double(m.unitId), ids)), 1, []);
            end
            holders = P(~cellfun(@isempty, uk(P)));
            if numel(holders) < minSessions || isempty(holders); continue; end
            units(end+1, :) = uk; %#ok<AGROW>
            key(end+1, 1) = string(M.cell(r)); %#ok<AGROW>
            labels(end+1, 1) = string(M.cell(r)); %#ok<AGROW>
            rows{end+1, 1} = [holders(1) uk{holders(1)}(1)]; %#ok<AGROW>
        end
end
nT = numel(key);
if nT == 0
    error('combineSessions:TooFew', 'No %s reaches MinSessions (%d session(s) with data on it).', tileWord(match), minSessions);
end
nUnits = cellfun(@numel, units);
% meta: one row per tile
parts = cell(nT, 1);
for t = 1:nT
    ku = rows{t};
    row = metas{ku(1)}(ku(2), :);
    if match == "pool"
        row.session = ku(1);
    else
        row.label = labels(t);
        row.nSessions = nnz(nUnits(t, :) > 0);
        row.nUnits = sum(nUnits(t, :));
        if match == "site" && ismember("unitId", string(row.Properties.VariableNames)); row.unitId = NaN; end
        if match == "mapping"; row.cell = labels(t); end
        if match == "site" && ismember("nSpikes", string(row.Properties.VariableNames))
            tot = 0;
            for k = P
                u = units{t, k};
                if ~isempty(u); tot = tot + sum(double(metas{k}.nSpikes(u))); end
            end
            row.nSpikes = tot;
        end
    end
    parts{t} = row;
end
tiles = struct('match', match, 'key', key, 'units', {units}, 'nUnits', nUnits);
tiles.labels = labels;
tiles.meta = stackTables(parts);
tiles.channel = chan;
if match ~= "pool" && isempty(chan) && ismember("channel", string(tiles.meta.Properties.VariableNames))
    tiles.channel = double(tiles.meta.channel);
end
end


function tiles = oneTile(P, nAll)
%oneTile  Behavior: one tile, every session's only "unit".
units = cell(1, nAll);
units(P) = {1};
tiles = struct('match', "none", 'key', "all", 'units', {units}, 'nUnits', double(~cellfun(@isempty, units)));
tiles.labels = "all";
tiles.meta = table();
tiles.channel = zeros(0, 1);
end


function m = metaOf(r)
%metaOf  A result's unit / channel table (built from its labels when it has none).
m = [];
if isfield(r, 'meta'); m = r.meta; end
n = numel(r.labels);
if ~istable(m) || height(m) ~= n
    label = reshape(string(r.labels), [], 1);
    m = table(label);
    if r.kind == "evoked" && isfield(r, 'channels') && numel(r.channels) == n
        m.channel = double(r.channels(:));
    end
end
if ~ismember("label", string(m.Properties.VariableNames))
    m.label = reshape(string(r.labels), [], 1);
end
end


function c = channelsOf(r, m)
%channelsOf  The recording channel of each unit / channel column of a result.
if ismember("channel", string(m.Properties.VariableNames))
    c = double(m.channel(:));
elseif isfield(r, 'channels')
    c = double(r.channels(:));
else
    c = (1:height(m)).';
end
end


function ids = parseIds(v)
%parseIds  A mapping cell's unit ids: a number, or text such as "3 7" / "3,7"; none for missing.
if iscell(v); v = v{1}; end
if isnumeric(v) || islogical(v)
    ids = double(v(:)).';
    ids = ids(isfinite(ids));
    return
end
v = string(v);
if ismissing(v) || strtrim(v) == ""; ids = []; return; end
ids = str2double(split(strtrim(regexprep(v, '[,;]', ' ')))).';
ids = ids(isfinite(ids));
end


function [E, off, epochSeries] = concatEpochs(Rs, P, sessions, pairs)
%concatEpochs  Every session's epochs in one table, renumbered; each epoch's series.
nAll = numel(Rs);
off = zeros(1, nAll);
parts = cell(numel(P), 1);
total = 0;
U = [];
pairOf = pairIndex(pairs, nAll);
epochSeries = zeros(0, 1);
for j = 1:numel(P)
    k = P(j);
    r = Rs{k};
    off(k) = total;
    if ~isfield(r, 'epochs') || ~istable(r.epochs); continue; end
    T = r.epochs;
    h = height(T);
    if isempty(U); U = T.Properties.UserData; else; U = addCounts(U, T.Properties.UserData); end
    T.Properties.UserData = [];
    T.epoch = total + (1:h).';
    T.session = repmat(k, h, 1);
    T.sessionKey = repmat(sessions.key(k), h, 1);
    parts{j} = T;
    % each epoch's series, from its own trial group
    gi = [];
    switch r.kind
        case "psth", gi = r.epochGroup(:);
        case "rate", gi = r.groupIndex(:);
        case "evoked", gi = T.groupIndex(:);
    end
    if ~isempty(gi)
        s = NaN(h, 1);
        ok = gi >= 1 & gi <= size(pairOf, 2);
        idx = zeros(h, 1);
        idx(ok) = pairOf(sub2ind(size(pairOf), repmat(k, nnz(ok), 1), gi(ok)));
        s(idx > 0) = pairs.s(idx(idx > 0));
        epochSeries = [epochSeries; s]; %#ok<AGROW>
    end
    total = total + h;
end
parts = parts(~cellfun(@isempty, parts));
if isempty(parts)
    E = [];
    return
end
E = stackTables(parts);
if isstruct(U)
    U.sessions = numel(P);
end
E.Properties.UserData = U;
end


function U = addCounts(U, V)
%addCounts  Sum the epoch tables' counts (UserData) over sessions.
if ~isstruct(U) || ~isstruct(V); return; end
for f = ["nEvents" "nDroppedNoValue" "nDroppedNoSequence" "nDroppedNoStop" "nDroppedEdge" "nDroppedArtifact" ...
        "nTrials" "nTrialsSelected"]
    if isfield(U, f) && isfield(V, f); U.(f) = U.(f) + V.(f); end
end
end


function M = pairIndex(pairs, nAll)
%pairIndex  M(k, g): the row of PAIRS holding session K's trial group G (0 = none).
M = zeros(nAll, max([1; pairs.g]));
for p = 1:height(pairs)
    M(pairs.k(p), pairs.g(p)) = p;
end
end


function T = sessionRows(Rs, P, sessions, pairs)
%sessionRows  The sessions table with each session's series, status, items and epochs.
n = height(sessions);
T = sessions;
series = NaN(n, 1);
status = repmat("missing", n, 1);
if ismember("status", string(sessions.Properties.VariableNames))
    status = string(sessions.status);
    status(status == "done") = "missing";
end
nItems = zeros(n, 1);
nEpochs = zeros(n, 1);
for k = P
    series(k) = pairs.b(find(pairs.k == k, 1));
    status(k) = "done";
    r = Rs{k};
    if r.kind == "behavior"
        nItems(k) = height(r.values);
    elseif isfield(r, 'labels')
        nItems(k) = numel(r.labels);
    end
    if isfield(r, 'epochs') && istable(r.epochs); nEpochs(k) = height(r.epochs); end
end
T.series = series;
T.status = status;
T.nItems = nItems;
T.nEpochs = nEpochs;
end


function S = normalizeSessions(S)
%normalizeSessions  The columns combineSessions reads: label, subject, key (filled when a hand-made table lacks them).
n = height(S);
vars = string(S.Properties.VariableNames);
if ~ismember("key", vars); S.key = "s" + (1:n).'; end
if ~ismember("label", vars)
    if ismember("name", vars); S.label = string(S.name); else; S.label = "session " + (1:n).'; end
end
if ~ismember("subject", vars); S.subject = strings(n, 1); end
S.key = string(S.key); S.label = string(S.label); S.subject = string(S.subject);
end


%% =====================================================================================
%  values: per member pair, then per series
%  =====================================================================================

function A = arrays3(r, field, asRow, asCol)
%arrays3  A result's value, SEM and band as [nRows x nUnits x nGroups] arrays: {mean, sem, lo, hi}.
%   asRow: a [nUnits x nGroups] field becomes [1 x nUnits x nGroups] (rate);
%   asCol: a [nRows x nGroups] field becomes [nRows x 1 x nGroups] (behavior).
if nargin < 3; asRow = false; end
if nargin < 4; asCol = false; end
m = r.(field);
s = r.sem;
[lo, hi] = resultBounds(r, field);
shape = @(x) x;
if asRow; shape = @(x) reshape(x, 1, size(x, 1), []); end
if asCol; shape = @(x) reshape(x, size(x, 1), 1, []); end
A = {shape(m), shape(s), shape(lo), shape(hi)};
end


function [M, H, LO, HI, V] = seriesArrays(Rs, tiles, info, getter, nRows, rowMaps)
%seriesArrays  The series' means, half widths and band edges [nRows x nT x nS]; V each member's values.
if nargin < 6; rowMaps = {}; end
pairs = info.pairs;
nT = numel(tiles.key);
nP = height(pairs);
nS = height(info.S);
V = NaN(nRows, nT, nP); Sm = V; Lo = V; Hi = V;
for p = 1:nP
    k = pairs.k(p);
    A = getter(Rs{k});
    rm = (1:size(A{1}, 1)).';
    if ~isempty(rowMaps); rm = rowMaps{k}; end
    for t = 1:nT
        u = tiles.units{t, k};
        if isempty(u); continue; end
        g = pairs.g(p);
        m = A{1}(:, u, g);
        if isscalar(u)
            V(rm, t, p) = m; Sm(rm, t, p) = A{2}(:, u, g); Lo(rm, t, p) = A{3}(:, u, g); Hi(rm, t, p) = A{4}(:, u, g);
        else   % a site's units: averaged, their SEM and band half widths combined
            v = mean(m, 2, 'omitnan');
            V(rm, t, p) = v;
            Sm(rm, t, p) = rss(A{2}(:, u, g));
            Lo(rm, t, p) = v - rss(m - A{3}(:, u, g));
            Hi(rm, t, p) = v + rss(A{4}(:, u, g) - m);
        end
    end
end
M = NaN(nRows, nT, nS); H = M; LO = M; HI = M;
for s = 1:nS
    ps = find(pairs.s == s);
    if info.single
        p = ps(1);
        M(:, :, s) = V(:, :, p); H(:, :, s) = Sm(:, :, p); LO(:, :, s) = Lo(:, :, p); HI(:, :, s) = Hi(:, :, p);
    else
        [m, h] = acrossSessions(V(:, :, ps), 3, info.error);
        M(:, :, s) = m; H(:, :, s) = h; LO(:, :, s) = m - h; HI(:, :, s) = m + h;
    end
end
end


function C = pairCombine(Rs, tiles, info, getter, nRows, how, rowMaps)
%pairCombine  Each member pair's values per tile [nRows x nT x nPairs]: a site's units averaged ("mean") or summed ("sum").
if nargin < 7; rowMaps = {}; end
pairs = info.pairs;
nT = numel(tiles.key);
C = NaN(nRows, nT, height(pairs));
for p = 1:height(pairs)
    k = pairs.k(p);
    A = getter(Rs{k});
    rm = (1:size(A, 1)).';
    if ~isempty(rowMaps); rm = rowMaps{k}; end
    for t = 1:nT
        u = tiles.units{t, k};
        if isempty(u); continue; end
        x = A(:, u, pairs.g(p));
        if how == "sum"
            C(rm, t, p) = sum(x, 2);
        else
            C(rm, t, p) = mean(x, 2, 'omitnan');
        end
    end
end
end


function [M, V] = seriesMean(Rs, tiles, info, getter)
%seriesMean  [1 x nT x nS]: the mean over each series' members (a site's units averaged first).
V = pairCombine(Rs, tiles, info, getter, 1, "mean");
nS = height(info.S);
M = NaN(1, size(V, 2), nS);
for s = 1:nS
    M(:, :, s) = mean(V(:, :, info.pairs.s == s), 3, 'omitnan');
end
M = reshape(M, size(V, 2), nS);
end


function n = seriesEpochs(Rs, info, getter)
%seriesEpochs  [nS x 1]: a per-group count summed over each series' member pairs.
nS = height(info.S);
n = zeros(nS, 1);
for p = 1:height(info.pairs)
    n(info.pairs.s(p)) = n(info.pairs.s(p)) + getter(Rs{info.pairs.k(p)}, info.pairs.g(p));
end
end


function [m, h, n] = acrossSessions(X, dim, type)
%acrossSessions  The mean over sessions and its band's half width: SEM, SD, the t 95% CI or none.
%   NaN-aware; the half width is NaN where fewer than 2 sessions have a value.
n = sum(~isnan(X), dim);
m = mean(X, dim, 'omitnan');
sd = std(X, 0, dim, 'omitnan');
switch type
    case "sem"
        h = sd ./ sqrt(n);
    case "sd"
        h = sd;
    case "ci95"
        h = tQuantile(n) .* sd ./ sqrt(n);
    otherwise
        h = NaN(size(m));
end
h(n < 2) = NaN;
end


function q = tQuantile(n)
%tQuantile  tinv(0.975, n - 1) (Statistics and Machine Learning Toolbox); 1.96 without it.
q = 1.96 * ones(size(n));
if ~hasTinv(); return; end
try
    q = tinv(0.975, max(n - 1, 1));
catch
    q = 1.96 * ones(size(n));
end
end


function tf = hasTinv()
tf = license('test', 'Statistics_Toolbox') && exist('tinv', 'file') == 2;
end


function y = rss(X)
%rss  sqrt(sum(X.^2)) / k along rows, k the values that are not NaN (NaN when none).
y = sqrt(sum(X .^ 2, 2, 'omitnan')) ./ sum(~isnan(X), 2);
end


function [et, over, nb] = errorKind(R1, single, err)
%errorKind  The merged band's type: the results' own (series session), else the across-session one.
if single
    et = "sem"; nb = NaN;
    if isfield(R1, 'err') && isstruct(R1.err) && isfield(R1.err, 'type')
        et = string(R1.err.type);
        if isfield(R1.err, 'nBoot'); nb = R1.err.nBoot; end
    end
    over = "epochs";
    return
end
switch err
    case "sd", et = "std";
    otherwise, et = err;
end
over = "sessions";
nb = NaN;
end


function M = membersOf(info, field, V)
%membersOf  Each member session's own values, to draw faintly under its series' summary.
pairs = info.pairs;
lab = info.sessions.label(pairs.k);
G = info.S;
grp = strings(height(pairs), 1);
for p = 1:height(pairs)
    if ismember("group", string(G.Properties.VariableNames))
        grp(p) = G.group(pairs.s(p));
        lab(p) = lab(p) + " · " + grp(p);
    end
end
M = struct('series', pairs.s, 'session', pairs.k, 'group', grp, 'label', lab);
M.(field) = V;
end


%% =====================================================================================
%  rasters, events, waveforms
%  =====================================================================================

function [raster, ok] = mergeRaster(Rs, tiles, info)
%mergeRaster  Each tile's spikes: its units' (pooled for a site), epochs offset to rows of the merged epochs.
P = info.P;
ok = all(cellfun(@(r) isfield(r, 'raster') && isstruct(r.raster) && ~isempty(r.raster), Rs(P)));
nT = numel(tiles.key);
raster = struct('times', cell(1, nT), 'epoch', cell(1, nT), 'group', cell(1, nT));
if ~ok; return; end
for t = 1:nT
    tm = zeros(0, 1); ep = zeros(0, 1);
    for k = P
        for u = tiles.units{t, k}
            r = Rs{k}.raster(u);
            tm = [tm; double(r.times(:))]; %#ok<AGROW>
            ep = [ep; info.off(k) + double(r.epoch(:))]; %#ok<AGROW>
        end
    end
    raster(t).times = tm;
    raster(t).epoch = ep;
    raster(t).group = info.epochSeries(ep);
    raster(t).group = reshape(raster(t).group, [], 1);
end
end


function ev = mergeRasterEvents(Rs, P, off)
%mergeRasterEvents  The raster marks of every session, by label, epochs offset.
ev = struct('line', {}, 'edge', {}, 'label', {}, 'epoch', {}, 't', {});
for k = P
    if ~isfield(Rs{k}, 'rasterEvents'); continue; end
    for m = reshape(Rs{k}.rasterEvents, 1, [])
        j = find(arrayfun(@(e) e.label == m.label, ev), 1);
        if isempty(j)
            ev(end+1) = struct('line', m.line, 'edge', m.edge, 'label', m.label, 'epoch', zeros(0, 1), 't', zeros(0, 1)); %#ok<AGROW>
            j = numel(ev);
        end
        ev(j).epoch = [ev(j).epoch; off(k) + m.epoch(:)];
        ev(j).t = [ev(j).t; m.t(:)];
    end
end
end


function se = mergeSortEvent(Rs, P, off, nE)
%mergeSortEvent  The raster's sort key over every epoch (NaN for a session without it).
se = [];
for k = P
    r = Rs{k};
    if ~isfield(r, 'rasterSortEvent') || ~isstruct(r.rasterSortEvent); continue; end
    if isempty(se); se = struct('label', r.rasterSortEvent.label, 't', NaN(nE, 1)); end
    t = r.rasterSortEvent.t(:);
    se.t(off(k) + (1:numel(t))) = t;
end
end


function W = mergeWaveformStructs(Rs, tiles)
%mergeWaveformStructs  unitWaveforms' fields, one row per (pool) tile.
nT = numel(tiles.key);
W = struct('timeMs', {cell(nT, 1)}, 'mean', {cell(nT, 1)}, 'spikes', {cell(nT, 1)}, 'from', repmat("none", nT, 1), ...
    'units', strings(nT, 1), 'total', zeros(nT, 1), 'note', "", 'maxSpikes', NaN);
notes = strings(0, 1);
for t = 1:nT
    k = find(~cellfun(@isempty, tiles.units(t, :)), 1);
    u = tiles.units{t, k};
    w = Rs{k}.waveforms;
    W.timeMs{t} = w.timeMs{u};
    W.mean{t} = w.mean{u};
    W.spikes{t} = w.spikes{u};
    W.from(t) = w.from(u);
    W.units(t) = w.units(u);
    W.total(t) = w.total(u);
    if isnan(W.maxSpikes); W.maxSpikes = w.maxSpikes; end
    if string(w.note) ~= ""; notes(end+1) = string(w.note); end %#ok<AGROW>
end
W.note = strjoin(unique(notes, 'stable'), "; ");
end


%% =====================================================================================
%  slicing one trial group out of a result
%  =====================================================================================

function r = sliceGroup(r, label)
%sliceGroup  The result R with only its trial group LABEL ([] when it has none): every epoch-indexed field follows.
G = r.groups;
g = find(string(G.label) == label, 1);
if isempty(g); r = []; return; end
G = G(g, :);
G.index = 1;
switch r.kind
    case "psth"
        keep = r.epochGroup(:) == g;
        map = zeros(numel(keep), 1);
        map(keep) = 1:nnz(keep);
        r.rate = r.rate(:, :, g); r.sem = r.sem(:, :, g); r.count = r.count(:, :, g);
        r = sliceErr(r, @(x) x(:, :, g));
        r.nEpochs = r.nEpochs(g); r.n = r.n(g); r.stopMean = r.stopMean(g);
        r.baselineRate = r.baselineRate(:, g); r.baselineSD = r.baselineSD(:, g);
        for u = 1:numel(r.raster)
            in = keep(r.raster(u).epoch);
            r.raster(u).times = r.raster(u).times(in);
            r.raster(u).epoch = map(r.raster(u).epoch(in));
            r.raster(u).group = ones(nnz(in), 1);
        end
        r.epochGroup = ones(nnz(keep), 1);
        r.epochStop = r.epochStop(keep);
        if isfield(r, 'rasterEvents')
            for m = 1:numel(r.rasterEvents)
                in = keep(r.rasterEvents(m).epoch);
                r.rasterEvents(m).epoch = map(r.rasterEvents(m).epoch(in));
                r.rasterEvents(m).t = r.rasterEvents(m).t(in);
            end
        end
        if isfield(r, 'rasterSortEvent') && isstruct(r.rasterSortEvent)
            r.rasterSortEvent.t = r.rasterSortEvent.t(keep);
        end
        if isfield(r, 'aux'); r = rmfield(r, 'aux'); end
        r.epochs = sliceEpochs(r.epochs, keep);
    case "evoked"
        E = r.epochs;
        keep = E.groupIndex(:) == g;
        map = zeros(numel(keep), 1);
        map(keep) = 1:nnz(keep);
        r.mean = r.mean(:, :, g); r.sem = r.sem(:, :, g);
        r = sliceErr(r, @(x) x(:, :, g));
        r.nEpochs = r.nEpochs(g); r.n = r.n(g);
        kept = r.keptEpochs(:);
        r.keptEpochs = map(kept(keep(kept)));
        r.data = [];
        r.epochs = sliceEpochs(E, keep);
    case "rate"
        keep = r.groupIndex(:) == g;
        for f = ["rate" "count" "rawRate" "baseline"]
            r.(f) = r.(f)(keep, :);
        end
        r.duration = r.duration(keep);
        r.meanRate = r.meanRate(:, g); r.sem = r.sem(:, g); r.median = r.median(:, g); r.baselineRate = r.baselineRate(:, g);
        r = sliceErr(r, @(x) x(:, g));
        r.epochIndex = (1:nnz(keep)).';
        r.groupIndex = ones(nnz(keep), 1);
        r.n = r.n(g);
        r.epochs = sliceEpochs(r.epochs, keep);
    case "tuning"
        r.mean = r.mean(:, :, g); r.sem = r.sem(:, :, g);
        r = sliceErr(r, @(x) x(:, :, g));
        r.n = r.n(:, g);
        r.series = r.series(g); r.seriesValues = r.seriesValues(g);
    case "behavior"
        V = r.values;
        V = V(V.seriesIndex == g, :);
        V.seriesIndex(:) = 1;
        r.values = V;
        r.mean = r.mean(:, g); r.sem = r.sem(:, g); r.median = r.median(:, g); r.n = r.n(:, g);
        r = sliceErr(r, @(x) x(:, g));
        r.series = r.series(g); r.seriesValues = r.seriesValues(g);
end
r.groups = G;
end


function r = sliceErr(r, f)
if isfield(r, 'err') && isstruct(r.err) && isfield(r.err, 'lo')
    r.err.lo = f(r.err.lo);
    r.err.hi = f(r.err.hi);
end
end


function E = sliceEpochs(E, keep)
%sliceEpochs  The epochs kept, renumbered, in the sliced group (groupIndex 1).
if ~istable(E); return; end
E = E(keep, :);
E.epoch = (1:height(E)).';
if ismember("groupIndex", string(E.Properties.VariableNames)); E.groupIndex(:) = 1; end
end


%% =====================================================================================
%  small helpers
%  =====================================================================================

function [ux, isNum, rowMaps] = levelUnion(Rs, P, xOf, numOf, param, sessions)
%levelUnion  The union of the sessions' levels (numeric ascending, text alphabetical) and each one's rows in it.
isNum = numOf(Rs{P(1)});
for k = P(2:end)
    if numOf(Rs{k}) ~= isNum
        error('combineSessions:MixedLevels', '%s: %s is numeric in some sessions and text in others (%s).', ...
            sessions.label(k), param, sessions.label(P(1)));
    end
end
xs = cell(numel(P), 1);
for j = 1:numel(P)
    x = xOf(Rs{P(j)});
    if isNum; xs{j} = double(x(:)); else; xs{j} = string(x(:)); end
end
ux = unique(vertcat(xs{:}));
rowMaps = cell(1, numel(Rs));
for j = 1:numel(P)
    [~, rowMaps{P(j)}] = ismember(xs{j}, ux);
end
end


function v = concatField(Rs, P, f, off)
%concatField  A per-epoch column of every session, stacked (offset by each session's first epoch row).
if nargin < 4; off = []; end
parts = cell(numel(P), 1);
for j = 1:numel(P)
    x = f(Rs{P(j)});
    if ~isempty(off); x = off(P(j)) + x; end
    parts{j} = x(:);
end
v = vertcat(parts{:});
if isempty(v); v = zeros(0, 1); end
end


function s = seriesParamOf(mode, combine, base)
switch mode
    case "session", s = "session";
    case "subject", s = "subject";
    otherwise,      s = "";
end
if combine && base ~= ""
    if s == ""; s = base; else; s = s + ", " + base; end
end
end


function v = fieldOr(r, f, d)
v = d;
if isfield(r, f); v = r.(f); end
end


function w = tileWord(match)
switch match
    case "site",    w = "recording channel (site)";
    case "mapping", w = "cell of the mapping";
    case "channel", w = "channel";
    otherwise,      w = "unit";
end
end


function txt = datasetText(sessions, P, groupLabel)
%datasetText  "3 sessions (SYNTH-01)", "5 sessions, 2 subjects" or "3 sessions" (+ ", <group>").
n = numel(P);
word = "sessions";
if n == 1; word = "session"; end
subj = unique(sessions.subject(P(sessions.subject(P) ~= "")));
txt = sprintf("%d %s", n, word);
if isscalar(subj)
    txt = txt + " (" + subj + ")";
elseif numel(subj) > 1
    txt = txt + sprintf(", %d subjects", numel(subj));
end
if groupLabel ~= ""; txt = txt + ", " + groupLabel; end
end


function T = stackTables(parts)
%stackTables  Tables stacked with their variables unioned (a variable a table lacks is NaN / "" / false / NaT).
parts = parts(~cellfun(@isempty, parts));
if isempty(parts); T = table(); return; end
vars = strings(1, 0);
for i = 1:numel(parts)
    v = string(parts{i}.Properties.VariableNames);
    vars = [vars v(~ismember(v, vars))]; %#ok<AGROW>
end
h = cellfun(@height, parts);
T = table();
for v = vars
    cols = cell(numel(parts), 1);
    ex = [];
    for i = 1:numel(parts)
        if ismember(v, string(parts{i}.Properties.VariableNames))
            cols{i} = parts{i}.(v);
            if isempty(ex); ex = cols{i}; end
        end
    end
    T.(v) = joinColumn(cols, ex, h);
end
end


function c = joinColumn(cols, ex, h)
%joinColumn  One variable's parts stacked; a missing part filled by the type of the first that has it.
w = max(1, size(ex, 2));
isText = isstring(ex) || ischar(ex) || iscellstr(ex);
for i = 1:numel(cols)
    x = cols{i};
    if isempty(x) && h(i) > 0 && ~(isequal(size(x), [h(i) w]))
        if isText
            x = strings(h(i), w);
        elseif islogical(ex)
            x = false(h(i), w);
        elseif isnumeric(ex)
            x = NaN(h(i), w);
        elseif isdatetime(ex)
            x = NaT(h(i), w);
        elseif iscategorical(ex)
            x = categorical(NaN(h(i), w));
        elseif iscell(ex)
            x = cell(h(i), w);
        else
            x = repmat(ex(1, :), h(i), 1);
        end
    elseif isText || isstring(x) || ischar(x) || iscellstr(x)
        x = string(x);
    end
    cols{i} = x;
end
if isText || any(cellfun(@isstring, cols))
    cols = cellfun(@string, cols, 'UniformOutput', false);
elseif any(cellfun(@(x) isnumeric(x) || islogical(x), cols)) && ~all(cellfun(@islogical, cols)) ...
        && all(cellfun(@(x) isnumeric(x) || islogical(x), cols))
    cols = cellfun(@double, cols, 'UniformOutput', false);
end
c = vertcat(cols{:});
end
