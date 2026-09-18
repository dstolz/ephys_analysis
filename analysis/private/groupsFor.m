function G = groupsFor(E, G)
%groupsFor  The groups table for epochs E: the one given, or one built from E.
%   G must have index, label and color and a row for every E.groupIndex;
%   without one, labels come from E.group and colours from groupColors.

nG = max([0; E.groupIndex(:)]);
if istable(G) && all(ismember(["index" "label" "color"], string(G.Properties.VariableNames))) && height(G) >= nG
    return
end
index = (1:nG).';
label = "group " + index;
if ismember("group", string(E.Properties.VariableNames))
    for g = 1:nG
        k = find(E.groupIndex == g, 1);
        if ~isempty(k); label(g) = string(E.group(k)); end
    end
end
if nG == 1
    color = [0.15 0.15 0.15];
else
    color = groupColors(index, false);
end
n = accumarray(E.groupIndex(:), 1, [nG 1]);
G = table(index, label, color, n);
end
