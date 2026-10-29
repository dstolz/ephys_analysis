classdef EpochGroupCounts < handle
    %EpochGroupCounts  A window that counts one dataset's epochs per group: a bar per group and a table.
    %   W = EpochGroupCounts() opens the window; W.update(SRC, REF, WIN, SEL)
    %   cuts the dataset SRC (loadAnalysisSource) into epochs with the event
    %   reference REF (eventRef), the epoch window WIN (epochWindow) and the
    %   trial selection SEL (trialSelection), through epochTable as
    %   epochMatrix does, and counts them by group: grouped by Depth, a bar
    %   per depth with the number of its epochs. DatasetBrowser opens it
    %   (the Trials tab's "Epochs per group" button, showGroupCounts); the
    %   analysis app's Alignment tab draws the same bars (drawBars).
    %
    %   The window, top to bottom:
    %     the heading (update's Title)
    %     the count: "N epochs from M of T trials in G groups (scope
    %       scope)" and the events dropped, why (summary); or, in red, why
    %       there are none
    %     "Show the epochs Pairing and Artifacts exclude": off (default),
    %       each bar counts the epochs the selection keeps; on, each bar
    %       counts the epochs of every pairing flag, with or without an
    %       artifact, and stacks the ones Pairing (gray) and the artifacts
    %       (red) exclude on the kept ones (withExcluded)
    %     the bars: one per group in its color, in the selection's group
    %       order, its count on top
    %     the table: a row per bar, the group's trials (those the
    %       selection keeps), its epochs and, with the excluded shown, the
    %       epochs Pairing and the artifacts exclude
    %
    %   W = EpochGroupCounts(Name=Value)
    %     Position     the window's [left bottom width height]
    %     Visible      true (default) | false
    %     WindowStyle  "alwaysontop" (default: it stays above the browser,
    %                  whose controls keep working) | "normal"
    %     Owner        a figure: the window closes with it
    %
    %   W.update(SRC, REF, WIN, SEL, Title=) counts and draws;
    %   W.setExcluded(TF) shows the excluded epochs or not; W.clear(MSG)
    %   empties it with a message; W.close() closes it (so does its close
    %   box); W.isOpen().
    %
    %   What it drew:
    %     Heading   update's Title
    %     Summary   the count line
    %     Message   what went wrong ("" if nothing)
    %     Groups    epochTable's groups (index, label, color, n: the
    %               epochs, nTrials: the trials the selection keeps)
    %     Counts    table, a row per bar: Group, Trials (NaN without paired
    %               trials, or when the selection fails), Epochs and, with
    %               Excluded, PairingExcludes and ArtifactsExclude
    %     Excluded  the excluded epochs are shown
    %
    %   For any axes (the analysis app's Alignment tab uses them):
    %     [N, LABEL, COLOR] = EpochGroupCounts.withExcluded(SRC, REF, WIN, SEL, E, G)
    %         per group [kept, excluded by Pairing, excluded by an
    %         artifact]: E and G epochTable's with SEL (table() when it
    %         gave none)
    %     EpochGroupCounts.drawBars(AX, N, LABEL, COLOR)
    %         a bar per row of N in its color, its count on top (Tag
    %         "epochCount"); N's columns 2-3 stacked on (Pairing, artifacts)
    %     S = EpochGroupCounts.summary(SRC, E, G)
    %         the count line
    %
    %   See also epochTable, selectTrials, EpochDiagram, DatasetBrowser,
    %   EphysAnalysisApp.

    properties (SetAccess = private)
        Fig                                     % the window (uifigure)
        Heading (1,1) string = ""               % what it shows (update's Title)
        Summary (1,1) string = ""               % the count line
        Message (1,1) string = ""               % what went wrong ("" if nothing)
        Groups table = table()                  % epochTable's groups
        Counts table = table()                  % a row per bar: Group, Trials, Epochs (, PairingExcludes, ArtifactsExclude)
        Excluded (1,1) logical = false          % the epochs Pairing and Artifacts exclude are shown
    end

    properties (Access = private)
        Ui struct = struct()
        Src = []                                % the dataset counted ([] when none)
        Ref = []                                % eventRef
        Win = []                                % epochWindow
        Sel = []                                % trialSelection
        OwnerListener = []
    end

    properties (Constant, Access = private)
        ErrorColor = [0.75 0.1 0.1]
        TextColor = [0.1 0.1 0.1]
        NoteColor = [0.35 0.35 0.35]
        NoData = "Scan and pick a dataset to see its epochs per group."
    end

    methods
        function obj = EpochGroupCounts(opts)
            arguments
                opts.Position (1,4) double = [260 140 640 620]
                opts.Visible (1,1) logical = true
                opts.WindowStyle (1,1) string {mustBeMember(opts.WindowStyle, ["alwaysontop" "normal"])} = "alwaysontop"
                opts.Owner = []
            end
            obj.Fig = uifigure("Name", "Epochs per group", "Position", opts.Position, "Visible", opts.Visible, ...
                "WindowStyle", opts.WindowStyle, "CloseRequestFcn", @(~, ~) obj.close());
            obj.build();
            if ~isempty(opts.Owner) && isvalid(opts.Owner)
                obj.OwnerListener = listener(opts.Owner, 'ObjectBeingDestroyed', @(~, ~) obj.close());
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
            if obj.isOpen(); delete(obj.Fig); end
        end

        function update(obj, src, ref, win, sel, opts)
            %update  Count the epochs REF, WIN and SEL cut from the dataset SRC, by group, and draw them.
            arguments
                obj (1,1) EpochGroupCounts
                src (1,1) struct
                ref = []
                win = []
                sel = []
                opts.Title (1,1) string = ""
            end
            if ~obj.isOpen(); return; end
            obj.Src = src;
            obj.Ref = ref;
            obj.Win = win;
            obj.Sel = sel;
            obj.Heading = opts.Title;
            obj.draw();
        end

        function setExcluded(obj, tf)
            %setExcluded  Stack the epochs Pairing and Artifacts exclude on the kept ones (TF true), or count the kept only.
            obj.Excluded = logical(tf);
            if ~obj.isOpen(); return; end
            obj.Ui.Excluded.Value = obj.Excluded;
            if ~isempty(obj.Src); obj.draw(); end
        end

        function clear(obj, msg)
            %clear  Nothing to count: say why.
            arguments
                obj (1,1) EpochGroupCounts
                msg (1,1) string = ""
            end
            if ~obj.isOpen(); return; end
            obj.Src = [];
            obj.Heading = "";
            obj.Summary = "";
            obj.Message = msg;
            obj.Groups = table();
            obj.Counts = table();
            U = obj.Ui;
            U.Title.Text = "";
            U.Summary.Text = msg;
            U.Summary.FontColor = obj.NoteColor;
            resetAxes(U.Axes);
            U.Axes.XTick = [];
            U.Axes.YTick = [];
            U.Table.Data = table();
        end
    end

    methods (Static)
        function [n, label, color] = withExcluded(src, ref, win, sel, E, G)
            %withExcluded  Per group: [kept, excluded by Pairing, excluded by an artifact] epochs.
            %   The epochs of every pairing flag with the artifact epochs kept, in
            %   their groups; an epoch the selection keeps (E, by its event) is
            %   kept, one it drops that touches an artifact on a trial of a
            %   ticked flag is the artifacts', the rest Pairing's. Groups keep
            %   their colors (G).
            sel = trialSelection(sel);
            every = sel;
            every.pairingFlags = string.empty(1, 0);
            every.maxGroups = Inf;
            [Ea, Ga] = epochTable(src, ref, Window=win, Selection=every, Artifacts="keep");
            kept = false(height(Ea), 1);
            if height(E) > 0; kept = ismember(Ea.t0, E.t0); end
            flagOk = true(height(Ea), 1);
            if src.hasTrials && ~isempty(sel.pairingFlags) && ismember("PairingFlag", string(src.trials.Properties.VariableNames))
                has = isfinite(Ea.trial);
                flagOk(has) = ismember(string(src.trials.PairingFlag(Ea.trial(has))), sel.pairingFlags);
            end
            art = ~kept & flagOk & Ea.artifact & sel.excludeArtifacts;
            pair = ~kept & ~art;
            nG = height(Ga);
            n = [accumarray(Ea.groupIndex, kept, [nG 1]) accumarray(Ea.groupIndex, pair, [nG 1]) accumarray(Ea.groupIndex, art, [nG 1])];
            label = Ga.label;
            color = Ga.color;
            if height(G) > 0
                [in, at] = ismember(label, G.label);
                color(in, :) = G.color(at(in), :);
            end
        end

        function drawBars(ax, n, label, color)
            %drawBars  A bar per group in its color, its count on top; columns 2-3 of N stacked on (Pairing, artifacts).
            nG = size(n, 1);
            x = 1:nG;
            if size(n, 2) == 1
                b = bar(ax, x, n, 'FaceColor', 'flat');
                b.CData = color;
            else
                b = bar(ax, x, n, 'stacked', 'FaceColor', 'flat');
                b(1).CData = color;
                b(2).CData = repmat([0.74 0.74 0.74], nG, 1);
                b(3).CData = repmat([0.93 0.45 0.40], nG, 1);
                names = ["kept" "Pairing excludes" "artifacts exclude"];
                on = [true any(n(:, 2:3) > 0, 1)];
                legend(ax, b(on), names(on), 'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off', ...
                    'AutoUpdate', 'off');
            end
            tot = sum(n, 2);
            ax.YLim = [0 max([tot; 1]) * 1.2];   % room for the counts
            fs = 11 - 2 * (nG > 6);
            text(ax, x, tot, " " + string(tot) + " ", 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                'FontSize', fs, 'FontWeight', 'bold', 'Color', [0.1 0.1 0.1], 'Clipping', 'off', 'Tag', 'epochCount');
            set(ax, 'XTick', x, 'XTickLabel', label, 'TickLabelInterpreter', 'none', 'XLim', [0.4 nG + 0.6], ...
                'XTickLabelRotation', 30 * (nG > 2));   % the labels clear each other beside the epoch diagram
            ylabel(ax, 'Epochs');
            title(ax, "Epochs per group");
        end

        function s = summary(src, E, G)
            %summary  The count line: "N epochs from M of T trials in G groups (scope scope)", then what was dropped, why.
            U = E.Properties.UserData;
            nT = numel(unique(E.trial(isfinite(E.trial))));
            s = sprintf("%d epochs", height(E));
            if src.hasTrials
                s = s + sprintf(" from %d of %d trials", nT, src.nTrials);
            end
            if height(G) > 1; s = s + sprintf(" in %d groups", height(G)); end
            s = s + " (" + U.scope + " scope)";
            if U.nDroppedNoSequence > 0; s = s + sprintf("; %d the sequence did not follow", U.nDroppedNoSequence); end
            if U.nDroppedNoStop > 0; s = s + sprintf("; %d without a stop event", U.nDroppedNoStop); end
            if U.nDroppedEdge > 0; s = s + sprintf("; %d leave the recording", U.nDroppedEdge); end
            if U.nDroppedArtifact > 0; s = s + sprintf("; %d touch an artifact period", U.nDroppedArtifact); end
            s = s + ".";
        end
    end

    methods (Access = private)
        function build(obj)
            g = uigridlayout(obj.Fig, [6 1], "RowHeight", {22, 'fit', 22, '2x', 'fit', '1x'}, ...
                "Padding", [12 10 12 10], "RowSpacing", 6);
            U = struct();
            U.Title = uilabel(g, "Text", "", "FontWeight", "bold", "FontSize", 14, "Interpreter", "none");
            U.Summary = uilabel(g, "Text", "", "WordWrap", "on", "FontWeight", "bold");
            U.Excluded = uicheckbox(g, "Text", "Show the epochs Pairing and Artifacts exclude", "Value", obj.Excluded, ...
                "ValueChangedFcn", @(src, ~) obj.setExcluded(src.Value), ...
                "Tooltip", "Off: each bar counts the epochs the selection keeps. On: each bar counts the epochs of every " + ...
                "pairing flag, with or without an artifact, and stacks the ones the Pairing ticks (gray) and the artifacts " + ...
                "(red) exclude on the kept ones (the group's color).");
            U.Axes = uiaxes(g);
            U.Axes.FontSize = 10;
            U.Axes.TickLabelInterpreter = 'none';
            uilabel(g, "Text", "Trials: the trials the selection keeps in the group. Epochs: the epochs they give, " + ...
                "the ones Compute averages.", "WordWrap", "on", "FontColor", obj.NoteColor);
            U.Table = uitable(g, "RowName", {}, "ColumnWidth", 'auto', "ColumnSortable", true);
            obj.Ui = U;
        end

        function draw(obj)
            %draw  epochTable on the dataset update kept: the count line, the bars and the table.
            U = obj.Ui;
            ax = U.Axes;
            resetAxes(ax);
            U.Title.Text = obj.Heading;
            U.Table.Data = table();
            obj.Groups = table();
            obj.Counts = table();
            obj.Message = "";
            src = obj.Src;
            try
                [E, G] = epochTable(src, obj.Ref, Window=obj.Win, Selection=obj.Sel);
            catch ME
                obj.Message = string(ME.message);
                obj.say("No epochs: " + obj.Message, true);
                if obj.Excluded
                    try   % what Pairing and the artifacts took, when they took every epoch
                        [n, label, color] = EpochGroupCounts.withExcluded(src, obj.Ref, obj.Win, obj.Sel, table(), table());
                        EpochGroupCounts.drawBars(ax, n, label, color);
                        obj.fillCounts(src, selectedGroups(src, obj.Sel), n, label);
                    catch
                    end
                end
                return
            end
            obj.Groups = G;
            obj.say(EpochGroupCounts.summary(src, E, G), false);
            n = G.n; label = G.label; color = G.color;
            if obj.Excluded
                try
                    [n, label, color] = EpochGroupCounts.withExcluded(src, obj.Ref, obj.Win, obj.Sel, E, G);
                catch ME
                    obj.Message = string(ME.message);
                    obj.say(obj.Summary + " (Excluded epochs not counted: " + obj.Message + ")", false);
                end
            end
            EpochGroupCounts.drawBars(ax, n, label, color);
            obj.fillCounts(src, G, n, label);
        end

        function fillCounts(obj, src, G, n, label)
            %fillCounts  The table: a row per bar, the group's trials (G.nTrials; 0 for a group G lacks), its epochs.
            label = reshape(string(label), [], 1);
            trials = NaN(numel(label), 1);
            if src.hasTrials && height(G) > 0
                [in, at] = ismember(label, string(G.label));
                trials(:) = 0;   % a group of no trial the selection keeps
                trials(in) = G.nTrials(at(in));
            end
            T = table(label, trials, n(:, 1), 'VariableNames', {'Group', 'Trials', 'Epochs'});
            names = {'Group', 'Trials', 'Epochs'};
            if size(n, 2) == 3
                T.PairingExcludes = n(:, 2);
                T.ArtifactsExclude = n(:, 3);
                names = [names {'Pairing excludes', 'Artifacts exclude'}];
            end
            obj.Counts = T;
            obj.Ui.Table.Data = T;
            obj.Ui.Table.ColumnName = names;
        end

        function say(obj, msg, isError)
            %say  The count line (ISERROR: in red).
            obj.Summary = string(msg);
            obj.Ui.Summary.Text = obj.Summary;
            obj.Ui.Summary.FontColor = obj.TextColor;
            if isError; obj.Ui.Summary.FontColor = obj.ErrorColor; end
        end
    end
end


function G = selectedGroups(src, sel)
%selectedGroups  selectTrials' groups with nTrials (the trials the selection keeps); table() when it fails.
G = table();
try
    [~, G] = selectTrials(src, sel);
    G.nTrials = G.n;
catch
end
end


function resetAxes(ax)
%resetAxes  Empty AX for a redraw: its children, legend, labels, limits and ticks.
legend(ax, 'off');
cla(ax);
hold(ax, 'off');
set(ax, 'XTickMode', 'auto', 'XTickLabelMode', 'auto', 'YTickMode', 'auto', 'YTickLabelMode', 'auto', ...
    'XLimMode', 'auto', 'YLimMode', 'auto', 'XTickLabelRotation', 0);
xlabel(ax, "");
ylabel(ax, "");
title(ax, "");
end
