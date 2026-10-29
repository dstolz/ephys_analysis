function T = plan(obj, opts)
%plan  Which figure runs on which dataset, and why one is skipped.
%   T = r.plan() has one row per dataset and figure (Config.Figures):
%   Dataset, Plot (the figure's id), Kind ("figure"), Source what it is
%   drawn for (the observe kind: "unit", "channel" or "dataset"; "probe"
%   for a probe figure, one page of tiles per dataset), Enabled
%   (it will run) and Reason (why not: from figureSkipReason -- no units,
%   detections or extract to observe, a missing line or parameter -- or a
%   dataset that cannot be read). Reading each dataset's source is cheap
%   (no signals or spikes), and nothing else is loaded: a unit filter or
%   channel list that leaves no observation shows only when the figure
%   runs ("skipped: no observation").
%   Then one row per session figure (a figure whose sessions.enabled is
%   true: never listed per dataset) and facet ("all", or one per subject
%   with facet "subject"): Dataset "sessions: <facet>", Plot its id, Kind
%   "figure", Source its observe kind, Reason from figureSessionSkipReason
%   ("disabled", an unsupported panel or auROC baseline, "no mapping
%   file", "fewer than N session(s) can draw it (...)" with each session's
%   figureSkipReason).
%
%   Options: Datasets (indices, keys or names; default all), Figures (ids;
%   [] = default: every figure drawn per dataset, enabled or not;
%   string.empty(1, 0) = none), SessionFigures (ids; default every session
%   figure; string.empty = none).
%
%   See also figureSkipReason, figureSessionSkipReason, EphysAnalysisRunner.run.

arguments
    obj (1,1) EphysAnalysisRunner
    opts.Datasets = []
    opts.Figures = []
    opts.SessionFigures = []
end

cfg = obj.Config;
idx = datasetIndices(obj, opts.Datasets);
fids = EphysAnalysisRunner.idList(opts.Figures, @() cfg.figureIds());
fids = fids(~arrayfun(@(f) cfg.isSessionFigure(f), fids));   % drawn across the datasets: rows of their own below
sfids = EphysAnalysisRunner.idList(opts.SessionFigures, @() cfg.sessionFigureIds());
n = numel(idx) * numel(fids);
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
    for id = fids
        r = r + 1;
        spec = cfg.figureFor(id);
        Dataset(r, 1) = obj.Names(i); Plot(r, 1) = id; Kind(r, 1) = "figure"; Source(r, 1) = spec.observe.kind;
        if spec.probe.enabled; Source(r, 1) = "probe"; end   % every unit or channel a tile, one page
        if err ~= ""
            Reason(r, 1) = err;
        else
            Reason(r, 1) = figureReason(src, spec);
        end
        Enabled(r, 1) = Reason(r) == "";
    end
end
for id = sfids
    if cfg.figureIndex(id) == 0; continue; end
    spec = cfg.figureFor(id);
    S = obj.sessionTable(obj.sessionFigureIndices(spec, idx));
    reasons = strings(1, height(S));
    for j = 1:height(S)
        [src, err] = sourceOf(S.index(j));
        if err ~= ""
            reasons(j) = err;
        else
            reasons(j) = figureSkipReason(src, spec);
        end
    end
    facets = "all";
    rowsOf = {1:height(S)};
    if spec.sessions.facet == "subject" && height(S) > 0
        subj = S.subject;
        subj(subj == "") = "(no subject)";
        facets = unique(subj, 'stable').';
        rowsOf = arrayfun(@(f) find(subj == f).', facets, 'UniformOutput', false);
    end
    for f = 1:numel(facets)
        rr = rowsOf{f};
        r = r + 1;
        Dataset(r, 1) = "sessions: " + facets(f); Plot(r, 1) = id; Kind(r, 1) = "figure"; Source(r, 1) = spec.observe.kind;
        Reason(r, 1) = figureSessionSkipReason(spec, reasons(rr), Labels=reshape(S.label(rr), 1, []));
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
