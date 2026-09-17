function refreshDatasetsTable(obj)
%refreshDatasetsTable  Rebuild the datasets table from project metadata.
%   Preserves the existing "Select" ticks (matched by key). The tokens ticked
%   under the name pattern become columns after Name (table variables
%   "Token_<name>", so a token cannot collide with a fixed column).
%
%   Columns the user dragged into a new order keep it: the displayed order
%   is baked into the table variables (see orderColumns), so it survives
%   rebuilds that change the column set. The token filters above the table
%   hide rows; ticks on hidden rows are kept in HiddenSelectedKeys.

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
prevDatasetIdx = obj.SelectedDatasetIdx;   % kept while its row is filtered out
if istable(prev) && obj.SelectedRow >= 1 && obj.SelectedRow <= height(prev) ...
        && any(strcmp('DatasetIdx', prev.Properties.VariableNames))
    prevDatasetIdx = prev.DatasetIdx(obj.SelectedRow);
end

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
    Name(i)   = d.Name;
    if patternMsg == ""
        [vals, ~, ok] = parseNameTokens(d.Name, obj.NamePatternField.Value);
        if ok
            nMatched = nMatched + 1;
            AllTokens(i, :) = vals;
        end
    end
    Format(i) = d.RecordingFormat;
    if ~isnat(d.AcqDate)
        AcqDate(i) = string(datetime(d.AcqDate, 'Format', 'yyyy-MM-dd HH:mm'));
    end
    NumChannels(i) = d.NumChannels;
    Fs(i) = d.Fs;
    if ~isnan(d.Duration); DurationMin(i) = d.Duration / 60; end
    if d.ProbeFile ~= "" && isfile(d.ProbeFile)
        [~, pn, pe] = fileparts(d.ProbeFile);
        Probe(i) = pn + pe;
    else
        Probe(i) = "-";
    end
    if isempty(d.ExcludeChannels)
        Exclude(i) = "-";
    else
        Exclude(i) = EphysDataset.formatChannelList(d.ExcludeChannels);
    end
    s = d.sortingStruct();
    if s.results_dir == ""
        Sorting(i) = "-";
    else
        txt = s.source;
        if isfinite(s.num_units); txt = txt + sprintf(": %d units", s.num_units); end
        if s.curated; txt = txt + ", curated"; end
        Sorting(i) = txt;
    end
    if d.BehaviorFile == "" || ~isfile(d.BehaviorFile)
        Behavior(i) = "-";
    else
        try
            m = epsychSessionMeta(d.BehaviorFile);
            Behavior(i) = sprintf("%s (%d trials)", m.subject, m.nTrials);
        catch
            [~, bf, be] = fileparts(d.BehaviorFile);
            Behavior(i) = bf + be;
        end
        if ~isempty(d.TrialPairing)
            Behavior(i) = Behavior(i) + ", pairing " + d.TrialPairing.status;
        end
    end
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
    table(Key, AcqDate, NumChannels, Fs, round(DurationMin, 2), Format, ...
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

% The last-clicked row follows its dataset (rows move as filters change).
obj.SelectedRow = 0;
if prevDatasetIdx >= 1 && any(T.DatasetIdx == prevDatasetIdx)
    obj.SelectedRow = find(T.DatasetIdx == prevDatasetIdx, 1);
end

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
    obj.updatePhyButtonState();
    obj.syncTabStrip();
end
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
