function V = variableColumns(T, idx)
%variableColumns  The dataset-variable columns (var_<name>) of table T at rows IDX; missing where IDX is 0.
%   V = variableColumns(T, IDX) takes the columns of T named with
%   DatasetVariables.ColumnPrefix, in T's order, one row per element of IDX
%   (rows of T; 0 gives a row of NaN, or missing for a text column). The
%   columns keep their VariableDescriptions and VariableUnits. A table of
%   numel(IDX) rows and no columns when T has none (or is not a table).
%   epochMatrix and populationAnalysis use it to put a dataset's variables
%   on a table of units, channels or datasets.
%
%   See also rowVariables, DatasetVariables.columns.

idx = reshape(idx, [], 1);
V = table('Size', [numel(idx) 0], 'VariableTypes', {}, 'VariableNames', {});
if ~istable(T); return; end
names = string(T.Properties.VariableNames);
isVar = startsWith(names, DatasetVariables.ColumnPrefix);
if ~any(isVar) || height(T) == 0; return; end
V = T(max(idx, 1), isVar);
gone = idx < 1;
if ~any(gone); return; end
for c = string(V.Properties.VariableNames)
    if isstring(V.(c))
        V.(c)(gone) = missing;
    else
        V.(c)(gone) = NaN;
    end
end
end
