function tf = inTimeColumn(look)
%inTimeColumn  True when another time panel (raster, PSTH, continuous, heat map, ...) shares a column of the page with this one.
%   TF = inTimeColumn(LOOK) for the panel LOOK.panel of the figure spec
%   LOOK.spec (renderFigure's look): another panel whose type shares the
%   time axis (panelTypes: SharesTime) lies in its column, apart or not
%   (figureNeighbors' inColumn: their rects share at least half the
%   narrower one's width). A panel drawing a color bar then keeps it inside
%   its axes (Location "east"), so its time axis lines up with theirs
%   (drawHeatmapPanel, drawPsthPanel, drawSpectrogramPanel).
%
%   See also drawHeatmapPanel, drawPsthPanel, drawSpectrogramPanel, renderFigure.
PT = EphysAnalysisConfig.panelTypes();
P = look.spec.panels;
tf = false;
if numel(P) < 2; return; end
p = find([P.id] == look.panel.id, 1);
if isempty(p); return; end
N = figureNeighbors(reshape([P.rect], 4, []).', EphysAnalysisConfig.RectTol);
for q = find(N.inColumn(p, :))
    row = PT.Type == P(q).type;
    if any(row) && PT.SharesTime(row)
        tf = true;
        return
    end
end
end
