function hk = drawWaveformsPanel(ax, P, look)
%drawWaveformsPanel  Draw a figure's unit waveforms panel: the observed unit's waveform, or several units' means overlaid.
%   HK = drawWaveformsPanel(AX, P, LOOK) draws the panel result P
%   (F.panels(k) of EphysAnalysisRunner.computeFigure) into the axes AX,
%   as renderFigure asks (LOOK: style, colors, W, spec, panel, panelId,
%   isTop, isBottom, epochs, groups, observation, isTime). Its first
%   computed layer (R.kind "waveforms": meta, labels, waveforms from
%   unitWaveforms) holds
%     one unit     drawn by renderWaveforms into AX (grid layout, the
%                  panel's options.waveform: mean, spikes or both, the
%                  label; Style.YLim: options.yLimMode's limits,
%                  panelYLimits: "fixed" options.yLim, "batch" the run's
%                  range)
%     several      (a fixed layer of several units) every unit's mean
%                  overlaid in a color of its own (role "waveMean", group =
%                  the unit's label), the spike time marked, each unit in
%                  the legend; the waveform's time span (timeMs) and, with
%                  ampScale "fixed", its ampLim as the y limits (the
%                  panel's own y limits, yLimMode not "auto", win)
%   In the probe layout (options.layout "probe") renderWaveforms draws every
%   unit of the first layer at its place on the probe (Layout "probe": the
%   sites behind, the panel's waveform settings), and the units the
%   further layers of the same source name (R.kind "ring", e.g. the
%   observed unit; matched by unit id) are framed in red there (Highlight:
%   role "unitDots", group "observed"); a ring layer of the other spike
%   source frames nothing (a detected layer's id is its channel).
%   A result merged across sessions (figureSessionCompute: its units the
%   session-units, meta.session) draws each unit's mean in its session's
%   series color (role "trace", group the series), the series once each
%   in the legend; one unit alone is drawn by renderWaveforms, which colors
%   it by its session too.
%   A skipped layer's reason is noted (figLayerNotes). HK: figDrawResult's
%   (renderWaveforms labels the axes; the overlay's y label is the
%   amplitude).
%
%   See also renderFigure, renderWaveforms, unitWaveforms, figurePanelRegistry.

style = look.style;
o = look.panel.options;
hk = figDrawResult(ax);
j = find(arrayfun(@(l) l.skip == "" && isstruct(l.R) && isfield(l.R, 'kind') && l.R.kind == "waveforms", P.layers), 1);
if isempty(j)
    tagPart(ax, "axes", "", look.panelId);
    figLayerNotes(ax, P, look, false);
    return
end
R = P.layers(j).R;
W = R.waveforms;
nU = height(R.meta);
st = style;
st.XLim = [];
[~, st.YLim] = panelYLimits(look);
if isfield(o, 'layout') && o.layout == "probe"   % its y axis is the probe's (um): options.yLim is the grid's
    st.YLim = [];
    h = renderWaveforms(R, ax, Layout="probe", Waveform=o.waveform, Style=st, Highlight=ringRows(R, P.layers, P.layers(j).source));
    hk.axes = h.axes(1);
    tagPart(hk.axes, "axes", "", look.panelId);
    figLayerNotes(hk.axes, P, look, true);
    return
end
if nU == 1
    h = renderWaveforms(R, ax, Layout="grid", Waveform=o.waveform, Style=st);
    hk.axes = h.axes(1);
    tagPart(hk.axes, "axes", "", look.panelId);
    figLayerNotes(hk.axes, P, look, true);
    return
end

tagPart(ax, "axes", "", look.panelId);
names = shortUnitLabels(R.labels);
order = probeOrder(R.meta, nU, style);
G = table((1:nU).', names(:), lines(nU), ones(nU, 1), 'VariableNames', {'index', 'label', 'color', 'n'});
C = groupPalette(G, style);
[ser, serLabel] = sessionSeriesOf(R, nU);   % merged across sessions: each unit in its session's (series') color
if ~isempty(ser)
    SC = groupPalette(R.groups, style);
    C = SC(ser, :);
end
hold(ax, 'on');
drew = false;
wave = EphysAnalysisConfig.normalizeSection("Waveform", o.waveform);
for u = reshape(order, 1, [])
    if u > numel(W.mean) || isempty(W.mean{u}); continue; end
    [t, m] = waveformSpan(W.timeMs{u}(:), W.mean{u}(:), [], wave.timeMs);
    if isempty(ser)
        hk.legendHandles(end+1) = tagPart(line(ax, t, m, 'Color', C(u, :), ...
            'LineWidth', max(1, style.LineWidth)), "waveMean", names(u));
        hk.legendLabels(end+1) = names(u);
        hk.legendGroup(end+1) = false;
    else   % a "trace" in its series' color, the series listed once (as the plot's session looks)
        h1 = tagPart(line(ax, t, m, 'Color', C(u, :), 'LineWidth', max(1, style.LineWidth)), ...
            "trace", serLabel(ser(u)));
        if ~any(hk.legendLabels == serLabel(ser(u)))
            hk.legendHandles(end+1) = h1;
            hk.legendLabels(end+1) = serLabel(ser(u));
            hk.legendGroup(end+1) = true;
        end
    end
    drew = true;
end
if drew
    tagPart(xline(ax, 0, ':', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off'), "waveZero");
end
hold(ax, 'off');
if ~drew
    figLayerNotes(ax, P, look, false, "No waveform for these units");
    return
end
axis(ax, 'tight');
if wave.ampScale == "fixed" && numel(wave.ampLim) == 2 && wave.ampLim(2) > wave.ampLim(1)
    ylim(ax, wave.ampLim);
end
styleAxes(ax, st);
xlabel(ax, 'Time (ms)');
u = unique(W.units(W.units ~= ""));
hk.yName = "Amplitude";
if isscalar(u); hk.yName = "Amplitude (" + ampText(u) + ")"; end
figLayerNotes(ax, P, look, true);
end


function [ser, label] = sessionSeriesOf(R, nU)
%sessionSeriesOf  A result merged across sessions (R.sessions, meta.session): each unit's series and the series' labels; [] otherwise.
ser = zeros(0, 1);
label = strings(0, 1);
if ~isfield(R, 'sessions') || ~istable(R.sessions) || ~isfield(R, 'groups') || ~istable(R.groups) ...
        || ~ismember("session", string(R.meta.Properties.VariableNames))
    return
end
s = double(R.meta.session(:));
if ismember("series", string(R.sessions.Properties.VariableNames))
    sr = double(R.sessions.series(:));
    ok = s >= 1 & s <= numel(sr);
    s(ok) = sr(s(ok));
end
s(~(s >= 1 & s <= height(R.groups))) = 1;
if numel(s) ~= nU; return; end
ser = s;
label = reshape(string(R.groups.label), [], 1);
end


function rows = ringRows(R, layers, source)
%ringRows  The rows of R.meta the probe layout's further layers name (R.kind "ring": by unit id and source).
%   Only ring layers of SOURCE, the drawn layer's: a detected layer's unit
%   id is its channel, which says nothing about a sorted unit's id.
rows = zeros(1, 0);
ids = double(R.meta.unitId(:));
for l = reshape(layers, 1, [])
    if l.skip ~= "" || ~isstruct(l.R) || ~isfield(l.R, 'kind') || l.R.kind ~= "ring"; continue; end
    if isfield(l.R, 'source') && string(l.R.source) ~= string(source); continue; end
    rows = [rows reshape(find(ismember(ids, double(l.R.meta.unitId(:)))), 1, [])]; %#ok<AGROW>
end
rows = unique(rows);
end


function s = ampText(units)
%ampText  The amplitude unit of a waveform (unitWaveforms' units).
switch units
    case "uV";       s = char(181) + "V";
    case "bin";      s = ".bin units";
    case "whitened"; s = "whitened";
    otherwise;       s = "a.u.";
end
end
