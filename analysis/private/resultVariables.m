function v = resultVariables(R, key)
%resultVariables  The variables of dataset KEY in an epochMatrix result R, a struct of values (struct() when none).
%   V = resultVariables(R, KEY) reads the var_<name> columns of R.datasets
%   at the row of KEY (rowVariables): V.probeDepth = 1200. struct() when R
%   has no datasets table, KEY is not in it or the dataset has no
%   variables. epochMatrixCSD, epochMatrixFieldTrip, epochMatrixMTRF and
%   epochMatrixRaster put it in their cfg or result, as sessionData does
%   for D.variables.
%
%   See also rowVariables, epochMatrix.

v = struct();
if ~isfield(R, 'datasets') || ~istable(R.datasets) || ~ismember("key", string(R.datasets.Properties.VariableNames))
    return
end
v = rowVariables(R.datasets, find(string(R.datasets.key) == string(key), 1));
end
