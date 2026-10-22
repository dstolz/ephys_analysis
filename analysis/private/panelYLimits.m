function [mode, lim] = panelYLimits(look)
%panelYLimits  A figure panel's y-limit mode and the limits it draws at: options.yLimMode, its yLim, a run's batch range.
%   [MODE, LIM] = panelYLimits(LOOK) for a draw function's LOOK
%   (renderFigure's: panel, batchYLim) reads LOOK.panel.options.yLimMode
%   (EphysAnalysisConfig.YLimModes; a type without it: "auto"):
%     "auto"   LIM [] (each axis fits its data, each stacked row itself)
%     "rows"   LIM [] (a stack's rows share the reach of them all)
%     "fixed"  LIM options.yLim; without an ascending pair, "auto"
%     "batch"  LIM LOOK.batchYLim, the range renderFigure's BatchYLim gave
%              the panel (EphysAnalysisRunner.run: every observation of
%              the run, figureBatchYLim); without one (a panel drawn
%              alone: the app's preview), "rows", its own range
%   An unknown mode is "auto". LIM is [lo hi] or []. A line stack passes
%   MODE and LIM to stackLayout (Mode=, Limits=); an axis without rows sets
%   LIM as its y limits, or leaves them to the data (its type's own:
%   0 to 1 for an auROC or a coherence) when LIM is [].
%
%   See also stackLayout, renderFigure, figureBatchYLim.
o = look.panel.options;
mode = "auto";
lim = [];
if isfield(o, 'yLimMode'); mode = string(o.yLimMode); end
ok = @(v) isnumeric(v) && numel(v) == 2 && all(isfinite(v)) && v(2) > v(1);
switch mode
    case "fixed"
        if isfield(o, 'yLim') && ok(o.yLim)
            lim = reshape(double(o.yLim), 1, 2);
        else
            mode = "auto";
        end
    case "batch"
        b = [];
        if isfield(look, 'batchYLim'); b = look.batchYLim; end
        if ok(b)
            lim = reshape(double(b), 1, 2);
        else
            mode = "rows";
        end
    case "rows"
    otherwise
        mode = "auto";
end
end
