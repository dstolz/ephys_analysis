function C = buildAlignControls(obj, parent, changed)
%buildAlignControls  Event-reference, window and trial-selection controls in PARENT.
%   C = buildAlignControls(obj, PARENT, CHANGED) builds three panels stacked
%   in PARENT -- Event reference (eventRef), Window (epochWindow, with its
%   stop event) and Trial selection (trialSelection) -- and returns their
%   handles; every control calls CHANGED when edited. The Alignment tab
%   uses one set for the config's Defaults, the Plots tab another for a
%   plot's own values (applyAlignControls / gatherAlignControls move values
%   in and out; fillAlignItems lists the active dataset's lines and
%   parameters).
g = uigridlayout(parent, [3 1]);
g.RowHeight = {'fit', 'fit', 'fit'};
g.Padding = [0 0 0 0];
g.RowSpacing = 6;
C = struct();
cb = @(~,~) changed();
[~, words] = respCodeBits();

% --- event reference ------------------------------------------------------------
C.RefPanel = uipanel(g, "Title", "Event reference (align to)");
rg = uigridlayout(C.RefPanel, [5 4]);
rg.RowHeight = repmat({22}, 1, 5);
rg.ColumnWidth = {80, '1x', 80, '1x'};
rg.RowSpacing = 4;
lab(rg, "Line:", 1, 1);
C.Line = uidropdown(rg, "Editable", "on", "Items", "Stim", "Value", "Stim", "ValueChangedFcn", cb, ...
    "Tooltip", "The digital line to align to; ""Trial"" is the paired trial line (TrialOnset / TrialOffset).");
C.Line.Layout.Row = 1; C.Line.Layout.Column = 2;
lab(rg, "Edge:", 1, 3);
C.Edge = uidropdown(rg, "Items", ["onset" "offset"], "ValueChangedFcn", cb);
C.Edge.Layout.Row = 1; C.Edge.Layout.Column = 4;
lab(rg, "Which:", 2, 1);
C.Which = uidropdown(rg, "Items", ["first" "last" "all" "nth"], "ValueChangedFcn", cb, ...
    "Tooltip", "Per trial in trial scope, over the recording in recording scope.");
C.Which.Layout.Row = 2; C.Which.Layout.Column = 2;
lab(rg, "n:", 2, 3);
C.N = uispinner(rg, "Limits", [1 Inf], "Step", 1, "Value", 1, "RoundFractionalValues", "on", "ValueChangedFcn", cb);
C.N.Layout.Row = 2; C.N.Layout.Column = 4;
lab(rg, "Scope:", 3, 1);
C.Scope = uidropdown(rg, "Items", ["auto" "trial" "recording"], "ValueChangedFcn", cb, ...
    "Tooltip", "trial: the line's intervals inside each selected trial; recording: every interval; auto: trial when the dataset has paired trials.");
C.Scope.Layout.Row = 3; C.Scope.Layout.Column = 2;
lab(rg, "Offset (s):", 3, 3);
C.Offset = uieditfield(rg, "numeric", "Value", 0, "ValueChangedFcn", cb, "Tooltip", "Added to every event time.");
C.Offset.Layout.Row = 3; C.Offset.Layout.Column = 4;
lab(rg, "Length (s):", 4, 1);
C.MinDur = uieditfield(rg, "text", "Value", "0", "ValueChangedFcn", cb, "Tooltip", "Keep intervals at least this long.");
C.MinDur.Layout.Row = 4; C.MinDur.Layout.Column = 2;
lab(rg, "to", 4, 3);
C.MaxDur = uieditfield(rg, "text", "Value", "Inf", "ValueChangedFcn", cb, "Tooltip", "... and at most this long (Inf = no limit).");
C.MaxDur.Layout.Row = 4; C.MaxDur.Layout.Column = 4;
lab(rg, "Time range (s):", 5, 1);
C.TimeFrom = uieditfield(rg, "text", "Value", "-Inf", "ValueChangedFcn", cb, ...
    "Tooltip", "Keep events in this range: from the trial onset (trial scope) or the recording start.");
C.TimeFrom.Layout.Row = 5; C.TimeFrom.Layout.Column = 2;
lab(rg, "to", 5, 3);
C.TimeTo = uieditfield(rg, "text", "Value", "Inf", "ValueChangedFcn", cb);
C.TimeTo.Layout.Row = 5; C.TimeTo.Layout.Column = 4;

% --- window ------------------------------------------------------------------------
C.WindowPanel = uipanel(g, "Title", "Epoch window");
wg = uigridlayout(C.WindowPanel, [4 4]);
wg.RowHeight = repmat({22}, 1, 4);
wg.ColumnWidth = {80, '1x', 80, '1x'};
wg.RowSpacing = 4;
lab(wg, "Mode:", 1, 1);
C.Mode = uidropdown(wg, "Items", ["fixed: [t0+pre, t0+post]" "between: [t0+pre, stop+post]"], ...
    "ItemsData", ["fixed" "between"], "ValueChangedFcn", cb);
C.Mode.Layout.Row = 1; C.Mode.Layout.Column = [2 4];
lab(wg, "Pre (s):", 2, 1);
C.Pre = uieditfield(wg, "numeric", "Value", -0.2, "ValueChangedFcn", cb);
C.Pre.Layout.Row = 2; C.Pre.Layout.Column = 2;
lab(wg, "Post (s):", 2, 3);
C.Post = uieditfield(wg, "numeric", "Value", 0.8, "ValueChangedFcn", cb);
C.Post.Layout.Row = 2; C.Post.Layout.Column = 4;
C.StopOn = uicheckbox(wg, "Text", "Stop event:", "ValueChangedFcn", cb, ...
    "Tooltip", "Ends each epoch (between mode); in fixed mode it is marked and can mask the PSTH.");
C.StopOn.Layout.Row = 3; C.StopOn.Layout.Column = 1;
C.StopLine = uidropdown(wg, "Editable", "on", "Items", "Stim", "Value", "Stim", "ValueChangedFcn", cb);
C.StopLine.Layout.Row = 3; C.StopLine.Layout.Column = 2;
C.StopEdge = uidropdown(wg, "Items", ["offset" "onset"], "ValueChangedFcn", cb);
C.StopEdge.Layout.Row = 3; C.StopEdge.Layout.Column = [3 4];
lab(wg, "Stop which:", 4, 1);
C.StopWhich = uidropdown(wg, "Items", ["first" "last" "all" "nth"], "ValueChangedFcn", cb, ...
    "Tooltip", "Among the stop events at or after each epoch's event.");
C.StopWhich.Layout.Row = 4; C.StopWhich.Layout.Column = 2;
C.StopScope = uidropdown(wg, "Items", ["auto" "trial" "recording"], "ValueChangedFcn", cb);
C.StopScope.Layout.Row = 4; C.StopScope.Layout.Column = [3 4];

% --- selection -----------------------------------------------------------------------
C.SelectionPanel = uipanel(g, "Title", "Trial selection");
sg = uigridlayout(C.SelectionPanel, [8 4]);
sg.RowHeight = repmat({22}, 1, 8);
sg.ColumnWidth = {90, '1x', 90, '1x'};
sg.RowSpacing = 6;
sg.Padding = [8 8 8 8];

% Filter
lab(sg, "Filter:", 1, 1);
fg = uigridlayout(sg, [1 2]);
fg.Layout.Row = 1; fg.Layout.Column = [2 4];
fg.ColumnWidth = {'1x', 28};
fg.Padding = [0 0 0 0];
C.Filter = uieditfield(fg, "text", "Placeholder", "e.g. Depth > 0 & RespLatency < 500   or   Hit | Miss", "ValueChangedFcn", cb);
C.FilterHelp = uibutton(fg, "Text", "?", "Tooltip", "The trial columns, response words and functions a filter can use.", ...
    "ButtonPushedFcn", @(~,~) obj.onFilterHelp());

% Response codes
lab(sg, "Response:", 2, 1);
rsp = uigridlayout(sg, [1 numel(words)]);
rsp.Layout.Row = 2; rsp.Layout.Column = [2 4];
rsp.Padding = [0 0 0 0]; rsp.ColumnSpacing = 3;
C.Response = struct();
for w = words
    C.Response.(w) = uicheckbox(rsp, "Text", w, "ValueChangedFcn", cb, "Tooltip", "Keep trials that are any of the ticked responses.");
end

% Pairing flags
lab(sg, "Pairing:", 3, 1);
flg = uigridlayout(sg, [2 2]);
flg.Layout.Row = [3 4]; flg.Layout.Column = [2 4];
flg.Padding = [0 0 0 0]; flg.RowSpacing = 3; flg.ColumnSpacing = 12;
C.Flags = struct();
flags = ["ok" "partial" "cut" "unpaired"];
for i = 1:numel(flags)
    f = flags(i);
    row = 1 + mod(i-1, 2);
    col = 1 + floor((i-1)/2);
    C.Flags.(f) = uicheckbox(flg, "Text", f, "Value", f == "ok", "ValueChangedFcn", cb, ...
        "Tooltip", "Keep trials with this PairingFlag (none ticked = every flag).");
    C.Flags.(f).Layout.Row = row;
    C.Flags.(f).Layout.Column = col;
end

% Grouping
lab(sg, "Group by:", 5, 1);
C.Group1 = uidropdown(sg, "Editable", "on", "Items", "(none)", "Value", "(none)", "ValueChangedFcn", cb);
C.Group1.Layout.Row = 5; C.Group1.Layout.Column = 2;
lab(sg, "and:", 5, 3);
C.Group2 = uidropdown(sg, "Editable", "on", "Items", "(none)", "Value", "(none)", "ValueChangedFcn", cb);
C.Group2.Layout.Row = 5; C.Group2.Layout.Column = 4;

% Ordering
lab(sg, "Order:", 6, 1);
C.Order = uidropdown(sg, "Items", ["ascending" "descending" "appearance"], "ValueChangedFcn", cb);
C.Order.Layout.Row = 6; C.Order.Layout.Column = 2;
lab(sg, "Max groups:", 6, 3);
C.MaxGroups = uispinner(sg, "Limits", [1 100], "Value", 12, "RoundFractionalValues", "on", "ValueChangedFcn", cb);
C.MaxGroups.Layout.Row = 6; C.MaxGroups.Layout.Column = 4;
end


function l = lab(parent, txt, row, col)
l = uilabel(parent, "Text", txt);
l.Layout.Row = row;
l.Layout.Column = col;
end
