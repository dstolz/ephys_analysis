function C = groupPalette(G, style)
%groupPalette  Group colours: G.color, or sampled from Style.Colormap.
%   Style.Colormap "lines" keeps the colours selectTrials chose; the name of
%   any colormap function (parula, turbo, hot, ...) resamples them from it.
C = G.color;
name = char(style.Colormap);
if strcmpi(name, "lines") || height(G) == 0
    return
end
try
    M = feval(name, 256);
catch
    return
end
if height(G) == 1
    C = M(1, :);
else
    C = M(round(linspace(1, 230, height(G))), :);
end
end
