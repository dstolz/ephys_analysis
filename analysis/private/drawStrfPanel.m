function hk = drawStrfPanel(ax, P, look)
%drawStrfPanel  Draw a figure's STRF panel: a spectrotemporal receptive field, its ripple transfer function or a DMR's CRH.
%   HK = drawStrfPanel(AX, P, LOOK) draws the panel result P (F.panels(k)
%   of EphysAnalysisRunner.computeFigure) into the axes AX, as renderFigure
%   asks (LOOK: style, colors, W, spec, panel, panelId, epochs, groups,
%   observation, isTime). Its layer's rippleStrf result (computeStrfPanel)
%   is drawn for the set options.group (a trial group or bank item,
%   clipped to the sets there are), by options.view:
%     "strf"  the STRF over lag (x, ms) and octaves above the lowest
%             carrier (y), role "image", on the diverging colormap centered
%             on 0: a DMR's or ripple noise's rate-normalized STRF
%             (spikes/s), a TORC's STRF (spikes/s per dB); showSig draws
%             the significant pixels only (the others 0), contour outlines
%             them (role "strfContour")
%     "rtf"   |H| of the significant STRF over modulation rate (x, Hz; > 0
%             with a positive density: a downward-moving ripple) and
%             ripple density (y, c/o), on the heat colormap from 0, the
%             best ripple marked + (role "strfBest") and a second best x
%             (rippleStrf's best.secondary)
%     "crh"   a DMR's conditioned response histogram over Fm (x, Hz) and
%             ripple density (y, c/o): spike counts (crhScale "count") or
%             spikes per second of stimulus in the bin ("rate"); a TORC
%             or ripple noise has none (the panel says so)
%   Color limits options.cLim (fixed, or ends from the values drawn:
%   colorLimits), else symmetric about 0 to the largest |value| (strf), or
%   0 to the largest (rtf, crh). options.stack "groups" draws every set
%   instead, an image row each (drawImageStack), on one color scale, when
%   their grids agree (else the one set options.group, with a note).
%   options.stats writes, at the top left (role "strfStats"), the set's
%   spikes and rate, its best ripple (bTM, bRD), a DMR's or ripple noise's
%   energy and phase-locking index, the SNR, and the first comparison of
%   the set with another (similarity, rate and magnitude disparity
%   indices). With several sets the title names the set drawn. Skipped
%   layers are noted (figLayerNotes).
%
%   See also renderFigure, computeStrfPanel, rippleStrf, drawImageStack.
style = look.style;
o = look.panel.options;
hk = figDrawResult(ax);
j = find(arrayfun(@(l) l.skip == "" && isstruct(l.R) && isfield(l.R, 'kind') && l.R.kind == "rippleStrf", P.layers), 1);
if isempty(j)
    tagPart(ax, "axes", "", look.panelId);
    figLayerNotes(ax, P, look, false);
    return
end
R = P.layers(j).R;
nS = numel(R.sets);
g = min(max(1, round(o.group)), nS);
view = string(o.view);
if view == "crh" && isempty(R.sets(g).crh)
    P.layers(j).skip = "No conditioned response histogram for " + R.sets(g).label + ": the CRH (Escabi & Schreiner " + ...
        "Eq. 15) is a DMR's, not a " + kindWord(R.sets(g).kind) + "'s";
    tagPart(ax, "axes", "", look.panelId);
    figLayerNotes(ax, P, look, false);
    return
end
gs = g;
note = "";
if string(o.stack) == "groups" && nS > 1
    sz = arrayfun(@(s) imageSize(s, view, o), R.sets, 'UniformOutput', false);
    if all(cellfun(@(c) isequal(c, sz{1}) && all(c > 0), sz))
        gs = 1:nS;
    else
        note = "The sets are on different grids (or a set has no " + upper(view) + "): one is drawn, Group picks it";
    end
end
stacked = numel(gs) > 1;
[xv, yv, ~] = imageOf(R.sets(g), view, o);
Z = zeros(numel(yv), numel(xv), numel(gs));
for q = 1:numel(gs)
    [~, ~, Zq] = imageOf(R.sets(gs(q)), view, o);
    Z(:, :, q) = Zq;
end
names = reshape([R.sets.label], 1, []);
if stacked
    colors = look.colors;
    if size(colors, 1) < nS; colors = lines(nS); end   % (the sets are bank items, or groups the figure does not color)
    [Lst, hLeg] = drawImageStack(ax, xv, yv, Z, names(gs), colors, o.stackSpacing);
    for q = 1:numel(gs)
        hk.legendHandles(end+1) = hLeg(q);
        hk.legendLabels(end+1) = names(gs(q));
        hk.legendGroup(end+1) = true;
    end
    offs = Lst.offset;
else
    tagPart(imagesc(ax, xv, yv, Z, 'AlphaData', double(isfinite(Z))), "image", P.layers(j).name);
    offs = 0;
end
tagPart(ax, "axes", "", look.panelId);   % after imagesc, which resets a replaced axes' properties
set(ax, 'YDir', 'normal', 'Layer', 'top');
v = Z(isfinite(Z));
if view == "strf"
    cmap = designColormap(style, "diverging", "blueWhiteRed");
    m = max(abs(v));
    if isempty(m) || ~(m > 0); m = 1; end
    autoLim = [-m m];
else
    cmap = designColormap(style, "heat", "parula");
    m = max(v);
    if isempty(m) || ~(m > 0); m = 1; end
    autoLim = [0 m];
end
colormap(ax, cmap);
clim(ax, colorLimits(o.cLim, v, autoLim));
hold(ax, 'on');
for q = 1:numel(gs)
    s = R.sets(gs(q));
    switch view
        case "strf"
            if o.contour && any(s.sig(:)) && numel(s.lags) > 1 && numel(s.x) > 1
                [~, hc] = contour(ax, s.lags * 1000, s.x + offs(q), double(s.sig), [0.5 0.5], 'LineColor', [0 0 0], ...
                    'LineWidth', 0.75, 'HandleVisibility', 'off');
                tagPart(hc, "strfContour", s.label);
            end
        case "rtf"
            b = s.best;
            if isfinite(b.fm)
                tagPart(plot(ax, b.fm, b.omega + offs(q), '+', 'Color', [0 0 0], 'MarkerSize', 9, 'LineWidth', 1.5, ...
                    'HandleVisibility', 'off'), "strfBest", s.label);
                if b.secondary
                    if b.fm >= 0; f2 = b.fmNeg; o2 = b.omegaNeg; else; f2 = b.fmPos; o2 = b.omegaPos; end
                    tagPart(plot(ax, f2, o2 + offs(q), 'x', 'Color', [0 0 0], 'MarkerSize', 8, 'LineWidth', 1.25, ...
                        'HandleVisibility', 'off'), "strfBest", s.label);
                end
            end
    end
end
hold(ax, 'off');
st = style;
st.XLim = [];
st.YLim = [];
st.CLim = [];
styleAxes(ax, st);
grid(ax, 'off');
if numel(xv) > 1; xlim(ax, [xv(1) xv(end)] + [-1 1] * median(diff(xv)) / 2); end
if ~stacked && numel(yv) > 1; ylim(ax, [yv(1) yv(end)] + [-1 1] * median(diff(yv)) / 2); end
s = R.sets(g);
cb = tagPart(colorbar(ax), "colorbar");
switch view
    case "strf"
        xlabel(ax, "Lag (ms)");
        what = "STRF";
        if s.kind ~= "TORC"; what = "Rate-normalized STRF"; end
        cb.Label.String = what + " (" + s.units + ")";
        yName = sprintf("Octaves above %.4g kHz", s.freq(1) / 1000);
    case "rtf"
        xlabel(ax, "Modulation rate (Hz; > 0 downward)");
        cb.Label.String = "|H| (" + s.units + ")";
        yName = "Ripple density (cyc/oct)";
    otherwise
        xlabel(ax, "Modulation rate Fm (Hz; > 0 downward)");
        cb.Label.String = "Spikes";
        if o.crhScale == "rate"; cb.Label.String = "Spikes/s in the bin"; end
        yName = "Ripple density (cyc/oct)";
end
if stacked
    hk.yName = sprintf("%s (%s per row)", "Set", yName);
else
    hk.yName = yName;
    if nS > 1
        title(ax, sprintf('%s (%s)', s.label, kindWord(s.kind)), 'FontWeight', 'normal', 'Interpreter', 'none');
    end
end
if o.stats && ~stacked
    tagPart(text(ax, 0.02, 0.98, statLines(R, g), 'Units', 'normalized', 'VerticalAlignment', 'top', ...
        'HorizontalAlignment', 'left', 'FontSize', max(6, style.FontSize - 2), 'Interpreter', 'none', ...
        'BackgroundColor', [1 1 1], 'Margin', 1, 'Clipping', 'on'), "strfStats", s.label);
end
figLayerNotes(ax, P, look, true);
if note ~= ""
    brokenGraphic(ax, note, Where="corner", FontSize=style.FontSize, Title="Not drawn in panel " + string(look.panelId));
end
end


function [x, y, Z] = imageOf(s, view, o)
%imageOf  The image a set draws in VIEW, with its x and y: [] where it has none.
switch view
    case "strf"
        x = s.lags * 1000;
        y = s.x(:);
        Z = s.strfRate;
        if o.showSig; Z = s.strfSig; end
    case "rtf"
        x = s.rtfFm;
        y = s.rtfOmega(:);
        Z = s.rtf;
    otherwise
        x = []; y = []; Z = [];
        if isempty(s.crh); return; end
        x = (s.crhFmEdges(1:end-1) + s.crhFmEdges(2:end)) / 2;
        y = ((s.crhOmegaEdges(1:end-1) + s.crhOmegaEdges(2:end)) / 2).';
        Z = s.crh;
        if o.crhScale == "rate"; Z = s.crhRate; end
end
end


function sz = imageSize(s, view, o)
%imageSize  The size of the image a set draws in VIEW (0 x 0: none).
[~, ~, Z] = imageOf(s, view, o);
sz = size(Z);
end


function L = statLines(R, g)
%statLines  The set's spikes and rate, best ripple, energy and PLI (a DMR's, ripple noise's), SNR and first comparison.
s = R.sets(g);
L = string(sprintf("n = %d spikes, %.3g spikes/s", s.nSpikes, s.rate));
if isfinite(s.best.fm)
    L(end+1) = sprintf("bTM %.3g Hz, bRD %.3g c/o", s.best.fm, s.best.omega);
else
    L(end+1) = "No significant pixel (p < " + num2str(R.settings.alpha) + ")";
end
if s.kind ~= "TORC"
    L(end+1) = sprintf("E %.3g, PLI %.3g", s.energy, s.pli);
end
if isfinite(s.snrMean)
    L(end+1) = sprintf("SNR %.3g mean, %.3g max", s.snrMean, s.snrMax);
end
C = R.compare;
k = find(C.ia == g | C.ib == g, 1);
if ~isempty(k)
    sg = 1;
    if C.ib(k) == g; sg = -1; end   % the indices are antisymmetric: this set's against the other's
    t = string(sprintf("vs %s: SI %.2f, RDI %.3g%%", other(C, k, g), C.si(k), sg * C.rdi(k)));
    if isfinite(C.mdi(k)); t = t + sprintf(", MDI %.3g%%", sg * C.mdi(k)); end
    L(end+1) = t;
end
L = cellstr(L);
end


function name = other(C, k, g)
name = C.b(k);
if C.ib(k) == g; name = C.a(k); end
end


function w = kindWord(k)
switch k
    case "RN", w = "ripple noise";
    case "DMR", w = "DMR";
    otherwise, w = "TORC";
end
end
