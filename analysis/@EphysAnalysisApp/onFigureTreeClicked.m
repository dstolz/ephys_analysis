function onFigureTreeClicked(obj, evt)
%onFigureTreeClicked  A click on a node's check box in the figure tree ticks or unticks it.
%   A figure's box enables or disables the figure; a group's unticks all
%   its figures when all are ticked, else ticks them all. A click elsewhere
%   on a node only selects it (onFigureTreeSelected). The boxes are icons
%   (checkIcon), which the tree reports no clicks of, so the click's x is
%   tested against where MATLAB draws a node's icon: BoxLeft pixels from the
%   tree's left edge for a top-level node, Indent more per level down
%   (measured on R2025a; the twisty of a group sits left of its box).
BoxLeft = 19;
Indent = 18;
Slack = 2;   % pixels either side of the 16-pixel icon still count
info = evt.InteractionInformation;
node = info.Node;
if isempty(node); return; end
level = 0;
p = node;
while isa(p, 'matlab.ui.container.TreeNode')
    level = level + 1;
    p = p.Parent;
end
x = info.Location(1) - obj.FiguresTree.Position(1);
left = BoxLeft + Indent * (level - 1);
if x < left - Slack || x > left + 16 + Slack; return; end
if isnumeric(node.NodeData)
    obj.setFiguresEnabled(node.NodeData, "toggle");
elseif ~isempty(node.Children)
    if isequal(node.UserData, "on"); how = "off"; else; how = "on"; end
    obj.setFiguresEnabled([node.Children.NodeData], how);
end
end
