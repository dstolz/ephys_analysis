function [color, ls] = figLayerLook(L, i, groupColor)
%figLayerLook  The color and line style of one trace of a figure panel's layer.
%   [COLOR, LS] = figLayerLook(L, I, GROUPCOLOR) for the layer L (figureFor's
%   spec layer: color, lineStyle) drawing the I-th item of its panel (the
%   panel's layers, and each layer's units or channels drawn one by one,
%   in order) in the trial group whose color is GROUPCOLOR:
%     COLOR  L.color when it is a color (a name or #rrggbb), else GROUPCOLOR
%     LS     L.lineStyle when set ("-", "--", ":", "-."), else by the
%            item's order: "-", "--", ":", "-.", "-", ...
%
%   See also drawPsthPanel, drawContinuousPanel.
styles = ["-" "--" ":" "-."];
color = groupColor;
if isfield(L, 'color') && strtrim(string(L.color)) ~= ""
    try
        color = validatecolor(char(strtrim(string(L.color))));
    catch
        % not a color (validate says so): the group's
    end
end
ls = styles(mod(i - 1, numel(styles)) + 1);
if isfield(L, 'lineStyle') && ismember(string(L.lineStyle), styles); ls = string(L.lineStyle); end
end
