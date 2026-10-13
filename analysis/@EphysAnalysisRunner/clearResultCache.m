function clearResultCache(obj)
%clearResultCache  Forget every cached per-dataset result (ResultCache); CacheBytes becomes 0.
%   CacheWanted is left as it is (run sets it).
%
%   See also EphysAnalysisRunner.cachedPlot, EphysAnalysisRunner.cachePut.
if isempty(obj.ResultCache)
    obj.ResultCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
elseif obj.ResultCache.Count > 0
    remove(obj.ResultCache, keys(obj.ResultCache));
end
obj.CacheBytes = 0;
obj.CacheOrder = string.empty(1, 0);
end
