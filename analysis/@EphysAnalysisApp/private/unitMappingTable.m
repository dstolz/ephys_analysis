function T = unitMappingTable(C, keys)
%unitMappingTable  A unit-mapping table (readUnitMapping's shape) from the text the editor shows.
%   T = unitMappingTable(C, KEYS) takes C, an n x (1 + numel(KEYS)) cell
%   array of text (a cell's name, then its unit id(s) under each dataset
%   key; a numeric or missing cell is turned to text, NaN and missing to
%   ""), and returns the table writeUnitMapping writes: a string variable
%   "cell", then one string variable per key, named as the key is (keys hold
%   "/"). Rows with no name and no id are dropped; ids and names are
%   trimmed. Errors (EphysAnalysisApp:UnitMapping) when a row has ids but
%   no name or two rows share a name -- the editor says so and stays open.
%
%   See also onEditUnitMapping, editUnitMapping, readUnitMapping.
keys = reshape(string(keys), 1, []);
m = numel(keys);
if isempty(C)
    C = cell(0, 1 + m);
end
n = size(C, 1);
S = strings(n, 1 + m);
for i = 1:n
    for j = 1:1 + m
        S(i, j) = strtrim(cellText(C{i, j}));
    end
end
name = S(:, 1);
ids = S(:, 2:end);
drop = name == "" & all(ids == "", 2);
if any(name == "" & ~drop)
    error('EphysAnalysisApp:UnitMapping', 'Row %d has unit ids but no cell name.', find(name == "" & ~drop, 1));
end
S(drop, :) = [];
name = S(:, 1);
[u, first] = unique(name, 'stable');
if numel(u) < numel(name)
    dup = name(setdiff(1:numel(name), first));
    error('EphysAnalysisApp:UnitMapping', 'Two rows are named "%s": each cell needs a name of its own.', dup(1));
end
cols = cell(1, 1 + m);
for j = 1:1 + m
    cols{j} = S(:, j);
end
T = table(cols{:}, 'VariableNames', cellstr(["cell" keys]));
end


function s = cellText(v)
%cellText  One cell as text ("" for missing and NaN).
if iscell(v)
    v = v{1};
end
if isnumeric(v) || islogical(v)
    if isempty(v) || ~isfinite(double(v(1)))
        s = "";
    else
        s = string(num2str(double(v(1)), 15));
    end
else
    s = string(v);
    if isempty(s) || ismissing(s(1))
        s = "";
    end
    s = s(1);
end
end
