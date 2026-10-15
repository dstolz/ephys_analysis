function T = figureSessionObservations(sources, spec, opts)
%figureSessionObservations  The observations a session figure is drawn for: matched across several datasets.
%   T = figureSessionObservations(SOURCES, SPEC) lists what the session
%   figure SPEC (EphysAnalysisConfig.figureFor of a figure whose
%   sessions.enabled is true) can be drawn for across the datasets SOURCES
%   (a cell {1 x nSessions} of loadAnalysisSource structs, in session
%   order: EphysAnalysisRunner.source of each dataset of sessionTable(IDX);
%   [] for a session that could not be read), one row each. Each dataset's
%   own observations come from figureObservations(SRC, SPEC) (perGroup
%   off: a session figure's trial groups follow sessions.trialGroups), and
%   are matched across the sessions by SPEC.observe.kind and
%   SPEC.sessions.match:
%     unit, match "site"     one row per recording channel that has a kept
%                            unit in at least sessions.minSessions
%                            sessions, labeled "site ch 7  -320 µm"; a
%                            session with several units on it draws the
%                            first (probe order); unitIds lists them all
%     unit, match "mapping"  one row per cell of the mapping file
%                            (sessions.mappingFile, readUnitMapping; or
%                            Mapping=) held by at least minSessions
%                            sessions, labeled with the cell; a session's
%                            ids are looked up in its column (its dataset
%                            key, SRC.key) among the units it keeps
%     channel                one row per recording channel of the observed
%                            extract present in at least minSessions
%                            sessions (an AUX channel, which has none, by
%                            its label), labeled as the first holder's
%     dataset                one row, labeled "<n> sessions"
%   Rows follow the first session's probe order, then the channels or
%   cells the later sessions add (mapping: the file's order).
%
%   T columns: those of figureObservations (kind, label, unitId (NaN but
%   for one session), channel, column, shank, depth, meta (the first
%   holder's row), group NaN, groupLabel ""), plus
%     nSessions  how many sessions hold it
%     unitIds    {1 x 1} cell holding a 1 x nSessions cell: each session's
%                unit id(s) on it ([] = none; channels and the dataset: [])
%     perSession {1 x 1} cell holding a table of nSessions rows, the
%                figureObservations row each session draws (column present
%                false, kind "", where it has none):
%                figureSessionCompute passes row k to figureCompute for
%                session k
%   A session without the observed source gives no row and holds none.
%
%   Options
%     Mapping  match "mapping": the unit-mapping table (default: read from
%              sessions.mappingFile); its columns are named by dataset key
%
%   Errors: figureSessionObservations:Mapping (match "mapping" with no
%   readable mapping file).
%
%   See also figureObservations, figureSessionCompute, readUnitMapping,
%   EphysAnalysisRunner.computeSessionFigure.

arguments
    sources cell
    spec (1,1) struct
    opts.Mapping = []
end

sources = reshape(sources, 1, []);
nS = numel(sources);
ss = spec.sessions;
one = spec;
one.observe.perGroup = false;
per = cell(1, nS);
for k = 1:nS
    if isempty(sources{k}); continue; end
    per{k} = figureObservations(sources{k}, one);
end
proto = emptyRow(per);
switch spec.observe.kind
    case "unit"
        if ss.match == "mapping"
            T = byMapping(sources, per, proto, ss, opts.Mapping);
        else
            T = byChannel(per, proto, ss, "site");
        end
    case "channel"
        T = byChannel(per, proto, ss, "channel");
    otherwise
        T = datasetRow(per, proto, nS);
end
end


function T = byChannel(per, proto, ss, how)
%byChannel  Rows by recording channel (an AUX channel by its label): sites of units, or channels of an extract.
nS = numel(per);
keys = strings(0, 1);
rowsOf = cell(0, nS);
for k = 1:nS
    O = per{k};
    if isempty(O) || height(O) == 0; continue; end
    for i = 1:height(O)
        key = channelKey(O(i, :));
        if key == ""; continue; end
        j = find(keys == key, 1);
        if isempty(j)
            keys(end+1, 1) = key; %#ok<AGROW>
            rowsOf(end+1, :) = cell(1, nS); %#ok<AGROW>
            j = numel(keys);
        end
        rowsOf{j, k} = [rowsOf{j, k} i];
    end
end
T = assemble(per, proto, rowsOf, ss.minSessions, how, strings(numel(keys), 1));
end


function T = byMapping(sources, per, proto, ss, M)
%byMapping  Rows by cell of the unit mapping: each session's ids looked up among the units it keeps.
nS = numel(per);
if isempty(M)
    if strtrim(ss.mappingFile) == "" || ~isfile(ss.mappingFile)
        error('figureSessionObservations:Mapping', 'match "mapping" needs a mapping file (sessions.mappingFile): "%s".', ss.mappingFile);
    end
    M = readUnitMapping(ss.mappingFile);
end
if ~istable(M) || ~ismember("cell", string(M.Properties.VariableNames))
    error('figureSessionObservations:Mapping', 'The unit mapping needs a "cell" column.');
end
cols = string(M.Properties.VariableNames);
nR = height(M);
rowsOf = cell(nR, nS);
names = string(M.cell);
for k = 1:nS
    O = per{k};
    if isempty(O) || height(O) == 0 || isempty(sources{k}) || ~isfield(sources{k}, 'key'); continue; end
    key = string(sources{k}.key);
    if ~ismember(key, cols); continue; end
    v = M.(char(key));
    for r = 1:nR
        ids = parseIds(v(r));
        if isempty(ids); continue; end
        rowsOf{r, k} = reshape(find(ismember(O.unitId, ids)), 1, []);
    end
end
T = assemble(per, proto, rowsOf, ss.minSessions, "mapping", names);
end


function T = datasetRow(per, proto, nS)
%datasetRow  The one dataset observation: every session's own.
rowsOf = cell(1, nS);
for k = 1:nS
    if ~isempty(per{k}) && height(per{k}) > 0; rowsOf{1, k} = 1; end
end
T = assemble(per, proto, rowsOf, 1, "dataset", "");
end


function T = assemble(per, proto, rowsOf, minSessions, how, names)
%assemble  One row per match held by at least MINSESSIONS sessions: label, the first holder's facts, unitIds, perSession.
nS = numel(per);
T = proto([], :);
T.nSessions = zeros(0, 1);
T.unitIds = cell(0, 1);
T.perSession = cell(0, 1);
for r = 1:size(rowsOf, 1)
    holders = find(~cellfun(@isempty, rowsOf(r, :)));
    if isempty(holders) || numel(holders) < minSessions; continue; end
    k1 = holders(1);
    row = per{k1}(rowsOf{r, k1}(1), :);
    ids = cell(1, nS);
    P = repmat(blankRow(proto), nS, 1);
    for k = holders
        O = per{k};
        i = rowsOf{r, k};
        if ismember("unitId", string(O.Properties.VariableNames)) && row.kind == "unit"; ids{k} = reshape(O.unitId(i), 1, []); end
        P(k, :) = presentRow(O(i(1), :), proto);
    end
    switch how
        case "site"
            row.label = strtrim(strjoin(["site ch " + row.channel, depthText(row.depth)], "  "));
        case "mapping"
            row.label = names(r);
        case "dataset"
            row.label = nS + " sessions";
            if nS == 1; row.label = "1 session"; end
    end
    if ismember(how, ["site" "mapping"]) && nS > 1; row.unitId = NaN; end   % each session's unit is its own (unitIds)
    row.group = NaN;
    row.groupLabel = "";
    row.nSessions = numel(holders);
    row.unitIds = {ids};
    row.perSession = {P};
    T = [T; row]; %#ok<AGROW>
end
end


function key = channelKey(row)
%channelKey  A row's recording channel as text ("ch7"), or an AUX channel's label; "" for none.
key = "";
if isfinite(row.channel)
    key = "ch" + row.channel;
else
    m = row.meta;
    if iscell(m); m = m{1}; end
    if istable(m) && height(m) >= 1 && ismember("label", string(m.Properties.VariableNames))
        key = "label:" + string(m.label(1));
    end
end
end


function proto = emptyRow(per)
%emptyRow  The figureObservations columns, as a 0-row table (from any session's table).
for k = 1:numel(per)
    if ~isempty(per{k}); proto = per{k}([], :); return; end
end
proto = table(strings(0, 1), strings(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), cell(0, 1), ...
    zeros(0, 1), strings(0, 1), ...
    'VariableNames', {'kind', 'label', 'unitId', 'channel', 'column', 'shank', 'depth', 'meta', 'group', 'groupLabel'});
end


function b = blankRow(proto)
%blankRow  One row with no observation: kind "", NaN numbers, an empty meta, present false.
b = table("", "", NaN, NaN, NaN, NaN, NaN, {[]}, NaN, "", false, ...
    'VariableNames', {'kind', 'label', 'unitId', 'channel', 'column', 'shank', 'depth', 'meta', 'group', 'groupLabel', 'present'});
b = b(:, [intersect(string(proto.Properties.VariableNames), string(b.Properties.VariableNames), 'stable') "present"]);
end


function p = presentRow(row, proto)
%presentRow  A session's figureObservations row in perSession's columns, present true.
p = blankRow(proto);
for f = string(p.Properties.VariableNames)
    if f == "present"; continue; end
    p.(f) = row.(f);
end
p.present = true;
end


function ids = parseIds(v)
%parseIds  A mapping cell's unit ids: a number, or text such as "3 7" / "3,7"; none for missing (combineSessions' rule).
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


function s = depthText(y)
s = "";
if isfinite(y); s = compose("%g µm", round(y)); end
end
