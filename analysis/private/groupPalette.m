function C = groupPalette(G, style)
%groupPalette  Group colours: G.color, sampled from Style.Colormap, or one colour.
%   Style.Colormap "lines" keeps the colours selectTrials chose; the name of
%   any colormap function (parula, turbo, hot, ...) resamples them from it;
%   a colour name or hex code ("black", "#1f77b4") gives every group that
%   colour.
C = G.color;
name = char(style.Colormap);
if strcmpi(name, "lines") || height(G) == 0
    return
end
if ~ismember(exist(name), [2 5]) %#ok<EXIST>
    try
        C = repmat(validatecolor(name), height(G), 1);
    catch
    end
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
