function [file, where] = chronuxFileFor(obj, k)
%chronuxFileFor  Dataset K's Chronux file: its output folder's (where "output"), else the local cache's ("cache").
%   The output folder's is the one DatasetOutputs finds (the newest
%   <Name>*.mat holding export + sp, under its search roots); the cache's
%   is <ChronuxCacheFolder>/<dataset key>/<Name>_chronux.mat. FILE ""
%   when there is neither.
file = "";
where = "";
if isempty(obj.Runner) || k < 1 || k > numel(obj.Runner.Outputs); return; end
out = obj.Runner.Outputs(k);
if out.has("chronux")
    file = string(out.ChronuxFile);
    where = "output";
    return
end
c = chronuxCachePath(obj.ChronuxCacheFolder, obj.Runner.Keys(k), obj.Runner.Names(k));
if c ~= "" && isfile(c)
    file = c;
    where = "cache";
end
end
