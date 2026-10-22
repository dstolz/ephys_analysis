function E = figureYExtents(F, spec)
%figureYExtents  One computed figure's y extents on its panels with a run's shared range (yLimMode "batch").
%   E = figureYExtents(F, SPEC) draws F (EphysAnalysisRunner.computeFigure,
%   figureCompute or a figure merged across sessions, figureSessionCompute)
%   with SPEC into a hidden figure, as renderFigure draws it (no user
%   aesthetics, no editing or data tips: the extents do not depend on
%   looks), each "batch" panel on its own range, and reads each one's y
%   extent (renderFigure's H.panels(k).yExtent: a stack's reach in its
%   values' units, else the axes' y limits MATLAB picked for the data, or
%   the type's own, 0 to 1 for an auROC or a coherence). E is a struct row
%   (id, lim): one per panel of figureBatchPanels(SPEC), lim [lo hi] or
%   [NaN NaN] where the panel drew nothing. A spec without such panels
%   draws nothing and gives an empty E.
%   The hidden figure is the export page's size (Export.FigureSizeCm is not
%   known here: 700 x 800 px), so the axes' automatic limits are the ones
%   a page picks.
%
%   See also figureBatchYLim, figureBatchPanels, EphysAnalysisRunner.run.
ids = figureBatchPanels(spec);
E = struct('id', cell(1, 0), 'lim', cell(1, 0));
if isempty(ids); return; end
fig = figure('Visible', 'off', 'Position', [100 100 700 800], 'HandleVisibility', 'off');
closer = onCleanup(@() delete(fig));
h = renderFigure(F, spec, fig, UserAesthetics=false, Editable=false, DataTips=false);
for id = ids
    k = find([h.panels.id] == id, 1);
    lim = [NaN NaN];
    if ~isempty(k) && isfield(h.panels(k), 'yExtent'); lim = h.panels(k).yExtent; end
    E(end+1) = struct('id', id, 'lim', double(reshape(lim, 1, 2))); %#ok<AGROW>
end
clear closer
end
