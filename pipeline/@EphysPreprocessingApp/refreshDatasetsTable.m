function refreshDatasetsTable(obj, opts)
%refreshDatasetsTable  Rebuild the datasets table from project metadata.
%   Preserves the existing "Select" ticks (matched by key). The tokens ticked
%   under the name pattern become columns after Name (table variables
%   "Token_<name>", so a token cannot collide with a fixed column).
%
%   Columns the user dragged into a new order keep it: the displayed order
%   is baked into the table variables (see orderColumns), so it survives
%   rebuilds that change the column set. The token filters above the table
%   hide rows; ticks on hidden rows are kept in HiddenSelectedKeys.
%
%   refreshDatasetsTable(Datasets=IDX) only recomputes the cells of the
%   datasets IDX (indices into Project.Datasets) in the rows the table
%   shows (the Kilosort4 monitor, as a run starts or ends); it rebuilds the
%   whole table when the table does not hold those datasets' rows. The
%   Behavior column reads each Epsych2 session file's summary once, and
%   again only when the file changes (EpsychMetaCache).
%
%   A probe, sorted-output folder or Epsych2 session that is associated but
%   not there now (a disk or share not connected) reads "missing: <name>";
%   a dataset without a probe of its own shows the config's default probe
%   as "default: <name>" (EphysPipeline.probeFor).
arguments
    obj (1,1) EphysPreprocessingApp
    opts.Datasets (1,:) double = []
end
if ~isempty(opts.Datasets) && refreshRows(obj, opts.Datasets)
    return
end

[tokenNames, shown, patternMsg] = nameTokenSettings(obj);
tokenVars = "Token_" + shown;
nTok = numel(shown);

% Natural column layout: variable, header, editable, sortable, width.
vars   = ["Select", "Name", tokenVars, "Key", "AcqDate", "NumChannels", "Fs", ...
          "DurationMin", "Format", "Probe", "Exclude", "Sorting", "Behavior", "DatasetIdx"];
labels = [{'Select', 'Name'}, cellstr(shown), ...
          {'Key', 'Acq date', 'Ch', 'Fs (Hz)', 'Dur (min)', 'Format', 'Probe', 'Exclude', 'Sorting', 'Behavior', ''}];
editable = [true, false(1, 12 + nTok)];
sortable = [true(1, 12 + nTok), false];
widths = [{64, 'fit'}, repmat({'fit'}, 1, nTok), ...
          {'1x', 118, 44, 76, 86, 'fit', 'fit', 90, 'fit', '1x', 1}];

prev = obj.DatasetsTable.Data;
order = displayedColumnOrder(obj, prev);

n = 0;
if ~isempty(obj.Project); n = obj.Project.NumDatasets; end
Select = false(n, 1);
Key = strings(n, 1);
for i = 1:n
    Key(i) = obj.Project.datasetKey(i);
end
hiddenKeys = obj.HiddenSelectedKeys;
for i = 1:n
    if istable(prev) && all(ismember({'Select', 'Key'}, prev.Properties.VariableNames)) ...
            && any(strcmpi(prev.Key, Key(i)))
        Select(i) = prev.Select(find(strcmpi(prev.Key, Key(i)), 1));
    else
        Select(i) = any(strcmpi(hiddenKeys, Key(i)));
    end
end

Name = strings(n, 1); AcqDate = strings(n, 1); NumChannels = zeros(n, 1); Fs = zeros(n, 1);
DurationMin = zeros(n, 1); Format = strings(n, 1); Probe = strings(n, 1); Exclude = strings(n, 1);
Sorting = strings(n, 1); Behavior = strings(n, 1);
AllTokens = repmat("-", n, numel(tokenNames));   % every pattern token (the filters use all)
nMatched = 0;

for i = 1:n
    d = obj.Project.Datasets(i);
    if patternMsg == ""
        [vals, ~, ok] = parseNameTokens(d.Name, obj.NamePatternField.Value);
        if ok
            nMatched = nMatched + 1;
            AllTokens(i, :) = vals;
        end
    end
    c = datasetCells(obj, d);
    Name(i) = c.Name; AcqDate(i) = c.AcqDate; NumChannels(i) = c.NumChannels; Fs(i) = c.Fs;
    DurationMin(i) = c.DurationMin; Format(i) = c.Format; Probe(i) = c.Probe;
    Exclude(i) = c.Exclude; Sorting(i) = c.Sorting; Behavior(i) = c.Behavior;
end

% Token filters: rebuild the dropdowns when the tokens change, refresh their
% value lists, then keep only the rows every active filter accepts.
obj.syncTokenFilters(tokenNames, AllTokens);
keep = true(n, 1);
nActive = 0;
for k = 1:numel(obj.NameTokenFilters)
    terms = filterTerms(obj.NameTokenFilters(k).Value);
    if isempty(terms); continue; end
    nActive = nActive + 1;
    col = AllTokens(:, tokenNames == string(obj.NameTokenFilters(k).UserData));
    keep = keep & matchesAny(col, terms);
end

[~, loc] = ismember(shown, tokenNames);
DatasetIdx = (1:n)';
T = [table(Select, Name), array2table(AllTokens(:, loc), 'VariableNames', cellstr(tokenVars)), ...
    table(Key, AcqDate, NumChannels, Fs, DurationMin, Format, ...
    Probe, Exclude, Sorting, Behavior, DatasetIdx)];
T.Properties.VariableNames = cellstr(vars);
obj.HiddenSelectedKeys = reshape(Key(~keep & Select), 1, []);
T = T(keep, :);

% Apply the remembered column order to the variables and every per-column
% property, then clear the table's own display order so it is not applied twice.
perm = orderColumns(vars, order);
obj.DatasetsTable.Data = T(:, perm);
obj.DatasetsTable.ColumnName = labels(perm);
obj.DatasetsTable.ColumnEditable = editable(perm);
obj.DatasetsTable.ColumnSortable = sortable(perm);
obj.DatasetsTable.ColumnWidth = widths(perm);
obj.DatasetsTable.DisplayColumnOrder = [];
obj.DatasetsColumnOrder = vars(perm);

% The highlight follows the active dataset (rows move as filters change).
obj.highlightDatasetRow();

if patternMsg ~= ""
    msg = patternMsg;
elseif n == 0
    msg = "";
else
    msg = sprintf("%d of %d names match", nMatched, n);
end
if nActive > 0
    msg = msg + sprintf("; showing %d of %d", nnz(keep), n);
    nHidden = numel(obj.HiddenSelectedKeys);
    if nHidden > 0
        msg = msg + sprintf(" (%d ticked hidden)", nHidden);
    end
end
obj.NameTokenStatusLabel.Text = msg;

if n > 0
    obj.syncToolsPanel();
    obj.syncTabStrip();
end
end


function done = refreshRows(obj, idx)
%refreshRows  Recompute the cells of datasets IDX in the rows the table shows.
%   False (nothing done) when the table does not hold this project's rows.
T = obj.DatasetsTable.Data;
done = false;
if isempty(obj.Project) || ~istable(T) || ~all(ismember({'Key', 'DatasetIdx'}, T.Properties.VariableNames))
    return
end
for i = idx(idx >= 1 & idx <= obj.Project.NumDatasets)
    r = find(T.DatasetIdx == i, 1);
    if isempty(r); continue; end   % hidden by the token filters: the next rebuild has it
    if ~strcmpi(T.Key(r), obj.Project.datasetKey(i)); return; end
    c = datasetCells(obj, obj.Project.Datasets(i));
    for f = string(fieldnames(c)).'
        T.(f)(r) = c.(f);
    end
end
obj.DatasetsTable.Data = T;
obj.highlightDatasetRow();
obj.syncToolsPanel();
done = true;
end


function c = datasetCells(obj, d)
%datasetCells  The cells of dataset D's row that come from its metadata,
%   probe, exclusions, sorted output and Epsych2 session.
c = struct('Name', d.Name, 'AcqDate', "", 'NumChannels', d.NumChannels, 'Fs', d.Fs, ...
    'DurationMin', 0, 'Format', d.RecordingFormat, 'Probe', "-", 'Exclude', "-", ...
    'Sorting', "-", 'Behavior', "-");
if ~isnat(d.AcqDate)
    c.AcqDate = string(datetime(d.AcqDate, 'Format', 'yyyy-MM-dd HH:mm'));
end
if ~isnan(d.Duration); c.DurationMin = round(d.Duration / 60, 2); end
if d.ProbeFile ~= ""
    c.Probe = fileName(d.ProbeFile);
    if ~isfile(d.ProbeFile); c.Probe = "missing: " + c.Probe; end
elseif obj.Config.Probe.DefaultProbeFile ~= ""
    c.Probe = "default: " + fileName(obj.Config.Probe.DefaultProbeFile);
end
if ~isempty(d.ExcludeChannels)
    c.Exclude = EphysDataset.formatChannelList(d.ExcludeChannels);
end
s = d.sortingStruct();
if s.results_dir ~= "" && ~s.exists
    c.Sorting = "missing: " + s.source;
elseif s.results_dir ~= ""
    txt = s.source;
    if isfinite(s.num_units); txt = txt + sprintf(": %d units", s.num_units); end
    if s.curated; txt = txt + ", curated"; end
    c.Sorting = txt;
end
if d.BehaviorFile ~= "" && ~isfile(d.BehaviorFile)
    c.Behavior = "missing: " + fileName(d.BehaviorFile);
elseif d.BehaviorFile ~= ""
    try
        m = sessionMeta(obj, d.BehaviorFile);
        c.Behavior = sprintf("%s (%d trials)", m.subject, m.nTrials);
    catch
        c.Behavior = fileName(d.BehaviorFile);
    end
    if ~isempty(d.TrialPairing)
        c.Behavior = c.Behavior + ", pairing " + d.TrialPairing.status;
        if d.TrialPairing.auto_approved
            c.Behavior = c.Behavior + " (auto)";
        end
    end
end
end


function s = fileName(f)
%fileName  The name and extension of file F.
[~, n, e] = fileparts(f);
s = string(n) + e;
end


function m = sessionMeta(obj, file)
%sessionMeta  epsychSessionMeta(FILE), read again only when the file's
%   modification time or size changed since it was last read.
if isempty(obj.EpsychMetaCache)
    obj.EpsychMetaCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
key = char(file);
f = dir(key);
if isKey(obj.EpsychMetaCache, key)
    e = obj.EpsychMetaCache(key);
    if e.datenum == f.datenum && e.bytes == f.bytes
        m = e.meta;
        return
    end
end
m = epsychSessionMeta(file);
obj.EpsychMetaCache(key) = struct('datenum', f.datenum, 'bytes', f.bytes, 'meta', m);
end


function [tokenNames, shown, msg] = nameTokenSettings(obj)
%nameTokenSettings  Pattern tokens and the ticked ones; MSG is the pattern
%   error ("" when it parses), in which case no token columns are shown.
tokenNames = string.empty(1, 0);
shown = string.empty(1, 0);
msg = "";
try
    [~, tokenNames] = parseNameTokens("", string(obj.NamePatternField.Value));
catch ME
    msg = string(ME.message);
    return
end
checks = obj.NameTokenChecks;
if ~isempty(checks)
    ticked = string({checks.Text});
    ticked = ticked(logical([checks.Value]));
    shown = tokenNames(ismember(tokenNames, ticked));
end
end


function order = displayedColumnOrder(obj, prev)
%displayedColumnOrder  Variable names in the order currently on screen.
order = obj.DatasetsColumnOrder;
dco = obj.DatasetsTable.DisplayColumnOrder;
if istable(prev) && width(prev) > 0 && numel(dco) == width(prev)
    order = string(prev.Properties.VariableNames(dco));
end
end


function perm = orderColumns(vars, order)
%orderColumns  Permutation of VARS following ORDER. Columns named in ORDER
%   take the slots they jointly occupy in VARS in ORDER's sequence; new
%   columns keep their natural slot. DatasetIdx (hidden) always stays last.
perm = 1:numel(vars);
known = order(ismember(order, vars));
slots = find(ismember(vars, known));
[~, perm(slots)] = ismember(known, vars);
last = find(vars(perm) == "DatasetIdx");
perm = [perm([1:last-1, last+1:end]), perm(last)];
end


function terms = filterTerms(value)
%filterTerms  Comma-separated filter text -> terms ("" / "(any)" = none).
terms = strtrim(split(string(value), ","));
terms = terms(terms ~= "" & terms ~= "(any)");
end


function tf = matchesAny(values, terms)
%matchesAny  Case-insensitive whole-value match against wildcard terms (* ?).
tf = false(size(values));
for t = reshape(terms, 1, [])
    rx = "^" + regexptranslate('wildcard', t) + "$";
    tf = tf | ~cellfun(@isempty, regexpi(cellstr(values), rx, 'once'));
end
end
