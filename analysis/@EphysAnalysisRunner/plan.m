function T = plan(obj, opts)
%plan  Which plot runs on which dataset, and why one is skipped.
%   T = r.plan() has one row per dataset and plot: Dataset, Plot, Kind,
%   Source, Enabled (it will run) and Reason (why not: "disabled", "no
%   sorted units", "no LFP extract", "no paired trials", "no line X", "no
%   trial parameter X", "no probe map", or a dataset that cannot be read).
%   Reading each dataset's source is cheap (no signals or spikes).
%   Then one row per dataset and figure (Config.Figures): Kind "figure",
%   Source what it is drawn for (the observe kind: "unit", "channel" or
%   "dataset"), Reason from figureSkipReason (no units, detections or
%   extract to observe, a missing line or parameter). Nothing is loaded
%   for it: a unit filter or channel list that leaves no observation shows
%   only when the figure runs ("skipped: no observation").
%   Then one row per session plot and facet (its figures: "all", or one
%   per subject with facet "subject"): Dataset "sessions: <facet>", Plot the
%   session plot's id, Kind and Source its base plot's, and Reason from
%   sessionPlotSkipReason ("disabled", "no base plot X", an unsupported
%   kind, "no mapping file", "fewer than N session(s) can draw it (...)"
%   with each session's own reason).
%
%   Options: Datasets (indices, keys or names; default all), Plots and
%   Figures (ids; [] = default: every plot / figure, enabled or not;
%   string.empty(1, 0) = none), SessionPlots (ids; default every session
%   plot; string.empty = none).
%
%   See also plotSkipReason, sessionPlotSkipReason, EphysAnalysisRunner.run.

arguments
    obj (1,1) EphysAnalysisRunner
    opts.Datasets = []
    opts.Plots = []
    opts.Figures = []
    opts.SessionPlots = []
end

cfg = obj.Config;
idx = datasetIndices(obj, opts.Datasets);
ids = EphysAnalysisRunner.idList(opts.Plots, @() cfg.plotIds());
fids = EphysAnalysisRunner.idList(opts.Figures, @() cfg.figureIds());
sids = opts.SessionPlots;
if isnumeric(sids) && isempty(sids)
    sids = cfg.sessionPlotIds();
else
    sids = reshape(string(sids), 1, []);
end
n = numel(idx) * (numel(ids) + numel(fids));
Dataset = strings(n, 1); Plot = strings(n, 1); Kind = strings(n, 1); Source = strings(n, 1);
Enabled = false(n, 1); Reason = strings(n, 1);
r = 0;
srcs = cell(1, numel(obj.Outputs));
errs = strings(1, numel(obj.Outputs));
    function [src, err] = sourceOf(i)
        if isempty(srcs{i}) && errs(i) == ""
            try
                srcs{i} = obj.source(i);
            catch ME
                errs(i) = "cannot read the dataset: " + string(ME.message);
            end
        end
        src = srcs{i};
        err = errs(i);
    end
for i = idx
    [src, err] = sourceOf(i);
    for id = ids
        r = r + 1;
        spec = cfg.plotFor(id);
        Dataset(r) = obj.Names(i); Plot(r) = id; Kind(r) = spec.kind; Source(r) = spec.source;
        if err ~= ""
            Reason(r) = err;
        else
            Reason(r) = plotSkipReason(src, spec);
        end
        Enabled(r) = Reason(r) == "";
    end
    for id = fids
        r = r + 1;
        spec = cfg.figureFor(id);
        Dataset(r, 1) = obj.Names(i); Plot(r, 1) = id; Kind(r, 1) = "figure"; Source(r, 1) = spec.observe.kind;
        if err ~= ""
            Reason(r, 1) = err;
        else
            Reason(r, 1) = figureReason(src, spec);
        end
        Enabled(r, 1) = Reason(r) == "";
    end
end
for id = sids
    k = cfg.sessionPlotIndex(id);
    if k == 0; continue; end
    sp = cfg.SessionPlots(k);
    spec = [];
    kind = ""; source = "";
    if cfg.plotIndex(sp.plot) > 0
        spec = cfg.sessionPlotFor(id);
        kind = spec.kind; source = spec.source;
    end
    ks = idx;
    if sp.datasets == "list"
        ks = arrayfun(@(key) obj.index(key), reshape(sp.datasetKeys, 1, []));
        ks = ks(ks > 0);
    end
    S = obj.sessionTable(ks);
    reasons = strings(1, height(S));
    for j = 1:height(S)
        [src, err] = sourceOf(S.index(j));
        if err ~= ""
            reasons(j) = err;
        elseif ~isempty(spec)
            reasons(j) = plotSkipReason(src, spec);
        end
    end
    facets = "all";
    rowsOf = {1:height(S)};
    if sp.facet == "subject" && height(S) > 0
        subj = S.subject;
        subj(subj == "") = "(no subject)";
        facets = unique(subj, 'stable').';
        rowsOf = arrayfun(@(f) find(subj == f).', facets, 'UniformOutput', false);
    end
    for f = 1:numel(facets)
        rr = rowsOf{f};
        r = r + 1;
        Dataset(r, 1) = "sessions: " + facets(f); Plot(r, 1) = id; Kind(r, 1) = kind; Source(r, 1) = source;
        Reason(r, 1) = sessionPlotSkipReason(cfg, sp, reasons(rr), Labels=S.label(rr).');
        Enabled(r, 1) = Reason(r) == "";
    end
end
T = table(Dataset, Plot, Kind, Source, Enabled, Reason);
end


function reason = figureReason(src, spec)
%figureReason  Why a figure cannot run on a dataset, from cheap facts only ("" = it can).
%   figureSkipReason's reason (what the dataset lacks: the observed sorted
%   units, detections or extract, the alignment's lines and parameters).
%   Nothing is loaded: whether the unit filter or the channel list leaves
%   an observation needs the units' or the extract's data, so the run
%   decides it ("no observation", runDataset).
reason = figureSkipReason(src, spec);
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
