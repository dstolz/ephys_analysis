function R = figureKindRules(D, kind)
%figureKindRules  A design's own rules for one kind of plot (its common rules apart).
%
%   See also renderFigure, renderProbeFigure.
R = PlotAesthetics.emptyRules();
kind = string(kind);
if isvarname(kind) && isfield(D, 'kinds') && isstruct(D.kinds) && isfield(D.kinds, kind) && ~isempty(D.kinds.(kind))
    R = PlotAesthetics.normalizeRules(D.kinds.(kind));
end
end
