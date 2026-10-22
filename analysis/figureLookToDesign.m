function [D, copied] = figureLookToDesign(D, fig, keys)
%figureLookToDesign  Give plot design D the look settings KEYS of figure FIG.
%   [D, COPIED] = figureLookToDesign(D, FIG, KEYS), D a design
%   (PlotDesign.load, PlotDesign.none), FIG a figure (a Figures entry),
%   copies FIG's settings KEYS that a design holds (figureSettingItems'
%   rows with Design true; KEYS as copyFigureSettings takes them, a part's
%   name too; default: every one) into D:
%     style.Colormap      a colormap function's name ("turbo"): the
%                         sequential colors (that name) and a palette of 7
%                         colors sampled from it; one color ("black",
%                         "#1f77b4"): the single color and a palette of it.
%                         "lines" (the design's own colors) is not offered
%     style.HeatColormap  the heat colors (heat map, probe map); blank (the
%                         design's) is not offered
%     looks.<n>           each remembered look picked, added to the
%                         design's common rules (PlotAesthetics.mergeRules:
%                         it replaces the rules it covers)
%   COPIED are the keys copied. A key FIG has that a design does not hold
%   (a panel's option, the font size) is left out; an unknown key raises
%   figureLookToDesign:BadSetting. D is not saved (PlotDesign.save).
%
%   See also figureSettingItems, copyFigureSettings, PlotDesign.
arguments
    D (1,1) struct
    fig (1,1) struct
    keys string = string(missing)
end
I = figureSettingItems(fig);
pick = pickSettingItems(I, keys, 'figureLookToDesign:BadSetting') & I.Design;
copied = reshape(I.Key(pick), 1, []);
for i = reshape(find(pick), 1, [])
    switch I.Key(i)
        case "style.Colormap"
            v = string(fig.style.Colormap);
            if ismember(exist(char(v)), [2 5]) %#ok<EXIST> a colormap function
                D.sequential = v;
                D.palette = PlotDesign.colormap(v, 7);
            else
                c = namedColor(v);
                D.single = c;
                D.palette = c;
            end
        case "style.HeatColormap"
            D.heat = string(fig.style.HeatColormap);
        otherwise   % a remembered look
            D.rules = PlotAesthetics.mergeRules(D.rules, fig.aesthetics(I.Index(i)));
    end
end
end
