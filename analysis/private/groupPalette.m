function C = groupPalette(G, style)
%groupPalette  Group colors: G.color, sampled from Style.Colormap, or one color.
%   Style.Colormap "lines" keeps the colors selectTrials chose -- or, with
%   a plot design (Style.Design, renderStyle), the design's: its sequential
%   colors for ordered groups (isOrdinalGroups), its single color for one
%   group, else its palette in order; the name of any colormap function
%   (parula, turbo, hot, ...) resamples them from it; a color name or hex
%   code ("black", "#1f77b4") gives every group that color.
%   Groups with a base column (combineSessions "combine": a series per
%   session and trial group) are colored by base: the colors are chosen for
%   the base series (each base's first row) and every row takes its base's,
%   so a session keeps its color across its trial groups.
C = G.color;
name = char(style.Colormap);
if height(G) == 0
    return
end
if ismember("base", string(G.Properties.VariableNames))
    [~, first, ib] = unique(G.base);
    Gb = G(first, :);
    Gb.base = [];
    Gb.index = (1:height(Gb)).';
    Cb = groupPalette(Gb, style);
    C = Cb(ib, :);
    return
end
if strcmpi(name, "lines")
    if isfield(style, 'Design'); C = designColors(G, style.Design); end
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


function C = designColors(G, D)
%designColors  The design's colors for groups G (G.color where it gives none).
n = height(G);
C = G.color;
if isOrdinalGroups(G)
    if ~isempty(D.sequential)
        M = PlotDesign.colormap(D.sequential, 256);
        C = M(round(linspace(1, 256, n)), :);
    end
elseif n == 1 && ~isempty(D.single)
    C = D.single;
elseif ~isempty(D.palette)
    C = D.palette(mod((1:n) - 1, size(D.palette, 1)) + 1, :);
end
end
