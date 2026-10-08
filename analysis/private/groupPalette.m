function C = groupPalette(G, style)
%groupPalette  Group colours: G.color, sampled from Style.Colormap, or one colour.
%   Style.Colormap "lines" keeps the colours selectTrials chose -- or, with
%   a plot design (Style.Design, renderStyle), the design's: its sequential
%   colours for ordered groups (isOrdinalGroups), its single colour for one
%   group, else its palette in order; the name of any colormap function
%   (parula, turbo, hot, ...) resamples them from it; a colour name or hex
%   code ("black", "#1f77b4") gives every group that colour.
C = G.color;
name = char(style.Colormap);
if height(G) == 0
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
%designColors  The design's colours for groups G (G.color where it gives none).
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
