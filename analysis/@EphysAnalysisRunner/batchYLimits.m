function B = batchYLimits(obj, idx, spec, opts)
%batchYLimits  The y range a figure's "batch" panels share over every observation on the datasets IDX.
%   B = r.batchYLimits(IDX, SPEC, Observation=, Fraction=) measures the figure SPEC
%   (Config.figureFor) on each dataset of IDX (indices) that can draw it
%   (figureSkipReason ""): every observation (figureObservations, with
%   Observation= as runDataset takes it) is computed (computeFigure) and
%   drawn hidden (figureYExtents), and B = figureBatchYLim of them all: a
%   struct row (figure, id, lim, n) per panel of figureBatchPanels(SPEC),
%   lim the union of the observations' y extents and n how many gave one.
%   run() calls it for each figure with such a panel before the datasets,
%   so the range spans the whole run; runDataset alone calls it for its
%   own dataset. Each dataset's data cache is cleared after it is
%   measured. Progress (which cancel() can stop) says "<name>: <id> y
%   range (<i>/<n>)" at Fraction= (default 0: where the run's bar is).
%   Computed figures are kept for the drawing pass (BatchCache, keyed by
%   dataset, figure and observation) while their total stays under
%   BatchCacheMB (512 MB): runDataset draws a kept one instead of
%   computing it again, and drops it. A figure that fails to compute for
%   an observation is left out of the range (runDataset reports it).
%
%   See also figureYExtents, figureBatchYLim, figureBatchPanels,
%   EphysAnalysisRunner.run, EphysAnalysisRunner.runDataset.
arguments
    obj (1,1) EphysAnalysisRunner
    idx (1,:) double
    spec (1,1) struct
    opts.Observation = []
    opts.Fraction (1,1) double = 0
end
ids = figureBatchPanels(spec);
B = struct('figure', cell(1, 0), 'id', cell(1, 0), 'lim', cell(1, 0), 'n', cell(1, 0));
if isempty(ids); return; end
if isempty(obj.BatchCache) || ~isa(obj.BatchCache, 'containers.Map')
    obj.BatchCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
E = cell(1, 0);
for k = idx
    name = obj.Names(k);
    src = obj.source(k);
    try
        if figureSkipReason(src, spec) ~= ""; continue; end
        T = figureObservations(src, spec, Observation=opts.Observation);
        n = height(T);
        for i = 1:n
            obj.progress(opts.Fraction, sprintf("%s: %s y range (%d/%d)", name, spec.id, i, n));   % cancel() stops here
            try
                F = obj.computeFigure(src, spec, Observation=T(i, :));
            catch ME
                if ME.identifier == "EphysAnalysisRunner:Canceled"; rethrow(ME); end
                continue
            end
            E{end+1} = figureYExtents(F, spec); %#ok<AGROW>
            w = whos('F');   % kept for its page while the kept ones stay under BatchCacheMB
            mb = w.bytes / 2^20;
            if obj.BatchCacheUsedMB + mb <= obj.BatchCacheMB
                obj.BatchCache(sprintf('%d|%s|%d', k, spec.id, i)) = F;
                obj.BatchCacheUsedMB = obj.BatchCacheUsedMB + mb;
            end
        end
    catch ME
        src.outputs.clearCache();
        if ME.identifier == "EphysAnalysisRunner:Canceled"; rethrow(ME); end
        obj.log("%s: %s y range FAILED: %s", name, spec.id, ME.message);
        continue
    end
    src.outputs.clearCache();
end
Bf = figureBatchYLim(E);
for b = Bf
    B(end+1) = struct('figure', spec.id, 'id', b.id, 'lim', b.lim, 'n', b.n); %#ok<AGROW>
end
end

