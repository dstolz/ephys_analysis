classdef TrialRaster < handle
    %TrialRaster  A window that shows one row of an epochMatrix result trial by trial.
    %   W = TrialRaster() opens the window; W.update(R, ROW) draws row ROW
    %   of the result R (epochMatrix, or DatasetBrowser's B.Result, made with
    %   settings.keepEpochs) from its epochs (epochMatrixRaster): a unit's
    %   raster, one line of ticks per epoch, or a channel's epochs as an
    %   image, one line per epoch; and under it the row's trace per group
    %   from R.data, the average the epochs make.
    %
    %   The window, top to bottom:
    %     the row (its label and dataset) and the result in words
    %       (R.labels.description), with the count of epochs per group
    %     ◀ Previous, the row drop-down (every row of R: "12  u37  (name)"),
    %       Next ▶ and Order: "by group" (each group's epochs together, in
    %       R.groupLabels' order, each labeled at the left and banded in its
    %       color) or "by time" (every epoch in time order, each tick in its
    %       group's color)
    %     the raster (units: each spike a tick on its epoch's line) or the
    %       epochs (channels: each epoch's trace as a line of an image, its
    %       raw unit on the color bar), time 0 dotted
    %     the row's trace per group, R.data(ROW, :, g), in the groups'
    %       colors (normalized when R is)
    %   The axes zoom and pan (their toolbar).
    %
    %   W = TrialRaster(Name=Value)
    %     Position     the window's [left bottom width height]
    %     Visible      true (default) | false
    %     WindowStyle  "normal" (default) | "alwaysontop"
    %     Owner        a figure: the window closes with it
    %
    %   W.update(R, ROW) draws ROW of R (ROW left out: the row shown, when R
    %   has it, else 1); W.showRow(ROW) another row of the same R;
    %   W.step(D) the next (D 1) or previous (-1) row; W.setOrder(ORDER)
    %   "group" or "time"; W.clear(MSG) empties it with a message;
    %   W.close() closes it (so does its close box); W.isOpen().
    %   A result without epochs, or a row that fails, is said in red.
    %
    %   What it drew:
    %     Result   the result (R)
    %     Row      the row drawn (0: none)
    %     Order    "group" | "time"
    %     Raster   epochMatrixRaster's struct of the row ([] when none)
    %     Message  what went wrong ("" if nothing)
    %
    %   See also epochMatrixRaster, epochMatrix, DatasetBrowser, EpochDiagram.

    properties (SetAccess = private)
        Fig                                     % the window (uifigure)
        Result = []                             % the result drawn from
        Row (1,1) double = 0                    % the row drawn (0: none)
        Order (1,1) string = "group"            % "group" | "time"
        Raster = []                             % epochMatrixRaster(Result, Row, Order=Order)
        Message (1,1) string = ""               % what went wrong ("" if nothing)
    end

    properties (Access = private)
        Ui struct = struct()
        OwnerListener = []
    end

    properties (Constant, Access = private)
        OneGroupColor = [0.15 0.15 0.15]        % one ungrouped set
        ErrorColor = [0.75 0.1 0.1]
        TextColor = [0.25 0.25 0.25]
        NoData = "Compute with ""Keep each epoch (R.epochs)"" ticked to see each row trial by trial."
    end

    methods
        function obj = TrialRaster(opts)
            arguments
                opts.Position (1,4) double = [240 120 820 760]
                opts.Visible (1,1) logical = true
                opts.WindowStyle (1,1) string {mustBeMember(opts.WindowStyle, ["alwaysontop" "normal"])} = "normal"
                opts.Owner = []
            end
            obj.Fig = uifigure("Name", "Trial rasters", "Position", opts.Position, "Visible", opts.Visible, ...
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

        function update(obj, R, row)
            %update  Draw row ROW of the result R (left out: the row shown when R has it, else 1).
            if ~obj.isOpen(); return; end
            obj.Result = R;
            n = 0;
            if isstruct(R) && isfield(R, 'rows'); n = height(R.rows); end
            if nargin < 3
                row = obj.Row;
                if row < 1 || row > n; row = 1; end
            end
            obj.fillRows();
            obj.showRow(row);
        end

        function showRow(obj, row)
            %showRow  Draw row ROW of the result.
            if ~obj.isOpen(); return; end
            R = obj.Result;
            obj.Raster = [];
            try
                X = epochMatrixRaster(R, row, Order=obj.Order);
            catch ME
                obj.Row = 0;
                if isstruct(R) && isfield(R, 'rows') && row >= 1 && row <= height(R.rows) && row == round(row)
                    obj.Row = row;
                end
                obj.clear(string(ME.message), true);
                return
            end
            obj.Row = row;
            obj.Raster = X;
            obj.Message = "";
            obj.draw();
        end

        function step(obj, d)
            %step  The next (D 1) or previous (D -1) row.
            R = obj.Result;
            if ~(isstruct(R) && isfield(R, 'rows')) || height(R.rows) == 0; return; end
            obj.showRow(min(max(obj.Row + d, 1), height(R.rows)));
        end

        function setOrder(obj, order)
            %setOrder  Order the epochs "group" (each group's together) or "time".
            order = string(order);
            if ~ismember(order, ["group" "time"])
                error('TrialRaster:BadOrder', 'Order must be "group" or "time" (got "%s").', order);
            end
            obj.Order = order;
            if obj.isOpen(); obj.Ui.Order.Value = char(order); end
            if obj.Row > 0; obj.showRow(obj.Row); end
        end

        function clear(obj, msg, isError)
            %clear  Nothing to draw: say why (ISERROR: in red).
            if nargin < 2; msg = ""; end
            if nargin < 3; isError = false; end
            if ~obj.isOpen(); return; end
            obj.Raster = [];
            obj.Message = string(msg);
            U = obj.Ui;
            U.Title.Text = "";
            U.Info.Text = string(msg);
            U.Info.FontColor = obj.TextColor;
            if isError; U.Info.FontColor = obj.ErrorColor; end
            for ax = [U.Raster U.Mean]
                resetAxes(ax);
                ax.XTick = []; ax.YTick = [];
            end
            obj.navEnable();
        end
    end

    methods (Access = private)
        function build(obj)
            g = uigridlayout(obj.Fig, [5 1], "RowHeight", {22, 'fit', 30, '3x', '1x'}, ...
                "Padding", [12 10 12 10], "RowSpacing", 6);
            U = struct();
            U.Title = uilabel(g, "Text", "", "FontWeight", "bold", "FontSize", 14, "Interpreter", "none");
            U.Info = uilabel(g, "Text", "", "WordWrap", "on", "FontColor", obj.TextColor);
            nav = uigridlayout(g, [1 6], "ColumnWidth", {'fit', '1x', 'fit', 'fit', 'fit', 110}, ...
                "RowHeight", {30}, "Padding", [0 0 0 0], "ColumnSpacing", 8);
            U.Prev = uibutton(nav, "Text", "◀ Previous", "ButtonPushedFcn", @(~, ~) obj.step(-1), ...
                "Tooltip", "The row before this one.");
            U.Rows = uidropdown(nav, "Items", {''}, "ValueChangedFcn", @(src, ~) obj.showRow(double(src.Value)), ...
                "Tooltip", "The row of the result (a unit or a channel) drawn trial by trial.");
            U.Next = uibutton(nav, "Text", "Next ▶", "ButtonPushedFcn", @(~, ~) obj.step(1), ...
                "Tooltip", "The row after this one.");
            uilabel(nav, "Text", "");
            uilabel(nav, "Text", "Order", "HorizontalAlignment", "right");
            U.Order = uidropdown(nav, "Items", {'by group', 'by time'}, "ItemsData", {'group', 'time'}, ...
                "Value", char(obj.Order), "ValueChangedFcn", @(src, ~) obj.setOrder(src.Value), ...
                "Tooltip", "by group: each group's epochs together, in the result's group order; " + ...
                "by time: every epoch in time order, colored by its group.");
            U.Raster = uiaxes(g);
            U.Mean = uiaxes(g);
            for ax = [U.Raster U.Mean]
                ax.FontSize = 10;
                ax.TickLabelInterpreter = 'none';
            end
            styleButton([U.Prev U.Next]);
            obj.Ui = U;
        end

        function fillRows(obj)
            %fillRows  The row drop-down: every row of the result, "12  u37  (name)".
            U = obj.Ui;
            R = obj.Result;
            if ~(isstruct(R) && isfield(R, 'rows')) || height(R.rows) == 0
                U.Rows.Items = {''};
                U.Rows.ItemsData = {0};
                U.Rows.Value = 0;
                return
            end
            n = height(R.rows);
            names = string(R.rows.Dataset);
            if isfield(R, 'datasets') && all(ismember({'key', 'name'}, R.datasets.Properties.VariableNames))
                [in, loc] = ismember(names, string(R.datasets.key));
                names(in) = string(R.datasets.name(loc(in)));
            end
            U.Rows.Items = cellstr(compose("%d  ", (1:n).') + string(R.rows.label) + "  (" + names + ")");
            U.Rows.ItemsData = num2cell(1:n);
        end

        function navEnable(obj)
            U = obj.Ui;
            R = obj.Result;
            n = 0;
            if isstruct(R) && isfield(R, 'rows'); n = height(R.rows); end
            on = @(tf) matlab.lang.OnOffSwitchState(tf);
            U.Rows.Enable = on(n > 0);
            U.Prev.Enable = on(obj.Row > 1);
            U.Next.Enable = on(obj.Row >= 1 && obj.Row < n);
            if obj.Row >= 1 && obj.Row <= n; U.Rows.Value = obj.Row; end
        end

        function draw(obj)
            X = obj.Raster;
            R = obj.Result;
            U = obj.Ui;
            colors = groupColorsOf(R.groupLabels, obj.OneGroupColor);
            nE = height(X.E);
            U.Title.Text = X.label + "  (" + X.name + ")";
            per = strjoin(reshape(X.groupNames + ": " + string(X.nPerGroup), 1, []), ", ");
            what = "";
            if isfield(R, 'labels') && isstruct(R.labels) && isfield(R.labels, 'description'); what = R.labels.description + ". "; end
            U.Info.Text = what + sprintf("%d epochs", nE) + " (" + per + ").";
            U.Info.FontColor = obj.TextColor;
            obj.navEnable();

            ax = U.Raster;
            resetAxes(ax);
            hold(ax, 'on');
            grp = double(X.E.resultGroup);
            byGroup = X.order == "group" && numel(X.groupLabels) > 1;
            if X.rowKind == "unit"
                if byGroup   % each group's band, pale, behind its epochs
                    for g = 1:numel(X.groupLabels)
                        r = find(grp == g);
                        if isempty(r); continue; end
                        patch(ax, 'XData', X.window([1 2 2 1]), 'YData', [r(1) r(1) r(end) r(end)] + [-0.5 -0.5 0.5 0.5], ...
                            'FaceColor', colors(g, :), 'FaceAlpha', 0.12, 'EdgeColor', 'none', 'HandleVisibility', 'off');
                    end
                end
                tg = grp(X.trial);
                for g = 1:numel(X.groupLabels)
                    in = tg == g;
                    if ~any(in); continue; end
                    xs = [X.times(in) X.times(in) NaN(nnz(in), 1)].';
                    ys = [X.trial(in) - 0.4 X.trial(in) + 0.4 NaN(nnz(in), 1)].';
                    line(ax, xs(:), ys(:), 'Color', colors(g, :), 'LineWidth', 0.5, 'Tag', "rasterTicks");
                end
                xlim(ax, X.window);
            else
                imagesc(ax, X.t, 1:nE, double(X.data), 'Tag', "epochImage");
                cb = colorbar(ax);
                cb.Label.String = X.units;
                if numel(X.t) > 1; xlim(ax, X.t([1 end]).'); end
                if byGroup   % the groups' edges over the image
                    for b = reshape(find(diff(grp) ~= 0), 1, [])
                        yline(ax, b + 0.5, 'Color', 'w', 'LineWidth', 1.5, 'HandleVisibility', 'off');
                    end
                end
            end
            xline(ax, 0, ':', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off');
            hold(ax, 'off');
            ax.YDir = 'reverse';
            ylim(ax, [0.5 max(nE, 1) + 0.5]);
            if byGroup   % each group labeled at its middle
                mids = NaN(numel(X.groupLabels), 1);
                for g = 1:numel(X.groupLabels)
                    r = find(grp == g);
                    if ~isempty(r); mids(g) = (r(1) + r(end)) / 2; end
                end
                ok = isfinite(mids);
                ax.YTick = mids(ok);
                ax.YTickLabel = cellstr(X.groupNames(ok));
                ylabel(ax, "Epochs by group");
            else
                ylabel(ax, "Epoch (by time)");
            end
            timeLabel = "Time from the event (s)";
            if isfield(R, 'labels') && isstruct(R.labels) && isfield(R.labels, 'time'); timeLabel = R.labels.time; end
            xlabel(ax, timeLabel);
            title(ax, ternary(X.rowKind == "unit", "Raster", "Each epoch"), 'FontWeight', 'normal');

            ax = U.Mean;
            resetAxes(ax);
            hold(ax, 'on');
            y = reshape(R.data(X.row, :, :), numel(R.t), []);
            for g = 1:size(y, 2)
                plot(ax, R.t, y(:, g), 'Color', colors(g, :), 'LineWidth', 1, 'DisplayName', X.groupNames(g));
            end
            xline(ax, 0, ':', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off');
            hold(ax, 'off');
            if ~isempty(R.t); xlim(ax, X.window); end
            valueLabel = string(R.valueUnits);
            if isfield(R, 'labels') && isstruct(R.labels) && isfield(R.labels, 'value'); valueLabel = R.labels.value; end
            ylabel(ax, valueLabel);
            xlabel(ax, timeLabel);
            if size(y, 2) > 1
                lg = legend(ax);
                lg.Location = 'eastoutside';
                lg.Interpreter = 'none';
            end
        end
    end
end


function resetAxes(ax)
%resetAxes  Empty AX for a redraw: its children, legend, color bar, labels, limits and ticks.
legend(ax, 'off');
colorbar(ax, 'off');
cla(ax);
hold(ax, 'off');
set(ax, 'XTickMode', 'auto', 'XTickLabelMode', 'auto', 'YTickMode', 'auto', 'YTickLabelMode', 'auto', ...
    'XLimMode', 'auto', 'YLimMode', 'auto', 'YDir', 'normal');
xlabel(ax, "");
ylabel(ax, "");
title(ax, "");
end


function C = groupColorsOf(labels, one)
%groupColorsOf  Each group's color: ordered (parula) for more than two numeric labels, else lines; ONE for a single group.
n = numel(labels);
if n <= 1
    C = repmat(one, max(n, 1), 1);
else
    C = groupColors(labels, isnumeric(labels));
end
end


function v = ternary(c, a, b)
if c; v = a; else; v = b; end
end
