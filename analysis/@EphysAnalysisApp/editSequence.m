function editSequence(obj, holder, lineCtl, edgeCtl, done)
%editSequence  Edit an event sequence in a window of its own.
%   obj.editSequence(HOLDER, LINECTL, EDGECTL, DONE) opens the "Event
%   sequence" window (obj.SequenceDialog) on the sequence the label HOLDER
%   keeps (setSequenceHolder): one event reference's (or stop's) steps. It
%   starts at the line and edge of the drop-downs LINECTL / EDGECTL (shown,
%   edited in the panel). The steps are a table: Then (followed by / not
%   followed by), Line (a drop-down of the lines), Edge, n, Within (s)
%   (maxGapSec, Inf = up to the next trial), Min / Max length (s). "Align
%   to" picks the epoch's event (alignStep). Apply stores the result in
%   HOLDER and calls DONE(); Cancel drops it. One window at a time: opening
%   another closes it, and so does showing other values in HOLDER's panel
%   (closeSequenceDialog). The window's UserData holds HOLDER (Holder) and
%   its controls (Line, Edge, Table, Align, Apply, Cancel, ...) for the
%   tests.
%
%   See also buildAlignControls, eventRef, eventRefLabel.

if ~isempty(obj.SequenceDialog) && isvalid(obj.SequenceDialog)
    delete(obj.SequenceDialog);
end
lines = unique(["Trial" string(lineCtl.Items)], 'stable');
r = EphysAnalysisConfig.defaults("EventRef");
r.line = strtrim(string(lineCtl.Value));
r.edge = string(edgeCtl.Value);
r.sequence = holder.UserData.sequence;
r.alignStep = holder.UserData.alignStep;
ref = r;

pos = obj.Fig.Position;
f = uifigure("Name", "Event sequence", "Position", [pos(1) + 120, pos(2) + 120, 720, 470]);
obj.SequenceDialog = f;
g = uigridlayout(f, [5 1]);
g.RowHeight = {26, '1x', 30, 'fit', 36};
g.Padding = [10 10 10 10];

D = struct('Holder', holder);
% --- the start --------------------------------------------------------------------
sg = uigridlayout(g, [1 3]);
sg.Layout.Row = 1;
sg.ColumnWidth = {70, '1x', 80};
sg.Padding = [0 0 0 0];
uilabel(sg, "Text", "Starts at:", "FontWeight", "bold");
D.Line = uidropdown(sg, "Editable", "on", "Items", lines, "Value", lines(1), "ValueChangedFcn", @(~,~) refreshAlign(), ...
    "Tooltip", "The line whose events start the sequence (""Trial"" = the paired trial line).");
D.Edge = uidropdown(sg, "Items", ["onset" "offset"], "ValueChangedFcn", @(~,~) refreshAlign());
set([D.Line D.Edge], "Enable", "off", "Tooltip", "Set in the panel (Line, Edge).");

% --- the steps --------------------------------------------------------------------
D.Table = uitable(g, "ColumnName", {'Then', 'Line', 'Edge', 'n', 'Within (s)', 'Min length (s)', 'Max length (s)'}, ...
    "ColumnEditable", true, "RowName", {}, "ColumnWidth", {120, '1x', 80, 50, 90, 100, 100}, ...
    "CellEditCallback", @(~,~) refreshAlign(), "CellSelectionCallback", @(~, e) onSelect(e));
D.Table.Layout.Row = 2;
bg = uigridlayout(g, [1 7]);
bg.Layout.Row = 3;
bg.ColumnWidth = {'fit', 'fit', 'fit', 'fit', '1x', 'fit', 260};
bg.Padding = [0 0 0 0];
D.AddStep = uibutton(bg, "Text", "Add step", "ButtonPushedFcn", @(~,~) onAddStep(), ...
    "Tooltip", "A step after the last: the next event that must (or must not) come.");
D.RemoveStep = uibutton(bg, "Text", "Remove step", "ButtonPushedFcn", @(~,~) onMove(0));
D.Up = uibutton(bg, "Text", "Up", "ButtonPushedFcn", @(~,~) onMove(-1));
D.Down = uibutton(bg, "Text", "Down", "ButtonPushedFcn", @(~,~) onMove(1));
uilabel(bg, "Text", "");
uilabel(bg, "Text", "Align to:", "FontWeight", "bold");
D.Align = uidropdown(bg, "Items", "the last step", "ItemsData", Inf, ...
    "Tooltip", "The event each epoch is aligned to. Aligned to the start, the steps are conditions only.");
D.Hint = uilabel(g, "WordWrap", "on", "FontColor", [0.3 0.3 0.3], "Text", ...
    "Each step looks for its event after the event before it: the start, or the last ""followed by"" step. " + ...
    """followed by"": the nth such event must come (it becomes the event before the next step); ""not followed by"": " + ...
    "none may come. Within (s) limits how long after (Inf: any time), and with paired trials no step looks past " + ...
    "the next trial's onset. An event whose sequence does not complete is left out (and counted). " + ...
    "Lines here: " + strjoin(lines, ", ") + ".");
D.Hint.Layout.Row = 4;
ag = uigridlayout(g, [1 3]);
ag.Layout.Row = 5;
ag.ColumnWidth = {'1x', 120, 120};
ag.Padding = [0 0 0 0];
uilabel(ag, "Text", "");
D.Apply = uibutton(ag, "Text", "Apply", "ButtonPushedFcn", @(~,~) onApply());
D.Cancel = uibutton(ag, "Text", "Cancel", "ButtonPushedFcn", @(~,~) delete(f));
styleButton(findall(f, "Type", "uibutton"));
styleButton(D.Apply, "confirm");
f.UserData = D;
selRow = 0;
show();

    function show()
        %show  Put the reference in the controls.
        setDrop(D.Line, ref.line);
        D.Edge.Value = char(ref.edge);
        D.Table.Data = stepTable(ref.sequence, lines);
        refreshAlign(ref.alignStep);
    end

    function r = current()
        %current  The reference as the controls show it.
        r = ref;
        r.line = strtrim(string(D.Line.Value));
        r.edge = string(D.Edge.Value);
        r.sequence = tableSteps(D.Table.Data);
        r.alignStep = D.Align.Value;
        if isfinite(r.alignStep) && r.alignStep > numel(r.sequence); r.alignStep = Inf; end
    end

    function refreshAlign(keep)
        %refreshAlign  Offer the start and each "followed by" step to align to.
        if nargin < 1; keep = D.Align.Value; end
        S = tableSteps(D.Table.Data);
        items = "the start (" + strtrim(string(D.Line.Value)) + " " + string(D.Edge.Value) + ")";
        data = 0;
        for k = 1:numel(S)
            if S(k).relation == "followedBy"
                items(end+1) = sprintf("step %d (%s %s)", k, S(k).line, S(k).edge); %#ok<AGROW>
                data(end+1) = k; %#ok<AGROW>
            end
        end
        items(end+1) = "the last step";
        data(end+1) = Inf;
        D.Align.Items = items;
        D.Align.ItemsData = data;
        if ~ismember(keep, data); keep = Inf; end
        D.Align.Value = keep;
    end

    function onSelect(e)
        if ~isempty(e.Indices); selRow = e.Indices(1, 1); end
    end

    function onAddStep()
        T = D.Table.Data;
        s = EphysAnalysisConfig.defaults("SequenceStep");
        s.line = "Trough";
        D.Table.Data = [T; stepTable(s, categories(T.Line))];
        refreshAlign();
    end

    function onMove(step)
        %onMove  Remove (STEP 0) or move up / down (-1 / 1) the selected step.
        T = D.Table.Data;
        k = selRow;
        if k < 1 || k > height(T); return; end
        if step == 0
            T(k, :) = [];
            selRow = 0;
        else
            j = k + step;
            if j < 1 || j > height(T); return; end
            T([k j], :) = T([j k], :);
            selRow = j;
        end
        D.Table.Data = T;
        refreshAlign();
    end

    function onApply()
        try
            r = current();
            eventRef(r);   % checked here: a bad step is said now
            setSequenceHolder(holder, struct('sequence', r.sequence, 'alignStep', r.alignStep));
        catch ME
            uialert(f, string(ME.message), "Event sequence");
            return
        end
        delete(f);
        done();
    end
end


function T = stepTable(S, lines)
%stepTable  The steps S as the table shows them; the Line column is a
%   drop-down of LINES (and of any line the steps already name).
n = numel(S);
rel = categorical(repmat("followed by", n, 1), ["followed by" "not followed by"]);
if n > 0; rel([S.relation] == "notFollowedBy") = "not followed by"; end
edge = categorical(reshape(string({S.edge}), [], 1), ["onset" "offset"]);
if n == 0; edge = categorical(strings(0, 1), ["onset" "offset"]); end
stepLines = reshape(string({S.line}), [], 1);
choices = unique([reshape(string(lines), 1, []) reshape(stepLines, 1, [])], 'stable');
choices(choices == "") = [];
line = categorical(stepLines, choices);   % a step without a line is <undefined> (dropped by tableSteps)
T = table(rel, line, edge, reshape([S.n], [], 1), ...
    reshape([S.maxGapSec], [], 1), reshape([S.minDurationSec], [], 1), reshape([S.maxDurationSec], [], 1), ...
    'VariableNames', {'Then', 'Line', 'Edge', 'n', 'Within', 'MinLength', 'MaxLength'});
end


function S = tableSteps(T)
%tableSteps  The steps a table shows (rows without a line dropped).
S = repmat(EphysAnalysisConfig.defaults("SequenceStep"), 1, 0);
for k = 1:height(T)
    line = string(T.Line(k));
    if ismissing(line) || strtrim(line) == ""; continue; end
    line = strtrim(line);
    s = EphysAnalysisConfig.defaults("SequenceStep");
    if string(T.Then(k)) == "not followed by"; s.relation = "notFollowedBy"; end
    s.line = line;
    s.edge = string(T.Edge(k));
    s.n = T.n(k);
    s.maxGapSec = T.Within(k);
    s.minDurationSec = T.MinLength(k);
    s.maxDurationSec = T.MaxLength(k);
    S(end+1) = s; %#ok<AGROW>
end
end


function setDrop(dd, v)
if ~ismember(v, string(dd.Items)); dd.Items = [string(dd.Items) v]; end
dd.Value = char(v);
end
