function onStopKSRuns(obj)
%onStopKSRuns  Ask which running Kilosort4 runs to stop, then stop them.
%   The Run tab's Stop runs... button. With one run going, a confirmation;
%   with several, a list of them (dataset, GPU, minutes running), all
%   selected at first. The chosen runs go to stopKSRuns. What a stopped
%   run wrote so far stays in its folder.
%
%   See also stopKSRuns, onStopKSQueue.

running = obj.KSRuns(~[obj.KSRuns.done]);
if isempty(running)
    return
end
labels = arrayfun(@runLabel, running);
if isscalar(running)
    answer = uiconfirm(obj.Fig, "Stop Kilosort4 on " + labels + "?" + newline + newline + ...
        "What it has written so far stays in its folder, and its row turns ""cancelled"".", ...
        "Stop a Kilosort4 run", "Options", ["Stop", "Keep running"], ...
        "DefaultOption", 2, "CancelOption", 2, "Icon", "warning");
    if answer == "Stop"
        obj.stopKSRuns(running.Name);
    end
    return
end
pick = pickRuns(obj.Fig, labels);
if ~isempty(pick)
    obj.stopKSRuns([running(pick).Name]);
end
end


function t = runLabel(r)
%runLabel  "name (cuda:1), 12 min" for one run.
t = r.Name;
if r.device ~= ""
    t = t + " (" + r.device + ")";
end
if ~isnat(r.started)
    t = t + sprintf(", %d min", round(minutes(datetime('now') - r.started)));
end
end


function pick = pickRuns(parent, labels)
%pickRuns  Modal list of LABELS; the indices picked ([] = none).
pick = [];
p = parent.Position;
w = 440;
h = 130 + 22 * min(numel(labels), 8);
d = uifigure("Name", "Stop Kilosort4 runs", "WindowStyle", "modal", ...
    "Position", [p(1) + (p(3) - w) / 2, p(2) + (p(4) - h) / 2, w, h]);
g = uigridlayout(d, [3 3], "RowHeight", {'fit', '1x', 'fit'}, "ColumnWidth", {'1x', 'fit', 'fit'});
l = uilabel(g, "Text", "Stop the selected runs? What they have written so far stays in their folders.", ...
    "WordWrap", "on");
l.Layout.Row = 1; l.Layout.Column = [1 3];
lb = uilistbox(g, "Items", labels, "ItemsData", 1:numel(labels), "Multiselect", "on", ...
    "Value", 1:numel(labels));
lb.Layout.Row = 2; lb.Layout.Column = [1 3];
b = uibutton(g, "Text", "Stop selected", "ButtonPushedFcn", @(~,~) finish(true));
b.Layout.Row = 3; b.Layout.Column = 2;
b = uibutton(g, "Text", "Keep running", "ButtonPushedFcn", @(~,~) finish(false));
b.Layout.Row = 3; b.Layout.Column = 3;
uiwait(d);

    function finish(stop)
        if stop
            pick = lb.Value;
        end
        delete(d);
    end
end
