function markFigureTree(obj)
%markFigureTree  Mark the figure tree: the figure in the editor in bold, each figure's preview by its color.
%   A figure's node is styled (uistyle on the node) by figureViewFresh's
%   look of its preview: as is when its kept preview is current ("fresh"),
%   amber italic when it is out of date ("stale": drawn from figures,
%   defaults, a dataset or an observation since changed, or Out of date,
%   canceled, waiting for Preview, computing), red when it failed, gray
%   when it is not drawn ("none": never shown, dropped by the cap, or the
%   dataset cannot draw it). The selected figure (SelectedFigure, the one
%   the editor shows; its preview follows once a running one is done) is
%   bold besides. The styles are made again only when a node's mark
%   changed (FigureTreeMarks keeps them as applied). Called by
%   refreshFigureList (every selection or change of the figures) and
%   setFigurePreviewState (every change of the badge).
%
%   See also figureViewFresh, refreshFigureList, syncFigureView.
tree = obj.FiguresTree;
if isempty(tree) || ~isvalid(tree); return; end
top = tree.Children;
if isempty(top) || isnumeric(top(1).NodeData)
    leaves = top;
else
    leaves = vertcat(top.Children);
end
leaves = reshape(leaves, 1, []);
n = numel(obj.Config.Figures);
look = strings(1, numel(leaves));
current = false(1, numel(leaves));
for i = 1:numel(leaves)
    k = leaves(i).NodeData;
    if ~isnumeric(k) || k < 1 || k > n; look(i) = "none"; continue; end
    [~, look(i)] = figureViewFresh(obj, k);
    current(i) = k == obj.SelectedFigure;
end
M = struct('nodes', leaves, 'look', look, 'current', current);
if isequal(obj.FigureTreeMarks, M); return; end
removeStyle(tree);
colors = struct('stale', [0.70 0.42 0.00], 'failed', [0.70 0.15 0.10], 'none', [0.50 0.50 0.50]);
for s = ["stale" "failed" "none"]
    on = look == s;
    if ~any(on); continue; end
    st = uistyle("FontColor", colors.(s));
    if s == "stale"; st.FontAngle = "italic"; end
    addStyle(tree, st, "node", leaves(on));
end
if any(current)
    addStyle(tree, uistyle("FontWeight", "bold"), "node", leaves(current));
end
obj.FigureTreeMarks = M;
end
