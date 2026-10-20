function tf = inTimeColumn(look)
%inTimeColumn  True when another time panel (raster, PSTH, continuous, heat map) shares a column with this one.
%   TF = inTimeColumn(LOOK) for the panel LOOK.panel of the figure spec
%   LOOK.spec (renderFigure's look): another panel whose type shares the
%   time axis (panelTypes: SharesTime) covers one of its columns. A panel
%   drawing a color bar then keeps it inside its axes (Location "east"),
%   so its time axis lines up with theirs (drawHeatmapPanel,
%   drawPsthPanel).
%
%   See also drawHeatmapPanel, drawPsthPanel, renderFigure.
PT = EphysAnalysisConfig.panelTypes();
p = look.panel;
tf = false;
for q = reshape(look.spec.panels, 1, [])
    row = PT.Type == q.type;
    if q.id == p.id || ~any(row) || ~PT.SharesTime(row); continue; end
    if q.col <= p.col + p.colSpan - 1 && p.col <= q.col + q.colSpan - 1
        tf = true;
        return
    end
end
end
