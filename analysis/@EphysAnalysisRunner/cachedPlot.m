function R = cachedPlot(obj, k, spec, opts)
%cachedPlot  One plot's result on one dataset, from ResultCache when it is there.
%   R = r.cachedPlot(K, SPEC) (K a dataset index, key or name; SPEC from
%   plotFor or sessionPlotFor) is the cached result under
%   cacheKey(Keys(K), SPEC), or else computePlot(source(K), SPEC), kept in
%   the cache (cachePut) and followed by the dataset's bulk data being
%   cleared (src.outputs.clearCache()), so a run over many datasets holds
%   one dataset's signals and spikes at a time. Keep=true leaves the
%   dataset's data in memory (the app keeps its active dataset's, so the
%   Plots tab's preview stays fast).
%
%   See also EphysAnalysisRunner.cacheKey, EphysAnalysisRunner.computeSessionPlot.
arguments
    obj (1,1) EphysAnalysisRunner
    k
    spec (1,1) struct
    opts.Keep (1,1) logical = false
end
i = obj.index(k);
if i == 0
    error('EphysAnalysisRunner:NoDataset', 'No dataset "%s".', string(k));
end
key = EphysAnalysisRunner.cacheKey(obj.Keys(i), spec);
if ~isempty(obj.ResultCache) && isKey(obj.ResultCache, char(key))
    R = obj.ResultCache(char(key)).R;
    return
end
src = obj.source(i);
try
    R = obj.computePlot(src, spec);
catch ME
    if ~opts.Keep; src.outputs.clearCache(); end
    rethrow(ME);
end
obj.cachePut(key, R);
if ~opts.Keep; src.outputs.clearCache(); end
end
