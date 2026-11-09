function v = rowVariables(T, k)
%rowVariables  A dataset's variable values from row K of a table with var_<name> columns: a struct (probeDepth = 1200).
%   V = rowVariables(T, K) reads the columns of T named with
%   DatasetVariables.ColumnPrefix (variableColumns) at row K and returns a
%   struct with a field per variable, named without the prefix, holding the
%   value. A variable that is missing in the row (NaN or a missing string:
%   the dataset has none) is left out. struct() when T has no such column
%   or K is not a row of T. It is DatasetVariables.values for a table
%   row, for the exporters that receive only epochMatrix's R.
%
%   See also variableColumns, DatasetVariables.values.

v = struct();
if ~istable(T) || ~isscalar(k) || k < 1 || k > height(T); return; end
prefix = DatasetVariables.ColumnPrefix;
for c = string(T.Properties.VariableNames)
    if ~startsWith(c, prefix); continue; end
    x = T.(c)(k);
    if ismissing(x); continue; end
    v.(extractAfter(c, strlength(prefix))) = x;
end
end
