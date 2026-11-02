function [fcn, names] = tableFilterFcn(expr, columns, opts)
%tableFilterFcn  Compile a trial-filter expression into @(T) logical rows.
%   [FCN, NAMES] = tableFilterFcn(EXPR, COLUMNS, RespField=) checks EXPR (see
%   trialSelection for the language) against the table columns COLUMNS and
%   returns FCN, which maps a table with those columns to a logical column
%   (one per row), and the column names EXPR uses. Identifiers become
%   T.("name"), response words bitand(T.(RespField), bit) > 0, "!" "~",
%   "&&" / "||" the row-wise "&" / "|",
%   "!=" "~=" and a single "=" "=="; functions must be on the allow-list.
%   The text is compiled with str2func, never eval, from these tokens only.
%   Two shapes MATLAB would read otherwise than written are refused: a
%   chained comparison ("0 < Depth < 5" is (0 < Depth) < 5: write
%   "0 < Depth & Depth < 5") and "&&" / "||" mixed with "&" / "|" (row by
%   row they bind differently). A trial whose response code is missing
%   (NaN) matches no response word.
%   With COLUMNS = [] only the syntax is checked (any name counts as a
%   column). The analysis trial filters (selectTrials) and the pipeline's
%   derived events (deriveEvents) share it.
%
%   Errors: trialSelection:BadFilter.
%
%   See also trialSelection, deriveEvents, respCodeBits.

arguments
    expr (1,1) string
    columns = []
    opts.RespField (1,1) string = "RespCode"
end

allowFns = ["abs" "round" "floor" "ceil" "fix" "mod" "rem" "min" "max" "isnan" "isfinite" ...
    "ismissing" "ismember" "any" "all" "strcmp" "strcmpi" "contains" "startsWith" "endsWith" ...
    "lower" "upper" "string" "double" "bitand"];
constants = ["true" "false" "pi" "NaN" "Inf"];
[bits, words] = respCodeBits();
checkOnly = isempty(columns) && isnumeric(columns);
columns = string(columns);

txt = char(strtrim(expr));
if isempty(txt)
    error('trialSelection:BadFilter', 'The filter is empty.');
end
pat = ['(?<str>"(?:[^"]|"")*"|''(?:[^'']|'''')*'')' ...
       '|(?<num>(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)' ...
       '|(?<id>[A-Za-z]\w*)' ...
       '|(?<op>==|~=|!=|<=|>=|&&|\|\||\.\*|\./|\.\^|[<>&|~!+\-*/^(),\[\]:=])' ...
       '|(?<ws>\s+)'];
[toks, st, en, nm] = regexp(txt, pat, 'match', 'start', 'end', 'names');
pos = 1;
for k = 1:numel(toks)
    if st(k) ~= pos; break; end
    pos = en(k) + 1;
end
if pos <= numel(txt)
    error('trialSelection:BadFilter', 'The filter "%s" has something it cannot use at "%s".', ...
        txt, txt(pos:min(end, pos + 9)));
end

parts = strings(1, numel(toks));
names = string.empty(1, 0);
for k = 1:numel(toks)
    t = string(toks{k});
    if ~isempty(nm(k).str)
        parts(k) = t;
    elseif ~isempty(nm(k).num)
        parts(k) = t;
    elseif ~isempty(nm(k).ws)
        parts(k) = " ";
    elseif ~isempty(nm(k).op)
        switch t
            case "!",  parts(k) = "~";
            case "!=", parts(k) = "~=";
            case "=",  parts(k) = "==";
            case "&&", parts(k) = "&";     % row-wise: the operands are columns
            case "||", parts(k) = "|";
            otherwise, parts(k) = t;
        end
    else
        called = nextToken(toks, k) == "(";
        if ismember(t, constants)
            parts(k) = t;
        elseif called && ismember(t, allowFns) && ~ismember(t, columns)
            parts(k) = t;
        elseif checkOnly || ismember(t, columns)
            parts(k) = "T.(""" + t + """)";
            names(end+1) = t; %#ok<AGROW>
        elseif ismember(t, words)
            if ~checkOnly && ~ismember(opts.RespField, columns)
                error('trialSelection:BadFilter', ...
                    'The filter uses "%s" but the trials have no %s column.', t, opts.RespField);
            end
            parts(k) = "(bitand(fillmissing(double(T.(""" + opts.RespField + """)), 'constant', 0), " + bits.(t) + ") > 0)";
            names(end+1) = opts.RespField; %#ok<AGROW>
        elseif ismember(t, allowFns)
            error('trialSelection:BadFilter', 'In the filter, %s must be called: %s(...).', t, t);
        else
            error('trialSelection:BadFilter', ...
                'The filter uses "%s", which is not a trial column, a response word or an allowed function (columns: %s).', ...
                t, strjoin(columns, ", "));
        end
    end
end
names = unique(names, 'stable');
checkOperators(toks, nm, txt);
try
    f0 = str2func("@(T) " + strjoin(parts, ""));
catch ME
    error('trialSelection:BadFilter', 'The filter "%s" is not a valid expression: %s', txt, ME.message);
end
fcn = @(T) applyFilter(f0, T, string(txt));
end


function checkOperators(toks, nm, txt)
%checkOperators  Refuse the shapes MATLAB would read otherwise than they are written.
%   A chained comparison ("0 < Depth < 5") is (0 < Depth) < 5, the same for
%   every trial; "&&" / "||" beside "&" / "|" change their precedence once
%   they are made row-wise. Both are refused, with the way to write them.
rel = ["==" "~=" "!=" "<" ">" "<=" ">=" "="];
shortOps = ["&&" "||"];
longOps = ["&" "|"];
seen = false;          % a comparison since the last boolean operator, comma or parenthesis at this depth
stack = false(1, 0);
hasShort = false;
hasLong = false;
for k = 1:numel(toks)
    if isempty(nm(k).op); continue; end
    t = string(toks{k});
    if t == "(" || t == "["
        stack(end+1) = seen; %#ok<AGROW>
        seen = false;
    elseif t == ")" || t == "]"
        if ~isempty(stack); seen = stack(end); stack(end) = []; end
    elseif any(t == [shortOps longOps ","])
        seen = false;
        hasShort = hasShort || any(t == shortOps);
        hasLong = hasLong || any(t == longOps);
    elseif any(t == rel)
        if seen
            error('trialSelection:BadFilter', ['The filter "%s" chains comparisons, which MATLAB reads as ' ...
                '(a < b) < c, the same for every trial: write "a < b & b < c".'], txt);
        end
        seen = true;
    end
end
if hasShort && hasLong
    error('trialSelection:BadFilter', ['The filter "%s" mixes && / || with & / |, which bind differently once ' ...
        'they are taken row by row: use one kind, or parentheses.'], txt);
end
end


function t = nextToken(toks, k)
%nextToken  The next non-blank token after K ("" at the end).
t = "";
for j = k+1:numel(toks)
    s = strtrim(string(toks{j}));
    if s ~= ""
        t = s;
        return
    end
end
end


function tf = applyFilter(f0, T, txt)
%applyFilter  Evaluate a compiled filter; one logical per row of T.
try
    v = f0(T);
catch ME
    error('trialSelection:BadFilter', 'The filter "%s" failed on the trials: %s', txt, ME.message);
end
if ~(islogical(v) || isnumeric(v)) || numel(v) ~= height(T)
    if (islogical(v) || isnumeric(v)) && isscalar(v)
        v = repmat(v, height(T), 1);
    else
        error('trialSelection:BadFilter', ...
            'The filter "%s" must give one true / false per trial (got a %s of %d element(s) for %d trials).', ...
            txt, class(v), numel(v), height(T));
    end
end
v = double(v(:));
v(isnan(v)) = 0;
tf = v ~= 0;
end
