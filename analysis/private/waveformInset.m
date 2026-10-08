function waveformInset(ax, W, u, opt, style)
%waveformInset  Unit U's waveform as a box at a compass point of AX.
%   waveformInset(AX, W, U, OPT, STYLE) draws unit U of W (unitWaveforms)
%   as OPT says (a plot's waveform settings, defaults("Waveform")): its mean
%   (dark red) and / or its spikes (thin, pale blue), on the box's own
%   amplitude scale, with the mean's peak-to-peak amplitude at the top. The
%   box is a third of AX's width and height times OPT.scale, at
%   OPT.location (northeast: the top right corner), placed in data units on
%   the limits AX has now, which it keeps (any axis direction or scale);
%   with OPT.showPP / OPT.showCount the label says the p-p amplitude / the
%   number of spikes drawn; with OPT.box it has an outline and a pale ground. A template (no spikes
%   read) is drawn as the mean whatever the mode, and says so. Nothing is
%   drawn for mode "off" or a unit without a waveform. The parts are tagged
%   waveBox, waveSpikes, waveMean and waveLabel, and kept out of legends.

if opt.mode == "off" || isempty(W) || ~isfield(W, 'mean') || u > numel(W.mean) || isempty(W.mean{u})
    return
end
m = W.mean{u}(:);
t = W.timeMs{u}(:);
S = W.spikes{u};
template = W.from(u) == "template";
showSpikes = ismember(opt.mode, ["subsample" "both"]) && ~isempty(S) && ~template;
showMean = ismember(opt.mode, ["mean" "both"]) || ~showSpikes;

% --- the box, in fractions of the axes as seen (0 0 = bottom left) ------------------
xl = xlim(ax);
yl = ylim(ax);
xlim(ax, xl);                       % drawing it moves nothing
ylim(ax, yl);
f = min(opt.scale / 3, 0.9);
pad = 0.03;
A = struct('north', [0.5 1], 'northeast', [1 1], 'east', [1 0.5], 'southeast', [1 0], ...
    'south', [0.5 0], 'southwest', [0 0], 'west', [0 0.5], 'northwest', [0 1]);
a = A.northeast;
if isfield(A, opt.location); a = A.(opt.location); end
x0 = pad + a(1) * (1 - 2 * pad - f);
y0 = pad + a(2) * (1 - 2 * pad - f);
X = @(fx) toData(fx, xl, ax.XScale, ax.XDir);
Y = @(fy) toData(fy, yl, ax.YScale, ax.YDir);

% --- the waveform on the box's scale: the top fifth is the label --------------------
V = m;
if showSpikes; V = [m S]; end
lo = min(V(:));
hi = max(V(:));
if ~(hi > lo); lo = lo - 1; hi = hi + 1; end
span = max(t) - min(t);
if ~(span > 0); span = 1; end
xw = X(x0 + f * (0.05 + 0.9 * (t - min(t)) / span));
yOf = @(v) Y(y0 + f * (0.05 + 0.70 * (v - lo) / (hi - lo)));

held = ishold(ax);
hold(ax, 'on');
if opt.box
    tagPart(patch(ax, X(x0 + [0 f f 0]), Y(y0 + [0 0 f f]), paleColor([1 1 1], 1, style), 'FaceAlpha', 0.85, ...
        'EdgeColor', [0.6 0.6 0.6], 'HandleVisibility', 'off'), "waveBox");
end
if showSpikes
    K = size(S, 2);
    tagPart(line(ax, repmat([xw; NaN], K, 1), reshape([yOf(S); NaN(1, K)], [], 1), ...
        'Color', [0.30 0.45 0.75 0.25], 'LineWidth', 0.5, 'HandleVisibility', 'off'), "waveSpikes");
end
if showMean
    tagPart(line(ax, xw, yOf(m), 'Color', [0.80 0.10 0.10], 'LineWidth', max(1, style.LineWidth), ...
        'HandleVisibility', 'off'), "waveMean");
end
parts = strings(1, 0);
if opt.showPP
    parts(end+1) = sprintf("%.3g %s p-p", max(m) - min(m), unitText(W.units(u)));
end
if opt.showCount && ~template && ~isempty(S)
    parts(end+1) = sprintf("%d spikes", size(S, 2));
end
if template; parts(end+1) = "(template)"; end
txt = strjoin(parts, ", ");
if txt ~= ""
    tagPart(text(ax, X(x0 + 0.05 * f), Y(y0 + 0.97 * f), txt, 'FontSize', max(6, style.FontSize - 2), ...
        'Color', [0.3 0.3 0.3], 'VerticalAlignment', 'top', 'Interpreter', 'none', 'Clipping', 'on', ...
        'HandleVisibility', 'off'), "waveLabel");
end
if ~held; hold(ax, 'off'); end
end


function v = toData(fr, lim, scale, dir)
%toData  Fractions of an axis as seen (0 = left / bottom) to its data values.
if string(dir) == "reverse"; fr = 1 - fr; end
if string(scale) == "log"
    v = 10 .^ (log10(lim(1)) + fr * (log10(lim(2)) - log10(lim(1))));
else
    v = lim(1) + fr * (lim(2) - lim(1));
end
end


function s = unitText(units)
%unitText  The amplitude unit for the label (unitWaveforms' units).
switch units
    case "uV";       s = char(181) + "V";
    case "bin";      s = ".bin units";
    case "whitened"; s = "whitened";
    otherwise;       s = "a.u.";
end
end
