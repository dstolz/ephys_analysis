function tf = arrangeHasFocus(obj)
%arrangeHasFocus  False when the control last clicked is outside the preview that Arrange boxes lie over (a field, the tree, a button).
%   WindowKeyPressFcn fires whatever control has the focus, so the arrow
%   keys are Arrange's nudges only while the figure's CurrentObject (the
%   component last clicked) is empty, the window or in the preview's
%   container (the overlay's axes and boxes are in it). Anything else
%   (onKeyPress clears FigureArrangeFocus then) keeps its own arrow keys:
%   a field's cursor, a spinner's step, the tree's selection.
tf = true;
try
    h = obj.Fig.CurrentObject;
    if isempty(h) || ~isgraphics(h) || isa(h, 'matlab.ui.Figure'); return; end
    P = obj.FigurePreviewPanel;
    while ~isempty(h) && isgraphics(h) && ~isa(h, 'matlab.ui.Figure')
        if isequal(h, P); return; end
        h = h.Parent;
    end
    tf = false;
catch
end
end
