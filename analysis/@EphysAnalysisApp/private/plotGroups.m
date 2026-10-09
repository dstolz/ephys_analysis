function [keys, labels, members] = plotGroups(P, by)
%plotGroups  The groups of the plot tree: the plots P sorted into groups by BY.
%   BY: "kind" (plot type), "source", "layout" (the layout drawn), "status"
%   (enabled / off) or "none" (one flat group). KEYS(g) names group g
%   ("<by>:<label>", "" when flat), LABELS(g) is what the node says, and
%   MEMBERS{g} the indices into P of its plots, in P's order (the run
%   order). Groups follow a fixed order where there is one (the kinds', the
%   sources', enabled before off), else the order they first appear in.
keys = strings(1, 0);
labels = strings(1, 0);
members = {};
n = numel(P);
if n == 0
    return
end
if by == "none"
    keys = "";
    labels = "";
    members = {1:n};
    return
end
K = EphysAnalysisConfig.plotKinds();
val = strings(1, n);
switch by
    case "kind"
        canon = K.Label.';
        for k = 1:n
            row = K.Kind == P(k).kind;
            val(k) = P(k).kind;
            if any(row); val(k) = K.Label(row); end
        end
    case "source"
        canon = ["units" "detected" "LFP" "MUA" "SPIKE" "AUX" "trials"];
        for k = 1:n
            val(k) = P(k).source;
        end
    case "layout"
        canon = strings(1, 0);
        for k = 1:n
            val(k) = P(k).layout;
            row = K.Kind == P(k).kind;
            if val(k) == "" && any(row); val(k) = K.DefaultLayout(row); end
        end
    case "status"
        canon = ["Enabled" "Off"];
        val(:) = "Off";
        val([P.enabled]) = "Enabled";
    otherwise
        error('EphysAnalysisApp:BadGrouping', 'Unknown plot grouping "%s".', by);
end
order = [canon(ismember(canon, val)), setdiff(unique(val, 'stable'), canon, 'stable')];
for g = 1:numel(order)
    keys(g) = by + ":" + order(g);
    labels(g) = order(g);
    members{g} = find(val == order(g)); %#ok<AGROW>
end
end
