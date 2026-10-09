function refreshPlotList(obj)
%refreshPlotList  The plot tree: the plots under groups, as Group by says.
%   A leaf reads "<id>  (<source>)" under plot-type groups, else
%   "<id>  (<kind>)"; disabled plots add "(off)". When the groups and their
%   plots are as the tree shows them, only the texts and the selection are
%   updated (this runs on every edit); otherwise the tree is rebuilt, the
%   groups the user collapsed (PlotGroupsCollapsed) staying collapsed.
P = obj.Config.Plots;
tree = obj.PlotsTree;
by = string(obj.PlotGroupDropDown.Value);
[keys, labels, members] = plotGroups(P, by);
[oldKeys, oldMembers] = treeStructure(tree);
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
if isempty(leaves)
    tree.SelectedNodes = [];
    return
end
want = leaves([leaves.NodeData] == obj.SelectedPlot);
if ~isempty(want) && ~isequal(tree.SelectedNodes, want)
    tree.SelectedNodes = want;
    if isa(want.Parent, 'matlab.ui.container.TreeNode')
        obj.PlotGroupsCollapsed(obj.PlotGroupsCollapsed == want.Parent.NodeData) = [];
        expand(want.Parent);
    end
    scroll(tree, want);
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
