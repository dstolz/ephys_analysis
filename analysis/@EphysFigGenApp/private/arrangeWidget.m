function w = arrangeWidget(ax, rect, id, selected, cb)
%arrangeWidget  A move and resize box over the preview for one panel (or the floating legend): Arrange's widget.
%   W = arrangeWidget(AX, RECT, ID, SELECTED, CB) draws an
%   images.roi.Rectangle in the Arrange overlay AX (its data units are the
%   page's 0-1, so the box's Position is the panel's rect) at RECT,
%   Tag "arrangeBox:<ID>", labeled ID when the pointer is over it, kept
%   on the page (DrawingArea), never deleted by a key or its own menu.
%   Dragging its face moves it, its handles resize it. SELECTED draws it
%   as selected (arrangeWidgetSelect: 2 or true the primary, blue and
%   thicker; 1 another selected panel, blue; 0 or false none). CB holds
%   what it calls:
%     moving   CB.moving(ID, EVT) on every step of a drag (MovingROI)
%     moved    CB.moved(ID, EVT) when the drag ends (ROIMoved)
%     clicked  CB.clicked(ID, EVT) on a click on it (ROIClicked)
%     menu     its right-click menu (arrangeMenu; deleted with it)
%     legend   (optional) true: the floating legend's box: dashed, Tag
%              "arrangeBox:legend", labeled "legend" (ID is what the
%              callbacks get)
%   The listeners live as long as the box (addlistener). The box is the
%   whole of the widget: arrangeWidgetSet moves it, arrangeWidgetSelect
%   marks it selected, arrangeWidgetLock locks it (Set corners' clicks
%   reach the overlay). Only these four files know it is an ROI.
%
%   See also EphysFigGenApp.syncArrangeOverlay, arrangeWidgetSet,
%   arrangeWidgetSelect, arrangeWidgetLock, arrangeMenu.
legend = isfield(cb, 'legend') && cb.legend;
tag = "arrangeBox:" + id;
label = id;
if legend; tag = "arrangeBox:legend"; label = "legend"; end
w = images.roi.Rectangle(ax, 'Position', rect, 'Tag', tag, 'Color', [0.3 0.3 0.3], 'FaceAlpha', 0.04, ...
    'LineWidth', 1, 'InteractionsAllowed', 'all', 'DrawingArea', [0 0 1 1], 'Label', char(label), 'LabelVisible', 'hover', ...
    'Deletable', false, 'MarkerSize', 6);
if legend; w.StripeColor = [1 1 1]; end   % dashed: the legend floats, it is no panel yet
if isfield(cb, 'menu') && ~isempty(cb.menu)
    w.ContextMenu = cb.menu;
    menu = cb.menu;
    addlistener(w, 'ObjectBeingDestroyed', @(~, ~) delete(menu(isvalid(menu))));
end
addlistener(w, 'MovingROI', @(~, evt) cb.moving(id, evt));
addlistener(w, 'ROIMoved', @(~, evt) cb.moved(id, evt));
addlistener(w, 'ROIClicked', @(~, evt) cb.clicked(id, evt));
arrangeWidgetSelect(w, selected);
end
