function ids = selectedPanelIds(obj)
%selectedPanelIds  The panels selected in the Figures tab: the selected panel (the primary, SelectedPanel) first, then the others Shift+click added.
%   IDS = selectedPanelIds(OBJ) is a string row of panel ids of the
%   selected figure: its selected panel (the one the editor's rows show,
%   the last clicked) and FigurePanelExtra, the panels added to it with
%   Shift+click on them in the preview or on their boxes in Arrange
%   (togglePanelSelection), each once and only those the figure still
%   has. Empty with no figure or no panel selected. With more than one,
%   the editor shows only the settings they all have, and an edit there
%   goes to all of them (spreadPanelEdit); the preview outlines them all
%   (markFigurePanel). In Arrange a drag of any of them moves them all, a
%   resize resizes them all alike and the arrow keys nudge them all;
%   Remove panel removes them all; Bring forward, Send back and Set
%   corners act on the primary.
%
%   See also togglePanelSelection, spreadPanelEdit, EphysFigGenApp.onArrangeClicked, arrangeGroup.
ids = strings(1, 0);
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures) || isempty(obj.Config.Figures(k).panels); return; end
pids = [obj.Config.Figures(k).panels.id];
j = obj.SelectedPanel;
if j >= 1 && j <= numel(pids); ids = pids(j); end
extra = reshape(string(obj.FigurePanelExtra), 1, []);
extra = extra(ismember(extra, pids) & ~ismember(extra, ids));
ids = [ids unique(extra, 'stable')];
end
