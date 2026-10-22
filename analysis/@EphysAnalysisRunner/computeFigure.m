function F = computeFigure(obj, src, spec, opts)
%computeFigure  Compute one figure for one observation of one dataset: every panel's layers, no graphics.
%   F = r.computeFigure(SRC, SPEC, Observation=OBS) with SRC from source(),
%   SPEC from Config.figureFor(id) and OBS one row of
%   figureObservations(SRC, SPEC) (default: the first row) is
%   figureCompute(SRC, SPEC, Observation=OBS, Check=CHK), which says what F
%   holds and how each panel is computed. While PollFcn is set (the app's
%   preview) CHK is the runner's checkpoint, so the compute can be stopped:
%   after cancel() the next checkpoint throws
%   EphysAnalysisRunner:Canceled. While it is empty (a run) there are no
%   checkpoints.
%   With Reuse=true (the app's preview) what an earlier preview computed
%   on the same data is taken again (figureCompute's Reuse: the skip
%   reasons, the epochs, each panel's layers, by their inputs): an edit of
%   a figure's looks computes nothing, an edit of one panel computes that
%   panel. The runner keeps them in FigureCache, the most recently used
%   first, up to FigureCacheMB; clearSources (and datasets) forgets them.
%   A run does not reuse: each observation's data is its own.
%
%   See also figureCompute, figureObservations,
%   figureSkipReason, renderFigure.

arguments
    obj (1,1) EphysAnalysisRunner
    src (1,1) struct
    spec (1,1) struct
    opts.Observation = []
    opts.Reuse (1,1) logical = false
end

chk = [];   % the checkpoint the long steps call, while the app's preview polls (PollFcn)
if ~isempty(obj.PollFcn); chk = @() obj.checkpoint(); end
if ~opts.Reuse
    F = figureCompute(src, spec, Observation=opts.Observation, Check=chk);
    return
end
[F, K] = figureCompute(src, spec, Observation=opts.Observation, Check=chk, Reuse=obj.FigureCache);
obj.keepFigureCache(K);
end
