function hk = drawProbeMapPanel(ax, P, look)
%drawProbeMapPanel  Draw a figure's probe map panel: the units' values on the probe, the observation ringed.
%   HK = drawProbeMapPanel(AX, P, LOOK) draws the panel result P
%   (F.panels(k) of EphysAnalysisRunner.computeFigure) into the axes AX,
%   as renderFigure asks (LOOK: style, colors, W, spec, panel, panelId,
%   isTop, isBottom, epochs, groups, observation, isTime). Its first
%   computed layer (a probeMapValues result) is drawn by renderProbeMap
%   into AX (Style.CLim = options.cLim): the units at their positions
%   colored by their rate or spike count (units per site: the sites
%   colored, the units as ink dots), the color bar; with a waveform mode
%   other than "off" each unit as its waveform (R.waveforms, the panel's
%   options.waveform; colored by its value with options.waveColor), and with options.unitLabels each unit's name beside
%   it, an arrow to it. The observation is ringed
%   in red (role "unitDots", group "observed"): a unit at its own position
%   (R.unitX / unitY of its row of R.table; a box round its glyph when
%   the units are waveforms), else (a channel, or a unit without a
%   position) the site of its recording channel. A skipped
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
W = [];
if isfield(R, 'waveforms'); W = R.waveforms; end
h = renderProbeMap(R, [], ax, Style=st, UnitLabels=o.unitLabels, Waveforms=W, Waveform=o.waveform, ColorWaveforms=o.waveColor);
ax = h.axes(1);
hk.axes = ax;
tagPart(ax, "axes", "", look.panelId);
[x, y] = observedAt(R, look.observation);
if isfinite(x) && isfinite(y)
    hold(ax, 'on');
    if h.glyph(1) > 0   % the unit's glyph framed, as a unit waveforms panel frames it
        g = 0.6 * h.glyph;
        tagPart(line(ax, x + g(1) * [-1 1 1 -1 -1], y + g(2) * [-1 -1 1 1 -1], 'Color', [0.85 0.1 0.1], 'LineWidth', 1.5, ...
            'HandleVisibility', 'off'), "unitDots", "observed");
    else
        tagPart(plot(ax, x, y, 'o', 'MarkerSize', max(10, 1.7 * style.SiteSize), 'LineWidth', 2, 'Color', [0.85 0.1 0.1], ...
            'HandleVisibility', 'off'), "unitDots", "observed");
    end
    hold(ax, 'off');
end
figLayerNotes(ax, P, look, true);
end


function [x, y] = observedAt(R, obs)
%observedAt  Where the observation is on the map: the unit's own position, else its channel's site (NaN: nowhere).
x = NaN; y = NaN;
if ~isstruct(obs) || ~isfield(obs, 'kind') || ~ismember(obs.kind, ["unit" "channel"]); return; end
if obs.kind == "unit" && isfield(R, 'table') && istable(R.table) && ismember("unitId", string(R.table.Properties.VariableNames)) ...
        && ~isempty(R.unitX)
    row = find(R.table.unitId == obs.unitId, 1);
    if ~isempty(row) && isfinite(R.unitX(row)) && isfinite(R.unitY(row))
        x = R.unitX(row);
        y = R.unitY(row);
        return
    end
end
if ~isfinite(obs.channel); return; end
k = find(R.channel(:) == obs.channel, 1);   % the site of the observed recording channel
if isempty(k); return; end
x = R.x(k);
y = R.y(k);
end
