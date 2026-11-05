function v = arrangeSelectLevel(id, sel)
%arrangeSelectLevel  How Arrange's box of panel ID shows the selection SEL (selectedPanelIds): 2 the primary (the editor's panel), 1 another selected panel, 0 none.
%   The level arrangeWidgetSelect draws: syncArrangeOverlay and
%   arrangeSelectBoxes.
%
%   See also arrangeWidgetSelect, arrangeSelectBoxes, selectedPanelIds.
v = 0;
if isempty(sel); return; end
if id == sel(1)
    v = 2;
elseif any(sel == id)
    v = 1;
end
end
