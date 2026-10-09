classdef EpochDiagram < handle
    %EpochDiagram  A window that draws how epochs are cut from a recording.
    %   D = EpochDiagram() opens the window; D.update(SRC, REF, WIN, SEL)
    %   draws how the event reference REF (eventRef), the epoch window WIN
    %   (epochWindow) and the trial selection SEL (trialSelection) cut the
    %   dataset SRC (loadAnalysisSource) into epochs. It goes through
    %   epochTable, so the epochs it draws are the ones a plot gets.
    %
    %   The window, top to bottom:
    %     the rule in words: what time 0 is, where each epoch starts and
    %       ends, which trials count
    %     the count: how many epochs, and how many events were dropped, why
    %     The recording: a stretch of it with each digital line involved as
    %       its TTL trace -- the trials (each in its group's colour, the ones
    %       the selection leaves out grey), the event's line and the stop
    %       event's line (with an event sequence, every line of it: time 0
    %       is on the step the sequence is aligned to, e.g. Trough for
    %       "Trial offset then Trough onset"). Each event picked is marked ▲
    %       on its line and a line in its group's colour runs through every
    %       row at it: time 0. With a sequence, ○ marks where it starts
    %       (its line's own event), with a dotted line to the ▲. An event
    %       moved by an offset or a trial parameter (Offset, Shift by) has
    %       an arrow from its edge to time 0. The stop event
    %       is marked ▼, with a dotted line. Each epoch's window is shaded
    %       across the rows and drawn as a bar on the Epochs row, numbered
    %       as the plot numbers its epochs; an epoch the plot drops is grey,
    %       crossed and says why. The baseline (a bar under each epoch),
    %       the time range searched for the event, the artifact periods and
    %       the stretches outside the recording show too
    %     Aligned to the event: the same epochs, one row each, on the time
    %       from their event, with the event's line as each epoch sees it:
    %       what the plot stacks and averages
    %     ◀ Previous / Next ▶ step through the events; Show sets how many
    %       are drawn at a time. The axes zoom and pan (their toolbar)
    %
    %   D = EpochDiagram(Name=Value)
    %     Position     the window's [left bottom width height]
    %     Visible      true (default) | false
    %     WindowStyle  "alwaysontop" (default: it stays above the app, whose
    %                  controls keep working) | "normal"
    %     Owner        a figure: the window closes with it
    %
    %   D.update(SRC, REF, WIN, SEL, Name=Value)
    %     Baseline     [b0 b1] s from the event ([] = none), as epochTable
    %                  (it tests the baseline against the recording's edges
    %                  and artifacts too)
    %     Incomplete   "drop" (default) | "keep", as epochTable
    %     Artifacts    "drop" (default) | "keep", as epochTable
    %     Title        the heading
    %   A value epochTable refuses (a fixed window with pre > post, a line
    %   the dataset lacks, ...) is reported in red and the lines are drawn
    %   all the same.
    %
    %   D.clear(MSG) empties it with a message; D.page(STEP) shows the next
    %   (STEP 1) or previous (-1) events; D.showFrom(K) starts at event K;
    %   D.setCount(N) draws N events at a time; D.close() closes it (so does
    %   its close box); D.isOpen().
    %
    %   What it drew:
    %     Epochs   every event and its epoch: epochTable's columns with
    %              Incomplete and Artifacts "keep", plus kept (the plot keeps
    %              it), number (its number among the plot's epochs; NaN when
    %              dropped), reason ("" | "no stop event" | "ends before it
    %              starts" | "outside the recording" | "touches an artifact
    %              period"), edge and stopEdge (the line edges the event and
    %              the stop event were picked at, before their offsets and
    %              shifts), anchorEdge (where the event's sequence starts,
    %              when it is aligned to a later step; else NaN)
    %     Groups   epochTable's groups, in the colours drawn (theirs; blue
    %              for one ungrouped set, which the plots draw dark grey)
    %     Heading  update's Title
    %     Rule     the rule in words, a sentence a row (describe)
    %     Summary, Message   the count line; what went wrong ("" if nothing)
    %     Shown    the rows of Epochs drawn (every event in the stretch)
    %     Range    the stretch of the recording drawn, s
    %     Lanes    the rows of the recording view, top to bottom
    %
    %   S = EpochDiagram.describe(REF, WIN, SEL, HASTRIALS) is the rule in
    %   words without a window.
    %
    %   See also epochTable, eventRef, epochWindow, trialSelection,
    %   EphysAnalysisApp.

    properties (SetAccess = private)
        Fig                                     % the window (uifigure)
        Heading (1,1) string = ""               % what it shows (update's Title)
        Epochs table = table()                  % every event and its epoch (above)
        Groups table = table()                  % epochTable's groups
        Rule (:,1) string = strings(0, 1)       % the rule in words, a sentence a row
        Summary (1,1) string = ""               % the count line
        Message (1,1) string = ""               % what went wrong ("" if nothing)
        Shown (:,1) double = zeros(0, 1)        % rows of Epochs drawn
        Range (1,2) double = [0 1]              % the stretch of the recording drawn, s
        Lanes (1,:) string = string.empty(1, 0) % the recording view's rows, top to bottom
        First (1,1) double = 1                  % the first event drawn
        Count (1,1) double = 5                  % events drawn at a time
    end

    properties (Access = private)
        Ui struct = struct()
        Src = []                                % the dataset (loadAnalysisSource)
        Ref = []                                % eventRef
        Win = []                                % epochWindow
        Sel = []                                % trialSelection
        Scope (1,1) string = "recording"        % the event's scope, "auto" resolved
        Baseline double = []
        TrialKept = false(0, 1)                 % the trials the selection keeps
        TrialColor = zeros(0, 3)                % each trial's colour (its group's)
        OwnerListener = []
    end

    properties (Constant, Access = private)
        StopColor = [0.12 0.12 0.12]
        OutColor = [0.82 0.82 0.82]             % a trial the selection leaves out
        DropGray = [0.55 0.55 0.55]             % a dropped epoch
        DropColor = [0.75 0.12 0.12]            % its cross and reason
        LineFill = [0.84 0.86 0.91]             % a digital line's pulses
        LineEdge = [0.30 0.32 0.38]
        ArtifactColor = [0.96 0.55 0.50]
        RangeColor = [1 0.92 0.55]
        OneGroupColor = [0 0.447 0.741]         % the one ungrouped set (the plots draw it dark grey)
        NoData = "Scan and pick a dataset to see how its epochs are cut."
    end

    methods
        function obj = EpochDiagram(opts)
            arguments
                opts.Position (1,4) double = [200 100 780 720]
                opts.Visible (1,1) logical = true
                opts.WindowStyle (1,1) string {mustBeMember(opts.WindowStyle, ["alwaysontop" "normal"])} = "alwaysontop"
                opts.Owner = []
            end
            obj.Fig = uifigure("Name", "How the epochs are cut", "Position", opts.Position, ...
                "Visible", opts.Visible, "WindowStyle", opts.WindowStyle, "CloseRequestFcn", @(~,~) obj.close());
            build(obj);
            if ~isempty(opts.Owner) && isvalid(opts.Owner)
                obj.OwnerListener = listener(opts.Owner, 'ObjectBeingDestroyed', @(~,~) obj.close());
            end
            obj.clear(obj.NoData);
        end

        function delete(obj)
            obj.close();
        end

        function tf = isOpen(obj)
            %isOpen  The window is still there.
            tf = ~isempty(obj.Fig) && isvalid(obj.Fig);
        end

        function close(obj)
            %close  Close the window.
            if ~isempty(obj.OwnerListener) && isvalid(obj.OwnerListener)
                delete(obj.OwnerListener);
            end
            if obj.isOpen()
                delete(obj.Fig);
            end
        end

        function update(obj, src, ref, win, sel, opts)
            %update  Draw how REF, WIN and SEL cut the dataset SRC into epochs.
            arguments
                obj (1,1) EpochDiagram
                src (1,1) struct
                ref = []
                win = []
                sel = []
                opts.Baseline double = []
                opts.Incomplete (1,1) string {mustBeMember(opts.Incomplete, ["drop" "keep"])} = "drop"
                opts.Artifacts (1,1) string {mustBeMember(opts.Artifacts, ["drop" "keep"])} = "drop"
                opts.Title (1,1) string = ""
            end
            if ~obj.isOpen(); return; end
            t0Was = NaN;   % the first event shown: the new events are shown from there
            if isempty(obj.Src) || obj.Src.key ~= src.key
                obj.First = 1;   % another dataset: from its first event
            elseif obj.First <= height(obj.Epochs)
                t0Was = obj.Epochs.t0(obj.First);
            end
            obj.Src = src;
            obj.Baseline = [];
            if numel(opts.Baseline) == 2; obj.Baseline = reshape(opts.Baseline, 1, 2); end
            [ref, win, sel, problem] = checked(ref, win, sel);
            obj.Ref = ref; obj.Win = win; obj.Sel = sel;
            obj.Scope = scopeOf(ref.scope, src.hasTrials);
            obj.Rule = EpochDiagram.describe(ref, win, sel, src.hasTrials);
            nT = 0;
            if src.hasTrials; nT = height(src.trials); end
            obj.TrialKept = true(nT, 1);
            obj.TrialColor = repmat(obj.OneGroupColor, nT, 1);
            if nT > 0
                try
                    [mask, G0, gi] = selectTrials(src, sel);
                    obj.TrialKept = mask;
                    obj.TrialColor(mask, :) = drawnColors(obj, G0, gi(mask));
                catch ME
                    if problem == ""; problem = string(ME.message); end
                end
            end
            E = table(); G = table(); U = struct();
            if problem == ""
                try
                    [E, G] = epochTable(src, ref, Window=win, Selection=sel, Baseline=obj.Baseline, ...
                        Incomplete="keep", Artifacts="keep");
                    U = E.Properties.UserData;
                    obj.Scope = U.scope;
                    G.color = drawnColors(obj, G, (1:height(G)).');
                    E = annotate(obj, E, opts.Incomplete, opts.Artifacts);
                catch ME
                    problem = string(ME.message);
                    E = table();
                    G = table();
                end
            end
            obj.Epochs = E;
            obj.Groups = G;
            obj.Message = problem;
            obj.Summary = summaryText(obj, U);
            if isfinite(t0Was) && height(E) > 0
                k = find(E.t0 >= t0Was - 1e-9, 1);
                if isempty(k); k = max(1, height(E) - obj.Count + 1); end
                obj.First = k;
            end
            obj.First = min(obj.First, max(1, height(E)));
            obj.Heading = opts.Title;
            obj.Ui.Title.Text = opts.Title;
            obj.draw();
        end

        function clear(obj, msg)
            %clear  Nothing to draw: say why.
            arguments
                obj (1,1) EpochDiagram
                msg (1,1) string = ""
            end
            if ~obj.isOpen(); return; end
            obj.Src = [];
            obj.Heading = "";
            obj.Epochs = table();
            obj.Groups = table();
            obj.Rule = strings(0, 1);
            obj.Summary = "";
            obj.Message = msg;
            obj.Shown = zeros(0, 1);
            obj.Lanes = string.empty(1, 0);
            U = obj.Ui;
            U.Title.Text = "";
            U.Rule.Text = "";
            U.Summary.Text = msg;
            U.Summary.FontColor = [0.35 0.35 0.35];
            for ax = [U.Recording U.Aligned]
                resetAxes(ax);
                ax.XTick = []; ax.YTick = [];
                title(ax, "");
                xlabel(ax, "");
            end
            text(U.Recording, 0.5, 0.5, msg, 'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                'Color', [0.4 0.4 0.4], 'Interpreter', 'none');
            U.Page.Text = "";
            set([U.Prev U.Next], 'Enable', 'off');
        end

        function page(obj, step)
            %page  Draw the next (STEP 1) or previous (STEP -1) events.
            n = height(obj.Epochs);
            if n == 0 || isempty(obj.Shown); return; end
            if step > 0
                obj.showFrom(max(obj.Shown) + 1);
            else
                obj.showFrom(min(obj.Shown) - obj.Count);
            end
        end

        function showFrom(obj, k)
            %showFrom  Draw from event K on.
            n = height(obj.Epochs);
            obj.First = min(max(1, round(k)), max(1, n));
            if ~isempty(obj.Src); obj.draw(); end
        end

        function setCount(obj, n)
            %setCount  Draw N events at a time.
            obj.Count = max(1, round(n));
            obj.Ui.Count.Value = obj.Count;
            if ~isempty(obj.Src); obj.draw(); end
        end
    end

    methods (Static)
        function s = describe(ref, win, sel, hasTrials)
            %describe  The rule in words: what time 0 is, where each epoch runs, which trials count.
            %   S = EpochDiagram.describe(REF, WIN, SEL, HASTRIALS) for a
            %   checked eventRef, epochWindow and trialSelection; HASTRIALS:
            %   the dataset has paired trials (the "auto" scopes follow it).
            %   One sentence a row, e.g. "Time 0 is the first Stim onset in
            %   each trial." / "Each epoch runs from 0.2 s before it to 0.8 s
            %   after it." / "Trials kept: pairing ok; grouped by Depth."
            scope = scopeOf(ref.scope, hasTrials);
            s = "Time 0 is " + eventPhrase(ref, scope) + ".";
            if win.mode == "between"
                stop = stopPhrase(win.stop, hasTrials);
                s(end+1, 1) = "Each epoch runs from " + relative(win.pre, "time 0", "time 0") + " to " + ...
                    relative(win.post, stop, stop) + "; an event without one makes no epoch.";
            else
                s(end+1, 1) = "Each epoch runs from " + relative(win.pre, "it", "time 0") + " to " + ...
                    relative(win.post, "it", "time 0") + ".";
                if ~isempty(win.stop)
                    s(end+1, 1) = "The stop event, " + stopPhrase(win.stop, hasTrials) + ", is marked on each epoch.";
                end
            end
            if hasTrials
                parts = strings(1, 0);
                if ~isempty(sel.pairingFlags); parts(end+1) = "pairing " + strjoin(sel.pairingFlags, " or "); end
                if ~isempty(sel.response); parts(end+1) = strjoin(sel.response, " or "); end
                if sel.filter ~= ""; parts(end+1) = "where " + sel.filter; end
                if ~isempty(sel.trials); parts(end+1) = sprintf("%d listed trial rows", numel(sel.trials)); end
                if isempty(parts)
                    t = "Every paired trial counts";
                else
                    t = "Trials kept: " + strjoin(parts, "; ");
                end
                if ~isempty(sel.groupBy); t = t + "; grouped by " + strjoin(sel.groupBy, " and "); end
                s(end+1, 1) = t + ".";
            elseif scope == "recording"
                s(end+1, 1) = "No paired trials: every event in the recording counts.";
            end
        end
    end

    methods (Access = private)
        function build(obj)
            %build  The labels, the two axes and the row of page controls.
            g = uigridlayout(obj.Fig, [6 1]);
            g.RowHeight = {22, 'fit', 'fit', '3x', 30, '2x'};
            g.Padding = [12 10 12 10];
            g.RowSpacing = 6;
            U = struct();
            U.Title = uilabel(g, "Text", "", "FontWeight", "bold", "FontSize", 14);
            U.Rule = uilabel(g, "Text", "", "WordWrap", "on", "FontSize", 13);
            U.Summary = uilabel(g, "Text", "", "WordWrap", "on", "FontWeight", "bold");
            U.Recording = uiaxes(g);
            nav = uigridlayout(g, [1 6]);
            nav.ColumnWidth = {'fit', 'fit', '1x', 'fit', 60, 'fit'};
            nav.Padding = [0 0 0 0];
            nav.ColumnSpacing = 8;
            U.Prev = uibutton(nav, "Text", "◀ Previous", "ButtonPushedFcn", @(~,~) obj.page(-1), ...
                "Tooltip", "The events before these.");
            U.Next = uibutton(nav, "Text", "Next ▶", "ButtonPushedFcn", @(~,~) obj.page(1), ...
                "Tooltip", "The events after these.");
            U.Page = uilabel(nav, "Text", "");
            uilabel(nav, "Text", "Show:", "HorizontalAlignment", "right");
            U.Count = uispinner(nav, "Limits", [1 50], "Value", obj.Count, "RoundFractionalValues", "on", ...
                "ValueChangedFcn", @(s,~) obj.setCount(s.Value), "Tooltip", "How many events to draw at a time.");
            uilabel(nav, "Text", "events at a time");
            U.Aligned = uiaxes(g);
            for ax = [U.Recording U.Aligned]
                ax.FontSize = 10;
                ax.TickLabelInterpreter = 'none';
            end
            styleButton([U.Prev U.Next]);
            obj.Ui = U;
        end

        function E = annotate(obj, E, incomplete, artifacts)
            %annotate  Which epochs the plot keeps, their numbers, why the others go; the edges.
            n = height(E);
            reason = strings(n, 1);
            if incomplete == "drop"
                between = obj.Win.mode == "between";
                bad = ~E.complete;
                reason(bad) = "outside the recording";
                reason(bad & between & isfinite(E.t1) & ~(E.duration > 0)) = "ends before it starts";
                reason(bad & between & ~isfinite(E.t1)) = "no stop event";
            end
            if artifacts == "drop"
                reason(reason == "" & E.artifact) = "touches an artifact period";
            end
            E.kept = reason == "";
            E.number = NaN(n, 1);
            E.number(E.kept) = (1:nnz(E.kept)).';
            E.reason = reason;
            E.edge = E.t0 - obj.Ref.offsetSec - trialParamShift(obj.Src, obj.Ref, E.trial);
            E.stopEdge = NaN(n, 1);
            stop = obj.Win.stop;
            if ~isempty(stop)
                E.stopEdge = E.t1 - stop.offsetSec - trialParamShift(obj.Src, stop, E.trial);
            end
            E.anchorEdge = obj.anchorEdges(E);
        end

        function x = anchorEdges(obj, E)
            %anchorEdges  Where each epoch's event sequence starts: its line's own edge (NaN without one).
            %   Only for a sequence aligned to a later step. resolveEvents
            %   picks the same events with alignStep 0, so each epoch's
            %   event is paired with its own by trial and rank, as epochTable
            %   asked for them (the trial mask in trial scope or under a
            %   restrictive selection).
            ref = obj.Ref;
            x = NaN(height(E), 1);
            if alignedStep(ref) < 1; return; end
            sel = obj.Sel;
            restrictive = sel.filter ~= "" || ~isempty(sel.response) || ~isempty(sel.trials) || ~isempty(sel.groupBy);
            mask = [];
            if obj.Scope == "trial" || restrictive; mask = obj.TrialKept; end
            try
                [tA, trA, kA] = resolveEvents(obj.Src, ref, mask);
                own = ref;
                own.alignStep = 0;
                [tB, trB, kB] = resolveEvents(obj.Src, own, mask);
            catch
                return
            end
            trA(~isfinite(trA)) = 0;
            trB(~isfinite(trB)) = 0;
            [~, ia] = ismember(E.t0, tA);
            for i = find(ia > 0).'
                j = find(trB == trA(ia(i)) & kB == kA(ia(i)), 1);
                if ~isempty(j)
                    x(i) = tB(j) - ref.offsetSec - trialParamShift(obj.Src, ref, E.trial(i));
                end
            end
        end

        function txt = summaryText(obj, U)
            %summaryText  "N epochs from M of T trials (scope); D of the events dropped: ..."
            if obj.Message ~= ""
                txt = "No epochs: " + obj.Message;
                return
            end
            E = obj.Epochs;
            src = obj.Src;
            txt = plural(nnz(E.kept), "epoch");
            notes = U.scope + " scope";
            if src.hasTrials
                tr = E.trial(E.kept & isfinite(E.trial));
                txt = txt + sprintf(" from %d of %d trials", numel(unique(tr)), src.nTrials);
                nOut = nnz(~obj.TrialKept);
                if nOut > 0
                    notes = notes + sprintf("; the selection leaves %d out", nOut);
                end
            end
            if height(obj.Groups) > 1
                txt = txt + sprintf(" in %d groups", height(obj.Groups));
            end
            txt = txt + " (" + notes + ")";
            drops = E.reason(~E.kept);
            if ~isempty(drops)
                say = dictionary(["no stop event" "ends before it starts" "outside the recording" "touches an artifact period"], ...
                    ["without a stop event" "ending before they start" "outside the recording" "touching an artifact period"]);
                [u, ~, k] = unique(drops);
                c = accumarray(k, 1);
                txt = txt + sprintf("; %d of the %d events dropped: ", numel(drops), height(E)) + ...
                    strjoin(string(c(:)) + " " + say(u(:)), ", ");
            end
            if isfield(U, 'nDroppedNoValue') && U.nDroppedNoValue > 0
                txt = txt + "; " + plural(U.nDroppedNoValue, "event") + " left out: " + ...
                    "no " + obj.Ref.offsetParam + " on their trial";
            end
            if isfield(U, 'nDroppedNoSequence') && U.nDroppedNoSequence > 0
                txt = txt + "; " + plural(U.nDroppedNoSequence, "event") + " left out: their sequence did not follow";
            end
            txt = txt + ".";
        end

        function draw(obj)
            %draw  The labels, both views and the page controls, from what update worked out.
            U = obj.Ui;
            U.Rule.Text = strjoin(obj.Rule, newline);
            U.Summary.Text = obj.Summary;
            U.Summary.FontColor = [0.1 0.1 0.1];
            if obj.Message ~= ""; U.Summary.FontColor = obj.DropColor; end
            [obj.Range, obj.Shown] = pageRange(obj);
            drawRecording(obj);
            drawAligned(obj);
            n = height(obj.Epochs);
            if isempty(obj.Shown)
                U.Page.Text = "";
                set([U.Prev U.Next], 'Enable', 'off');
            else
                f = min(obj.Shown);
                l = max(obj.Shown);
                U.Page.Text = sprintf("Events %d to %d of %d", f, l, n);
                U.Prev.Enable = matlab.lang.OnOffSwitchState(f > 1);
                U.Next.Enable = matlab.lang.OnOffSwitchState(l < n);
            end
        end

        function [range, shown] = pageRange(obj)
            %pageRange  The stretch to draw: the page's epochs (and their whole trials when not far bigger).
            E = obj.Epochs;
            src = obj.Src;
            n = height(E);
            shown = zeros(0, 1);
            if n == 0
                range = [0 10];
                if src.hasTrials
                    on = src.trials.TrialOnset;
                    off = src.trials.TrialOffset;
                    ok = find(isfinite(on) & isfinite(off));
                    if ~isempty(ok)
                        k = ok(1:min(obj.Count, numel(ok)));
                        range = [min(on(k)) max(off(k))];
                    end
                else
                    iv = obj.intervals(obj.Ref.line);
                    if ~isempty(iv)
                        k = min(obj.Count, size(iv, 1));
                        range = [iv(1, 1) - 0.5, iv(k, 2) + 0.5];
                    end
                end
            else
                rows = (obj.First:min(obj.First + obj.Count - 1, n)).';
                x = [E.tStart(rows); E.tStop(rows); E.t0(rows); E.edge(rows); E.t1(rows); E.stopEdge(rows)];
                if numel(obj.Baseline) == 2
                    x = [x; E.t0(rows) + obj.Baseline(1); E.t0(rows) + obj.Baseline(2)];
                end
                x = x(isfinite(x));
                a = min(x);
                b = max(x);
                if src.hasTrials
                    tr = E.trial(rows);
                    tr = tr(isfinite(tr));
                    if ~isempty(tr)
                        ta = min(a, min(src.trials.TrialOnset(tr)));
                        tb = max(b, max(src.trials.TrialOffset(tr)));
                        if tb - ta <= 4 * max(b - a, eps)
                            a = ta;
                            b = tb;
                        end
                    end
                end
                range = [a b];
            end
            w = range(2) - range(1);
            if ~(w > 0); w = 1; end
            range = range + [-1 1] * 0.04 * w;
            if n > 0
                shown = find(E.t0 >= range(1) & E.t0 <= range(2));
            end
        end

        function L = lanes(obj)
            %lanes  The recording view's rows: the trials, the event's lines, the stop's lines.
            %   One row a line, carrying the marks of every role it plays:
            %   ▲ event on the line time 0 is on (an event sequence's
            %   aligned step: "Trial offset then Trough onset" puts it on
            %   Trough), ▼ stop on the stop event's; the other lines of a
            %   sequence are rows too ("· sequence"). The event's own line
            %   (anchor) is where its time range is searched. "Trial" is
            %   the trials' row.
            src = obj.Src;
            ref = obj.Ref;
            stop = obj.Win.stop;
            isTrial = @(x) src.hasTrials && (x == "Trial" || (src.trialLine ~= "" && x == src.trialLine));
            key = @(x) string(x) + "";
            L = struct('label', {}, 'line', {}, 'trials', {}, 'event', {}, 'stop', {}, 'anchor', {}, 'step', {});
            if src.hasTrials
                L(end+1) = lane("Trials", src.trialLine, true);
            end
            roles = {ref, "event"};
            if ~isempty(stop); roles(end+1, :) = {stop, "stop"}; end
            for j = 1:size(roles, 1)
                r = roles{j, 1};
                [aligned, chain] = sequenceLines(r);
                for ln = chain
                    if isTrial(ln)
                        i = find([L.trials], 1);
                    else
                        i = find(arrayfun(@(x) ~x.trials && key(x.line) == ln, L), 1);
                        if isempty(i)
                            L(end+1) = lane(ln, ln, false); %#ok<AGROW>
                            i = numel(L);
                        end
                    end
                    if ln == aligned
                        L(i).(roles{j, 2}) = true;
                    else
                        L(i).step = true;
                    end
                    if roles{j, 2} == "event" && ln == r.line
                        L(i).anchor = true;
                    end
                end
            end
            for i = 1:numel(L)
                if ~L(i).trials && isempty(obj.intervals(L(i).line)) && ~isfield(src.events, char(L(i).line))
                    L(i).label = L(i).label + " (no such line)";
                end
                if L(i).trials && src.trialLine ~= ""
                    L(i).label = "Trials (" + src.trialLine + ")";
                end
                if L(i).event; L(i).label = L(i).label + "  ▲ event"; end
                if L(i).stop;  L(i).label = L(i).label + "  ▼ stop"; end
                if L(i).step && ~L(i).event && ~L(i).stop; L(i).label = L(i).label + "  · sequence"; end
            end
        end

        function iv = intervals(obj, line)
            %intervals  [on off] of a digital line ("Trial": the trial line), s; zeros(0,2) without.
            src = obj.Src;
            name = string(line);
            if name == "Trial"; name = src.trialLine; end
            iv = zeros(0, 2);
            if name ~= "" && isfield(src.events, char(name))
                iv = double(src.events.(name));
                if isempty(iv); iv = zeros(0, 2); end
                iv = sortrows(iv);
            end
        end

        function iv = searchRange(obj, a, b)
            %searchRange  Where the event is looked for under its time range (empty: everywhere).
            tr = obj.Ref.timeRange;
            iv = zeros(0, 2);
            if all(~isfinite(tr)); return; end
            src = obj.Src;
            if obj.Scope == "trial" && src.hasTrials
                on = src.trials.TrialOnset;
                off = src.trials.TrialOffset;
                k = isfinite(on) & isfinite(off) & off >= a & on <= b;
                iv = [max(on(k) + tr(1), on(k)), min(on(k) + tr(2), off(k))];
            else
                iv = [max(tr(1), a - 1), min(tr(2), b + 1)];
            end
            iv = iv(iv(:, 2) > iv(:, 1), :);
        end

        function c = drawnColors(obj, G, gi)
            %drawnColors  The colours of groups GI of G: theirs, or blue for one ungrouped set.
            if height(G) == 1
                c = repmat(obj.OneGroupColor, numel(gi), 1);
            else
                c = G.color(gi, :);
            end
        end

        function c = colorOf(obj, r)
            %colorOf  Epoch R's colour: its group's, grey when the plot drops it.
            if obj.Epochs.kept(r)
                c = obj.Groups.color(obj.Epochs.groupIndex(r), :);
            else
                c = obj.DropGray;
            end
        end

        function drawRecording(obj)
            %drawRecording  The stretch of the recording: TTL rows, events, windows, epochs.
            ax = obj.Ui.Recording;
            resetAxes(ax);
            src = obj.Src;
            E = obj.Epochs;
            G = obj.Groups;
            rows = obj.Shown;
            a = obj.Range(1);
            b = obj.Range(2);
            L = obj.lanes();
            nL = numel(L);                  % lane i at y = nL - i + 1; the epochs at y = 0
            yOf = @(i) nL - i + 1;
            yLo = -0.62;
            yHi = nL + 0.62;
            legH = gobjects(1, 0);
            legS = strings(1, 0);

            % --- behind: outside the recording, artifact periods ---------------------------
            iv = zeros(0, 2);
            if a < 0; iv(end+1, :) = [a 0]; end
            if isfinite(src.durationSec) && b > src.durationSec; iv(end+1, :) = [src.durationSec b]; end
            if ~isempty(iv)
                legH(end+1) = rectPatch(ax, iv, yLo, yHi, [0.55 0.55 0.55], 0.25);
                legS(end+1) = "outside the recording";
            end
            if isfield(src, 'artifacts') && ~isempty(src.artifacts)
                iv = src.artifacts(src.artifacts(:, 2) >= a & src.artifacts(:, 1) <= b, :);
                if ~isempty(iv)
                    legH(end+1) = rectPatch(ax, iv, yLo, yHi, obj.ArtifactColor, 0.45);
                    legS(end+1) = "artifact period";
                end
            end

            % --- the digital lines as TTL traces ------------------------------------------------
            for i = 1:nL
                y = yOf(i);
                lo = y - 0.28;
                hi = y + 0.28;
                if L(i).trials
                    on = src.trials.TrialOnset;
                    off = src.trials.TrialOffset;
                    vis = find(isfinite(on) & isfinite(off) & off >= a & on <= b);
                    in = vis(obj.TrialKept(vis));
                    out = vis(~obj.TrialKept(vis));
                    if ~isempty(in)
                        rectPatch(ax, [on(in) off(in)], lo, hi, paleColor(obj.TrialColor(in, :), 0.6), 1);
                    end
                    if ~isempty(out)
                        legH(end+1) = rectPatch(ax, [on(out) off(out)], lo, hi, obj.OutColor, 1); %#ok<AGROW>
                        legS(end+1) = "trial the selection leaves out"; %#ok<AGROW>
                    end
                    ttlLine(ax, [on(vis) off(vis)], a, b, lo, hi, obj.LineEdge);
                    for r = vis(:).'   % above the box, clear of the lines through the rows
                        text(ax, max(on(r), a), hi + 0.16, " trial " + r, 'FontSize', 9, 'HorizontalAlignment', 'left', ...
                            'Color', [0.25 0.25 0.25], 'Clipping', 'on', 'Interpreter', 'none');
                    end
                else
                    if L(i).anchor
                        rg = obj.searchRange(a, b);
                        if ~isempty(rg)
                            legH(end+1) = rectPatch(ax, rg, lo - 0.08, hi + 0.08, obj.RangeColor, 0.8); %#ok<AGROW>
                            legS(end+1) = "time range searched"; %#ok<AGROW>
                        end
                    end
                    iv = obj.intervals(L(i).line);
                    iv = iv(iv(:, 2) >= a & iv(:, 1) <= b, :);
                    if ~isempty(iv)
                        rectPatch(ax, iv, lo, hi, obj.LineFill, 1);
                    end
                    ttlLine(ax, iv, a, b, lo, hi, obj.LineEdge);
                end
            end

            % --- each epoch's window, shaded across the rows ---------------------------------------
            if ~isempty(rows)
                ok = isfinite(E.tStart(rows)) & isfinite(E.tStop(rows));
                kept = rows(ok & E.kept(rows));
                drop = rows(ok & ~E.kept(rows));
                for g = unique(E.groupIndex(kept)).'
                    k = kept(E.groupIndex(kept) == g);
                    legH(end+1) = rectPatch(ax, [E.tStart(k) E.tStop(k)], yLo, yHi, G.color(g, :), 0.14); %#ok<AGROW>
                    if height(G) > 1
                        legS(end+1) = "epoch window: " + G.label(g); %#ok<AGROW>
                    else
                        legS(end+1) = "epoch window"; %#ok<AGROW>
                    end
                end
                if ~isempty(drop)
                    legH(end+1) = rectPatch(ax, [E.tStart(drop) E.tStop(drop)], yLo, yHi, obj.DropGray, 0.12);
                    legS(end+1) = "window of a dropped epoch";
                end
            end

            % --- the epochs row: a bar per epoch, numbered as the plot numbers them -------------------
            hBase = gobjects(0);
            for r = rows(:).'
                c = obj.colorOf(r);
                if isfinite(E.tStart(r)) && isfinite(E.tStop(r))
                    h = rectPatch(ax, [E.tStart(r) E.tStop(r)], -0.28, 0.28, c, 0.5);
                    h.EdgeColor = c * 0.8;
                    xm = (max(E.tStart(r), a) + min(E.tStop(r), b)) / 2;
                    if E.kept(r)
                        text(ax, xm, 0, "#" + E.number(r), 'HorizontalAlignment', 'center', 'FontWeight', 'bold', ...
                            'FontSize', 10, 'Clipping', 'on');
                    else
                        h.LineStyle = '--';
                        text(ax, xm, 0, "✕ " + E.reason(r), 'HorizontalAlignment', 'center', 'FontSize', 9, ...
                            'Color', obj.DropColor, 'Clipping', 'on');
                    end
                else
                    line(ax, E.t0(r), 0, 'Marker', 'x', 'MarkerSize', 10, 'LineWidth', 2, 'Color', obj.DropColor, 'LineStyle', 'none');
                    text(ax, E.t0(r), 0, "   ✕ " + E.reason(r), 'FontSize', 9, 'Color', obj.DropColor, 'Clipping', 'on');
                end
                if numel(obj.Baseline) == 2
                    hBase(end+1) = line(ax, E.t0(r) + obj.Baseline, [-0.45 -0.45], 'Color', c * 0.75, 'LineWidth', 3); %#ok<AGROW>
                end
            end
            if ~isempty(hBase)
                legH(end+1) = hBase(1);
                legS(end+1) = "baseline";
            end
            if isempty(rows)
                text(ax, (a + b) / 2, 0, "no epochs", 'HorizontalAlignment', 'center', 'Color', obj.DropColor, 'FontSize', 10);
            end

            % --- time 0 and the stop event: lines through every row, marks on their lines ---------------
            evLane = find([L.event], 1);
            stLane = find([L.stop], 1);
            anLane = find([L.anchor], 1);
            h0 = gobjects(0);
            h1 = gobjects(0);
            hA = gobjects(0);
            for r = rows(:).'
                c = obj.colorOf(r);
                style = '-';
                if ~E.kept(r); style = '--'; end
                h0(end+1) = line(ax, [E.t0(r) E.t0(r)], [yLo + 0.1, nL + 0.32], 'Color', c, 'LineWidth', 1.6, 'LineStyle', style); %#ok<AGROW>
                if ~isempty(evLane)
                    markEdge(ax, E.edge(r), E.t0(r), yOf(evLane) - 0.44, '^', c);
                end
                if ~isempty(anLane) && ~isempty(evLane) && isfinite(E.anchorEdge(r))   % the sequence's start, linked to its ▲
                    ya = yOf(anLane) - 0.44;
                    line(ax, [E.anchorEdge(r) E.edge(r)], [ya yOf(evLane) - 0.44], 'Color', c, 'LineStyle', ':', 'LineWidth', 1.2);
                    hA(end+1) = line(ax, E.anchorEdge(r), ya, 'Marker', 'o', 'MarkerSize', 7, 'MarkerFaceColor', [1 1 1], ...
                        'MarkerEdgeColor', c, 'LineWidth', 1.5, 'LineStyle', 'none'); %#ok<AGROW>
                end
                if isfinite(E.t1(r))
                    h1(end+1) = line(ax, [E.t1(r) E.t1(r)], [yLo + 0.1, nL + 0.32], 'Color', obj.StopColor, ...
                        'LineWidth', 1.3, 'LineStyle', ':'); %#ok<AGROW>
                    if ~isempty(stLane)
                        markEdge(ax, E.stopEdge(r), E.t1(r), yOf(stLane) + 0.44, 'v', obj.StopColor);
                    end
                end
            end
            if ~isempty(h0)
                k = find(E.kept(rows), 1);   % a kept epoch's line, if any
                if isempty(k); k = 1; end
                legH = [h0(k) legH];
                legS = ["time 0: the event (▲ the edge it is picked at)" legS];
            end
            if ~isempty(h1)
                legH = [legH(1:min(1, end)) h1(1) legH(min(1, end)+1:end)];
                legS = [legS(1:min(1, end)) "stop event (▼)" legS(min(1, end)+1:end)];
            end
            if ~isempty(hA)
                legH = [legH(1:min(1, end)) hA(1) legH(min(1, end)+1:end)];
                legS = [legS(1:min(1, end)) "where its sequence starts" legS(min(1, end)+1:end)];
            end

            labels = [string({L.label}) "Epochs"];
            obj.Lanes = labels;
            ax.YDir = 'normal';
            ax.XLim = [a b];
            ax.YLim = [yLo yHi];
            ax.YTick = 0:nL;
            ax.YTickLabel = flip(labels);
            ax.XGrid = 'on';
            ax.YGrid = 'off';
            ax.Box = 'on';
            xlabel(ax, "Time in the recording (s)");
            title(ax, "The recording: where each epoch comes from", 'FontWeight', 'normal', 'Interpreter', 'none');
            if ~isempty(legH)
                legend(ax, legH, legS, 'Location', 'southoutside', 'NumColumns', min(3, numel(legH)), ...
                    'Box', 'off', 'Interpreter', 'none', 'FontSize', 9, 'AutoUpdate', 'off');
            end
        end

        function drawAligned(obj)
            %drawAligned  The same epochs, one row each, on the time from their event.
            ax = obj.Ui.Aligned;
            resetAxes(ax);
            E = obj.Epochs;
            rows = obj.Shown;
            m = numel(rows);
            title(ax, "Aligned to the event: the epochs the plot stacks", 'FontWeight', 'normal');
            xlabel(ax, "Time from the event (s)");
            if m == 0
                ax.YTick = [];
                ax.XLim = [-1 1];
                ax.YLim = [0 1];
                text(ax, 0.5, 0.5, "No epochs to align.", 'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                    'Color', [0.45 0.45 0.45]);
                return
            end
            win = obj.Win;
            t0 = E.t0(rows);
            x0 = E.tStart(rows) - t0;
            x1 = E.tStop(rows) - t0;
            xs = E.t1(rows) - t0;
            x = [x0; x1; xs; E.edge(rows) - t0; 0; win.pre];
            if win.mode == "fixed"; x(end+1) = win.post; end
            if numel(obj.Baseline) == 2; x = [x; obj.Baseline(:)]; end
            x = x(isfinite(x));
            xa = min(x);
            xz = max(x);
            w = xz - xa;
            if ~(w > 0); w = 1; end
            xa = xa - 0.05 * w;
            xz = xz + 0.05 * w;
            iv = obj.intervals(sequenceLines(obj.Ref));   % the line time 0 is on
            labels = strings(m, 1);
            for j = 1:m
                r = rows(j);
                c = obj.colorOf(r);
                if isfinite(x0(j)) && isfinite(x1(j))
                    h = rectPatch(ax, [x0(j) x1(j)], j - 0.32, j + 0.32, c, 0.28);
                    h.EdgeColor = c;
                    if ~E.kept(r); h.LineStyle = '--'; end
                end
                seg = iv(iv(:, 2) >= t0(j) + xa & iv(:, 1) <= t0(j) + xz, :) - t0(j);
                ttlLine(ax, seg, xa, xz, j + 0.2, j - 0.2, obj.LineEdge);   % y runs down: high is up
                if isfinite(xs(j))
                    line(ax, xs(j), j - 0.38, 'Marker', 'v', 'MarkerSize', 7, 'MarkerFaceColor', obj.StopColor, ...
                        'MarkerEdgeColor', obj.StopColor, 'LineStyle', 'none');
                end
                if numel(obj.Baseline) == 2
                    line(ax, obj.Baseline, [j + 0.42 j + 0.42], 'Color', c * 0.75, 'LineWidth', 3);
                end
                tr = "";
                if isfinite(E.trial(r)); tr = " · trial " + E.trial(r); end
                if E.kept(r)
                    labels(j) = "#" + E.number(r) + tr;
                else
                    labels(j) = "✕" + tr;
                    text(ax, xz, j, "✕ " + E.reason(r) + "  ", 'HorizontalAlignment', 'right', 'FontSize', 9, ...
                        'Color', obj.DropColor);
                end
            end
            line(ax, [0 0], [0.45 m + 0.55], 'Color', [0 0 0], 'LineWidth', 1.6);
            guides = win.pre;
            names = "pre";
            if win.mode == "fixed"
                guides(2) = win.post;
                names(2) = "post";
            end
            align = ["right" "left"];   % pre to the left of its line, post to the right
            for k = 1:numel(guides)
                line(ax, guides([k k]), [0.45 m + 0.55], 'Color', [0.45 0.45 0.45], 'LineStyle', '--', 'LineWidth', 1);
                text(ax, guides(k), 0.45, " " + names(k) + " ", 'VerticalAlignment', 'bottom', 'FontSize', 9, ...
                    'HorizontalAlignment', align(k), 'Color', [0.35 0.35 0.35]);
            end
            text(ax, 0, 0.45, " 0 ", 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', ...
                'FontSize', 9, 'FontWeight', 'bold');
            ax.YDir = 'reverse';
            ax.XLim = [xa xz];
            ax.YLim = [0.2 m + 0.6];
            ax.YTick = 1:m;
            ax.YTickLabel = labels;
            ax.XGrid = 'on';
            ax.YGrid = 'off';
            ax.Box = 'on';
        end
    end
end


% --- helpers ----------------------------------------------------------------------------------

function [ref, win, sel, problem] = checked(ref, win, sel)
%checked  The values checked (eventRef, epochWindow, trialSelection); else normalized, and why not.
problem = "";
try
    ref = eventRef(ref);
catch ME
    problem = string(ME.message);
    ref = loose("EventRef", ref);
end
try
    win = epochWindow(win);
catch ME
    if problem == ""; problem = string(ME.message); end
    win = loose("EpochWindow", win);
end
try
    sel = trialSelection(sel);
catch ME
    if problem == ""; problem = string(ME.message); end
    sel = loose("TrialSelection", sel);
end
end


function s = loose(section, s)
%loose  A section's fields, normalized but not checked (the defaults when it cannot be).
try
    if isempty(s); s = struct(); end
    if isstring(s) || ischar(s); s = struct('line', string(s)); end
    s = EphysAnalysisConfig.normalizeSection(section, s);
catch
    s = EphysAnalysisConfig.defaults(section);
end
end


function scope = scopeOf(scope, hasTrials)
%scopeOf  "auto" is "trial" with paired trials, else "recording".
if scope == "auto"
    if hasTrials; scope = "trial"; else; scope = "recording"; end
end
end


function p = edgeName(r)
%edgeName  "Stim onset", "trial offset".
if r.line == "Trial"
    p = "trial " + r.edge;
else
    p = r.line + " " + r.edge;
end
end


function p = eventPhrase(ref, scope)
%eventPhrase  "the first Stim onset in each trial", with its filters and shifts.
%   With a sequence: "the Trough onset of the first «Trial offset then
%   Trough onset» in each trial" (the step time 0 is at, of the sequence).
thing = edgeName(ref);
seq = hasSequence(ref);
if seq; thing = "«" + chainLabel(ref) + "»"; end
if ref.line == "Trial" && scope == "trial" && ref.which ~= "nth" && ~seq
    p = "each trial's " + ref.edge;
else
    switch ref.which
        case "first", p = "the first " + thing;
        case "last",  p = "the last " + thing;
        case "all",   p = "every " + thing;
        otherwise,    p = "the " + ordinal(ref.n) + " " + thing;
    end
    if scope == "trial"
        p = p + " in each trial";
    elseif ref.which ~= "all"
        p = p + " of the recording";
    end
end
if seq; p = "the " + alignedName(ref) + " of " + p; end
lo = ref.minDurationSec;
hi = ref.maxDurationSec;
if lo > 0 && isfinite(hi)
    p = p + " (pulses " + num(lo) + " to " + num(hi) + " s long)";
elseif lo > 0
    p = p + " (pulses at least " + num(lo) + " s long)";
elseif isfinite(hi)
    p = p + " (pulses at most " + num(hi) + " s long)";
end
origin = "the recording start";
if scope == "trial"; origin = "the trial onset"; end
tr = ref.timeRange;
if all(isfinite(tr))
    p = p + " between " + num(tr(1)) + " and " + num(tr(2)) + " s from " + origin;
elseif isfinite(tr(1))
    p = p + " at least " + num(tr(1)) + " s from " + origin;
elseif isfinite(tr(2))
    p = p + " at most " + num(tr(2)) + " s from " + origin;
end
p = p + shiftPhrase(ref);
end


function p = stopPhrase(stop, hasTrials)
%stopPhrase  "the next RespWindow offset in the same trial".
thing = edgeName(stop);
seq = hasSequence(stop);
if seq; thing = "«" + chainLabel(stop) + "»"; end
switch stop.which
    case "last", p = "the last " + thing + " after time 0";
    case "nth",  p = "the " + ordinal(stop.n) + " " + thing + " from time 0";
    otherwise,   p = "the next " + thing;
end
if seq; p = "the " + alignedName(stop) + " of " + p; end
if scopeOf(stop.scope, hasTrials) == "trial"
    p = p + " in the same trial";
end
p = p + shiftPhrase(stop);
end


function tf = hasSequence(r)
tf = isfield(r, 'sequence') && ~isempty(r.sequence);
end


function s = chainLabel(r)
%chainLabel  A sequence in words without where it is aligned: "Trial offset then Trough onset".
s = regexprep(eventRefLabel(r), " \(aligned to [^)]*\)$", "");
end


function s = alignedName(r)
%alignedName  The line and edge time 0 is at: R's own, or its sequence's aligned step's.
k = alignedStep(r);
if k >= 1
    s = edgeName(r.sequence(k));
else
    s = edgeName(r);
end
end


function p = shiftPhrase(r)
%shiftPhrase  " plus its trial's RespLatency (ms)", " plus 0.05 s".
p = "";
if r.offsetParam ~= ""
    p = p + " plus its trial's " + r.offsetParam + " (" + r.offsetParamUnit + ")";
end
if r.offsetSec > 0
    p = p + " plus " + num(r.offsetSec) + " s";
elseif r.offsetSec < 0
    p = p + " minus " + num(-r.offsetSec) + " s";
end
end


function p = relative(x, what, zero)
%relative  "0.2 s before it", "0.8 s after it", or ZERO for 0.
if x < 0
    p = num(-x) + " s before " + what;
elseif x > 0
    p = num(x) + " s after " + what;
else
    p = zero;
end
end


function s = num(x)
s = string(sprintf('%g', x));
end


function s = ordinal(n)
%ordinal  "1st", "2nd", "3rd", "11th", "22nd".
suffix = "th";
if mod(n, 100) < 11 || mod(n, 100) > 13
    switch mod(n, 10)
        case 1, suffix = "st";
        case 2, suffix = "nd";
        case 3, suffix = "rd";
    end
end
s = string(n) + suffix;
end


function s = plural(n, word)
s = sprintf("%d %s", n, word);
if n ~= 1; s = s + "s"; end
end


function L = lane(label, line, trials)
L = struct('label', string(label), 'line', string(line), 'trials', trials, 'event', false, 'stop', false, ...
    'anchor', false, 'step', false);
end


function [aligned, chain] = sequenceLines(r)
%sequenceLines  The line an event reference's time is on, and every line its event involves.
%   Without a sequence both are R.line. With one (eventRef's sequence and
%   alignStep), CHAIN is R.line and then each step's line, once each, and
%   ALIGNED the line alignStep names (0: R.line; Inf: the last followedBy
%   step's).
aligned = r.line;
chain = r.line;
if ~isfield(r, 'sequence') || isempty(r.sequence); return; end
steps = r.sequence;
chain = unique([r.line, steps.line], 'stable');
k = alignedStep(r);
if k >= 1; aligned = steps(k).line; end
end


function k = alignedStep(r)
%alignedStep  The step of R's sequence its time is at: 0 = R's own event (also without a sequence).
k = 0;
if ~isfield(r, 'sequence') || isempty(r.sequence); return; end
k = r.alignStep;
if isinf(k)
    k = find([r.sequence.relation] == "followedBy", 1, 'last');
    if isempty(k); k = 0; end
end
end


function resetAxes(ax)
%resetAxes  Empty an axes for a redraw (its legend too).
legend(ax, 'off');
cla(ax);
hold(ax, 'on');
ax.XTickMode = 'auto';
ax.XTickLabelMode = 'auto';
end


function h = rectPatch(ax, iv, lo, hi, color, alpha)
%rectPatch  One patch of rectangles [on off] x [lo hi]; COLOR one RGB or one a rectangle.
k = size(iv, 1);
V = [reshape([iv(:, 1) iv(:, 2) iv(:, 2) iv(:, 1)].', [], 1), repmat([lo; lo; hi; hi], k, 1)];
F = reshape(1:4*k, 4, k).';
if size(color, 1) > 1
    h = patch(ax, 'Faces', F, 'Vertices', V, 'FaceColor', 'flat', 'FaceVertexCData', color, ...
        'FaceAlpha', alpha, 'EdgeColor', 'none');
else
    h = patch(ax, 'Faces', F, 'Vertices', V, 'FaceColor', color, 'FaceAlpha', alpha, 'EdgeColor', 'none');
end
end


function h = ttlLine(ax, iv, a, b, lo, hi, color)
%ttlLine  A digital line's trace: low, up at each onset, down at each offset, over [a b] and past it.
iv = sortrows(iv);
k = size(iv, 1);
x = [min([a; iv(:, 1)]) - 1; reshape([iv(:, 1) iv(:, 1) iv(:, 2) iv(:, 2)].', [], 1); max([b; iv(:, 2)]) + 1];
y = [lo; repmat([lo; hi; hi; lo], k, 1); lo];
h = line(ax, x, y, 'Color', color, 'LineWidth', 1);
end


function markEdge(ax, edge, t, y, marker, c)
%markEdge  The edge an event was picked at (MARKER), and an arrow to where its offsets moved it.
if ~isfinite(edge); return; end
if isfinite(t) && abs(t - edge) > 1e-9
    line(ax, [edge t], [y y], 'Color', c, 'LineWidth', 1.2);
    head = '>';
    if t < edge; head = '<'; end
    line(ax, t, y, 'Marker', head, 'MarkerSize', 5, 'MarkerFaceColor', c, 'MarkerEdgeColor', c, 'LineStyle', 'none');
end
line(ax, edge, y, 'Marker', marker, 'MarkerSize', 8, 'MarkerFaceColor', c, 'MarkerEdgeColor', c * 0.7, 'LineStyle', 'none');
end
