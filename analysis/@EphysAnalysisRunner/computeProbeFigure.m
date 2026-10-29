function PF = computeProbeFigure(obj, src, spec, opts)
%computeProbeFigure  Compute a probe figure on one dataset: the whole figure for every tile on the probe, no graphics.
%   PF = r.computeProbeFigure(SRC, SPEC) with SRC from source() and SPEC
%   from Config.figureFor(id) of a figure whose probe.enabled is true is
%   figureProbeCompute(SRC, SPEC, Check=CHK, ProgressFcn=), which says what
%   PF holds and how the tiles are picked (figureProbeTiles) and computed
%   (figureCompute per tile, the steps the tiles share computed once).
%   While PollFcn is set (the app's preview) CHK is the runner's
%   checkpoint, so the compute can be stopped between the tiles and inside
%   them: after cancel() the next checkpoint throws
%   EphysAnalysisRunner:Canceled. While it is empty (a run) there are no
%   checkpoints. ProgressFcn(i, n, label) (default [] = none) is called
%   before tile i of n.
%   With Reuse=true (the app's preview) what an earlier preview computed on
%   the same data is taken again, as computeFigure does (FigureCache, the
%   most recently used first, up to FigureCacheMB): every tile's steps are
%   kept, so a look-only edit, or an edit of the probe layout, computes
%   nothing. A run does not reuse across calls; its tiles still share the
%   figure's epochs.
%
%   See also figureProbeCompute, figureProbeTiles, EphysAnalysisRunner.computeFigure,
%   renderFigure.

arguments
    obj (1,1) EphysAnalysisRunner
    src (1,1) struct
    spec (1,1) struct
    opts.Reuse (1,1) logical = false
    opts.ProgressFcn = []
end

chk = [];   % the checkpoint the long steps call, while the app's preview polls (PollFcn)
if ~isempty(obj.PollFcn); chk = @() obj.checkpoint(); end
if ~opts.Reuse
    PF = figureProbeCompute(src, spec, Check=chk, ProgressFcn=opts.ProgressFcn);
    return
end
[PF, K] = figureProbeCompute(src, spec, Check=chk, Reuse=obj.FigureCache, ProgressFcn=opts.ProgressFcn);
obj.keepFigureCache(K);
end
