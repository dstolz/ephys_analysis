function [keys, labels, members] = figureGroups(F, by)
%figureGroups  The groups of the figure tree: the figures F sorted into groups by BY.
%   BY: "observe" (what each figure is drawn for: a unit, a channel or the
%   dataset, EphysAnalysisConfig.observeKind; a figure across sessions by
%   its observation too), "status" (enabled / off) or "none" (one flat
%   group). KEYS(g) names group g ("<by>:<value>", "" when flat), LABELS(g)
%   is what its node says, and MEMBERS{g} the indices into F of its
%   figures, in F's order (the run order). Groups follow a fixed order
%   (unit, channel, dataset; enabled before off) and only those with a
%   figure are listed.
keys = strings(1, 0);
labels = strings(1, 0);
members = {};
n = numel(F);
if n == 0
    return
end
if by == "none"
    keys = "";
    labels = "";
    members = {1:n};
    return
end
val = strings(1, n);
switch by
    case "observe"
        canon = ["unit" "channel" "dataset"];
        names = ["Per unit" "Per channel" "Per dataset"];
        for k = 1:n
            val(k) = EphysAnalysisConfig.observeKind(F(k));
        end
    case "status"
        canon = ["Enabled" "Off"];
        names = canon;
        val(:) = "Off";
        val([F.enabled]) = "Enabled";
    otherwise
        error('EphysAnalysisApp:BadGrouping', 'Unknown figure grouping "%s".', by);
end
order = [canon(ismember(canon, val)), setdiff(unique(val, 'stable'), canon, 'stable')];
for g = 1:numel(order)
    keys(g) = by + ":" + order(g);
    i = find(canon == order(g), 1);
    labels(g) = order(g);
    if ~isempty(i); labels(g) = names(i); end
    members{g} = find(val == order(g)); %#ok<AGROW>
end
end
