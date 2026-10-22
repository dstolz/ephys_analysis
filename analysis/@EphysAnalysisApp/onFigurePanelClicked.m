function onFigurePanelClicked(obj, id, panel, ctrl, fromWindow)
%onFigurePanelClicked  A Ctrl+Click on a drawn panel of figure ID: select that panel and go to its section in the figure editor.
%   onFigurePanelClicked(OBJ, ID, PANEL, CTRL, FROMWINDOW) is renderFigure's
%   OnSelect, for the preview and for Open in window. PANEL is the id of the
%   panel clicked; CTRL is whether the figure saw Ctrl (Cmd) down at the
%   click. A Ctrl+Click reports the "alt" button, as a right-click does
%   (which opens the aesthetics menu): the click counts only with CTRL or
%   with the app's own record of the key (CtrlHeld: onKeyPress), so a
%   right-click is left to its menu. The figure (when the click is in a
%   window of its own, the app comes to the front and the Figures tab
%   shows) and the panel are selected as a click on the panel in the
%   arrangement's schematic does (onFigureSelected, onPanelSelected: the
%   editor shows it, the preview outlines it), then the editor scrolls to
%   the Selected panel section (gotoFigureSection: opened if collapsed).
%   Picking a panel is not an edit: nothing is recorded in the undo
%   history, and the Ctrl held for the click does not open Apply to
%   figures (that follows an edit made with Ctrl down; this makes none).
%
%   See also renderFigure, onPanelSelected, gotoFigureSection, gotoFigureSetting.
arguments
    obj (1,1) EphysAnalysisApp
    id (1,1) string
    panel (1,1) string
    ctrl (1,1) logical = true
    fromWindow (1,1) logical = false
end
if ~(ctrl || obj.CtrlHeld); return; end
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
if k ~= obj.SelectedFigure; obj.onFigureSelected(k); end
if p ~= obj.SelectedPanel; obj.onPanelSelected(p); end
obj.gotoFigureSection("panel");
end
