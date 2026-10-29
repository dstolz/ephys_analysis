function W = figureFixedWindow(w)
%figureFixedWindow  [pre post] of a fixed epoch window W, [] for any other (between events, or none).
%
%   See also renderFigure, renderProbeFigure.
W = [];
if isstruct(w) && all(isfield(w, {'pre' 'post'})) && (~isfield(w, 'mode') || w.mode == "fixed")
    W = double([w.pre w.post]);
    if ~(numel(W) == 2 && all(isfinite(W)) && W(2) > W(1)); W = []; end
end
end
