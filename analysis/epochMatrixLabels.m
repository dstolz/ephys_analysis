function L = epochMatrixLabels(R)
%epochMatrixLabels  Axis labels, legend text and a description of an epochMatrix result, in words.
%   L = epochMatrixLabels(R) describes the result R of epochMatrix (or of
%   DatasetBrowser, B.Result) from its settings, group labels and value
%   unit, so a script need not spell them out. epochMatrix stores it as
%   R.labels; DatasetBrowser refreshes it on a result it restores.
%
%   Fields of L (strings; groups is a column)
%     value        the axis or color-bar label of R.data: "Firing rate
%                  (spikes/s)", "Spike count (spikes/bin)", "auROC vs.
%                  baseline"; signals "LFP, mean over epochs (uV)", with
%                  "Rectified " or " magnitude" when those options are on
%     measure      the quantity without its unit, for titles: "Firing
%                  rate", "Spike count", "auROC", "LFP mean", ...
%     time         the label of R.t: "Time from Stim onset (s)", from the
%                  event the epochs are aligned to (eventRef.alignStep)
%     event        the whole event reference (eventRefLabel): "Stim onset
%                  then Platform offset"
%     group        the groupBy parameters, "Depth" or "Depth, Level" (""
%                  without groupBy)
%     groups       a label per group of R.groupLabels, in its order:
%                  "Depth 3" for one parameter, the label itself ("Depth =
%                  3, Level = 2") for several, "All trials" without groupBy
%     rows         what a row of R.data is, plural: "units", "detected
%                  channels", "LFP channels", "AUX magnitudes"
%     trials       the trials kept: "Hit trials", "Hit or Miss trials
%                  where Depth > 0", "all trials"
%     window       the epoch window: "-1 to 1 s"
%     bins         "10 ms bins" (spikes; "" for signals)
%     baseline     the auROC's baseline or the signal's subtracted one:
%                  "baseline -1 to -0.5 s" ("" without one)
%     description  one line of the above, for a subtitle or a caption:
%                  "Firing rate of units in 10 ms bins, -1 to 1 s from Stim
%                  onset; Hit trials by Depth (descending)"
%
%   Example
%     R = B.Result;
%     imagesc(R.t, 1:height(R.rows), R.data(:, :, 1));
%     xlabel(R.labels.time); title(R.labels.groups(1)); subtitle(R.labels.description)
%     cb = colorbar; cb.Label.String = R.labels.value;
%
%   See also epochMatrix, epochMatrixSettings, eventRefLabel, DatasetBrowser.

S = R.settings;
spikes = ismember(S.data, ["units" "detected"]);
vu = string(R.valueUnits);

% --- the values
if spikes
    switch S.measure
        case "rate";  L.measure = "Firing rate";
        case "count"; L.measure = "Spike count";
        case "auroc"; L.measure = "auROC";
    end
    if S.measure == "auroc"
        L.value = "auROC vs. baseline";
    else
        L.value = withUnit(L.measure, vu);
    end
else
    sig = S.signal;
    what = S.data;
    if sig.magnitude; what = what + " magnitude"; end
    if sig.rectify; what = "Rectified " + what; end
    L.measure = what + " " + sig.statistic;
    L.value = withUnit(what + ", " + sig.statistic + " over epochs", vu);
end

% --- time and event
L.time = "Time from " + alignedEvent(S.ref) + " (s)";
L.event = eventRefLabel(S.ref);

% --- groups
by = S.selection.groupBy;
L.group = strjoin(by, ", ");
gl = R.groupLabels(:);
if isempty(by)
    L.groups = repmat("All trials", numel(gl), 1);
elseif isscalar(by)
    L.groups = by + " " + labelText(gl);
else
    L.groups = labelText(gl);
end

% --- rows, trials, window, bins, baseline
switch S.data
    case "units";    L.rows = "units";
    case "detected"; L.rows = "detected channels";
    otherwise
        L.rows = S.data + " channels";
        if S.signal.magnitude; L.rows = S.data + " magnitudes"; end
end
L.trials = trialsText(S.selection);
L.window = string(sprintf('%g to %g s', S.window.pre, S.window.post));
L.bins = "";
if spikes; L.bins = string(sprintf('%g ms bins', S.binSec * 1000)); end
L.baseline = "";
if spikes && S.measure == "auroc"
    L.baseline = string(sprintf('baseline %g to %g s', S.baseline));
elseif ~spikes && ~isempty(S.signal.baseline)
    L.baseline = string(sprintf('baseline %g to %g s subtracted', S.signal.baseline));
end

% --- one line
d = L.measure + " of " + L.rows;
if L.bins ~= ""; d = d + " in " + L.bins; end
d = d + ", " + L.window + " from " + L.event;
if L.baseline ~= ""; d = d + ", " + L.baseline; end
d = d + "; " + L.trials;
if ~isempty(by); d = d + " by " + L.group + " (" + S.selection.groupOrder + ")"; end
L.description = d;

L = orderfields(L, ["value" "measure" "time" "event" "group" "groups" "rows" "trials" "window" "bins" ...
    "baseline" "description"]);
end


function s = withUnit(name, unit)
s = name;
if unit ~= ""; s = name + " (" + unit + ")"; end
end

function s = alignedEvent(ref)
%alignedEvent  The line and edge of the event the epochs are aligned to (eventRef.alignStep).
s = ref.line + " " + ref.edge;
steps = ref.sequence;
if isempty(steps); return; end
a = ref.alignStep;
if isinf(a)
    a = find([steps.relation] == "followedBy", 1, 'last');
    if isempty(a); a = 0; end
end
if a >= 1; s = steps(a).line + " " + steps(a).edge; end
end

function s = labelText(v)
if isnumeric(v)
    s = string(arrayfun(@(x) sprintf('%g', x), v, 'UniformOutput', false));
else
    s = string(v);
end
end

function s = trialsText(sel)
s = "all trials";
if ~isempty(sel.response); s = strjoin(sel.response, " or ") + " trials"; end
if sel.filter ~= ""; s = s + " where " + sel.filter; end
if ~isempty(sel.trials); s = s + sprintf(' (%d chosen)', numel(sel.trials)); end
end
