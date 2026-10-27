classdef AlignControls
    %AlignControls  The event-reference, epoch-window and trial-selection controls of EphysAnalysisApp and DatasetBrowser.
    %   One set of controls edits an event reference (eventRef), an epoch
    %   window (epochWindow) and a trial selection (trialSelection), event
    %   sequences included. The analysis app builds one set in its
    %   Alignment tab and two in its Figures tab; DatasetBrowser builds one
    %   for epochMatrix's settings (FixedWindow=true). Static methods only:
    %
    %     C = AlignControls.build(PARENTS, CHANGED, Name=Value)
    %         builds the three grids in PARENTS (C.RefGrid, C.WindowGrid,
    %         C.SelectionGrid) and returns the controls (below)
    %     AlignControls.show(C, REF, WIN, SEL)          the values in C
    %     [REF, WIN, SEL] = AlignControls.read(C, REF0, WIN0, SEL0)
    %         the values C shows, over REF0 / WIN0 / SEL0
    %     AlignControls.fillItems(C, SRC)               SRC's lines and parameters in the lists
    %     AlignControls.syncEnable(C)                   enable what is in use
    %     AlignControls.setSequenceHolder(HOLDER, DATA) a sequence in its summary label
    %     AlignControls.setWindowModes(DD, MODES, V)    the window modes offered
    %     F = AlignControls.editSequence(HOLDER, LINECTL, EDGECTL, DONE)
    %         the Event sequence window
    %     MSG = AlignControls.filterHelpText(SRC)       what a trial filter can use
    %
    %   The controls (fields of C)
    %     Event reference: Line, Edge, Which, N, Scope, Offset, MinDur /
    %       MaxDur (Length), TimeFrom / TimeTo (Time range), ShiftParam /
    %       ShiftUnit (Shift by: eventRef's offsetParam, offsetParamUnit),
    %       SeqText / SeqEdit (Sequence: the steps that must, or must not,
    %       follow the event, eventRef's sequence and alignStep, kept in
    %       SeqText's UserData by setSequenceHolder; Edit... opens
    %       editSequence on them)
    %     Epoch window: Mode, Pre, Post, StopOn, StopLine, StopEdge,
    %       StopWhich, StopN, StopScope, StopShiftParam / StopShiftUnit,
    %       StopSeqText / StopSeqEdit, Diagram ("Epoch Diagram": its
    %       ButtonPushedFcn is the caller's)
    %     Trial selection: Filter, FilterHelp ("?"), Response, Flags
    %       (Pairing), Group1 / Group2 (Group by), Order, MaxGroups,
    %       ExcludeArtifacts, MinArtifact
    %
    %   build's options
    %     EditSequence  @(HOLDER, LINECTL, EDGECTL, DONE): what Edit...
    %                   does (the caller keeps one window open at a time,
    %                   e.g. F = AlignControls.editSequence(...))
    %     FilterHelp    @(): what "?" beside the filter does
    %     FixedWindow   true: the window is fixed with no stop event (Mode
    %                   and the stop rows are hidden); default false
    %
    %   See also eventRef, epochWindow, trialSelection, eventRefLabel,
    %   EpochDiagram, EphysAnalysisApp, DatasetBrowser.

    methods (Static)
        function C = build(parents, changed, opts)
            %build  The Event reference, Epoch window and Trial selection controls in PARENTS (three containers).
            %   Every control calls CHANGED(PART) when edited, PART "ref",
            %   "window" or "selection".
            arguments
                parents
                changed (1,1) function_handle
                opts.EditSequence = []
                opts.FilterHelp = []
                opts.FixedWindow (1,1) logical = false
            end
            C = struct();
            cbRef = @(~,~) changed("ref");
            cbWin = @(~,~) changed("window");
            cbSel = @(~,~) changed("selection");
            [~, words] = respCodeBits();

            % --- event reference ------------------------------------------------------------
            rg = uigridlayout(parents(1), [7 4]);
            rg.RowHeight = repmat({22}, 1, 7);
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
            lab(rg, "Shift by:", 6, 1);
            C.ShiftParam = uidropdown(rg, "Editable", "on", "Items", "(none)", "Value", "(none)", "ValueChangedFcn", cbRef, ...
                "Tooltip", "A trial parameter whose value on each event's trial is added to the event time, e.g. RespLatency " + ...
                "to align to the response (Line RespWindow, onset). Events whose trial has no value (misses) are left out.");
            C.ShiftParam.Layout.Row = 6; C.ShiftParam.Layout.Column = 2;
            lab(rg, "unit:", 6, 3);
            C.ShiftUnit = uidropdown(rg, "Items", ["ms" "s"], "Value", "ms", "ValueChangedFcn", cbRef, ...
                "Tooltip", "The parameter's unit (Epsych2 stores times in ms).");
            C.ShiftUnit.Layout.Row = 6; C.ShiftUnit.Layout.Column = 4;
            lab(rg, "Sequence:", 7, 1);
            [C.SeqText, C.SeqEdit] = sequenceRow(rg, 7, "The events that must (or must not) follow each event above, " + ...
                "e.g. Trial offset then Trough onset: the first Trough onset after each trial's end.");
            if ~isempty(opts.EditSequence)
                C.SeqEdit.ButtonPushedFcn = @(~,~) opts.EditSequence(C.SeqText, C.Line, C.Edge, @() changed("ref"));
            end

            % --- window ------------------------------------------------------------------------
            wg = uigridlayout(parents(2), [8 4]);
            wg.RowHeight = [repmat({22}, 1, 7) {30}];
            wg.ColumnWidth = {95, '1x', 70, '1x'};
            wg.RowSpacing = 4;
            C.WindowGrid = wg;
            lab(wg, "Mode:", 1, 1);
            C.Mode = uidropdown(wg, "Items", "", "ValueChangedFcn", cbWin);
            AlignControls.setWindowModes(C.Mode, ["fixed" "between"], "fixed");
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
            lab(wg, "Stop shift by:", 6, 1);
            C.StopShiftParam = uidropdown(wg, "Editable", "on", "Items", "(none)", "Value", "(none)", "ValueChangedFcn", cbWin, ...
                "Tooltip", "A trial parameter whose value on the epoch's trial is added to the stop event, e.g. RespLatency " + ...
                "after RespWindow onset: the response time, marked on each raster row and sortable as the stop latency.");
            C.StopShiftParam.Layout.Row = 6; C.StopShiftParam.Layout.Column = 2;
            lab(wg, "unit:", 6, 3);
            C.StopShiftUnit = uidropdown(wg, "Items", ["ms" "s"], "Value", "ms", "ValueChangedFcn", cbWin, ...
                "Tooltip", "The parameter's unit (Epsych2 stores times in ms).");
            C.StopShiftUnit.Layout.Row = 6; C.StopShiftUnit.Layout.Column = 4;
            lab(wg, "Stop sequence:", 7, 1);
            [C.StopSeqText, C.StopSeqEdit] = sequenceRow(wg, 7, "The events that must follow the stop line's event, " + ...
                "e.g. RespWindow offset then Trough onset: stop at the first Trough onset after the response window.");
            if ~isempty(opts.EditSequence)
                C.StopSeqEdit.ButtonPushedFcn = @(~,~) opts.EditSequence(C.StopSeqText, C.StopLine, C.StopEdge, @() changed("window"));
            end
            C.Diagram = uibutton(wg, "Text", "Epoch Diagram");   % the caller sets its ButtonPushedFcn and tooltip
            C.Diagram.Layout.Row = 8; C.Diagram.Layout.Column = [1 4];
            if opts.FixedWindow
                % fixed, no stop event: only Pre / Post and the diagram show
                AlignControls.setWindowModes(C.Mode, "fixed", "fixed");
                hide = [1 3:7];
                wg.RowHeight(hide) = {0};
                for h = reshape(wg.Children, 1, [])
                    if any(ismember(h.Layout.Row, hide)); h.Visible = "off"; end
                end
            end

            % --- selection -----------------------------------------------------------------------
            sg = uigridlayout(parents(3), [6 4]);
            sg.RowHeight = {22, 120, 66, 22, 22, 22};
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
            C.FilterHelp = uibutton(fg, "Text", "?", "Tooltip", "The trial columns, response words and functions a filter can use.");
            if ~isempty(opts.FilterHelp)
                C.FilterHelp.ButtonPushedFcn = @(~,~) opts.FilterHelp();
            end

            % Response codes: a multi-select list (none selected = every response)
            l = lab(sg, "Response:", 2, 1);
            l.VerticalAlignment = "top";
            C.Response = uilistbox(sg, "Items", cellstr(words), "Multiselect", "on", "Value", {}, "ValueChangedFcn", cbSel, ...
                "Tooltip", "Keep trials that are any of the selected responses (none selected = every response; Ctrl or Shift to select several).");
            C.Response.Layout.Row = 2; C.Response.Layout.Column = [2 4];

            % Pairing flags: a multi-select list
            l = lab(sg, "Pairing:", 3, 1);
            l.VerticalAlignment = "top";
            C.Flags = uilistbox(sg, "Items", {'ok', 'partial', 'cut', 'unpaired'}, "Multiselect", "on", "Value", {'ok'}, "ValueChangedFcn", cbSel, ...
                "Tooltip", "Keep trials with any of the selected PairingFlags (none selected = every flag; Ctrl or Shift to select several).");
            C.Flags.Layout.Row = 3; C.Flags.Layout.Column = [2 4];

            % Grouping
            lab(sg, "Group by:", 4, 1);
            C.Group1 = uidropdown(sg, "Editable", "on", "Items", "(none)", "Value", "(none)", "ValueChangedFcn", cbSel);
            C.Group1.Layout.Row = 4; C.Group1.Layout.Column = 2;
            lab(sg, "and:", 4, 3);
            C.Group2 = uidropdown(sg, "Editable", "on", "Items", "(none)", "Value", "(none)", "ValueChangedFcn", cbSel);
            C.Group2.Layout.Row = 4; C.Group2.Layout.Column = 4;

            % Ordering
            lab(sg, "Order:", 5, 1);
            C.Order = uidropdown(sg, "Items", ["ascending" "descending" "appearance"], "ValueChangedFcn", cbSel);
            C.Order.Layout.Row = 5; C.Order.Layout.Column = 2;
            lab(sg, "Max groups:", 5, 3);
            C.MaxGroups = uispinner(sg, "Limits", [1 100], "Value", 100, "RoundFractionalValues", "on", "ValueChangedFcn", cbSel);
            C.MaxGroups.Layout.Row = 5; C.MaxGroups.Layout.Column = 4;

            % Artifacts
            lab(sg, "Artifacts:", 6, 1);
            C.ExcludeArtifacts = uicheckbox(sg, "Text", "Exclude epochs", "Value", true, "ValueChangedFcn", cbSel, ...
                "Tooltip", "Leave out the epochs whose window (or baseline) touches an artifact period, the stretches the " + ...
                "Signals step erased. Untick to keep them: their signal is the erased (filled) stretch.");
            C.ExcludeArtifacts.Layout.Row = 6; C.ExcludeArtifacts.Layout.Column = 2;
            lab(sg, "at least (s):", 6, 3);
            C.MinArtifact = uieditfield(sg, "numeric", "Value", 0, "Limits", [0 Inf], "ValueChangedFcn", cbSel, ...
                "Tooltip", "Only artifact periods at least this long exclude an epoch (0 = every one).");
            C.MinArtifact.Layout.Row = 6; C.MinArtifact.Layout.Column = 4;
            AlignControls.syncEnable(C);
        end

        function show(C, ref, win, sel)
            %show  Show an event reference, window and selection in a control set.
            %   The fields without a control (the stop event's offset, interval length
            %   and time range; the selection's explicit trial rows) are not shown:
            %   read keeps them from the values it is given. A window mode the mode
            %   box does not offer is added to it. The sequences go to their summary
            %   labels (setSequenceHolder). A caller with an Event sequence window
            %   open on C's sequences closes it first.
            ref = EphysAnalysisConfig.normalizeSection("EventRef", ref);   % shown as is, checked elsewhere
            C.Line.Value = char(ref.line);
            C.Edge.Value = char(ref.edge);
            C.Which.Value = char(ref.which);
            C.N.Value = ref.n;
            C.Scope.Value = char(ref.scope);
            C.Offset.Value = ref.offsetSec;
            C.MinDur.Value = num2text(ref.minDurationSec);
            C.MaxDur.Value = num2text(ref.maxDurationSec);
            C.TimeFrom.Value = num2text(ref.timeRange(1));
            C.TimeTo.Value = num2text(ref.timeRange(2));
            setDrop(C.ShiftParam, noneIfEmpty(ref.offsetParam));
            setDrop(C.ShiftUnit, ref.offsetParamUnit);
            AlignControls.setSequenceHolder(C.SeqText, struct('sequence', ref.sequence, 'alignStep', ref.alignStep));

            w = EphysAnalysisConfig.normalizeSection("EpochWindow", win);
            AlignControls.setWindowModes(C.Mode, string(C.Mode.ItemsData), w.mode);
            C.Pre.Value = w.pre;
            C.Post.Value = w.post;
            C.StopOn.Value = ~isempty(w.stop);
            stopSeq = struct('sequence', repmat(EphysAnalysisConfig.defaults("SequenceStep"), 1, 0), 'alignStep', Inf);
            if ~isempty(w.stop); stopSeq = struct('sequence', w.stop.sequence, 'alignStep', w.stop.alignStep); end
            AlignControls.setSequenceHolder(C.StopSeqText, stopSeq);
            if ~isempty(w.stop)
                s = w.stop;
                C.StopLine.Value = char(s.line);
                C.StopEdge.Value = char(s.edge);
                C.StopWhich.Value = char(s.which);
                C.StopN.Value = s.n;
                C.StopScope.Value = char(s.scope);
                setDrop(C.StopShiftParam, noneIfEmpty(s.offsetParam));
                setDrop(C.StopShiftUnit, s.offsetParamUnit);
            end
            s = EphysAnalysisConfig.normalizeSection("TrialSelection", sel);
            C.Filter.Value = char(s.filter);
            C.Response.Value = cellstr(C.Response.Items(ismember(string(C.Response.Items), s.response)));
            C.Flags.Value = cellstr(C.Flags.Items(ismember(string(C.Flags.Items), s.pairingFlags)));
            g = [s.groupBy "(none)" "(none)"];
            setDrop(C.Group1, g(1));
            setDrop(C.Group2, g(2));
            C.Order.Value = char(s.groupOrder);
            C.MaxGroups.Value = s.maxGroups;
            C.ExcludeArtifacts.Value = s.excludeArtifacts;
            C.MinArtifact.Value = s.minArtifactSec;
            AlignControls.syncEnable(C);
        end

        function [ref, win, sel] = read(C, ref, win, sel)
            %read  The event reference, window and selection a control set shows.
            %   [REF, WIN, SEL] = AlignControls.read(C, REF0, WIN0, SEL0) takes the
            %   values the controls C were shown from (show) and sets every field
            %   that has a control. The others keep their values: the stop event's
            %   offset, interval length and time range, and the selection's explicit
            %   trial rows (a stop event ticked on anew starts from the eventRef
            %   defaults). Normalized, not checked: the callers check them.
            ref = EphysAnalysisConfig.normalizeSection("EventRef", ref);
            win = EphysAnalysisConfig.normalizeSection("EpochWindow", win);
            sel = EphysAnalysisConfig.normalizeSection("TrialSelection", sel);
            ref.line = strtrim(string(C.Line.Value));
            ref.edge = string(C.Edge.Value);
            ref.which = string(C.Which.Value);
            ref.n = C.N.Value;
            ref.scope = string(C.Scope.Value);
            ref.minDurationSec = text2num(C.MinDur.Value, 0);
            ref.maxDurationSec = text2num(C.MaxDur.Value, Inf);
            ref.timeRange = [text2num(C.TimeFrom.Value, -Inf) text2num(C.TimeTo.Value, Inf)];
            ref.offsetSec = C.Offset.Value;
            ref.offsetParam = paramOf(C.ShiftParam);
            ref.offsetParamUnit = string(C.ShiftUnit.Value);
            ref.sequence = C.SeqText.UserData.sequence;
            ref.alignStep = C.SeqText.UserData.alignStep;
            stop = [];
            if C.StopOn.Value
                stop = win.stop;
                if isempty(stop); stop = EphysAnalysisConfig.defaults("EventRef"); end
                stop.line = strtrim(string(C.StopLine.Value));
                stop.edge = string(C.StopEdge.Value);
                stop.which = string(C.StopWhich.Value);
                stop.n = C.StopN.Value;
                stop.scope = string(C.StopScope.Value);
                stop.offsetParam = paramOf(C.StopShiftParam);
                stop.offsetParamUnit = string(C.StopShiftUnit.Value);
                stop.sequence = C.StopSeqText.UserData.sequence;
                stop.alignStep = C.StopSeqText.UserData.alignStep;
            end
            win.mode = string(C.Mode.Value);
            win.pre = C.Pre.Value;
            win.post = C.Post.Value;
            win.stop = stop;
            resp = reshape(string(C.Response.Value), 1, []);
            flags = reshape(string(C.Flags.Value), 1, []);
            g = strtrim([string(C.Group1.Value) string(C.Group2.Value)]);
            g = g(g ~= "(none)" & g ~= "");
            g = unique(g, 'stable');
            if isempty(resp); resp = string.empty(1, 0); end
            if isempty(flags); flags = string.empty(1, 0); end
            if isempty(g); g = string.empty(1, 0); end
            sel.filter = strtrim(string(C.Filter.Value));
            sel.response = resp;
            sel.pairingFlags = flags;
            sel.groupBy = g;
            sel.groupOrder = string(C.Order.Value);
            sel.maxGroups = C.MaxGroups.Value;
            sel.excludeArtifacts = C.ExcludeArtifacts.Value;
            sel.minArtifactSec = C.MinArtifact.Value;
        end

        function fillItems(C, src)
            %fillItems  List SRC's lines and trial parameters in a control set ([] SRC: only "Trial").
            %   The line boxes offer "Trial" and every digital line (the extract's and
            %   the trials'); the group-by and shift-by boxes every Epsych2 parameter.
            %   The boxes are editable, so a value SRC lacks stays as typed.
            lines = "Trial";
            params = string.empty(1, 0);
            if ~isempty(src)
                if isstruct(src.events); lines = [lines string(fieldnames(src.events)).']; end
                if src.hasTrials && height(src.trials) > 0 && ismember("TrialEvents", string(src.trials.Properties.VariableNames))
                    lines = [lines string(fieldnames(src.trials.TrialEvents)).'];
                end
                params = reshape(string(src.paramNames), 1, []);
            end
            lines = unique(lines, 'stable');
            setItems(C.Line, lines);
            setItems(C.StopLine, lines);
            setItems(C.Group1, ["(none)" params]);
            setItems(C.Group2, ["(none)" params]);
            setItems(C.ShiftParam, ["(none)" params]);
            setItems(C.StopShiftParam, ["(none)" params]);
        end

        function syncEnable(C)
            %syncEnable  Enable the controls C whose options are in use.
            %   The stop event's line, edge, which, n, scope, shift and sequence only
            %   with the stop event ticked; each n only for "nth"; each shift's unit
            %   only with a parameter to shift by; the artifacts' minimum length only
            %   when they exclude epochs.
            en = @(c, tf) set(c, 'Enable', matlab.lang.OnOffSwitchState(tf));
            en(C.N, string(C.Which.Value) == "nth");
            stop = C.StopOn.Value;
            en([C.StopLine C.StopEdge C.StopWhich C.StopScope C.StopSeqText C.StopSeqEdit], stop);
            en(C.StopN, stop && string(C.StopWhich.Value) == "nth");
            en(C.StopShiftParam, stop);
            shifts = @(dd) ~ismember(strtrim(string(dd.Value)), ["(none)" ""]);
            en(C.ShiftUnit, shifts(C.ShiftParam));
            en(C.StopShiftUnit, stop && shifts(C.StopShiftParam));
            en(C.MinArtifact, C.ExcludeArtifacts.Value);
        end

        function setSequenceHolder(holder, data)
            %setSequenceHolder  Keep an event sequence in its summary label and show it.
            %   setSequenceHolder(HOLDER, DATA) stores DATA, struct('sequence', STEPS,
            %   'alignStep', A) -- an event reference's or a stop's steps (the
            %   "Sequence" rows, the figure editor's event and sort rows) -- in the
            %   label HOLDER's UserData and writes its summary as the label's text
            %   and tooltip: "none", or the steps after the line, e.g. "then Trough
            %   onset". editSequence edits DATA; read (and the figure editor) read
            %   it back.
            if isempty(data.sequence)
                txt = "none";
            else
                r = EphysAnalysisConfig.defaults("EventRef");
                r.line = char(1);   % a placeholder for the panel's line, cut off below
                r.sequence = data.sequence;
                r.alignStep = data.alignStep;
                lbl = eventRefLabel(r);
                txt = replace(extractAfter(lbl, strlength(r.line + " " + r.edge + " ")), r.line + " " + r.edge, "the event");
            end
            holder.UserData = data;
            holder.Text = txt;
            holder.Tooltip = txt;
        end

        function setWindowModes(dd, modes, v)
            %setWindowModes  Offer the epoch-window MODES in DD and show V (kept when not among them).
            %   The items spell out each mode's window: fixed [t0+pre, t0+post],
            %   between [t0+pre, stop+post]. V defaults to DD's value.
            if nargin < 3; v = string(dd.Value); end
            labels = dictionary(["fixed" "between"], ["fixed: [t0+pre, t0+post]" "between: [t0+pre, stop+post]"]);
            modes = unique([reshape(string(modes), 1, []) string(v)], 'stable');
            items = modes;
            known = isKey(labels, modes);
            items(known) = labels(modes(known));
            dd.Items = items;
            dd.ItemsData = modes;
            dd.Value = string(v);
        end

        function f = editSequence(holder, lineCtl, edgeCtl, done)
            %editSequence  Edit an event sequence in a window of its own; F the window.
            %   F = AlignControls.editSequence(HOLDER, LINECTL, EDGECTL, DONE) opens
            %   the "Event sequence" window on the sequence the label HOLDER keeps
            %   (setSequenceHolder): one event reference's (or stop's) steps. It
            %   starts at the line and edge of the drop-downs LINECTL / EDGECTL
            %   (shown, edited in the panel). The steps are a table: Then (followed
            %   by / not followed by), Line (a drop-down of LINECTL's lines), Edge,
            %   n, Within (s) (maxGapSec, Inf = up to the next trial), Min / Max
            %   length (s). "Align to" picks the epoch's event (alignStep). Apply
            %   checks the steps (eventRef), stores them in HOLDER and calls DONE();
            %   Cancel drops them. The window opens over HOLDER's figure. Its
            %   UserData holds HOLDER (Holder) and its controls (Line, Edge, Table,
            %   Align, AddStep, RemoveStep, Up, Down, Apply, Cancel) for the tests.
            %   The caller keeps one window at a time (deletes F before opening
            %   another, and when HOLDER shows other values).
            lines = unique(["Trial" string(lineCtl.Items)], 'stable');
            r = EphysAnalysisConfig.defaults("EventRef");
            r.line = strtrim(string(lineCtl.Value));
            r.edge = string(edgeCtl.Value);
            r.sequence = holder.UserData.sequence;
            r.alignStep = holder.UserData.alignStep;
            ref = r;

            pos = [100 100 720 470];
            owner = ancestor(holder, 'figure');
            if ~isempty(owner); pos(1:2) = owner.Position(1:2) + 120; end
            f = uifigure("Name", "Event sequence", "Position", pos);
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
                    AlignControls.setSequenceHolder(holder, struct('sequence', r.sequence, 'alignStep', r.alignStep));
                catch ME
                    uialert(f, string(ME.message), "Event sequence");
                    return
                end
                delete(f);
                done();
            end
        end

        function msg = filterHelpText(src)
            %filterHelpText  What a trial filter can use: SRC's trial columns ([] SRC: none listed), the response words, the functions.
            [~, words] = respCodeBits();
            cols = "(scan and pick a dataset to list its trial columns)";
            if ~isempty(src) && src.hasBehavior
                v = string(src.trials.Properties.VariableNames);
                ok = arrayfun(@(c) isvarname(c) && size(src.trials.(c), 2) == 1 && ~isstruct(src.trials.(c)), v);
                v = v(ok);
                [~, ord] = sort(lower(v));
                cols = strjoin(v(ord), ", ");
            end
            msg = "A filter keeps the trials for which it is true, e.g." + newline + ...
                "   Depth > 0 & RespLatency < 500" + newline + ...
                "   Hit | Miss" + newline + ...
                "   ismember(Depth, [0.5 1]) & ~FA" + newline + newline + ...
                "Trial columns: " + cols + newline + newline + ...
                "Response words (bits of RespCode): " + strjoin(words, ", ") + newline + newline + ...
                "Operators: == ~= (or !=) < <= > >= & | ~ (or !) + - * / ( ) [ ], a single = means ==." + newline + ...
                "Functions: abs round floor ceil fix mod rem min max isnan isfinite ismissing ismember any all " + ...
                "strcmp strcmpi contains startsWith endsWith lower upper string double bitand; true false pi NaN Inf." + newline + ...
                "Text columns compare with ==, e.g. Protocol == ""AM"". Nothing else is evaluated.";
        end
    end
end


function [txt, btn] = sequenceRow(grid, row, tip)
%sequenceRow  A sequence's summary (setSequenceHolder) and its Edit button, in ROW of GRID.
sg = uigridlayout(grid, [1 2]);
sg.Layout.Row = row; sg.Layout.Column = [2 4];
sg.ColumnWidth = {'1x', 70};
sg.Padding = [0 0 0 0];
txt = uilabel(sg, "Text", "none");
AlignControls.setSequenceHolder(txt, struct('sequence', repmat(EphysAnalysisConfig.defaults("SequenceStep"), 1, 0), 'alignStep', Inf));
btn = uibutton(sg, "Text", "Edit...", "Tooltip", tip);
end


function l = lab(parent, txt, row, col)
l = uilabel(parent, "Text", txt);
l.Layout.Row = row;
l.Layout.Column = col;
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


function t = num2text(x)
if isinf(x)
    if x > 0; t = 'Inf'; else; t = '-Inf'; end
else
    t = char(string(x));
end
end


function v = noneIfEmpty(v)
if v == ""; v = "(none)"; end
end


function setDrop(dd, v)
%setDrop  Drop-down DD shows V (added to its items when they lack it).
if ~ismember(v, string(dd.Items)); dd.Items = [string(dd.Items) v]; end
dd.Value = char(v);
end


function setItems(dd, items)
%setItems  ITEMS in drop-down DD; its value stays (added when the items lack it).
v = string(dd.Value);
if ~ismember(v, items); items = [items v]; end
dd.Items = items;
dd.Value = char(v);
end


function p = paramOf(dd)
%paramOf  The parameter a "(none)"-or-parameter drop-down shows ("" for none).
p = strtrim(string(dd.Value));
if p == "(none)"; p = ""; end
end


function x = text2num(t, default)
t = lower(strtrim(string(t)));
switch t
    case {"inf", "+inf"}, x = Inf;
    case "-inf",          x = -Inf;
    case "",              x = default;
    otherwise
        x = str2double(t);
        if isnan(x); x = default; end
end
end
