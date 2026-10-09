function editSequence(obj, holder, mode, lineCtl, edgeCtl, done)
%editSequence  Edit an event sequence in a window of its own.
%   obj.editSequence(HOLDER, MODE, LINECTL, EDGECTL, DONE) opens the
%   "Event sequence" window (obj.SequenceDialog) on the sequence the label
%   HOLDER keeps (setSequenceHolder):
%     MODE "event"  one event reference's (or stop's) steps: it starts at
%                   the line and edge of the drop-downs LINECTL / EDGECTL
%                   (shown, edited in the panel)
%     MODE "marks"  a plot's mark sequences: a list of event references,
%                   each with its own start (line, edge, which, scope) and
%                   steps; EDGECTL is unused
%   The steps are a table: Then (followed by / not followed by), Line,
%   Edge, n, Within (s) (maxGapSec, Inf = up to the next trial), Min / Max
%   length (s). "Align to" picks the epoch's event (alignStep). Apply
%   stores the result in HOLDER and calls DONE(); Cancel drops it. One
%   window at a time: opening another closes it, and so does showing
%   other values in HOLDER's panel (closeSequenceDialog). The window's
%   UserData holds HOLDER (Holder) and its controls (List, Line, Edge,
%   Which, Scope, Table, Align, Apply, Cancel, ...) for the tests.
%
%   See also buildAlignControls, eventRef, eventRefLabel.

if ~isempty(obj.SequenceDialog) && isvalid(obj.SequenceDialog)
    delete(obj.SequenceDialog);
end
marks = mode == "marks";
lines = unique(["Trial" string(lineCtl.Items)], 'stable');
def = EphysAnalysisConfig.defaults("EventRef");
if marks
    refs = holder.UserData;
    if isempty(refs); refs = repmat(def, 1, 0); end
else
    r = def;
    r.line = strtrim(string(lineCtl.Value));
    r.edge = string(edgeCtl.Value);
    r.sequence = holder.UserData.sequence;
    r.alignStep = holder.UserData.alignStep;
    refs = r;
end
cur = min(1, numel(refs));

pos = obj.Fig.Position;
f = uifigure("Name", "Event sequence", "Position", [pos(1) + 120, pos(2) + 120, 720, 470 + 110 * marks]);
obj.SequenceDialog = f;
g = uigridlayout(f, [6 1]);
g.RowHeight = {110 * marks, 26, '1x', 30, 'fit', 36};
g.Padding = [10 10 10 10];

D = struct('Holder', holder);
% --- the list of mark sequences ---------------------------------------------------
lg = uigridlayout(g, [2 2]);
lg.Layout.Row = 1;
lg.ColumnWidth = {'1x', 150};
lg.RowHeight = {'1x', '1x'};
lg.Padding = [0 0 0 0];
lg.Visible = matlab.lang.OnOffSwitchState(marks);
D.List = uilistbox(lg, "Items", {}, "ValueChangedFcn", @(~,~) onPick());
D.List.Layout.Row = [1 2]; D.List.Layout.Column = 1;
D.AddSeq = uibutton(lg, "Text", "Add sequence", "ButtonPushedFcn", @(~,~) onAddSeq(), ...
    "Tooltip", "Mark another event, e.g. Trial offset then Trough onset.");
D.AddSeq.Layout.Row = 1; D.AddSeq.Layout.Column = 2;
D.RemoveSeq = uibutton(lg, "Text", "Remove sequence", "ButtonPushedFcn", @(~,~) onRemoveSeq());
D.RemoveSeq.Layout.Row = 2; D.RemoveSeq.Layout.Column = 2;

% --- the start --------------------------------------------------------------------
sg = uigridlayout(g, [1 7]);
sg.Layout.Row = 2;
sg.ColumnWidth = {70, '1x', 80, 'fit', 80, 'fit', 100};
sg.Padding = [0 0 0 0];
uilabel(sg, "Text", "Starts at:", "FontWeight", "bold");
D.Line = uidropdown(sg, "Editable", "on", "Items", lines, "Value", lines(1), "ValueChangedFcn", @(~,~) refreshAlign(), ...
    "Tooltip", "The line whose events start the sequence (""Trial"" = the paired trial line).");
D.Edge = uidropdown(sg, "Items", ["onset" "offset"], "ValueChangedFcn", @(~,~) refreshAlign());
D.WhichLabel = uilabel(sg, "Text", "which:");
D.Which = uidropdown(sg, "Items", ["all" "first" "last"], "Value", "all", ...
    "Tooltip", "Of the start events the sequence follows: every one, or the first / last per trial (trial scope) or in the recording.");
D.ScopeLabel = uilabel(sg, "Text", "scope:");
D.Scope = uidropdown(sg, "Items", ["auto" "trial" "recording"], "Value", "auto", ...
    "Tooltip", "trial: start events inside the trials (each its trial's); recording: every one; auto: trial with paired trials.");
set([D.WhichLabel D.Which D.ScopeLabel D.Scope], "Visible", matlab.lang.OnOffSwitchState(marks));
if ~marks
    set([D.Line D.Edge], "Enable", "off", "Tooltip", "Set in the panel (Line, Edge).");
end

% --- the steps --------------------------------------------------------------------
D.Table = uitable(g, "ColumnName", {'Then', 'Line', 'Edge', 'n', 'Within (s)', 'Min length (s)', 'Max length (s)'}, ...
    "ColumnEditable", true, "RowName", {}, "ColumnWidth", {120, '1x', 80, 50, 90, 100, 100}, ...
    "CellEditCallback", @(~,~) refreshAlign(), "CellSelectionCallback", @(~, e) onSelect(e));
D.Table.Layout.Row = 3;
bg = uigridlayout(g, [1 7]);
bg.Layout.Row = 4;
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
D.Hint.Layout.Row = 5;
ag = uigridlayout(g, [1 3]);
ag.Layout.Row = 6;
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
        %show  Put refs(cur) in the controls (and the list).
        if marks
            labels = strings(1, numel(refs));
            for k = 1:numel(refs); labels(k) = eventRefLabel(refs(k)); end
            D.List.Items = cellstr(labels);
            D.List.ItemsData = 1:numel(refs);
            if cur >= 1; D.List.Value = cur; end
            onOff = 'off';
            if cur >= 1; onOff = 'on'; end
            set([D.Line D.Edge D.Which D.Scope D.Table D.AddStep D.RemoveStep D.Up D.Down D.Align D.RemoveSeq], "Enable", onOff);
        end
        if cur < 1
            D.Table.Data = stepTable(repmat(EphysAnalysisConfig.defaults("SequenceStep"), 1, 0));
            return
        end
        r = refs(cur);
        setDrop(D.Line, r.line);
        D.Edge.Value = char(r.edge);
        if marks
            setDrop(D.Which, r.which);
            D.Scope.Value = char(r.scope);
        end
        D.Table.Data = stepTable(r.sequence);
        refreshAlign(r.alignStep);
    end

    function r = current()
        %current  refs(cur) as the controls show it.
        r = refs(cur);
        r.line = strtrim(string(D.Line.Value));
        r.edge = string(D.Edge.Value);
        if marks
            r.which = string(D.Which.Value);
            r.scope = string(D.Scope.Value);
        end
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

    function onPick()
        refs(cur) = current();
        cur = D.List.Value;
        show();
    end

    function onAddSeq()
        if cur >= 1; refs(cur) = current(); end
        r = def;
        r.line = "Trial";
        r.edge = "offset";
        r.which = "all";
        r.sequence = EphysAnalysisConfig.defaults("SequenceStep");
        r.sequence.line = "Trough";
        refs(end+1) = r;
        cur = numel(refs);
        show();
    end

    function onRemoveSeq()
        if cur < 1; return; end
        refs(cur) = [];
        cur = min(cur, numel(refs));
        show();
    end

    function onAddStep()
        T = D.Table.Data;
        s = EphysAnalysisConfig.defaults("SequenceStep");
        s.line = "Trough";
        D.Table.Data = [T; stepTable(s)];
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
            if marks
                if cur >= 1; refs(cur) = current(); end
                for k = 1:numel(refs); eventRef(refs(k)); end   % checked here: a bad step is said now
                setSequenceHolder(holder, refs);
            else
                r = current();
                eventRef(r);
                setSequenceHolder(holder, struct('sequence', r.sequence, 'alignStep', r.alignStep));
            end
        catch ME
            uialert(f, string(ME.message), "Event sequence");
            return
        end
        delete(f);
        done();
    end
end


function T = stepTable(S)
%stepTable  The steps S as the table shows them.
n = numel(S);
rel = categorical(repmat("followed by", n, 1), ["followed by" "not followed by"]);
if n > 0; rel([S.relation] == "notFollowedBy") = "not followed by"; end
edge = categorical(reshape(string({S.edge}), [], 1), ["onset" "offset"]);
if n == 0; edge = categorical(strings(0, 1), ["onset" "offset"]); end
T = table(rel, reshape(cellstr(string({S.line})), [], 1), edge, reshape([S.n], [], 1), ...
    reshape([S.maxGapSec], [], 1), reshape([S.minDurationSec], [], 1), reshape([S.maxDurationSec], [], 1), ...
    'VariableNames', {'Then', 'Line', 'Edge', 'n', 'Within', 'MinLength', 'MaxLength'});
end


function S = tableSteps(T)
%tableSteps  The steps a table shows (rows without a line dropped).
S = repmat(EphysAnalysisConfig.defaults("SequenceStep"), 1, 0);
for k = 1:height(T)
    line = strtrim(string(T.Line{k}));
    if line == ""; continue; end
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
