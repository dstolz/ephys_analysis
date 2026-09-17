function refreshTrialsPlot(obj)
%refreshTrialsPlot  The Trials tab's plot of the digital lines from TrialsPairing.
%   One bar per event, from its onset to its offset with the polarity applied
%   (an inverted line's bars run from each falling edge to the next rising
%   edge). The trial line's bars are coloured by pairing state, and dotted
%   lines across every row mark its onsets and offsets. Each paired trial can
%   carry a text label above the trial line, starting at its onset, with its
%   values of the Epsych2 parameters in TrialsLabelParams that the session
%   has: the value alone for one parameter, name=value for several. The
%   plot's context menu shows or hides the onset / offset lines, the grid
%   lines and the labels (onTrialsPlotMenu).
ax = obj.TrialsAxes;
delete(allchild(ax));   % not cla: it leaves the objects kept out of the legend
legend(ax, "off");
P = obj.TrialsPairing;
if isempty(P)
    return
end

E = P.events;
names = [P.trialLine, setdiff(string(fieldnames(E)).', P.trialLine, 'stable')];
nL = numel(names);
iv = P.intervals;
nI = size(iv, 1);
state = repmat("unpaired", nI, 1);
state(P.interval(~isnan(P.interval))) = "ok";
state(P.partialIntervals) = "partial";
isCut = false(nI, 1);
isCut(1:P.cutIntervals(1)) = true;
isCut(nI - P.cutIntervals(2) + 1:nI) = true;
state(isCut) = "cut";
colors = struct('ok', [0 0.45 0.74], 'partial', [0.85 0.5 0], 'cut', [0.55 0.55 0.55], 'unpaired', [0.8 0.1 0.1]);
labels = struct('ok', "paired", 'partial', "partial (recording edge)", 'cut', "cut", 'unpaired', "unpaired");
[trialText, labelParams] = trialLabels(obj, P);
labelled = find(~isnan(P.onset) & trialText ~= "");
yTop = nL + 0.6 + 0.5 * ~isempty(labelled);   % head room for the labels
hold(ax, "on");
if nI > 0
    t = reshape(iv.', [], 1);
    x = [t t NaN(size(t))].';
    y = repmat([0.4; yTop; NaN], 1, numel(t));
    plot(ax, x(:), y(:), ":", "Color", [0.6 0.6 0.6], "LineWidth", 0.5, "HandleVisibility", "off", ...
        "Visible", obj.TrialsEdgesMenu.Checked, "Tag", "trialEdges", "ContextMenu", ax.ContextMenu);
end
for st = ["ok" "partial" "cut" "unpaired"]
    k = find(state == st);
    if ~isempty(k)
        segments(ax, iv(k, :), nL, colors.(st), 8, labels.(st), P.trialLine);
    end
end
for j = 2:nL
    segments(ax, E.(names(j)), nL - j + 1, [0.4 0.4 0.4], 5, "", names(j));
end
if ~isempty(labelled)
    text(ax, P.onset(labelled), repmat(nL + 0.25, numel(labelled), 1), cellstr(trialText(labelled)), ...
        "FontSize", 8, "Color", [0.25 0.25 0.25], "HorizontalAlignment", "left", ...
        "VerticalAlignment", "bottom", "Interpreter", "none", "Clipping", "on", ...
        "PickableParts", "none", "Tag", "trialLabels");
end
hold(ax, "off");
tEnd = max([P.nSamples / P.Fs, iv(:).', 1]);
xlim(ax, [0 tEnd]);
ylim(ax, [0.4 yTop]);
yticks(ax, 1:nL);
rowLabels = names;
isInverted = ismember(names, P.invertedLines);
rowLabels(isInverted) = rowLabels(isInverted) + " (inverted)";
yticklabels(ax, cellstr(flip(rowLabels)));
if nI > 0
    legend(ax, "Location", "eastoutside");
end
ttl = string(sprintf("Digital lines over the recording (%s: %d interval(s), %d trial(s)", P.trialLine, nI, P.nTrials));
if ~isempty(labelled)
    ttl = ttl + "; labels: " + strjoin(labelParams, ", ");
end
title(ax, ttl + ")");
end


function segments(ax, iv, y, color, width, name, lineName)
%segments  Draw [k x 2] events (s) as bars from onset to offset at height Y.
if isempty(iv); return; end
x = [iv(:, 1), iv(:, 2), NaN(size(iv, 1), 1)].';
yy = y * ones(size(x));
h = plot(ax, x(:), yy(:), "-", "Color", color, "LineWidth", width, "Tag", "events:" + lineName, ...
    "ContextMenu", ax.ContextMenu);
if name == ""
    h.HandleVisibility = "off";
else
    h.DisplayName = name;
end
end


function [lbl, params] = trialLabels(obj, P)
%trialLabels  One label per trial (text, "" = none) and the parameters it shows.
lbl = strings(P.nTrials, 1);
params = string.empty(1, 0);
S = obj.TrialsSession;
if ~istable(S) || height(S) ~= P.nTrials
    return
end
params = obj.TrialsLabelParams(ismember(obj.TrialsLabelParams, string(S.Properties.VariableNames)));
if isempty(params)
    return
end
parts = strings(P.nTrials, numel(params));
for j = 1:numel(params)
    parts(:, j) = valueTexts(S.(params(j)));
    if numel(params) > 1
        parts(:, j) = params(j) + "=" + parts(:, j);
    end
end
lbl = join(parts, ", ", 2);
end


function s = valueTexts(v)
%valueTexts  One text per trial (row) of a session column; numbers as %g.
s = strings(size(v, 1), 1);
for i = 1:size(v, 1)
    x = v(i, :);
    if iscell(x) && isscalar(x)
        x = x{1};
    end
    if isnumeric(x)
        x = compose("%g", double(x));
    end
    try
        s(i) = strjoin(reshape(string(x), 1, []), " ");
    catch
        s(i) = "[" + strjoin(string(size(x)), "x") + " " + class(x) + "]";
    end
end
end
