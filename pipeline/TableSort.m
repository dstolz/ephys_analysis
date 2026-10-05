classdef TableSort
    % TableSort  Keep a uitable's column sort when its data is refreshed.
    %   A uitable sorts on a header click, but only its display: the sort is
    %   gone as soon as the app sets the table's Data again (another dataset,
    %   a refresh, an edit). TableSort remembers the click as a state, the
    %   column and the direction, and sorts the rows the app shows next the
    %   same way:
    %
    %     tbl.DisplayDataChangedFcn = @(~, evt) remember(TableSort.fromEvent(tbl, evt, s));
    %     [data, ord] = TableSort.apply(data, s, tbl.ColumnName);
    %     tbl.Data = data;              % row i shows the row ord(i) of the data given
    %
    %   A state is a struct with fields column (a table variable name, or the
    %   header of a cell-array table's column) and direction ("ascend" or
    %   "descend"); TableSort.none() is no sort. It holds whatever the rows
    %   are, so it carries over to another dataset's rows; a column the rows
    %   lack leaves them in the order given. toPref / fromPref store it as an
    %   app preference.
    %
    %   apply sorts by that column alone and keeps the order given among
    %   equal values. Numbers, logicals, dates, durations and categories sort
    %   by value; text ignores case. Empty cells, "", NaN, NaT, <missing> and
    %   <undefined> go last in either direction. A cell column of numbers
    %   sorts as numbers; a column mixing numbers and text sorts as text.
    %
    %   Apply the order to everything the app keeps by row: styles (addStyle
    %   targets rows of Data) and any map from a row to the app's data.
    %
    %   See also EphysPipelineApp.

    methods (Static)
        function s = none()
            %none  The state of a table with no sort.
            s = struct('column', "", 'direction', "");
        end

        function tf = isSorted(s)
            %isSorted  True when state S sorts by a column.
            tf = isstruct(s) && isscalar(s) && isfield(s, 'column') && isfield(s, 'direction') ...
                && isscalar(string(s.column)) && strlength(string(s.column)) > 0 ...
                && isscalar(string(s.direction)) && ismember(string(s.direction), ["ascend" "descend"]);
        end

        function s = fromEvent(tbl, evt, prev)
            %fromEvent  The state after a header click: S = TableSort.fromEvent(TBL, EVT, PREV).
            %   For a DisplayDataChangedFcn: EVT's Interaction "sort" gives
            %   the column clicked (InteractionVariable, else
            %   InteractionColumn, a column of Data); the order of
            %   TBL.DisplayData gives the direction (fromDisplay). Any other
            %   interaction (an edit) returns PREV.
            arguments
                tbl
                evt
                prev = TableSort.none()
            end
            s = prev;
            if ~strcmpi(string(member(evt, 'Interaction', "")), "sort")
                return
            end
            col = member(evt, 'InteractionColumn', []);
            variable = string(member(evt, 'InteractionVariable', ""));
            s = TableSort.fromDisplay(tbl.Data, tbl.DisplayData, col, tbl.ColumnName, prev, variable);
        end

        function s = fromDisplay(data, shown, col, names, prev, variable)
            %fromDisplay  The state a header click left: the column and the order shown.
            %   S = TableSort.fromDisplay(DATA, SHOWN, COL, NAMES, PREV, VARIABLE).
            %   DATA is the table's Data, SHOWN its DisplayData, COL the
            %   column clicked (a column of DATA), NAMES its ColumnName and
            %   VARIABLE the variable clicked when DATA is a table ("" = from COL).
            %   The direction is the one most neighbouring values in SHOWN
            %   follow. When they tell none (one row, equal values) it is
            %   "ascend" for a new column and the other direction for the
            %   column of PREV, as a second click on a header gives. PREV
            %   comes back when the column cannot be told.
            arguments
                data
                shown
                col
                names = {}
                prev = TableSort.none()
                variable (1,1) string = ""
            end
            s = prev;
            key = "";
            v = [];
            if istable(data)
                vars = string(data.Properties.VariableNames);
                if (ismissing(variable) || variable == "") && isscalar(col) && col >= 1 && col <= numel(vars)
                    variable = vars(col);
                end
                if ~ismissing(variable) && variable ~= "" && any(vars == variable)
                    key = variable;
                    if istable(shown) && any(string(shown.Properties.VariableNames) == variable)
                        v = shown.(variable);
                    end
                end
            else
                names = string(names);
                if isscalar(col) && col >= 1 && col <= numel(names)
                    key = names(col);
                    if size(shown, 2) >= col && size(shown, 1) == size(data, 1)
                        v = shown(:, col);
                    end
                end
            end
            if key == "" || ismissing(key)
                return
            end
            direction = TableSort.direction(v);
            if direction == ""
                direction = "ascend";
                if TableSort.isSorted(prev) && string(prev.column) == key && string(prev.direction) == "ascend"
                    direction = "descend";
                end
            end
            s = struct('column', key, 'direction', direction);
        end

        function d = direction(v)
            %direction  "ascend" or "descend": the way most neighbouring values of V go.
            %   Missing values are left out; "" when no two values differ.
            g = sortRanks(v);
            g = g(~isnan(g));
            steps = diff(g);
            nUp = nnz(steps > 0);
            nDown = nnz(steps < 0);
            d = "";
            if nUp > nDown
                d = "ascend";
            elseif nDown > nUp
                d = "descend";
            end
        end

        function [data, ord] = apply(data, s, names)
            %apply  DATA's rows in the order of state S: [DATA, ORD] = TableSort.apply(DATA, S, NAMES).
            %   DATA is a table (S.column is a variable) or a cell / numeric
            %   array (S.column is one of NAMES, the table's ColumnName). Row
            %   i of the result is row ORD(i) of DATA. Without a sort, or when
            %   DATA lacks the column, DATA comes back as given.
            arguments
                data
                s = TableSort.none()
                names = {}
            end
            n = size(data, 1);
            ord = (1:n).';
            if n < 2 || ~TableSort.isSorted(s)
                return
            end
            v = [];
            key = string(s.column);
            if istable(data)
                if any(string(data.Properties.VariableNames) == key)
                    v = data.(key);
                end
            else
                j = find(string(names) == key, 1);
                if ~isempty(j) && j <= size(data, 2)
                    v = data(:, j);
                end
            end
            if isempty(v)
                return
            end
            g = sortRanks(v);
            miss = isnan(g);
            g(miss) = 0;
            sgn = 1;
            if string(s.direction) == "descend"; sgn = -1; end
            [~, ord] = sortrows([double(miss), sgn * g, (1:n).']);
            data = data(ord, :);
        end

        function p = toPref(s)
            %toPref  State S (or a struct of states, one field per table) as a preference value.
            p = s;
            if ~isstruct(p) || ~isscalar(p); p = struct(); return; end
            if isfield(p, 'column') && isfield(p, 'direction')
                p = struct('column', char(string(p.column)), 'direction', char(string(p.direction)));
                return
            end
            for f = string(fieldnames(p)).'
                p.(f) = TableSort.toPref(p.(f));
            end
        end

        function s = fromPref(p)
            %fromPref  A state from a preference value; TableSort.none() when P is not one.
            s = TableSort.none();
            try
                if isstruct(p) && isscalar(p) && isfield(p, 'column') && isfield(p, 'direction')
                    c = string(p.column);
                    d = string(p.direction);
                    if isscalar(c) && isscalar(d) && ~ismissing(c) && strlength(c) > 0 && ismember(d, ["ascend" "descend"])
                        s = struct('column', c, 'direction', d);
                    end
                end
            catch
            end
        end
    end
end


function v = member(evt, name, default)
%member  EVT.(NAME) for an event object or a struct; DEFAULT when it has none.
v = default;
try
    if isstruct(evt)
        if isfield(evt, name); v = evt.(name); end
    elseif isprop(evt, name)
        v = evt.(name);
    end
catch
end
if isempty(v); v = default; end
end


function g = sortRanks(v)
%sortRanks  The rank of each value of column V in ascending order; NaN = missing.
%   Equal values share a rank. Text is compared ignoring case.
n = size(v, 1);
g = NaN(n, 1);
if n == 0; return; end
[x, miss] = sortValues(v);
if all(miss); return; end
[~, ~, r] = unique(x(~miss));
g(~miss) = r;
end


function [x, miss] = sortValues(v)
%sortValues  Column V as one comparable vector X, and which of its values are missing.
if iscell(v)
    v = v(:, 1);
    miss = cellfun(@(c) isempty(c) || (isstring(c) && isscalar(c) && (ismissing(c) || c == "")) ...
        || ((isnumeric(c) || islogical(c)) && isscalar(c) && isnan(double(c))), v);
    num = cellfun(@(c) (isnumeric(c) || islogical(c)) && isscalar(c), v);
    if all(num | miss)
        x = NaN(size(v));
        x(num) = cellfun(@double, v(num));
        miss = miss | isnan(x);
        return
    end
    x = strings(size(v));
    for i = find(~miss).'
        x(i) = cellText(v{i});
    end
    x = lower(x);
    miss = miss | ismissing(x) | x == "";
    return
end
if ischar(v)
    v = string(v);
end
if size(v, 2) > 1
    v = v(:, 1);
end
if isnumeric(v) || islogical(v)
    x = double(v);
    miss = isnan(x);
elseif isdatetime(v)
    x = v;
    miss = isnat(v);
elseif isduration(v)
    x = v;
    miss = isnan(v);
elseif iscategorical(v)
    x = v;
    miss = isundefined(v);
elseif isstring(v)
    x = lower(v);
    miss = ismissing(x) | x == "";
else
    x = strings(size(v, 1), 1);
    for i = 1:size(v, 1)
        x(i) = cellText(v(i));
    end
    x = lower(x);
    miss = ismissing(x) | x == "";
end
end


function s = cellText(c)
%cellText  One cell's value as one string ("" when it has no text form).
try
    s = strjoin(reshape(string(c), 1, []), " ");
catch
    s = "";
end
if isempty(s) || ~isscalar(s); s = ""; end
end
