function C = buildAlignControls(obj, parents, changed)
%buildAlignControls  Event-reference, window and trial-selection controls in three containers.
%   C = buildAlignControls(obj, PARENTS, CHANGED) builds the Event reference
%   (eventRef), the Epoch window (epochWindow, with its stop event) and the
%   Trial selection (trialSelection), each in a grid in its container of
%   PARENTS (three panels, in that order: C.RefGrid, C.WindowGrid,
%   C.SelectionGrid), and returns their handles. Every control calls
%   CHANGED(PART) when edited, PART "ref", "window" or "selection". The
%   Alignment tab builds one set in three titled panels for the config's
%   Defaults, the Plots tab another in three sections of its editor for a
%   plot's own values (applyAlignControls / gatherAlignControls move values
%   in and out; fillAlignItems lists the active dataset's lines and
%   parameters; syncAlignEnable enables what is in use).
C = struct();
cbRef = @(~,~) changed("ref");
cbWin = @(~,~) changed("window");
cbSel = @(~,~) changed("selection");
[~, words] = respCodeBits();

% --- event reference ------------------------------------------------------------
rg = uigridlayout(parents(1), [5 4]);
rg.RowHeight = repmat({22}, 1, 5);
rg.ColumnWidth = {95, '1x', 70, '1x'};
rg.RowSpacing = 4;
C.RefGrid = rg;
lab(rg, "Line:", 1, 1);
C.Line = uidropdown(rg, "Editable", "on", "Items", "Stim", "Value", "Stim", "ValueChangedFcn", cbRef, ...
    "Tooltip", "The digital line to align to; ""Trial"" is the paired trial line (TrialOnset / TrialOffset).");
C.Line.Layout.Row = 1; C.Line.Layout.Column = 2;
lab(rg, "Edge:", 1, 3);
C.Edge = uidropdown(rg, "Items", ["onset" "offset"], "ValueChangedFcn", cbRef);
C.Edge.Layout.Row = 1; C.Edge.Layout.Column = 4;
lab(rg, "Which:", 2, 1);
C.Which = uidropdown(rg, "Items", ["first" "last" "all" "nth"], "ValueChangedFcn", cbRef, ...
    "Tooltip", "Per trial in trial scope, over the recording in recording scope.");
C.Which.Layout.Row = 2; C.Which.Layout.Column = 2;
lab(rg, "n:", 2, 3);
C.N = uispinner(rg, "Limits", [1 Inf], "Step", 1, "Value", 1, "RoundFractionalValues", "on", "ValueChangedFcn", cbRef, ...
    "Tooltip", "The event ""nth"" takes.");
C.N.Layout.Row = 2; C.N.Layout.Column = 4;
lab(rg, "Scope:", 3, 1);
C.Scope = uidropdown(rg, "Items", ["auto" "trial" "recording"], "ValueChangedFcn", cbRef, ...
    "Tooltip", "trial: the line's intervals inside each selected trial; recording: every interval; auto: trial when the dataset has paired trials.");
C.Scope.Layout.Row = 3; C.Scope.Layout.Column = 2;
lab(rg, "Offset (s):", 3, 3);
C.Offset = uieditfield(rg, "numeric", "Value", 0, "ValueChangedFcn", cbRef, "Tooltip", "Added to every event time.");
C.Offset.Layout.Row = 3; C.Offset.Layout.Column = 4;
lab(rg, "Length (s):", 4, 1);
C.MinDur = uieditfield(rg, "text", "Value", "0", "ValueChangedFcn", cbRef, "Tooltip", "Keep intervals at least this long.");
C.MinDur.Layout.Row = 4; C.MinDur.Layout.Column = 2;
lab(rg, "to", 4, 3);
C.MaxDur = uieditfield(rg, "text", "Value", "Inf", "ValueChangedFcn", cbRef, "Tooltip", "... and at most this long (Inf = no limit).");
C.MaxDur.Layout.Row = 4; C.MaxDur.Layout.Column = 4;
lab(rg, "Time range (s):", 5, 1);
C.TimeFrom = uieditfield(rg, "text", "Value", "-Inf", "ValueChangedFcn", cbRef, ...
    "Tooltip", "Keep events in this range: from the trial onset (trial scope) or the recording start.");
C.TimeFrom.Layout.Row = 5; C.TimeFrom.Layout.Column = 2;
lab(rg, "to", 5, 3);
C.TimeTo = uieditfield(rg, "text", "Value", "Inf", "ValueChangedFcn", cbRef);
C.TimeTo.Layout.Row = 5; C.TimeTo.Layout.Column = 4;

% --- window ------------------------------------------------------------------------
wg = uigridlayout(parents(2), [5 4]);
wg.RowHeight = repmat({22}, 1, 5);
wg.ColumnWidth = {95, '1x', 70, '1x'};
wg.RowSpacing = 4;
C.WindowGrid = wg;
lab(wg, "Mode:", 1, 1);
C.Mode = uidropdown(wg, "Items", "", "ValueChangedFcn", cbWin);
setWindowModes(C.Mode, ["fixed" "between"], "fixed");
C.Mode.Layout.Row = 1; C.Mode.Layout.Column = [2 4];
lab(wg, "Pre (s):", 2, 1);
C.Pre = uieditfield(wg, "numeric", "Value", -0.2, "ValueChangedFcn", cbWin);
C.Pre.Layout.Row = 2; C.Pre.Layout.Column = 2;
lab(wg, "Post (s):", 2, 3);
C.Post = uieditfield(wg, "numeric", "Value", 0.8, "ValueChangedFcn", cbWin);
C.Post.Layout.Row = 2; C.Post.Layout.Column = 4;
C.StopOn = uicheckbox(wg, "Text", "Stop event:", "ValueChangedFcn", cbWin, ...
    "Tooltip", "Ends each epoch (between mode); in fixed mode it is marked and can mask the PSTH.");
C.StopOn.Layout.Row = 3; C.StopOn.Layout.Column = 1;
C.StopLine = uidropdown(wg, "Editable", "on", "Items", "Stim", "Value", "Stim", "ValueChangedFcn", cbWin);
C.StopLine.Layout.Row = 3; C.StopLine.Layout.Column = 2;
C.StopEdge = uidropdown(wg, "Items", ["offset" "onset"], "ValueChangedFcn", cbWin);
C.StopEdge.Layout.Row = 3; C.StopEdge.Layout.Column = [3 4];
lab(wg, "Stop which:", 4, 1);
C.StopWhich = uidropdown(wg, "Items", ["first" "last" "all" "nth"], "ValueChangedFcn", cbWin, ...
    "Tooltip", "Among the stop events at or after each epoch's event.");
C.StopWhich.Layout.Row = 4; C.StopWhich.Layout.Column = 2;
lab(wg, "n:", 4, 3);
C.StopN = uispinner(wg, "Limits", [1 Inf], "Step", 1, "Value", 1, "RoundFractionalValues", "on", "ValueChangedFcn", cbWin, ...
    "Tooltip", "The stop event ""nth"" takes.");
C.StopN.Layout.Row = 4; C.StopN.Layout.Column = 4;
lab(wg, "Stop scope:", 5, 1);
C.StopScope = uidropdown(wg, "Items", ["auto" "trial" "recording"], "ValueChangedFcn", cbWin);
C.StopScope.Layout.Row = 5; C.StopScope.Layout.Column = 2;

% --- selection -----------------------------------------------------------------------
sg = uigridlayout(parents(3), [7 4]);
sg.RowHeight = repmat({22}, 1, 7);
sg.ColumnWidth = {95, '1x', 75, '1x'};
sg.RowSpacing = 4;
C.SelectionGrid = sg;

% Filter
lab(sg, "Filter:", 1, 1);
fg = uigridlayout(sg, [1 2]);
fg.Layout.Row = 1; fg.Layout.Column = [2 4];
fg.ColumnWidth = {'1x', 28};
fg.Padding = [0 0 0 0];
C.Filter = uieditfield(fg, "text", "Placeholder", "e.g. Depth > 0 & RespLatency < 500   or   Hit | Miss", "ValueChangedFcn", cbSel);
C.FilterHelp = uibutton(fg, "Text", "?", "Tooltip", "The trial columns, response words and functions a filter can use.", ...
    "ButtonPushedFcn", @(~,~) obj.onFilterHelp());

% Response codes, four to a row
lab(sg, "Response:", 2, 1);
nc = ceil(numel(words) / 2);
rsp = uigridlayout(sg, [2 nc]);
rsp.Layout.Row = [2 3]; rsp.Layout.Column = [2 4];
rsp.ColumnWidth = repmat({'fit'}, 1, nc);
rsp.Padding = [0 0 0 0]; rsp.RowSpacing = 4; rsp.ColumnSpacing = 8;
C.Response = struct();
for i = 1:numel(words)
    w = words(i);
    C.Response.(w) = uicheckbox(rsp, "Text", w, "ValueChangedFcn", cbSel, "Tooltip", "Keep trials that are any of the ticked responses.");
    C.Response.(w).Layout.Row = 1 + floor((i-1) / nc);
    C.Response.(w).Layout.Column = 1 + mod(i-1, nc);
end

% Pairing flags
lab(sg, "Pairing:", 4, 1);
flg = uigridlayout(sg, [2 2]);
flg.Layout.Row = [4 5]; flg.Layout.Column = [2 4];
flg.Padding = [0 0 0 0]; flg.RowSpacing = 3; flg.ColumnSpacing = 12;
C.Flags = struct();
flags = ["ok" "partial" "cut" "unpaired"];
for i = 1:numel(flags)
    f = flags(i);
    row = 1 + mod(i-1, 2);
    col = 1 + floor((i-1)/2);
    C.Flags.(f) = uicheckbox(flg, "Text", f, "Value", f == "ok", "ValueChangedFcn", cbSel, ...
        "Tooltip", "Keep trials with this PairingFlag (none ticked = every flag).");
    C.Flags.(f).Layout.Row = row;
    C.Flags.(f).Layout.Column = col;
end

% Grouping
lab(sg, "Group by:", 6, 1);
C.Group1 = uidropdown(sg, "Editable", "on", "Items", "(none)", "Value", "(none)", "ValueChangedFcn", cbSel);
C.Group1.Layout.Row = 6; C.Group1.Layout.Column = 2;
lab(sg, "and:", 6, 3);
C.Group2 = uidropdown(sg, "Editable", "on", "Items", "(none)", "Value", "(none)", "ValueChangedFcn", cbSel);
C.Group2.Layout.Row = 6; C.Group2.Layout.Column = 4;

% Ordering
lab(sg, "Order:", 7, 1);
C.Order = uidropdown(sg, "Items", ["ascending" "descending" "appearance"], "ValueChangedFcn", cbSel);
C.Order.Layout.Row = 7; C.Order.Layout.Column = 2;
lab(sg, "Max groups:", 7, 3);
C.MaxGroups = uispinner(sg, "Limits", [1 100], "Value", 12, "RoundFractionalValues", "on", "ValueChangedFcn", cbSel);
C.MaxGroups.Layout.Row = 7; C.MaxGroups.Layout.Column = 4;
syncAlignEnable(C);
end


function l = lab(parent, txt, row, col)
l = uilabel(parent, "Text", txt);
l.Layout.Row = row;
l.Layout.Column = col;
end
