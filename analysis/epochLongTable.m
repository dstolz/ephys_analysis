function T = epochLongTable(X, opts)
%epochLongTable  Unroll a session plot's data into a long (tidy) table.
%   T = epochLongTable(X, What=, MaxRows=) turns X, a sessionData struct
%   (S, or load(file) of a data .mat) or one dataset's epochData D, into a
%   table with one row per observation, for R, pandas or MATLAB's own
%   grouping functions. Pure: no I/O.
%
%   What "values" (X a sessions struct; its default) -- the plotted numbers:
%   one row per result x series x tile x bin / level, from X.perSession
%   (each session's own result, when it was kept) and else from the merged
%   X.results. Columns
%     plot     the base plot's id
%     facet    "all", or the subject of a facet "subject" figure
%     group    the trial group (the merged results: the figure's, "" for
%              none; a tuning or behavior result's series)
%     series   what the line is: the session's label (per-session rows), or
%              the merged result's series (a session, a subject, "All
%              sessions", "<series> . <group>" for combine)
%     session  the row of X.sessions (NaN for a series that averages sessions)
%     subject, date   the session's (a subject series: its subject; NaT)
%     tile     the unit, site, cell or channel label ("" for behavior)
%     unit     its unit id (NaN for a site, a cell or a channel), channel its
%              recording channel (NaN when the result has none)
%     t | x    the time from the event (s) for psth and evoked results, the
%              level for tuning and behavior; absent for a rate result
%     value    the mean (psth: rate; evoked: signal; tuning, behavior, rate)
%     err      its error half-width as R.sem holds it (SEM across epochs;
%              across sessions for a series that averages them)
%     n        the epochs (tuning, behavior: at that level) behind the value
%   What "counts" (X an epochData D, or a sessions struct holding epochs):
%   one row per epoch x unit x bin -- session (the dataset's identity.label),
%   subject, date, trial, epoch, group, unit, bin, t (the bin's center), count
%   What "spikes": one row per spike -- session, subject, date, trial, epoch,
%   group, unit, t (relative to the event, s)
%   What "signals": one row per epoch x channel x sample -- session, subject,
%   date, trial, epoch, group, channel, label, sample (the offset from the
%   event, samples), t, value
%   The last three also carry the epochs' further trial columns (the
%   grouping and plot parameters: E's columns beyond epoch, trial, t0 ..
%   group). A sessions struct gives the rows of every session that has epochs.
%
%   Options
%     What     as above ("" = "values" for a sessions struct, "counts" for D)
%     MaxRows  epochLongTable:TooLarge above this many rows (default 5e6)
%
%   Errors: epochLongTable:Input, :Kind (a result without values, e.g.
%   waveforms), :NoValues, :NoEpochs, :NoCounts, :NoSpikes, :NoSignals,
%   :TooLarge.
%
%   See also sessionData, epochData, writeAnalysisData.
arguments
    X (1,1) struct
    opts.What (1,1) string {mustBeMember(opts.What, ["" "values" "counts" "spikes" "signals"])} = ""
    opts.MaxRows (1,1) double {mustBePositive} = 5e6
end

isSessions = isfield(X, 'schema') && isfield(X, 'results') && isfield(X, 'sessions');
isEpochs = isfield(X, 'identity') && isfield(X, 'E') && isfield(X, 'spikes');
if ~isSessions && ~isEpochs
    error('epochLongTable:Input', 'X must be a sessionData struct or an epochData result.');
end
what = opts.What;
if what == ""
    if isSessions; what = "values"; else; what = "counts"; end
end
if what == "values"
    if ~isSessions
        error('epochLongTable:Input', 'What "values" needs a sessionData struct, not one dataset''s epochData.');
    end
    T = valuesTable(X, opts.MaxRows);
    return
end

if isSessions
    Ds = X.epochs(~cellfun(@isempty, X.epochs));
    if isempty(Ds)
        error('epochLongTable:NoEpochs', 'This sessions struct holds no epochs (the session plot''s data list lacks "epochs").');
    end
else
    Ds = {X};
end
rows = cellfun(@(D) rowCount(D, what), Ds);
if sum(rows) > opts.MaxRows
    error('epochLongTable:TooLarge', 'The "%s" table would have %d rows, over MaxRows (%d).', what, sum(rows), opts.MaxRows);
end
parts = cell(1, numel(Ds));
for k = 1:numel(Ds)
    switch what
        case "counts",  parts{k} = countsTable(Ds{k});
        case "spikes",  parts{k} = spikesTable(Ds{k});
        case "signals", parts{k} = signalsTable(Ds{k});
    end
end
T = vertcat(parts{:});
end


function n = rowCount(D, what)
%rowCount  The rows a dataset's "counts" / "spikes" / "signals" table has (errors when it holds none).
switch what
    case "counts"
        if isempty(D.spikes) || size(D.spikes.counts, 2) == 0
            error('epochLongTable:NoCounts', '%s holds no binned spike counts (a spike source, Counts on, a window with whole bins).', D.identity.name);
        end
        n = numel(D.spikes.counts);
    case "spikes"
        if isempty(D.spikes)
            error('epochLongTable:NoSpikes', '%s holds no spike times (not a spike source).', D.identity.name);
        end
        n = sum(cellfun(@numel, D.spikes.times), 'all');
    case "signals"
        if isempty(D.signals)
            error('epochLongTable:NoSignals', '%s holds no epoched signal (a signal source read with Signals=true).', D.identity.name);
        end
        n = numel(D.signals.data);
end
end


% ---- counts / spikes / signals -------------------------------------------------------------

function T = countsTable(D)
C = D.spikes.counts;                    % [epoch x bin x unit]
[nE, nB, nU] = size(C);
N = numel(C);
Cp = permute(C, [2 1 3]);               % bin fastest, then epoch, then unit
idx = (0:N-1).';
ib = mod(idx, nB) + 1;
ie = mod(floor(idx / nB), nE) + 1;
iu = floor(idx / (nB * nE)) + 1;
E = D.E;
unit = unitIds(D, nU);
T = [header(D, E, ie), table(unit(iu), ib, D.spikes.t(ib), Cp(:), 'VariableNames', {'unit', 'bin', 't', 'count'})];
T = [T, extraColumns(E, ie)];
end


function T = spikesTable(D)
times = D.spikes.times;                 % {epoch x unit}
[nE, nU] = size(times);
unit = unitIds(D, nU);
ie = zeros(0, 1); iu = zeros(0, 1); t = zeros(0, 1);
for u = 1:nU
    n = cellfun(@numel, times(:, u));
    ie = [ie; repelem((1:nE).', n)]; %#ok<AGROW>
    iu = [iu; repmat(u, sum(n), 1)]; %#ok<AGROW>
    t = [t; vertcat(times{:, u})]; %#ok<AGROW>
end
E = D.E;
T = [header(D, E, ie), table(unit(iu), t, 'VariableNames', {'unit', 't'})];
T = [T, extraColumns(E, ie)];
end


function T = signalsTable(D)
S = D.signals;
[nT, nC, ~] = size(S.data);
N = numel(S.data);
idx = (0:N-1).';
is = mod(idx, nT) + 1;
ic = mod(floor(idx / nT), nC) + 1;
ik = floor(idx / (nT * nC)) + 1;
E = S.epochs;
labels = string(S.labels);
T = [header(D, E, ik), table(S.channels(ic), labels(ic), is + S.sampleOffsets(1) - 1, S.t(is), double(S.data(:)), ...
    'VariableNames', {'channel', 'label', 'sample', 't', 'value'})];
T = [T, extraColumns(E, ik)];
end


function T = header(D, E, ie)
%header  session, subject, date, trial, epoch, group of the epochs IE.
N = numel(ie);
T = table(repmat(string(D.identity.label), N, 1), repmat(string(D.identity.subject), N, 1), repmat(D.identity.date, N, 1), ...
    E.trial(ie), E.epoch(ie), E.group(ie), 'VariableNames', {'session', 'subject', 'date', 'trial', 'epoch', 'group'});
end


function T = extraColumns(E, ie)
%extraColumns  E's columns beyond epochTable's own (the trial parameters), at the epochs IE.
standard = ["epoch" "trial" "t0" "t0Continuous" "t1" "tStart" "tStop" "duration" "complete" "artifact" "groupIndex" "group"];
names = setdiff(string(E.Properties.VariableNames), standard, 'stable');
T = table();
for c = names
    T.(c) = E.(c)(ie);
end
if isempty(names); T = table.empty(numel(ie), 0); end
end


function u = unitIds(D, nU)
u = (1:nU).';
if istable(D.meta) && ismember("unitId", string(D.meta.Properties.VariableNames)) && height(D.meta) == nU
    u = double(D.meta.unitId(:));
end
end


% ---- values --------------------------------------------------------------------------------

function T = valuesTable(X, maxRows)
sp = X.sessionPlot;
S = X.sessions;
parts = cell(1, 0);
nRows = 0;
if ~isempty(X.perSession) && any(~cellfun(@isempty, X.perSession))
    for j = 1:numel(X.perSession)
        R = X.perSession{j};
        if isempty(R); continue; end
        P = resultValues(R);
        nS = size(P.A, 3);
        facet = "all";
        if sp.facet == "subject"
            facet = S.subject(j);
            if facet == ""; facet = "(no subject)"; end
        end
        deco = struct('facet', repmat(facet, nS, 1), 'group', P.series, 'series', repmat(S.label(j), nS, 1), ...
            'session', repmat(j, nS, 1), 'subject', repmat(S.subject(j), nS, 1), 'date', repmat(S.date(j), nS, 1));
        [parts, nRows] = addPart(parts, nRows, maxRows, sp.plot, P, deco);
    end
else
    for i = 1:numel(X.results)
        R = X.results(i).R;
        if isempty(R); continue; end
        P = resultValues(R);
        nS = size(P.A, 3);
        group = repmat(string(X.results(i).group), nS, 1);
        base = (1:nS).';
        if istable(R.groups) && ismember("group", string(R.groups.Properties.VariableNames))
            group = string(R.groups.group(:));
        end
        if istable(R.groups) && ismember("base", string(R.groups.Properties.VariableNames)); base = R.groups.base(:); end
        session = NaN(nS, 1);
        subject = strings(nS, 1);
        date = NaT(nS, 1);
        smode = "session";
        if isfield(R, 'sessionSeries'); smode = R.sessionSeries.mode; end
        for s = 1:nS
            if smode == "subject"
                subject(s) = P.series(s);
            elseif smode == "session" && isfield(R, 'sessions') && ismember("series", string(R.sessions.Properties.VariableNames))
                row = find(R.sessions.series == base(s), 1);
                j = find(S.key == R.sessions.key(row), 1);
                if ~isempty(j)
                    session(s) = j;
                    subject(s) = S.subject(j);
                    date(s) = S.date(j);
                end
            end
        end
        deco = struct('facet', repmat(string(X.results(i).facet), nS, 1), 'group', group, 'series', P.series, ...
            'session', session, 'subject', subject, 'date', date);
        [parts, nRows] = addPart(parts, nRows, maxRows, sp.plot, P, deco);
    end
end
if isempty(parts)
    error('epochLongTable:NoValues', 'This sessions struct holds no result with values.');
end
T = vertcat(parts{:});
end


function [parts, nRows] = addPart(parts, nRows, maxRows, plotId, P, deco)
%addPart  The long rows of one result, appended to PARTS (epochLongTable:TooLarge past MaxRows).
[nP, nT, ~] = size(P.A);
N = numel(P.A);
nRows = nRows + N;
if nRows > maxRows
    error('epochLongTable:TooLarge', 'The "values" table would have more than %d rows (MaxRows).', maxRows);
end
idx = (0:N-1).';
ip = mod(idx, nP) + 1;
it = mod(floor(idx / nP), nT) + 1;
is = floor(idx / (nP * nT)) + 1;
T = table(repmat(string(plotId), N, 1), deco.facet(is), deco.group(is), deco.series(is), deco.session(is), ...
    deco.subject(is), deco.date(is), P.tile(it), P.unit(it), P.channel(it), ...
    'VariableNames', {'plot', 'facet', 'group', 'series', 'session', 'subject', 'date', 'tile', 'unit', 'channel'});
if P.posName ~= ""
    pos = P.pos(:);
    T.(P.posName) = pos(ip);
end
T.value = P.A(:);
T.err = P.Err(:);
T.n = P.N(:);
parts{end+1} = T;
end


function P = resultValues(R)
%resultValues  A result's plotted numbers as [position x tile x series] arrays, with the labels of each.
P = struct('posName', "", 'pos', [], 'A', [], 'Err', [], 'N', [], 'series', strings(0, 1), ...
    'tile', strings(0, 1), 'unit', [], 'channel', []);
switch R.kind
    case {"psth", "raster"}
        P.A = R.rate; P.Err = R.sem; P.posName = "t"; P.pos = R.t;
        nS = size(R.rate, 3);
        P.N = repmat(reshape(R.nEpochs(:), 1, 1, nS), size(R.rate, 1), size(R.rate, 2), 1);
        P.series = string(R.groups.label(:));
    case "evoked"
        P.A = R.mean; P.Err = R.sem; P.posName = "t"; P.pos = R.t;
        nS = size(R.mean, 3);
        P.N = repmat(reshape(R.nEpochs(:), 1, 1, nS), size(R.mean, 1), size(R.mean, 2), 1);
        P.series = string(R.groups.label(:));
    case "tuning"
        nX = size(R.mean, 1);
        nS = size(R.mean, 3);
        P.A = R.mean; P.Err = R.sem; P.posName = "x"; P.pos = R.x;
        P.N = repmat(reshape(R.n, nX, 1, nS), 1, size(R.mean, 2), 1);
        P.series = string(R.series(:));
    case "behavior"
        nX = size(R.mean, 1);
        nS = size(R.mean, 2);
        P.A = reshape(R.mean, nX, 1, nS); P.Err = reshape(R.sem, nX, 1, nS); P.posName = "x"; P.pos = R.x;
        P.N = reshape(R.n, nX, 1, nS);
        P.series = string(R.series(:));
    case "rate"
        nT = size(R.meanRate, 1);
        nS = size(R.meanRate, 2);
        P.A = permute(reshape(R.meanRate, nT, 1, nS), [2 1 3]);   % [1 x nTile x nSeries]: no position
        P.Err = permute(reshape(R.sem, nT, 1, nS), [2 1 3]);
        P.N = repmat(reshape(R.groups.n(:), 1, 1, nS), 1, nT, 1);   % the epochs of each series
        P.series = string(R.groups.label(:));
    otherwise
        error('epochLongTable:Kind', 'A "%s" result has no values to unroll.', R.kind);
end
nT = size(P.A, 2);
P.tile = repmat("", nT, 1);
if isfield(R, 'labels') && numel(R.labels) == nT && R.kind ~= "behavior"
    P.tile = string(R.labels(:));
end
P.unit = NaN(nT, 1);
P.channel = NaN(nT, 1);
if isfield(R, 'meta') && istable(R.meta) && height(R.meta) == nT
    v = string(R.meta.Properties.VariableNames);
    if ismember("unitId", v); P.unit = double(R.meta.unitId(:)); end
    if ismember("channel", v); P.channel = double(R.meta.channel(:)); end
end
end
