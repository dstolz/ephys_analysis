function [D, follows] = figureDesignFor(design, userAesthetics)
%figureDesignFor  The design to draw in, and whether it is the user's choice (a new choice redraws it).
%
%   See also renderFigure, renderProbeFigure.
follows = false;
if isstruct(design)
    D = design;
elseif string(design) ~= ""
    D = PlotDesign.load(string(design));
elseif userAesthetics
    D = PlotDesign.current();
    follows = true;
else
    D = PlotDesign.none();
end
end
