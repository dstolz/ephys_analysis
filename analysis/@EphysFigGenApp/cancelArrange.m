function cancelArrange(obj, msg)
%cancelArrange  End what Arrange is doing over the preview without changing the figure: a drag, or Set corners' clicks.
%   cancelArrange(OBJ, MSG): FigureArrangeMode goes back to "" and
%   FigureCorners to []; when a drag holds the window's pointer callbacks
%   (FigureDrag: oldMotion, oldUp, oldDown), they come back as they were.
%   The status bar says MSG unless it is "" (default "Canceled."). Escape
%   calls it, on any tab (onKeyPress), and so does Arrange turned off
%   (onArrangeToggled).
%
%   See also EphysFigGenApp.onArrangeToggled, EphysFigGenApp.onKeyPress.
if nargin < 2; msg = "Canceled."; end
D = obj.FigureDrag;
obj.FigureDrag = [];
obj.FigureArrangeMode = "";
obj.FigureCorners = [];
if isstruct(D) && ~isempty(obj.Fig) && isvalid(obj.Fig)
    back = struct('oldMotion', 'WindowButtonMotionFcn', 'oldUp', 'WindowButtonUpFcn', 'oldDown', 'WindowButtonDownFcn');
    for f = string(fieldnames(back)).'
        if isfield(D, f); obj.Fig.(back.(f)) = D.(f); end
    end
end
if msg ~= ""; obj.setStatus(msg); end
end
