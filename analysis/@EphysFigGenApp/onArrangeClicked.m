function onArrangeClicked(obj, id, evt)
%onArrangeClicked  A click on the Arrange overlay: on a panel's box it selects the panel (Shift+click: adds it or takes it out); anywhere it gives the arrow keys to the overlay.
%   onArrangeClicked(OBJ, ID, EVT) is the ROIClicked listener of panel
%   ID's widget (arrangeWidget; ":legend" the floating legend's) and, with
%   ID "", the overlay's ButtonDownFcn (a click on the page between the
%   boxes). It notes the overlay clicked last (FigureArrangeFocus: the
%   arrow keys now nudge the selection, nudgePanel, until an editor
%   control is used). On a box:
%     click         selects that panel alone, as Ctrl+Click on it does,
%                   in two steps so that a drag can start at once: on the
%                   press its box turns blue and the Position and Size
%                   fields show it (selectLightly); the rest of the
%                   editor shows it once the press ends (the release, or
%                   Escape: finishPendingSelect, as onPanelSelected
%                   fills it). On a box that is one of several selected, the
%                   selection stays while the mouse button is down (a drag
%                   moves them all); let go without a drag and that panel
%                   alone is selected (the window's WindowButtonUpFcn, for
%                   that one release)
%     Shift+click   adds the panel to the selection (it becomes the
%                   primary: the one the editor shows), or takes a
%                   selected one out of it (the primary too, when others
%                   are selected: the one added last is the primary then),
%                   as a Shift+click on the panel in the preview does
%                   (togglePanelSelection)
%     right-click   selects the panel, keeping a selection it is part of
%                   (its menu's Remove panel removes them all)
%   The selection is SelectedPanel (the primary, the last one clicked)
%   and FigurePanelExtra (the others: selectedPanelIds), the same with
%   Arrange on or off; every selected box is blue, the primary's line
%   thicker (syncArrangeOverlay), and the editor shows the settings the
%   selected panels share (syncFigureEditor). A click on the page between
%   the boxes leaves the primary alone selected.
%   EVT.SelectionType ("shift", or "extend") or the window's Shift
%   (CurrentModifier) makes it a Shift+click; "right" (or "alt") a
%   right-click. A drag that Escape canceled is over with the next click.
%   While Set corners waits for its clicks (FigureArrangeMode "corners")
%   the click is one of them (cornerClick), wherever it lands on the page.
%
%   See also EphysFigGenApp.syncArrangeOverlay, EphysFigGenApp.nudgePanel, EphysFigGenApp.startCornerMode, selectedPanelIds.
arguments
    obj (1,1) EphysFigGenApp
    id (1,1) string = ""
    evt = []
end
if obj.FigureArrangeMode == "corners"
    cornerClick(obj);
    return
end
if obj.FigureArrangeMode == "canceled"; obj.FigureArrangeMode = ""; end
obj.FigureArrangeFocus = true;
arrangeClickDone(obj);   % (an earlier press's wait for its release, if it is still there)
finishPendingSelect(obj);   % (an earlier press's light select whose release never came)
[shift, right] = clickKind(obj, evt);
if id == ":legend"; return; end
if id == ""
    if ~shift && ~isempty(obj.FigurePanelExtra)   % the page: the primary alone
        obj.FigurePanelExtra = strings(1, 0);
        obj.syncFigureEditor();   % (the editor's rows are the primary's alone again; its box alone blue)
    end
    return
end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures) || isempty(obj.Config.Figures(k).panels); return; end
ids = [obj.Config.Figures(k).panels.id];
j = find(ids == id, 1);
if isempty(j); return; end
sel = selectedPanelIds(obj);
primary = "";
if ~isempty(sel); primary = sel(1); end
extra = sel(2:end);
if shift
    togglePanelSelection(obj, id);   % (as a Shift+click on the panel in the preview)
elseif any(sel == id) && numel(sel) > 1   % one of several: they stay selected for a drag
    if id ~= primary
        obj.FigurePanelExtra = [extra(extra ~= id) primary];
        obj.onPanelSelected(j);
    end
    if ~right
        obj.FigureArrangeClick = struct('id', id, 'oldUp', {obj.Fig.WindowButtonUpFcn}, 'alone', true);
        obj.Fig.WindowButtonUpFcn = @(~, ~) released(obj);
    end
else
    many = ~isempty(obj.FigurePanelExtra);
    obj.FigurePanelExtra = strings(1, 0);
    if j ~= obj.SelectedPanel && right
        obj.onPanelSelected(j);   % (no drag follows a right-click: its menu opens)
    elseif j ~= obj.SelectedPanel
        selectLightly(obj, j);   % its box and fields now; the editor's rows when the press ends (finishPendingSelect)
        obj.FigureArrangeClick = struct('id', id, 'oldUp', {obj.Fig.WindowButtonUpFcn}, 'alone', false);
        obj.Fig.WindowButtonUpFcn = @(~, ~) released(obj);   % (a click with no drag: the release ends it here or in onArrangeMoved)
    elseif many
        obj.syncFigureEditor();   % (the editor's rows are this panel's alone again)
    else
        obj.syncArrangeOverlay();
    end
end
obj.FigureArrangeFocus = true;
end


function [shift, right] = clickKind(obj, evt)
%clickKind  Whether the click was a Shift+click or a right-click: the ROI's SelectionType, else the window's modifier keys.
t = "";
if (isstruct(evt) && isfield(evt, 'SelectionType')) || (isobject(evt) && isprop(evt, 'SelectionType'))
    t = string(evt.SelectionType);
end
mods = strings(1, 0);
try
    mods = string(obj.Fig.CurrentModifier);
catch
end
shift = any(t == ["shift" "extend"]) || any(mods == "shift");
right = any(t == ["right" "alt"]);
end


function released(obj)
%released  The mouse button let go after a click on a box and no drag came: a box selected on the press fills the editor; one of several selected is selected alone.
if ~isvalid(obj); return; end
C = obj.FigureArrangeClick;
arrangeClickDone(obj);
if ~isstruct(C) || obj.FigureArrangeMode == "drag"; return; end
if ~C.alone
    finishPendingSelect(obj);   % (the editor's rows are this panel's)
    return
end
obj.FigurePanelExtra = strings(1, 0);
obj.syncFigureEditor();   % (the editor's rows are this panel's alone again; its box alone blue)
end

