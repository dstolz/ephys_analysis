function T = plan(obj, opts)
%plan  Which plot runs on which dataset, and why one is skipped.
%   T = r.plan() has one row per dataset and plot: Dataset, Plot, Kind,
%   Source, Enabled (it will run) and Reason (why not: "disabled", "no
%   sorted units", "no LFP extract", "no paired trials", "no line X", "no
%   trial parameter X", "no probe map", or a dataset that cannot be read).
%   Reading each dataset's source is cheap (no signals or spikes).
%
%   Options: Datasets (indices, keys or names; default all), Plots (ids;
%   default every plot).
%
%   See also plotSkipReason, EphysAnalysisRunner.run.

arguments
    obj (1,1) EphysAnalysisRunner
    opts.Datasets = []
    opts.Plots (1,:) string = string.empty(1, 0)
end

idx = datasetIndices(obj, opts.Datasets);
ids = opts.Plots;
if isempty(ids); ids = obj.Config.plotIds(); end
n = numel(idx) * numel(ids);
Dataset = strings(n, 1); Plot = strings(n, 1); Kind = strings(n, 1); Source = strings(n, 1);
Enabled = false(n, 1); Reason = strings(n, 1);
r = 0;
for i = idx
    src = []; err = "";
    try
        src = obj.source(i);
    catch ME
        err = "cannot read the dataset: " + string(ME.message);
    end
    for id = ids
        r = r + 1;
        spec = obj.Config.plotFor(id);
        Dataset(r) = obj.Names(i); Plot(r) = id; Kind(r) = spec.kind; Source(r) = spec.source;
        if err ~= ""
            Reason(r) = err;
        else
            Reason(r) = plotSkipReason(src, spec);
        end
        Enabled(r) = Reason(r) == "";
    end
end
T = table(Dataset, Plot, Kind, Source, Enabled, Reason);
end


function idx = datasetIndices(obj, sel)
if isempty(sel)
    idx = 1:numel(obj.Outputs);
elseif isnumeric(sel)
    idx = reshape(sel, 1, []);
else
    idx = arrayfun(@(k) obj.index(k), reshape(string(sel), 1, []));
    idx = idx(idx > 0);
end
end
