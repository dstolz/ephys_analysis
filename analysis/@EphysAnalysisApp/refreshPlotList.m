function refreshPlotList(obj)
%refreshPlotList  The plot tree: the plots under groups, as Group by says.
%   A leaf reads "<id>  (<source>)" under plot-type groups, else
%   "<id>  (<kind>)"; disabled plots add "(off)". Each node has a check box
%   (an icon, checkIcon): a plot's is ticked while it is enabled, a group's
%   when all its plots are, "mixed" when some. When the groups and their
%   plots are as the tree shows them, only the texts and the selection are
%   updated (this runs on every edit); otherwise the tree is rebuilt, the
%   groups the user collapsed (PlotGroupsCollapsed) staying collapsed. The
%   plots selected (selectedPlots) are the tree's selection, their groups
%   expanded, scrolled to the one in the editor.
P = obj.Config.Plots;
tree = obj.PlotsTree;
by = string(obj.PlotGroupDropDown.Value);
[keys, labels, members] = plotGroups(P, by);
[oldKeys, oldMembers] = treeStructure(tree);
on = [P.enabled];
if isequal(oldKeys, keys) && isequal(oldMembers, members)
    leaves = leafNodes(tree);
    for i = 1:numel(leaves)
        text = leafText(P(leaves(i).NodeData), by);
        if ~strcmp(leaves(i).Text, text); leaves(i).Text = text; end
    end
else
    delete(tree.Children);
    flat = by == "none";
    for g = 1:numel(keys)
        if flat
            parent = tree;
        else
            parent = uitreenode(tree, "Text", sprintf("%s  (%d)", labels(g), numel(members{g})), "NodeData", keys(g));
        end
        for k = members{g}
            uitreenode(parent, "Text", leafText(P(k), by), "NodeData", k);
        end
        if ~flat && ~ismember(keys(g), obj.PlotGroupsCollapsed)
            expand(parent);
        end
    end
end
leaves = leafNodes(tree);
for node = reshape(tree.Children, 1, [])   % the check boxes: a plot's own state, a group's all / some / none
    if isnumeric(node.NodeData)
        setCheck(node, on(node.NodeData));
    else
        for leaf = reshape(node.Children, 1, [])
            setCheck(leaf, on(leaf.NodeData));
        end
        setCheck(node, on([node.Children.NodeData]));
    end
end
obj.refreshPlotFilter();
if isempty(leaves)
    tree.SelectedNodes = [];
    return
end
ks = obj.selectedPlots();
want = leaves(ismember([leaves.NodeData], ks));
if ~isempty(want) && ~isequal(sort(plotsIn(tree.SelectedNodes)), sort(ks))
    tree.SelectedNodes = want;
    for w = reshape(want, 1, [])
        if isa(w.Parent, 'matlab.ui.container.TreeNode')
            obj.PlotGroupsCollapsed(obj.PlotGroupsCollapsed == w.Parent.NodeData) = [];
            expand(w.Parent);
        end
    end
    scroll(tree, want([want.NodeData] == ks(1)));
end
end


function ks = plotsIn(nodes)
function setCheck(node, enabled)
%setCheck  NODE's check box: ticked when all of ENABLED are true, empty when none, "mixed" between.
if all(enabled)
    state = "on";
elseif ~any(enabled)
    state = "off";
else
    state = "mixed";
end
if ~isequal(node.UserData, state)   % the icon is the state's, so it changes only with it
    node.Icon = checkIcon(state);
    node.UserData = state;
end
end


%plotsIn  The plot indices of NODES; NaN for a group's header (so a header picked counts as a change).
ks = zeros(1, 0);
for n = reshape(nodes, 1, [])
    if isnumeric(n.NodeData); ks(end+1) = n.NodeData; else; ks(end+1) = NaN; end %#ok<AGROW>
end
end


function text = leafText(p, by)
if by == "kind"
    second = p.source;
else
    second = p.kind;
end
text = char(p.id + "  (" + second + ")");
if ~p.enabled && by ~= "status"
    text = [text '  (off)'];
end
end


function [keys, members] = treeStructure(tree)
%treeStructure  The group keys and the plot indices under each, as the tree stands.
%   Same shapes as plotGroups; a flat tree is one group with key "".
keys = strings(1, 0);
members = {};
top = tree.Children;
if isempty(top)
    return
end
if isnumeric(top(1).NodeData)
    keys = "";
    members = {reshape([top.NodeData], 1, [])};
    return
end
for g = 1:numel(top)
    keys(g) = top(g).NodeData;
    members{g} = reshape([top(g).Children.NodeData], 1, []); %#ok<AGROW>
end
end


function leaves = leafNodes(tree)
%leafNodes  The plot nodes of the tree, top to bottom.
top = tree.Children;
if isempty(top) || isnumeric(top(1).NodeData)
    leaves = top;
else
    leaves = vertcat(top.Children);
end
end
