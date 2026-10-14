function hk = drawProbeMapPanel(ax, P, look)
%drawProbeMapPanel  Draw a figure's probe map panel: a per-channel value on the probe sites, the observation ringed.
%   HK = drawProbeMapPanel(AX, P, LOOK) draws the panel result P
%   (F.panels(k) of EphysAnalysisRunner.computeFigure) into the axes AX,
%   as renderFigure asks (LOOK: style, colors, W, spec, panel, panelId,
%   isTop, isBottom, epochs, groups, observation, isTime). Its first
%   computed layer (a probeMapValues result) is drawn by renderProbeMap
%   into AX (Style.CLim = options.cLim): the sites colored by the value,
%   the units' positions as dots, the color bar. The observation is ringed
%   in red (role "unitDots", group "observed"): a unit at its own position
%   (R.unitX / unitY of its row of R.table), else (a channel, or a unit
%   without a position) the site of its recording channel. A skipped
%   layer's reason is noted (figLayerNotes). HK: figDrawResult's
%   (renderProbeMap labels the axes).
%
%   See also renderFigure, renderProbeMap, probeMapValues, figurePanelRegistry.

style = look.style;
o = look.panel.options;
hk = figDrawResult(ax);
j = find(arrayfun(@(l) l.skip == "" && isstruct(l.R) && isfield(l.R, 'kind') && l.R.kind == "probemap", P.layers), 1);
if isempty(j)
    tagPart(ax, "axes", "", look.panelId);
    figLayerNotes(ax, P, look, false);
    return
end
R = P.layers(j).R;
st = style;
st.XLim = [];
st.YLim = [];
st.CLim = [];
if numel(o.cLim) == 2 && o.cLim(2) > o.cLim(1); st.CLim = o.cLim; end
h = renderProbeMap(R, [], ax, Style=st);
ax = h.axes(1);
hk.axes = ax;
tagPart(ax, "axes", "", look.panelId);
[x, y] = observedAt(ax, R, look.observation);
if isfinite(x) && isfinite(y)
    hold(ax, 'on');
    tagPart(plot(ax, x, y, 'o', 'MarkerSize', max(10, 1.6 * style.SiteSize), 'LineWidth', 1.5, 'Color', [0.85 0.1 0.1], ...
        'HandleVisibility', 'off'), "unitDots", "observed");
    hold(ax, 'off');
end
figLayerNotes(ax, P, look, true);
end


function [x, y] = observedAt(ax, R, obs)
%observedAt  Where the observation is drawn on the map: the unit's dot, else its channel's site (NaN: nowhere).
x = NaN; y = NaN;
if ~isstruct(obs) || ~isfield(obs, 'kind') || ~ismember(obs.kind, ["unit" "channel"]); return; end
if obs.kind == "unit" && isfield(R, 'table') && istable(R.table) && ismember("unitId", string(R.table.Properties.VariableNames)) ...
        && ~isempty(R.unitX)
    row = find(R.table.unitId == obs.unitId, 1);
    dots = findobj(ax, 'Tag', 'unitDots');
    if ~isempty(row) && isscalar(dots)
        placed = isfinite(R.unitX(:)) & isfinite(R.unitY(:));
        if placed(row)
            k = nnz(placed(1:row));
            if k <= numel(dots.XData)
                x = dots.XData(k);
                y = dots.YData(k);
                return
            end
        end
    end
end
if ~isfinite(obs.channel); return; end
% the site of the observed recording channel, where renderProbeMap drew it (its shanks may be shifted sideways)
fin = isfinite(R.value(:));
X = NaN(numel(fin), 1);
s = findobj(ax, 'Tag', 'sites');
e = findobj(ax, 'Tag', 'emptySites');
if isscalar(s) && numel(s.XData) == nnz(fin); X(fin) = s.XData(:); end
if isscalar(e) && numel(e.XData) == nnz(~fin); X(~fin) = e.XData(:); end
k = find(R.channel(:) == obs.channel, 1);
if isempty(k); return; end
x = X(k);
y = R.y(k);
end
