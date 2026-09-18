function [mask, G, gi] = selectTrials(src, sel)
%selectTrials  Apply a trial selection to a dataset's paired trials.
%   [MASK, G, GI] = selectTrials(SRC, SEL) takes SRC from loadAnalysisSource
%   and SEL from trialSelection (a struct or [] for the defaults) and
%   returns
%     MASK   [nTrials x 1] logical: the trials kept (rows of src.trials)
%     G      groups table, one row per group: index, label ("Depth = 0.5";
%            "Depth = 0.5, TrialType = 1"; "all" without groupBy), color
%            [1 x 3], n (kept trials in the group), then one column per
%            groupBy parameter holding the group's value
%     GI     [nTrials x 1] group of each trial (0 = not kept)
%   A trial is kept when its PairingFlag is one of pairingFlags, it is any of
%   the response words, the filter is true for it and (when trials is set)
%   it is one of the listed rows. Groups follow groupOrder; colours come
%   from groupColors (a numeric parameter with more than two values runs
%   through parula, anything else uses lines; one ungrouped set is dark
%   grey).
%
%   Without paired trials (src.hasTrials false) there is one group "all"
%   and MASK is empty; a filter, response, trials or groupBy then raises
%   selectTrials:NoTrials. Other errors: selectTrials:NoParam,
%   selectTrials:NoRespCode, selectTrials:TooManyGroups,
%   trialSelection:BadFilter.
%
%   See also trialSelection, epochTable, loadAnalysisSource.

arguments
    src (1,1) struct
    sel = []
end

sel = trialSelection(sel);
restrictive = sel.filter ~= "" || ~isempty(sel.response) || ~isempty(sel.trials) || ~isempty(sel.groupBy);
if ~src.hasTrials
    if restrictive
        error('selectTrials:NoTrials', ...
            '%s has no paired trials, so trials cannot be filtered or grouped (write its behavior file with the pairing first).', src.name);
    end
    mask = false(0, 1);
    gi = zeros(0, 1);
    G = table(1, "all", [0.15 0.15 0.15], 0, 'VariableNames', {'index', 'label', 'color', 'n'});
    return
end

T = src.trials;
n = height(T);
vars = string(T.Properties.VariableNames);
mask = true(n, 1);
if ~isempty(sel.pairingFlags) && ismember("PairingFlag", vars)
    mask = mask & ismember(string(T.PairingFlag), sel.pairingFlags);
end
if ~isempty(sel.response)
    if src.respField == ""
        error('selectTrials:NoRespCode', '%s: the trials have no RespCode column to select responses from.', src.name);
    end
    bits = respCodeBits();
    rc = double(T.(src.respField));
    any1 = false(n, 1);
    for w = sel.response
        any1 = any1 | bitand(rc, bits.(w)) > 0;
    end
    mask = mask & any1;
end
if sel.filter ~= ""
    rf = src.respField;
    if rf == ""; rf = "RespCode"; end
    f = tableFilterFcn(sel.filter, vars, RespField=rf);
    mask = mask & f(T);
end
if ~isempty(sel.trials)
    keep = false(n, 1);
    keep(sel.trials(sel.trials <= n)) = true;
    mask = mask & keep;
end

% --- groups ------------------------------------------------------------------
gi = zeros(n, 1);
p = sel.groupBy;
if isempty(p)
    gi(mask) = 1;
    G = table(1, "all", [0.15 0.15 0.15], nnz(mask), 'VariableNames', {'index', 'label', 'color', 'n'});
    return
end
missing = setdiff(p, vars, 'stable');
if ~isempty(missing)
    error('selectTrials:NoParam', '%s: no trial parameter %s (parameters: %s).', ...
        src.name, strjoin(missing, ", "), strjoin(src.paramNames, ", "));
end
rows = find(mask);
nP = numel(p);
keys = strings(numel(rows), nP);
vals = cell(1, nP);
isNum = false(1, nP);
for j = 1:nP
    v = T.(p(j));
    if iscell(v); v = string(v); end
    if size(v, 2) ~= 1
        error('selectTrials:NoParam', '%s: parameter %s has more than one value per trial and cannot group.', src.name, p(j));
    end
    v = v(rows);
    isNum(j) = isnumeric(v) || islogical(v);
    if isNum(j)
        v = double(v);
        k = compose("%.10g", v);
    else
        v = string(v);
        k = v;
    end
    k(ismissing(k)) = "<missing>";
    keys(:, j) = k;
    vals{j} = v;
end
[~, first, gIdx] = unique(join(keys, char(31), 2), 'stable');
nG = numel(first);

% order the groups: by value (numeric or text) per parameter, or as they appear
order = (1:nG).';
if sel.groupOrder ~= "appearance"
    sortKeys = cell(1, nP);
    for j = 1:nP
        v = vals{j}(first);
        if isNum(j)
            sk = v; sk(isnan(sk)) = Inf;
        else
            [~, ~, sk] = unique(v);   % alphabetical rank
        end
        sortKeys{j} = sk(:);
    end
    [~, order] = sortrows([sortKeys{:}]);
    if sel.groupOrder == "descending"; order = flipud(order); end
end
if nG > sel.maxGroups
    error('selectTrials:TooManyGroups', ...
        '%s: grouping by %s gives %d groups, more than maxGroups (%d). Filter the trials or raise maxGroups.', ...
        src.name, strjoin(p, " and "), nG, sel.maxGroups);
end
rank = zeros(nG, 1);
rank(order) = 1:nG;
gi(rows) = rank(gIdx);

index = (1:nG).';
label = strings(nG, 1);
cnt = accumarray(gi(rows), 1, [nG 1]);
for g = 1:nG
    r = first(order(g));
    parts = strings(1, nP);
    for j = 1:nP
        parts(j) = p(j) + " = " + keys(r, j);
    end
    label(g) = strjoin(parts, ", ");
end
v1 = vals{1}(first(order));
color = groupColors(v1, isNum(1) && nP == 1);
G = table(index, label, color, cnt, 'VariableNames', {'index', 'label', 'color', 'n'});
for j = 1:nP
    G.(p(j)) = reshape(vals{j}(first(order)), [], 1);
end
end
