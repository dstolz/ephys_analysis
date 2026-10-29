function tf = figureEditable(mode, target)
%figureEditable  Whether the right-click aesthetics editor goes on: "auto" = in a visible figure.
%
%   See also renderFigure, renderProbeFigure.
if isstring(mode) || ischar(mode)
    if string(mode) ~= "auto"
        error('renderFigure:BadEditable', 'Editable is "auto", true or false.');
    end
    fig = ancestor(target, 'figure');
    tf = ~isempty(fig) && strcmp(fig.Visible, 'on');
else
    tf = logical(mode);
end
end
