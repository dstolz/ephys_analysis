function tileTicks(axs, style)
%tileTicks  Small tiles of a grid: smaller tick labels, at most three y ticks.
%   tileTicks(AXS, STYLE) draws the tick labels of every axes in AXS 2
%   points under Style.FontSize (6 at least), keeps titles and axis labels
%   at Style.FontSize, and thins each automatic y axis (both sides of a
%   yyaxis) to three ticks at most, so the labels of a short tile do not
%   run into each other. Ticks set by the renderer (a stack's rows, a
%   heatmap's units) are left alone. Call it once the limits are final.
tick = max(6, style.FontSize - 2);
for ax = reshape(axs, 1, [])
    if ~isgraphics(ax); continue; end
    ax.FontSize = tick;
    texts = [ax.Title ax.XAxis(1).Label reshape([ax.YAxis.Label], 1, [])];
    set(texts, 'FontSize', style.FontSize);
    for r = reshape(ax.YAxis, 1, [])
        thin(r, 3);
    end
end
end


function thin(ruler, maxN)
%thin  At most MAXN ticks on an automatic numeric ruler, at the smallest round step that fits.
%   Steps are 1, 2, 2.5 or 5 x 10^k; whole-number ticks (epochs) keep
%   whole-number steps.
if ~isprop(ruler, 'TickValuesMode') || ruler.TickValuesMode ~= "auto"; return; end
tk = ruler.TickValues;
if numel(tk) <= maxN; return; end
lim = double(ruler.Limits);
span = diff(lim);
if ~(isfinite(span) && span > 0); return; end
whole = all(tk == round(tk));
for e = floor(log10(span / maxN)) + (0:2)
    for m = [1 2 2.5 5]
        s = m * 10^e;
        if whole && s ~= round(s); continue; end
        v = (ceil(lim(1) / s - 1e-9):floor(lim(2) / s + 1e-9)) * s;
        if numel(v) <= maxN
            ruler.TickValues = v;
            return
        end
    end
end
end
