function refreshFigureList(obj)
%refreshFigureList  The figure tree: the figures under groups, as Group by says.
%   A leaf reads "<id>  (<n> panels)" under groups by what the figures
%   observe (the group says the rest), else "<id>  (<n> panels, per
%   <observation kind>)" (observeKind of its observe.data); disabled
%   figures add "  (off)" but under groups by status. Each node has a check
%   box (an icon, checkIcon): a figure's is ticked while it is enabled, a
%   group's when all its figures are, "mixed" when some. When the groups
%   and their figures are as the tree shows them, only the texts, the boxes
%   and the selection are updated (this runs on every edit); otherwise the
%   tree is rebuilt, the groups the user collapsed (FigureGroupsCollapsed)
%   staying collapsed. The selected figure (SelectedFigure) is the tree's
%   selection, its group expanded, scrolled to. The preview then shows
%   the selected figure's own container (syncFigureView: the tree drives
%   it), and the nodes are marked: the figure shown in bold, each
%   figure's preview out of date, failed or not drawn by its color
%   (markFigureTree).
F = obj.Config.Figures;
tree = obj.FiguresTree;
by = string(obj.FigureGroupDropDown.Value);
[keys, labels, members] = figureGroups(F, by);
[oldKeys, oldMembers] = treeStructure(tree);
on = false(1, 0);
if ~isempty(F); on = [F.enabled]; end
if isequal(oldKeys, keys) && isequal(oldMembers, members)
    leaves = leafNodes(tree);
    for i = 1:numel(leaves)
        text = leafText(F(leaves(i).NodeData), by);
        if ~strcmp(leaves(i).Text, text); leaves(i).Text = text; end
    end
    if by ~= "none"
        for g = 1:numel(keys)
            text = sprintf("%s  (%d)", labels(g), numel(members{g}));
            if ~strcmp(tree.Children(g).Text, text); tree.Children(g).Text = text; end
        end
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
            uitreenode(parent, "Text", leafText(F(k), by), "NodeData", k);
        end
        if ~flat && ~ismember(keys(g), obj.FigureGroupsCollapsed)
            expand(parent);
        end
    end
end
for node = reshape(tree.Children, 1, [])   % the check boxes: a figure's own state, a group's all / some / none
    if isnumeric(node.NodeData)
        setCheck(node, on(node.NodeData));
    else
        for leaf = reshape(node.Children, 1, [])
            setCheck(leaf, on(leaf.NodeData));
        end
        setCheck(node, on([node.Children.NodeData]));
    end
end
leaves = leafNodes(tree);
k = obj.SelectedFigure;
if isempty(leaves) || k < 1 || k > numel(F)
    tree.SelectedNodes = [];
    showView(obj);
    return
end
want = leaves([leaves.NodeData] == k);
if isempty(want); showView(obj); return; end
if isempty(tree.SelectedNodes) || ~isequal(tree.SelectedNodes(1).NodeData, k)
    tree.SelectedNodes = want;
    if isa(want.Parent, 'matlab.ui.container.TreeNode')
        obj.FigureGroupsCollapsed(obj.FigureGroupsCollapsed == want.Parent.NodeData) = [];
        expand(want.Parent);
    end
    scroll(tree, want);
end
showView(obj);
end


function showView(obj)
%showView  The selected figure's preview container shown (syncFigureView), the nodes marked (markFigureTree).
obj.syncFigureView();
markFigureTree(obj);
end


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


function text = leafText(f, by)
%leafText  A figure's node: "<id>  (<n> panels)", the observation kind unless the group says it, "(off)" unless it does.
m = numel(f.panels);
what = sprintf("%d panel%s", m, repmat('s', 1, m ~= 1));
if by ~= "observe"
    what = what + ", per " + EphysAnalysisConfig.observeKind(f);
end
text = char(f.id + "  (" + what + ")");
if ~f.enabled && by ~= "status"
    text = [text '  (off)'];
end
end


function [keys, members] = treeStructure(tree)
%treeStructure  The group keys and the figure indices under each, as the tree stands.
%   Same shapes as figureGroups; a flat tree is one group with key "".
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
%leafNodes  The figure nodes of the tree, top to bottom.
top = tree.Children;
if isempty(top) || isnumeric(top(1).NodeData)
    leaves = top;
else
    leaves = vertcat(top.Children);
end
end
