function warmUp(obj)
%warmUp  Load and compile what Arrange's first use would, so the first Arrange on and the first drag of a session cost no more than the next.
%   warmUp(OBJ) runs the drag's pure functions once on made-up rects
%   (snapRect, arrangeGroup, unitsShown: MATLAB compiles a function when
%   it is first called, and a session's first drag step paid about a
%   second for that where the next steps take 10 ms), then makes one
%   images.roi.Rectangle in an axes of a hidden figure and deletes both
%   (loading those classes took about 1.2 s inside the first Arrange on,
%   measured 2026-11-05; 0.03 s a box after). The constructor runs it from
%   a timer two seconds after the window shows (warmArrangeClasses), in the
%   idle moment after startup; a script or a bench may call it itself.
%   Nothing is drawn and nothing in the app changes.
%
%   See also arrangeWidget, EphysFigGenApp.syncArrangeOverlay, EphysFigGenApp.onArrangeMoving.
try   % the drag's arithmetic
    others = [0.55 0.1 0.4 0.4; 0.1 0.55 0.4 0.4];
    snapRect([0.12 0.1 0.4 0.4], [0.1 0.1 0.4 0.4], others, [0.05 0.05], [0.01 0.01], Names=["a" "b"]);
    snapRect([0.1 0.1 0.42 0.4], [0.1 0.1 0.4 0.4], others, [0 0], [0 0], Names=["a" "b"]);
    arrangeGroup([0.1 0.1 0.4 0.4], [0.12 0.1 0.4 0.4], others);
    unitsShown([0.1 0.1 0.4 0.4], "normalized", obj.FigureRectUnits, [20 15], 150, "rect");
catch
end
if isstruct(obj.FigureArrangeOverlay) || ~isempty(obj.FigureArrangeKept); return; end   % (Arrange on already loaded the boxes' classes)
f = figure('Visible', 'off', 'HandleVisibility', 'off', 'IntegerHandle', 'off');
c = onCleanup(@() delete(f)); %#ok<NASGU>
try
    ax = axes(f, 'XLim', [0 1], 'YLim', [0 1]);
    w = images.roi.Rectangle(ax, 'Position', [0.1 0.1 0.2 0.2]);
    delete(w);
catch
    % (nothing lost: Arrange on loads the classes itself)
end
end
