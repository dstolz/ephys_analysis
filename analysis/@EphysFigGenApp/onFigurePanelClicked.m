function onFigurePanelClicked(obj, id, panel, ctrl, fromWindow, shift)
%onFigurePanelClicked  A Ctrl+Click on a drawn panel of figure ID: select that panel and go to its section in the figure editor (Shift+Click: add it to the selected panels, or take it out).
%   onFigurePanelClicked(OBJ, ID, PANEL, CTRL, FROMWINDOW, SHIFT) is
%   renderFigure's OnSelect, for the preview and for Open in window. PANEL
%   is the id of the panel clicked; CTRL is whether the figure saw Ctrl
%   (Cmd) down at the click, SHIFT whether it saw Shift. A Ctrl+Click
%   reports the "alt" button, as a right-click does (which opens the
%   aesthetics menu): the click counts only with CTRL, SHIFT or the app's
%   own record of the key (CtrlHeld: onKeyPress), so a right-click is
%   left to its menu. The figure (when the click is in a window of its
%   own, the app comes to the front and the Figures tab shows) and the
%   panel are selected (onFigureSelected, onPanelSelected: the editor
%   shows it, the preview outlines it), then the editor scrolls to the
%   Panel section (gotoFigureSection: opened if collapsed).
%   A Ctrl+Click selects the panel alone (the panels Shift+Click added are
%   let go). A Shift+Click (with Ctrl or not) on a panel of the figure
%   selected adds it to the selected panels or takes it out
%   (togglePanelSelection): the editor then shows the settings they all
%   have, an edit there goes to all of them (spreadPanelEdit), and the
%   preview outlines each one; on a panel of another figure it selects
%   that figure and the panel alone.
%   Picking a panel is not an edit: nothing is recorded in the undo
%   history, and the Ctrl held for the click does not open Apply to
%   figures (that follows an edit made with Ctrl down; this makes none).
%
%   See also renderFigure, onPanelSelected, togglePanelSelection, gotoFigureSection, gotoFigureSetting.
arguments
    obj (1,1) EphysFigGenApp
    id (1,1) string
    panel (1,1) string
    ctrl (1,1) logical = true
    fromWindow (1,1) logical = false
    shift (1,1) logical = false
end
if ~(ctrl || shift || obj.CtrlHeld); return; end
if obj.Running; return; end
k = obj.Config.figureIndex(followedFigureId(obj, id));
if k < 1; return; end
p = [];
if ~isempty(obj.Config.Figures(k).panels); p = find([obj.Config.Figures(k).panels.id] == panel, 1); end
if isempty(p); return; end
if fromWindow
    try figure(obj.Fig); catch; end   % the window is one of its own: the app comes to the front
    if obj.Tabs.SelectedTab ~= obj.TabFigures; obj.selectTab(obj.TabFigures); end
end
if shift && k == obj.SelectedFigure
    togglePanelSelection(obj, obj.Config.Figures(k).panels(p).id);
    obj.gotoFigureSection("panel");
    return
end
if k ~= obj.SelectedFigure; obj.onFigureSelected(k); end
many = ~isempty(obj.FigurePanelExtra);
obj.FigurePanelExtra = strings(1, 0);   % a Ctrl+Click selects the panel alone
if p ~= obj.SelectedPanel
    obj.onPanelSelected(p);
elseif many
    obj.syncFigureEditor();   % (the rows are this panel's alone again; one outline)
    obj.setStatus("Selected " + obj.Config.Figures(k).panels(p).id + ".");
end
obj.gotoFigureSection("panel");
end
