function ids = arrangeSelection(obj)
%arrangeSelection  The panels selected in Arrange: the selected panel (the primary, SelectedPanel) first, then the others Shift+click added.
%   IDS = arrangeSelection(OBJ) is a string row of panel ids of the
%   selected figure: its selected panel (the one the editor shows, the
%   last clicked) and FigureArrangeExtra, the panels added to it with
%   Shift+click on their boxes, each once and only those the figure still
%   has. Empty with no figure or no panel selected. A drag of any of them
%   moves them all, a resize resizes them all alike, the arrow keys nudge
%   them all, and a box's Remove panel removes them all; Bring forward,
%   Send back and Set corners act on the primary.
%
%   See also EphysFigGenApp.onArrangeClicked, arrangeGroup.
ids = strings(1, 0);
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures) || isempty(obj.Config.Figures(k).panels); return; end
pids = [obj.Config.Figures(k).panels.id];
j = obj.SelectedPanel;
if j >= 1 && j <= numel(pids); ids = pids(j); end
extra = reshape(string(obj.FigureArrangeExtra), 1, []);
extra = extra(ismember(extra, pids) & ~ismember(extra, ids));
ids = [ids unique(extra, 'stable')];
end
