function [fig, copied] = copyFigureSettings(fig, from, parts)
%copyFigureSettings  Give figure FIG the settings of figure FROM, part by part.
%   FIG = copyFigureSettings(FIG, FROM, PARTS) copies FROM's fields of the
%   parts PARTS (figureSettingParts' Part names, e.g. ["alignment"
%   "style"]; default: every part) onto FIG and normalizes the result
%   (EphysAnalysisConfig.normalizeFigure). FIG keeps its id (and autoId:
%   an automatic id follows the panels copied once FIG is stored in a
%   config), title and enabled, and every part not named. "arrangement" copies the grid and
%   the panels as they are, panel ids included.
%
%   [FIG, COPIED] = ... also gives the parts copied (a string row, in
%   figureSettingParts' order). Error: copyFigureSettings:BadPart.
%
%   See also figureSettingParts.
arguments
    fig (1,1) struct
    from (1,1) struct
    parts string = string(missing)
end
T = figureSettingParts();
if isscalar(parts) && ismissing(parts)
    parts = T.Part.';
end
parts = reshape(parts, 1, []);
bad = parts(~ismember(parts, T.Part));
if ~isempty(bad)
    error('copyFigureSettings:BadPart', 'Unknown part "%s" (parts: %s).', bad(1), strjoin(T.Part, ", "));
end
copied = T.Part(ismember(T.Part, parts)).';
for part = copied
    for f = T.Fields{T.Part == part}
        fig.(f) = from.(f);
    end
end
fig = EphysAnalysisConfig.normalizeFigure(fig, "Figure");
end
