function scrollFigureEditor(obj, S)
%scrollFigureEditor  Scroll the figure editor back to where a figure left it (S from restoreFigureEditorState).
%   After the editor shows the figure (applyFigureEditor), once its layout
%   has settled; S = [] (the figure has no kept state) or no scroll kept
%   leaves it where it is.
%
%   See also saveFigureEditorState, restoreFigureEditorState.
if isempty(S) || ~isfield(S, 'Scroll') || numel(S.Scroll) ~= 2; return; end
drawnow nocallbacks;   % the sections laid out first, so the scroll is not clipped to the old height
try
    scroll(obj.FigureEditorGrid, S.Scroll(1), S.Scroll(2));
catch
end
end
