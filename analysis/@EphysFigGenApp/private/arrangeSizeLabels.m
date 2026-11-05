function arrangeSizeLabels(obj)
%arrangeSizeLabels  Arrange's size labels: each selected panel's width x height by its box on the preview, while it is selected.
%   arrangeSizeLabels(OBJ) labels the box (arrangeWidget) of each panel
%   selected in Arrange (selectedPanelIds: the primary and those added
%   with Shift+click) with its size, "9.00 x 6.00 cm", in the Panels
%   section's units (FigureRectUnits, on the figure's export page:
%   figurePage), rounded as its Size fields show it (unitsShown). The
%   label sits centered under the box, white on the selection's blue;
%   above it when the page has no room under it, else just inside its
%   bottom edge. During a drag (FigureArrangeMode "drag" or "canceled")
%   the labels hide, the smart guides' readout showing the size
%   (arrangeCues), and they come back when it ends. The labels (texts,
%   Tag "arrangeSize", none taking a click) are made as needed and kept
%   in the overlay (its field sizes); one not needed is hidden.
%   Called by syncArrangeOverlay (a panel selected, an edit, a preview
%   drawn, the canvas resized), onArrangeMoving (a drag begins),
%   onArrangeMoved (it ends) and onRectUnitsChanged.
%
%   See also EphysFigGenApp.syncArrangeOverlay, arrangeCues, selectedPanelIds.
if ~isvalid(obj); return; end
O = obj.FigureArrangeOverlay;
if ~isstruct(O) || isempty(O.axes) || ~isvalid(O.axes); return; end
T = gobjects(1, 0);
if isfield(O, 'sizes') && ~isempty(O.sizes); T = reshape(O.sizes(isvalid(O.sizes)), 1, []); end
rects = zeros(0, 4);
if ~ismember(obj.FigureArrangeMode, ["drag" "canceled"])
    for id = selectedPanelIds(obj)
        if ~isKey(O.widgets, char(id)); continue; end
        w = O.widgets(char(id));
        if isvalid(w); rects(end+1, :) = double(w.Position); end %#ok<AGROW>
    end
end
n = size(rects, 1);
if n > 0
    ax = O.axes;
    for i = numel(T)+1:n
        T(i) = text(ax, 0, 0, "", 'Tag', 'arrangeSize', 'Color', [1 1 1], 'BackgroundColor', [0.05 0.45 0.95], ...
            'FontSize', 9, 'Interpreter', 'none', 'Margin', 1, 'HorizontalAlignment', 'center', 'Visible', 'off', ...
            'HitTest', 'off', 'PickableParts', 'none', 'Clipping', 'off');
    end
    px = max(ax.Position(3:4), 1);   % the page in px: a few px of offset in its 0-1
    gap = 3 / px(2);
    room = 18 / px(2);   % a label's height and its gap
    u = obj.FigureRectUnits;
    [pageCm, dpi] = figurePage(obj);
    [~, d, tail] = unitsShown([], "", u);
    for i = 1:n
        r = rects(i, :);
        v = unitsShown(r, "normalized", u, pageCm, dpi, "rect");
        if r(2) >= room   % under the box
            y = r(2) - gap; va = 'top';
        elseif 1 - r(2) - r(4) >= room   % above it
            y = r(2) + r(4) + gap; va = 'bottom';
        else   % inside its bottom edge
            y = r(2) + gap; va = 'bottom';
        end
        set(T(i), 'Position', [r(1) + r(3) / 2, y, 0], 'VerticalAlignment', va, ...
            'String', sprintf("%.*f x %.*f%s", d, v(3), d, v(4), tail));
    end
end
on = false(size(T));
on(1:n) = true;
vis = arrayfun(@(t) logical(t.Visible), T);
set(T(on & ~vis), 'Visible', 'on');
set(T(~on & vis), 'Visible', 'off');
O.sizes = T;
obj.FigureArrangeOverlay = O;
end
