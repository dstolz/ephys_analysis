function src = source(obj, k)
%source  The analysis source of dataset K (an index, key or name), loaded once.
%   SRC = r.source(K) is loadAnalysisSource(r.Outputs(K), Key=r.Keys(K)),
%   kept in r.Sources until datasets() or clearSources().
%
%   See also loadAnalysisSource, EphysAnalysisRunner.datasets.

i = obj.index(k);
if i == 0
    error('EphysAnalysisRunner:NoDataset', 'No dataset "%s".', string(k));
end
key = char(obj.Keys(i));
if isKey(obj.Sources, key)
    src = obj.Sources(key);
    return
end
src = loadAnalysisSource(obj.Outputs(i), Key=obj.Keys(i));
obj.Sources(key) = src;
end
