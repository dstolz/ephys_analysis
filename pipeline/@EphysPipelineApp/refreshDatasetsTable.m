function refreshDatasetsTable(obj, opts)
%refreshDatasetsTable  Rebuild the datasets table from project metadata.
%   Preserves the existing "Select" ticks (matched by key). The tokens ticked
%   under the name pattern become columns after Name (table variables
%   "Token_<name>", so a token cannot collide with a fixed column).
%
%   Columns the user dragged into a new order keep it: the displayed order
%   is baked into the table variables (see orderColumns), so it survives
%   rebuilds that change the column set. A header click's sort is kept too:
%   the rows are put in its order on every rebuild (tableSort "Datasets"),
%   and rows map to datasets through DatasetIdx. The token filters and the
%   tag filter above the table hide rows; ticks on hidden rows are kept in
%   HiddenSelectedKeys. The tag filter, the DatasetBrowser's (datasetFilter),
%   keeps the datasets that hold any (or all) of the tags picked or typed,
%   none of the "not" tags, and every search word somewhere in their name,
%   key or tags; a typed term that is no valid tag matches nothing, and an
%   empty filter passes every row. The status filter under it keeps the
%   datasets in any of the states ticked (datasetStatus: no behavior, not
%   paired, pairing not approved, not sorted, not curated in phy, no probe);
%   none ticked passes every row.
%
%   refreshDatasetsTable(Datasets=IDX) only recomputes the cells of the
%   datasets IDX (indices into Project.Datasets) in the rows the table
%   shows (the Kilosort4 monitor, as a run starts or ends), and their rows
%   of the Review tab's Datasets table (refreshReviewDatasets); it rebuilds
%   the whole table when the table does not hold those datasets' rows, or
%   while the tag or status filter is on (a tag edit, a sort or a pairing
%   may show or hide a row). The
%   Behavior column reads each Epsych2 session file's summary once, and
%   again only when the file changes (EpsychMetaCache).
%
%   A probe, sorted-output folder or Epsych2 session that is associated but
%   not there now (a disk or share not connected) reads "missing: <name>";
%   a dataset without a probe of its own shows the config's default probe
%   as "default: <name>" (EphysPipeline.probeFor).
arguments
    obj (1,1) EphysPipelineApp
    opts.Datasets (1,:) double = []
end
obj.syncProjectEmptyState();
if ~isempty(opts.Datasets)
    obj.refreshReviewDatasets(Datasets=opts.Datasets);   % the Review tab's rows of them too
    if refreshRows(obj, opts.Datasets)
        return
    end
end

[tokenNames, shown, patternMsg] = nameTokenSettings(obj);
tokenVars = "Token_" + shown;
nTok = numel(shown);

% Natural column layout: variable, header, editable, sortable, width.
vars   = ["Select", "Name", tokenVars, "Key", "AcqDate", "NumChannels", "Fs", ...
          "DurationMin", "Format", "Probe", "Exclude", "Sorting", "Behavior", "Tags", "Vars", "DatasetIdx"];
labels = [{'Select', 'Name'}, cellstr(shown), ...
          {'Key', 'Acq date', 'Ch', 'Fs (Hz)', 'Dur (min)', 'Format', 'Probe', 'Exclude', 'Sorting', 'Behavior', 'Tags', 'Variables', ''}];
editable = [true, false(1, 14 + nTok)];
sortable = [true(1, 14 + nTok), false];
% No '1x' column: a weighted column gets only what the others leave, which a
% 1280 px window leaves none of (a column a few pixels wide). Every column
% fits its contents, Tags and Variables are fixed so an empty cell is still easy to click,
% and the table scrolls sideways when the window is narrower than the columns.
widths = [{64, 'fit'}, repmat({'fit'}, 1, nTok), ...
          {'fit', 118, 44, 76, 86, 'fit', 'fit', 90, 'fit', 'fit', 140, 160, 1}];

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
Sorting = strings(n, 1); Behavior = strings(n, 1); Tags = strings(n, 1); Vars = strings(n, 1);
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
    Exclude(i) = c.Exclude; Sorting(i) = c.Sorting; Behavior(i) = c.Behavior; Tags(i) = c.Tags;
    Vars(i) = c.Vars;
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
% Tag filter: its list follows the tags in use; it counts as one filter.
sets = cell(1, n);
for i = 1:n
    sets{i} = obj.Project.Datasets(i).Tags;
end
syncTagFilterItems(obj, sets);
[tagKeep, tagActive] = tagFilter(obj, sets, Name + " " + Key + " " + Tags);
keep = keep & tagKeep;
nActive = nActive + tagActive;
% Status filter: the datasets in any ticked state; it counts as one filter.
[statusKeep, statusActive] = statusFilter(obj, keep);
keep = keep & statusKeep;
nActive = nActive + statusActive;

[~, loc] = ismember(shown, tokenNames);
DatasetIdx = (1:n)';
T = [table(Select, Name), array2table(AllTokens(:, loc), 'VariableNames', cellstr(tokenVars)), ...
    table(Key, AcqDate, NumChannels, Fs, DurationMin, Format, ...
    Probe, Exclude, Sorting, Behavior, Tags, Vars, DatasetIdx)];
T.Properties.VariableNames = cellstr(vars);
obj.HiddenSelectedKeys = reshape(Key(~keep & Select), 1, []);
T = T(keep, :);

% Apply the remembered column order to the variables and every per-column
% property, then clear the table's own display order so it is not applied twice.
% The rows take the remembered sort.
perm = orderColumns(vars, order);
obj.DatasetsTable.Data = TableSort.apply(T(:, perm), obj.tableSort("Datasets"));
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
obj.syncSourcePanel();
end


function done = refreshRows(obj, idx)
%refreshRows  Recompute the cells of datasets IDX in the rows the table shows.
%   False (nothing done) when the table does not hold this project's rows,
%   or while the tag or status filter is on (a change may show or hide a row).
T = obj.DatasetsTable.Data;
done = false;
if isempty(obj.Project) || ~istable(T) || ~all(ismember({'Key', 'DatasetIdx'}, T.Properties.VariableNames)) ...
        || ~isempty(statusTerms(obj))
    return
end
sets = arrayfun(@(d) d.Tags, obj.Project.Datasets, 'UniformOutput', false);
[~, tagActive] = tagFilter(obj, sets, strings(numel(sets), 1));
if tagActive; return; end
syncTagFilterItems(obj, sets);   % a tag edit may add or drop one
for i = idx(idx >= 1 & idx <= obj.Project.NumDatasets)
    r = find(T.DatasetIdx == i, 1);
    if isempty(r); continue; end   % hidden by the token filters: the next rebuild has it
    if ~strcmpi(T.Key(r), obj.Project.datasetKey(i)); return; end
    c = datasetCells(obj, obj.Project.Datasets(i));
    for f = string(fieldnames(c)).'
        T.(f)(r) = c.(f);
    end
end
obj.DatasetsTable.Data = TableSort.apply(T, obj.tableSort("Datasets"));   % a changed cell may move its row
obj.highlightDatasetRow();
obj.syncToolsPanel();
obj.syncSourcePanel();
done = true;
end


function c = datasetCells(obj, d)
%datasetCells  The cells of dataset D's row that come from its metadata,
%   probe, exclusions, sorted output, Epsych2 session, tags and variables.
c = struct('Name', d.Name, 'AcqDate', "", 'NumChannels', d.NumChannels, 'Fs', d.Fs, ...
    'DurationMin', 0, 'Format', d.RecordingFormat, 'Probe', "-", 'Exclude', "-", ...
    'Sorting', "-", 'Behavior', "-", 'Tags', TagSet.toText(d.Tags, TagSet.DisplayDelimiter), ...
    'Vars', DatasetVariables.toText(d.Variables));   % "Vars": a table cannot have a variable named Variables
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
    c.Sorting = sortingCell(s);
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


function txt = sortingCell(s)
%sortingCell  The Sorting cell of a sort that is there (sortingStruct S):
%   "auto: 12 good units" while the sorter's labels stand, "phy: 9 good
%   units" once phy saved a label, merge or split (phyStatus.modified), the
%   good units counted from the labels in use (labelCounts). A folder
%   picked on the Sorting tab adds ", manual folder".
n = EphysDataset.labelCounts(s.results_dir);
txt = "auto";
if curatedInPhy(s.results_dir, n); txt = "phy"; end
if isfinite(n.good)
    txt = txt + sprintf(": %d good unit", n.good);
    if n.good ~= 1; txt = txt + "s"; end
end
if s.source == "manual"; txt = txt + ", manual folder"; end
end


function tf = curatedInPhy(resultsDir, n)
%curatedInPhy  Whether phy changed the sort in RESULTSDIR: the labels in use
%   are phy's (labelCounts N), or a save labeled, merged or split a cluster
%   (phyStatus.modified). The Sorting cell then reads "phy", else "auto".
tf = n.source == "phy" || EphysDataset.phyStatus(resultsDir).modified;
end


function keys = statusTerms(obj)
%statusTerms  The keys of the status filter's ticked boxes (none: the filter is off).
keys = strings(1, 0);
cb = obj.StatusFilterChecks;
if isempty(cb); return; end
cb = cb(isvalid(cb));
cb = cb(logical([cb.Value]));
keys = reshape(string({cb.UserData}), 1, []);
end


function [keep, active] = statusFilter(obj, shown)
%statusFilter  Which datasets the status filter keeps: those in any ticked
%   state (datasetStatus). Only the rows the other filters SHOW (n x 1) are
%   looked at, as each look reads files; the others are kept here, hidden
%   anyway. ACTIVE: a box is ticked.
keep = true(numel(shown), 1);
want = statusTerms(obj);
active = ~isempty(want);
if ~active; return; end
for i = reshape(find(shown), 1, [])
    keep(i) = any(ismember(datasetStatus(obj, obj.Project.Datasets(i)), want));
end
end


function states = datasetStatus(obj, d)
%datasetStatus  The states of dataset D the status filter tells apart, as keys:
%   behavior   "nobehavior" no trial source (trialSource: no Epsych2 session,
%                           or one not there now, and no TDT trial epocs)
%              "unpaired"   a trial source, no trial pairing recorded
%              "unapproved" a pairing recorded, not approved
%   sorting    "unsorted"   no sorted output there (sortingStruct.exists)
%              "uncurated"  sorted, phy has not changed it (curatedInPhy)
%   probe      "noprobe"    no probe (EphysPipeline.resolveProbe: its own, a
%                           rule's or the default), or its file not there
states = strings(1, 0);
if trialSource(d, true) == ""
    states(end+1) = "nobehavior";
elseif isempty(d.TrialPairing)
    states(end+1) = "unpaired";
elseif d.TrialPairing.status ~= "approved"
    states(end+1) = "unapproved";
end
s = d.sortingStruct();
if ~s.exists
    states(end+1) = "unsorted";
elseif ~curatedInPhy(s.results_dir, EphysDataset.labelCounts(s.results_dir))
    states(end+1) = "uncurated";
end
f = EphysPipeline.resolveProbe(obj.Config.Probe, d);
if f == "" || ~isfile(f)
    states(end+1) = "noprobe";
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


function syncTagFilterItems(obj, sets)
%syncTagFilterItems  The tag filter and its "not" list show '(any)' and every
%   tag in use (SETS, one per dataset); a typed value is kept by the editable dropdowns.
voc = [{'(any)'}, TagSet.vocabulary(sets)];
for dd = [obj.TagFilterDropDown, obj.NotTagFilterDropDown]
    if isempty(dd) || ~isvalid(dd); continue; end
    v = dd.Value;
    dd.Items = voc;
    dd.Value = v;
end
end


function [keep, active] = tagFilter(obj, sets, text)
%tagFilter  Which datasets (SETS, one tag set each) the tag filter keeps.
%   KEEP (n x 1): holding any / all of the tags picked or typed, none of the
%   "not" tags, and every search word in TEXT (a string per dataset: its
%   name, key and tags), as the DatasetBrowser filters (datasetFilter). A
%   typed term that is no valid tag matches nothing. ACTIVE: any part is set.
keep = true(numel(sets), 1);
active = false;
dd = obj.TagFilterDropDown;
if isempty(dd) || ~isvalid(dd); return; end
[keep, active] = datasetFilter(strings(numel(sets), 1), reshape(sets, [], 1), Tags=dd.Value, ...
    TagMode=obj.TagFilterModeDropDown.Value, ExcludeTags=obj.NotTagFilterDropDown.Value, ...
    Search=obj.DatasetSearchField.Value, Text=text);
end


function tf = matchesAny(values, terms)
%matchesAny  Case-insensitive whole-value match against wildcard terms (* ?).
tf = false(size(values));
for t = reshape(terms, 1, [])
    rx = "^" + regexptranslate('wildcard', t) + "$";
    tf = tf | ~cellfun(@isempty, regexpi(cellstr(values), rx, 'once'));
end
end
