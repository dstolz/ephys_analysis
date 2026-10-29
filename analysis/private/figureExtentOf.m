function e = figureExtentOf(hk, ax, p)
%figureExtentOf  A panel's y extent as drawn (yLimMode panels only): the draw function's yExtent, else its axes' y limits.
%
%   See also renderFigure, renderProbeFigure.
e = [NaN NaN];
if ~isfield(p.options, 'yLimMode'); return; end
if isfield(hk, 'yExtent') && numel(hk.yExtent) == 2 && all(isfinite(hk.yExtent))
    e = double(reshape(hk.yExtent, 1, 2));
elseif isgraphics(ax) && isscalar(ax.YAxis)
    e = double(ylim(ax));
end
end
