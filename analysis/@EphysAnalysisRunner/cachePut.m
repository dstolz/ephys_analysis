function cachePut(obj, key, R)
%cachePut  Keep a per-dataset result in ResultCache under KEY (cacheKey), within CacheMaxMB.
%   r.cachePut(KEY, R) stores R (replacing an entry of that key), adds its
%   size (whos) to CacheBytes and drops the oldest entries while the cache
%   holds more than CacheMaxMB megabytes; a result larger than the whole
%   limit is not kept. R.page (a one-page compute) is never cached.
%
%   See also EphysAnalysisRunner.cachedPlot, EphysAnalysisRunner.cacheKey.
arguments
    obj (1,1) EphysAnalysisRunner
    key (1,1) string
    R (1,1) struct
end
if isfield(R, 'page'); return; end
if isempty(obj.ResultCache); obj.clearResultCache(); end
w = whos('R');
bytes = w.bytes;
limit = obj.CacheMaxMB * 2^20;
c = char(key);
if isKey(obj.ResultCache, c)
    obj.CacheBytes = obj.CacheBytes - obj.ResultCache(c).bytes;
    remove(obj.ResultCache, c);
    obj.CacheOrder(obj.CacheOrder == key) = [];
end
if bytes > limit; return; end
while obj.CacheBytes + bytes > limit && ~isempty(obj.CacheOrder)
    old = char(obj.CacheOrder(1));
    obj.CacheBytes = obj.CacheBytes - obj.ResultCache(old).bytes;
    remove(obj.ResultCache, old);
    obj.CacheOrder(1) = [];
end
obj.ResultCache(c) = struct('R', R, 'bytes', bytes);
obj.CacheOrder(end+1) = key;
obj.CacheBytes = obj.CacheBytes + bytes;
end
