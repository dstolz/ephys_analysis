function refreshTrialsTable(obj)
%refreshTrialsTable  The Trials table from TrialsPairing and the loaded session.
%   Fixed columns: trial, TrialIndex, interval, onset / offset (s and
%   sample), flag and the other lines overlapping the trial. After Flag come
%   the Epsych2 parameters in TrialsParamColumns that the session has (table
%   variables "Param_<name>", so a parameter cannot collide with a fixed
%   column), in the order they were added. Rows are coloured by flag.
%
%   Every column sorts and can be dragged to a new place. As in the Project
%   table, the order on screen is baked into the table variables here, so it
%   survives rebuilds that change the column set; TrialsColumnOrder remembers
%   it (a preference, see trialsColumnOrder). A sort is not kept: setting the
%   data shows the rows in trial order again.

tbl = obj.TrialsTable;
P = obj.TrialsPairing;
removeStyle(tbl);
if isempty(P)
    tbl.Data = table();
    return
end

n = P.nTrials;
S = obj.TrialsSession;
if ~istable(S) || height(S) ~= n
    S = table();
end
sessionVars = string(S.Properties.VariableNames);
params = obj.TrialsParamColumns(ismember(obj.TrialsParamColumns, sessionVars) & obj.TrialsParamColumns ~= "TrialIndex");

% Natural column layout: variable, header, width.
vars   = ["Trial", "TrialIndex", "Interval", "Onset", "Offset", "OnsetSample", "OffsetSample", "Flag", ...
          "Param_" + params, "OtherLines"];
labels = [{'Trial', 'TrialIndex', 'Interval', 'Onset (s)', 'Offset (s)', 'Onset sample', 'Offset sample', 'Flag'}, ...
          cellstr(params), {'Other lines'}];
widths = [{45, 70, 60, 80, 80, 95, 95, 70}, repmat({'fit'}, 1, numel(params)), {'auto'}];

C = P.columns;
trialIndex = (1:n).';
if ismember("TrialIndex", sessionVars)
    trialIndex = double(S.TrialIndex);
end
other = strings(n, 1);
for ln = string(fieldnames(P.lines)).'
    c = cellfun(@(x) size(x, 1), P.lines.(ln));
    has = c > 0;
    other(has) = other(has) + ln + ":" + string(c(has)) + " ";
end
T = table((1:n).', trialIndex, C.TrialInterval, round(C.TrialOnset, 4), round(C.TrialOffset, 4), ...
    C.TrialOnsetSample, C.TrialOffsetSample, C.PairingFlag);
for p = params
    T.("Param_" + p) = displayColumn(S.(p));
end
T.OtherLines = strtrim(other);
T.Properties.VariableNames = cellstr(vars);

% Apply the remembered column order, then clear the table's own display
% order so it is not applied twice.
obj.TrialsColumnOrder = obj.trialsColumnOrder();   % with a drag since the last refresh
perm = orderColumns(vars, obj.TrialsColumnOrder);
tbl.Data = T(:, perm);
tbl.ColumnName = labels(perm);
tbl.ColumnWidth = widths(perm);
tbl.DisplayColumnOrder = [];
obj.TrialsColumnOrder = obj.trialsColumnOrder(vars(perm));

for f = ["cut" "partial" "unpaired"]
    k = find(P.flag == f);
    if isempty(k); continue; end
    switch f
        case "cut";      s = uistyle("BackgroundColor", [0.9 0.9 0.9], "FontColor", [0.45 0.45 0.45]);
        case "partial";  s = uistyle("BackgroundColor", [1 0.92 0.78]);
        case "unpaired"; s = uistyle("BackgroundColor", [1 0.85 0.85]);
    end
    addStyle(tbl, s, "row", k);
end
end


function perm = orderColumns(vars, order)
%orderColumns  Permutation of VARS following ORDER. Columns named in ORDER
%   take the slots they jointly occupy in VARS in ORDER's sequence; new
%   columns keep their natural slot.
perm = 1:numel(vars);
known = order(ismember(order, vars));
slots = find(ismember(vars, known));
[~, perm(slots)] = ismember(known, vars);
end


function v = displayColumn(v)
%displayColumn  A session column as one table column. Single-column numeric,
%   logical, text, categorical, datetime and duration values stay as they
%   are; cells of numeric scalars (empty -> NaN) become numbers so they sort
%   as numbers; anything else is shown as text, one string per trial.
if size(v, 2) == 1 && (isnumeric(v) || islogical(v) || isstring(v) || iscategorical(v) || isdatetime(v) || isduration(v))
    return
end
if iscell(v) && all(cellfun(@(x) (isnumeric(x) || islogical(x)) && numel(x) <= 1, v(:)))
    x = NaN(size(v, 1), 1);
    has = ~cellfun(@isempty, v(:, 1));
    x(has) = cellfun(@double, v(has, 1));
    v = x;
    return
end
v = arrayfun(@(k) valueText(v(k, :)), (1:size(v, 1)).');
end


function s = valueText(x)
%valueText  One trial's value as text ("[size class]" when it has none).
if iscell(x) && isscalar(x)
    x = x{1};
end
try
    s = strjoin(reshape(string(x), 1, []), " ");
catch
    s = "[" + strjoin(string(size(x)), "x") + " " + class(x) + "]";
end
end
