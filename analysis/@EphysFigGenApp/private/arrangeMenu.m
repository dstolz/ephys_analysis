function cm = arrangeMenu(obj, id)
%arrangeMenu  The right-click menu of a panel's box in Arrange: Set corners, Bring forward, Send back, Remove panel.
%   CM = arrangeMenu(OBJ, ID) is a context menu (in the app's window) for
%   the panel ID's widget (arrangeWidget, which deletes it with itself).
%   Each item selects the panel first (onPanelSelected), then does what
%   the Layout section's button of that name does: onSetCorners,
%   onPanelOrder(1), onPanelOrder(-1), onRemovePanel; with several panels
%   selected (Shift+click, selectedPanelIds) and ID one of them, Remove
%   panel removes them all (one undo step, "Remove panels"), the others
%   act on the primary (the one right-clicked). ID ":legend" (the
%   floating legend's box) has one item, Make it a legend panel here,
%   which places a legend panel at the box (onArrangeMoved).
%
%   See also arrangeWidget, EphysFigGenApp.onSetCorners, EphysFigGenApp.onPanelOrder,
%   EphysFigGenApp.onRemovePanel.
cm = uicontextmenu(obj.Fig, 'Tag', 'arrangeMenu', 'UserData', id);   % (its box's id)
if id == ":legend"
    uimenu(cm, 'Text', 'Make it a legend panel here', 'MenuSelectedFcn', @(~, ~) obj.onArrangeMoved(id, []));
    return
end
uimenu(cm, 'Text', 'Set corners', 'Tag', 'setCorners', 'MenuSelectedFcn', @(~, ~) act(obj, id, @() obj.onSetCorners()));
uimenu(cm, 'Text', 'Bring forward', 'Tag', 'bringForward', 'Separator', 'on', 'MenuSelectedFcn', @(~, ~) act(obj, id, @() obj.onPanelOrder(1)));
uimenu(cm, 'Text', 'Send back', 'Tag', 'sendBack', 'MenuSelectedFcn', @(~, ~) act(obj, id, @() obj.onPanelOrder(-1)));
uimenu(cm, 'Text', 'Remove panel', 'Tag', 'removePanel', 'Separator', 'on', 'MenuSelectedFcn', @(~, ~) removeSelected(obj, id));
end


function removeSelected(obj, id)
%removeSelected  Remove panel: the panel ID, or with several selected (ID one of them) all of them, one undo step "Remove panels" (onRemovePanel).
if any(selectedPanelIds(obj) == id)
    obj.onRemovePanel();   % the panels selected, this one among them
else
    obj.FigurePanelExtra = strings(1, 0);   % another panel: it alone
    act(obj, id, @() obj.onRemovePanel());
end
end


function act(obj, id, fcn)
%act  Select the panel ID of the selected figure (when it is still there), then call FCN.
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures) || isempty(obj.Config.Figures(k).panels); return; end
j = find([obj.Config.Figures(k).panels.id] == id, 1);
if isempty(j); return; end
if j ~= obj.SelectedPanel; obj.onPanelSelected(j); end
fcn();
end
