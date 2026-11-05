function d = trialMeasureDialog(obj, which)
%trialMeasureDialog  A trials layer's measure, or a trial scatter's x measure, in a modal window: the number each trial gives.
%   D = trialMeasureDialog(OBJ, WHICH) opens the Trial measure window
%   (WindowStyle "modal", Tag trialMeasureDialog; one at a time) on the
%   layer selected in the Figures tab (OBJ.SelectedFigure, SelectedPanel,
%   SelectedLayer: a trials layer of a trial distribution, histogram or
%   scatter panel) and returns it:
%     WHICH "measure"   the layer's measure (Layer.measure; a scatter's y):
%                       the Layers section's Measure row, Edit...
%     WHICH "xMeasure"  a trial scatter's x (Layer.xMeasure): the X measure
%                       row, Edit...
%   Its rows edit a TrialMeasure (EphysAnalysisConfig.defaults
%   ("TrialMeasure"); trialMeasure computes it):
%     Kind         Delay from an event to another, Duration of an
%                  interval, Count of events after an event, A trial
%                  parameter (kind)
%     From (A)     the event each trial's value starts from (from): the
%                  Alignment tab's event rows (AlignControls: Line, Edge,
%                  Which, n, Scope, Offset, Length, Time range, Shift by,
%                  Sequence with Edit..., the Event sequence window, modal
%                  over this one); hidden for a trial parameter
%     To (B)       the event it is measured to (to), the same rows; shown
%                  for a delay and a count (Which "all": a value per B,
%                  several values per trial)
%     Direction    a delay's: after (the first B at or after A) or before
%                  (the last B at or before A: negative values)
%     Max gap (s)  a delay's (a B further from A is dropped, and counted)
%                  and a count's (its window ends at A + the gap at the
%                  latest); blank = Inf, no limit
%     Parameter    a trial parameter's: the trial column (the active
%                  dataset's parameters listed; one can be typed)
%     Unit         a delay's or a duration's: ms or s
%     Label        blank = automatic; the gray line under it shows the
%                  label the measure gets (trialMeasureLabel), kept current
%                  with every edit
%   The rows a kind does not use are hidden (From, To) or grayed out. OK
%   checks the events (eventRef), the gap (a number above 0) and a
%   parameter's name, and says what is wrong in red on the label's line
%   (the window stays open); else it gives the layer the measure
%   (EphysAnalysisConfig.normalizeSection("TrialMeasure", ...)) as one
%   edit, "Trial measure" ("Trial x measure") in the undo history
%   (commitFigureEdit), and closes the window. Cancel closes it, changing
%   nothing. Showing another figure, panel or layer closes it
%   (closeTrialMeasureDialog: applyFigureEditor), and so does closing the
%   app. The window's UserData holds its controls for the tests: Kind, A
%   and B (the two AlignControls sets: Line, Edge, Which, N, Scope, ...),
%   Direction, MaxGap, Param, Unit, Label, Preview (the gray line), Ok,
%   Cancel; and what it edits: Which, FigureId, PanelId, LayerIndex.
%   Nothing opens, and the status line says why, without a trials layer
%   selected (a trial scatter's, for "xMeasure").
%
%   See also trialMeasure, trialMeasureLabel, AlignControls, latencyDialog,
%   closeTrialMeasureDialog, commitFigureEdit.
arguments
    obj (1,1) EphysFigGenApp
    which (1,1) string {mustBeMember(which, ["measure" "xMeasure"])} = "measure"
end
closeTrialMeasureDialog(obj, true);
d = [];
name = "Trial measure";
if which == "xMeasure"; name = "Trial x measure"; end
k = obj.SelectedFigure;
j = obj.SelectedPanel;
i = obj.SelectedLayer;
F = obj.Config.Figures;
ok = k >= 1 && k <= numel(F) && j >= 1 && j <= numel(F(k).panels) && i >= 1 && i <= numel(F(k).panels(j).layers) ...
    && F(k).panels(j).layers(i).source == "trials" && (which == "measure" || F(k).panels(j).type == "trialScatter");
if ~ok
    what = "a trials layer of a trial distribution, histogram or scatter panel";
    if which == "xMeasure"; what = "a trials layer of a trial scatter panel"; end
    obj.setStatus(name + ": select " + what + " first.");
    return
end
fig = F(k);
p = fig.panels(j);
m = EphysAnalysisConfig.normalizeSection("TrialMeasure", p.layers(i).(which));
id = fig.id;
pid = p.id;
src = activeSource(obj);
params = string.empty(1, 0);
if ~isempty(src); params = reshape(string(src.paramNames), 1, []); end
win0 = EphysAnalysisConfig.defaults("EpochWindow");   % (the event rows' sets have window and selection rows too: hidden)
sel0 = EphysAnalysisConfig.defaults("TrialSelection");
gray = [0.35 0.35 0.35];
kinds = EphysAnalysisConfig.TrialMeasureKinds;
kindLabels = ["Delay from an event to another" "Duration of an interval" "Count of events after an event" "A trial parameter"];
abHeight = 232;

pos = obj.Fig.Position;
d = uifigure('Name', name + ": " + pid + ", layer " + i, 'Position', [pos(1) + 100, pos(2) + 60, 1000, 600], ...
    'Tag', 'trialMeasureDialog', 'WindowStyle', 'modal');
addlistener(obj.Fig, 'ObjectBeingDestroyed', @(~, ~) delete(d(isvalid(d))));   % it goes with the app
g = uigridlayout(d, [9 1], 'RowHeight', {'fit', 24, abHeight, 24, 24, 24, 24, '1x', 36}, 'Padding', [12 12 12 12], ...
    'RowSpacing', 8);
what = "The number each trial gives";
if which == "xMeasure"; what = "The number each trial gives on the scatter's x axis (paired with its y by trial)"; end
l = uilabel(g, 'WordWrap', 'on', 'Text', what + ": the delay from an event A to an event B, the duration of A's " + ...
    "interval, the count of B events after A, or a trial parameter. A and B are found in each trial of the panel's " + ...
    "trial selection as the Alignment tab finds an event: its line, edge, which, scope, shifts and sequence.");
l.Layout.Row = 1;
r = 2;
kg = row("Kind:", {'1x'});
D.Kind = uidropdown(kg, 'Items', kindLabels, 'ItemsData', kinds, 'Value', pick(m.kind, kinds, "delay"), ...
    'ValueChangedFcn', @(~, ~) sync(), 'Tooltip', "What each trial's number is: the time from A to B, the length of " + ...
    "A's interval (onset to offset), how many B events follow A, or a trial column.");

% A and B: the Alignment tab's event rows each (their window and selection rows built out of sight)
abg = uigridlayout(g, [1 3], 'ColumnWidth', {'1x', '1x', 0}, 'Padding', [0 0 0 0], 'ColumnSpacing', 10);
abg.Layout.Row = 3;
pa = uipanel(abg, 'Title', "From (A): the event each trial's value starts from");
pb = uipanel(abg, 'Title', "To (B): the event it is measured to");
hid = uigridlayout(abg, [1 4], 'Padding', [0 0 0 0], 'Visible', 'off');
hp = gobjects(1, 4);
for q = 1:4; hp(q) = uipanel(hid); end
CA = AlignControls.build([pa hp(1) hp(2)], @(~) sync(), EditSequence=@editSeq);
CB = AlignControls.build([pb hp(3) hp(4)], @(~) sync(), EditSequence=@editSeq);
CB.Which.Tooltip = "Which B per A: the first, the last, the nth, or all (all: a value per B, several values per trial).";
AlignControls.fillItems(CA, src);
AlignControls.fillItems(CB, src);
AlignControls.show(CA, m.from, win0, sel0);
AlignControls.show(CB, m.to, win0, sel0);
r = 4;

dg = row("Direction:", {'1x', 'fit', 90});
D.Direction = uidropdown(dg, 'Items', ["after: the first B at or after A" "before: the last B at or before A (negative)"], ...
    'ItemsData', ["after" "before"], 'Value', pick(m.direction, ["after" "before"], "after"), 'ValueChangedFcn', @(~, ~) sync(), ...
    'Tooltip', "A delay's: from A to the first B at or after it, or back to the last B at or before it (a negative value).");
uilabel(dg, 'Text', 'Max gap (s):');
D.MaxGap = uieditfield(dg, 'text', 'Value', gapText(m.maxGapSec), 'Placeholder', 'Inf', 'ValueChangedFcn', @(~, ~) sync(), ...
    'Tooltip', "A delay's: a B further than this from A is dropped (and counted). A count's: its window ends at A plus " + ...
    "this at the latest. Blank (Inf): no limit.");
pg = row("Parameter:", {'1x'});
D.Param = uidropdown(pg, 'Editable', 'on', 'Items', unique([string(m.param) params], 'stable'), 'Value', m.param, ...
    'ValueChangedFcn', @(~, ~) sync(), 'Tooltip', "A trial parameter's: the trial column whose value each trial gives " + ...
    "(numeric; trials without a value are left out and counted).");
ug = row("Unit:", {120, '1x'});
D.Unit = uidropdown(ug, 'Items', ["ms" "s"], 'Value', pick(m.unit, ["ms" "s"], "ms"), 'ValueChangedFcn', @(~, ~) sync(), ...
    'Tooltip', "A delay's or a duration's unit (a count has none; a parameter keeps its own).");
uilabel(ug, 'Text', '', 'FontColor', gray);
lg = row("Label:", {'1x'});
D.Label = uieditfield(lg, 'text', 'Value', m.label, 'Placeholder', 'automatic', 'ValueChangedFcn', @(~, ~) sync(), ...
    'ValueChangingFcn', @(~, e) typing(e.Value), 'Tooltip', "The measure's name on the axis, in the legend and the " + ...
    "caption, and in the {Measure} label variable. Blank: automatic (the line below).");
D.Preview = uilabel(g, 'WordWrap', 'on', 'FontColor', gray, 'VerticalAlignment', 'top', 'Text', "");
D.Preview.Layout.Row = 8;
bg = uigridlayout(g, [1 3], 'ColumnWidth', {'1x', 100, 100}, 'Padding', [0 0 0 0]);
bg.Layout.Row = 9;
uilabel(bg, 'Text', '');
D.Ok = uibutton(bg, 'Text', 'OK', 'ButtonPushedFcn', @(~, ~) apply(), 'Tooltip', "Give the layer this measure, and close the window.");
D.Cancel = uibutton(bg, 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) delete(d), 'Tooltip', 'Close the window, changing nothing.');
styleButton(D.Cancel);
styleButton(D.Ok, 'confirm');
styleButton([CA.SeqEdit CB.SeqEdit]);
D.A = CA;
D.B = CB;
D.Which = which;
D.FigureId = id;
D.PanelId = pid;
D.LayerIndex = i;
d.UserData = D;
d.DeleteFcn = @(~, ~) dropSequence();
sync();

    function gg = row(label, widths)
        %row  The next row: its label and a grid for its controls (GG).
        rg = uigridlayout(g, [1 2], 'ColumnWidth', {100, '1x'}, 'Padding', [0 0 0 0]);
        rg.Layout.Row = r;
        r = r + 1;
        uilabel(rg, 'Text', label);
        gg = uigridlayout(rg, [1 numel(widths)], 'ColumnWidth', widths, 'Padding', [0 0 0 0]);
    end

    function N = current()
        %current  The measure the rows show (normalized; a gap that is no number errors).
        N = m;
        N.kind = string(D.Kind.Value);
        N.from = AlignControls.read(CA, m.from, win0, sel0);
        N.to = AlignControls.read(CB, m.to, win0, sel0);
        N.direction = string(D.Direction.Value);
        N.maxGapSec = gapOf(D.MaxGap.Value);
        N.param = strtrim(string(D.Param.Value));
        N.unit = string(D.Unit.Value);
        N.label = strtrim(string(D.Label.Value));
        N = EphysAnalysisConfig.normalizeSection("TrialMeasure", N);
    end

    function sync()
        %sync  The rows the kind uses shown and enabled, and the label the measure gets.
        if ~isvalid(d); return; end
        on = @(tf) matlab.lang.OnOffSwitchState(tf);
        kind = string(D.Kind.Value);
        usesB = ismember(kind, ["delay" "count"]);
        pa.Visible = on(kind ~= "param");
        pb.Visible = on(usesB);
        g.RowHeight{3} = abHeight * (kind ~= "param");
        D.Direction.Enable = on(kind == "delay");
        D.MaxGap.Enable = on(usesB);
        D.Param.Enable = on(kind == "param");
        D.Unit.Enable = on(ismember(kind, ["delay" "duration"]));
        AlignControls.syncEnable(CA);
        AlignControls.syncEnable(CB);
        D.Preview.FontColor = gray;
        try
            D.Preview.Text = "Label: " + trialMeasureLabel(current());
        catch ME
            D.Preview.Text = "Label: (" + string(ME.message) + ")";
        end
    end

    function typing(txt)
        %typing  The label line while the Label field is typed in.
        try
            N = current();
            N.label = strtrim(string(txt));
            D.Preview.Text = "Label: " + trialMeasureLabel(N);
            D.Preview.FontColor = gray;
        catch
        end
    end

    function editSeq(holder, lineCtl, edgeCtl, done)
        %editSeq  The app's Event sequence window on A's or B's sequence, modal over this one.
        obj.editSequence(holder, lineCtl, edgeCtl, done);
        f = obj.SequenceDialog;
        if ~isempty(f) && isvalid(f); f.WindowStyle = "modal"; end
    end

    function dropSequence()
        %dropSequence  An Event sequence window open on A's or B's sequence goes with this one.
        if ~isvalid(obj); return; end
        try
            closeSequenceDialog(obj, [CA.SeqText CA.StopSeqText CB.SeqText CB.StopSeqText]);
        catch
        end
    end

    function apply()
        %apply  The layer the window was opened on takes the measure, as one named edit; a measure that cannot be is said in red.
        if ~isvalid(obj) || ~isvalid(obj.Fig); delete(d); return; end
        try
            N = current();
            if N.kind ~= "param"; eventRef(N.from); end
            if ismember(N.kind, ["delay" "count"]); eventRef(N.to); end
            if N.kind == "param" && ~isvarname(N.param)
                error("trialMeasureDialog:NoParam", "Pick the trial parameter (a trial column of the dataset).");
            end
        catch ME
            D.Preview.Text = "Cannot apply: " + string(ME.message);
            D.Preview.FontColor = [0.75 0.1 0.1];
            return
        end
        cfg = obj.gatherConfig();
        fid = followedFigureId(obj, id);   % renamed since the window opened (an automatic id that followed an edit)
        q = cfg.figureIndex(fid);
        kp = [];
        if q >= 1 && ~isempty(cfg.Figures(q).panels); kp = find([cfg.Figures(q).panels.id] == pid, 1); end
        if isempty(kp) || i > numel(cfg.Figures(q).panels(kp).layers) || cfg.Figures(q).panels(kp).layers(i).source ~= "trials"
            obj.setStatus(name + ": there is no trials layer " + i + " in " + pid + " of " + fid + " any more.");
            delete(d);
            return
        end
        cfg.Figures(q).panels(kp).layers(i).(which) = N;
        whose = "measure";
        if which == "xMeasure"; whose = "x measure"; end
        commitFigureEdit(obj, cfg, pid + ", layer " + i + ": its " + whose + " is " + trialMeasureLabel(N) + ".", Action=name);
        if isvalid(d); delete(d); end
    end
end


function src = activeSource(obj)
%activeSource  The active dataset's source (its lines and trial parameters), else [].
src = [];
if isempty(obj.Runner) || obj.ActiveIdx < 1; return; end
try
    src = obj.Runner.source(obj.ActiveIdx);
catch
end
end


function t = gapText(x)
%gapText  The Max gap field's text: blank for Inf (no limit).
t = '';
if isfinite(x); t = char(string(x)); end
end


function x = gapOf(t)
%gapOf  The Max gap field's seconds: blank or Inf = Inf; else a number above 0 (an error otherwise).
t = lower(strtrim(string(t)));
if t == "" || t == "inf"
    x = Inf;
    return
end
x = str2double(t);
if ~(isfinite(x) && x > 0)
    error("trialMeasureDialog:BadGap", "Max gap (s) is a number of seconds above 0, or blank for no limit.");
end
end


function v = pick(v, allowed, default)
v = string(v);
if ~ismember(v, allowed); v = default; end
end
