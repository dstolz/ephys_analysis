function [labels, name] = rowLabels(R)
%rowLabels  Each group's value (its groupBy columns) and the parameter names: a stack's row labels.
%   [LABELS, NAME] = rowLabels(R) for a result R with groups (a spikePSTH,
%   evokedPotential or Chronux result). The parameters
%   are the trial selection's groupBy (R.epochs' UserData, from
%   epochTable); a result without it (put together by hand) takes the
%   group table's columns other than its bookkeeping (index, label, color,
%   n, nTrials). A group table without the groupBy columns (a Chronux
%   result's): its labels, named by the parameters. Without any: the group
%   labels, and "Group". A result
%   merged across sessions (combineSessions: R.sessions) has series, not
%   trial groups, as its rows: their labels, named by what they are
%   ("Session", "Subject"; combine: "Session · trial group"). Used by
%   every stacked panel (drawStack and the line and image stacks) and a
%   firing rate panel's x axis.
%
%   See also drawStack, drawPsthPanel.
G = R.groups;
vars = string(G.Properties.VariableNames);
if isfield(R, 'sessions') && istable(R.sessions)
    labels = string(G.label);
    name = "Group";
    if isfield(R, 'sessionSeries') && isfield(R.sessionSeries, 'mode')
        switch R.sessionSeries.mode
            case "session", name = "Session";
            case "subject", name = "Subject";
        end
    end
    if ismember("lineStyle", vars)
        if name == "Group"; name = "Trial group"; else; name = name + " · trial group"; end
    end
    return
end
extra = string.empty(1, 0);
if isfield(R, 'epochs') && istable(R.epochs) && isfield(R.epochs.Properties.UserData, 'selection')
    extra = R.epochs.Properties.UserData.selection.groupBy;
end
if isempty(extra)
    extra = setdiff(vars, ["index" "label" "color" "n" "nTrials"], 'stable');
end
named = extra;
extra = extra(ismember(extra, vars));
if isempty(extra)   % the group table lacks the parameters (a Chronux result's): its labels, named by the parameters
    labels = string(G.label);
    name = "Group";
    if ~isempty(named); name = strjoin(named, ", "); end
    return
end
parts = strings(height(G), numel(extra));
for j = 1:numel(extra)
    v = G.(extra(j));
    if isnumeric(v) || islogical(v)
        parts(:, j) = compose("%.6g", double(v));
    else
        parts(:, j) = string(v);
    end
end
parts(ismissing(parts)) = "<missing>";
labels = join(parts, ", ", 2);
name = strjoin(extra, ", ");
end
