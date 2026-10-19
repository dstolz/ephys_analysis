classdef DataTipFieldsDialog < handle
    %DataTipFieldsDialog  Choose what the data tips of drawn figures show.
    %   D = DataTipFieldsDialog() opens a modal window with a check box per
    %   data tip field (FigureDataTips.fields), grouped as Point, Trial and
    %   Source, ticked as the user chose them last (FigureDataTips.chosen).
    %   A figure's right-click "Data tip fields..." opens it, and so does
    %   the analysis app's Design menu.
    %     All / None   tick or untick every field
    %     Reset        the default fields
    %     Cancel       closes the window, nothing kept (so does closing it)
    %     OK           keeps the choice as your preference
    %                  (FigureDataTips.setChosen) and shows it at once on
    %                  every figure on screen (FigureDataTips.refresh);
    %                  figures drawn after use it too
    %
    %   Options
    %     Parent    the figure to center the window over ([] = none)
    %     Visible   false builds it hidden (tests)
    %
    %   The same without the mouse (tests, scripts):
    %     d.setField(KEY, TF), d.all(), d.none(), d.reset(), d.ok(), d.cancel()
    %
    %   See also FigureDataTips, renderFigure, PlotAestheticsDialog.

    properties (SetAccess = private)
        Fig                             % the dialog's uifigure
        Fields table                    % FigureDataTips.fields
        Chosen (1,:) string             % the keys ticked
        Boxes struct = struct()         % a check box per key
    end

    methods
        function obj = DataTipFieldsDialog(opts)
            arguments
                opts.Parent = []
                opts.Visible (1,1) logical = true
            end
            obj.Fields = FigureDataTips.fields();
            obj.Chosen = FigureDataTips.chosen();
            obj.build(opts.Parent, opts.Visible);
        end

        function delete(obj)
            if ~isempty(obj.Fig) && isvalid(obj.Fig); delete(obj.Fig); end
        end

        function setField(obj, key, tf)
            %setField  Tick (TF true) or untick field KEY.
            key = string(key);
            if ~any(obj.Fields.Key == key)
                error('FigureDataTips:BadField', 'No data tip field "%s".', key);
            end
            if tf
                obj.Chosen = obj.Fields.Key(ismember(obj.Fields.Key, [obj.Chosen key])).';
            else
                obj.Chosen = obj.Chosen(obj.Chosen ~= key);
            end
            obj.show();
        end

        function all(obj)
            %all  Tick every field.
            obj.Chosen = obj.Fields.Key.';
            obj.show();
        end

        function none(obj)
            %none  Untick every field (the tips then say X and Y only).
            obj.Chosen = strings(1, 0);
            obj.show();
        end

        function reset(obj)
            %reset  The default fields.
            obj.Chosen = obj.Fields.Key(obj.Fields.Default).';
            obj.show();
        end

        function ok(obj)
            %ok  Keep the choice (preferences), show it on every figure on screen, and close.
            FigureDataTips.setChosen(obj.Chosen);
            FigureDataTips.refresh();
            delete(obj);
        end

        function cancel(obj)
            %cancel  Close, keeping nothing.
            delete(obj);
        end
    end

    methods (Access = private)
        function build(obj, parent, visible)
            T = obj.Fields;
            sections = unique(T.Section, 'stable');
            sz = [460 120 + 26 * height(T) + 34 * numel(sections)];
            pos = [100 100 sz];
            if ~isempty(parent) && isgraphics(parent)
                try
                    pp = getpixelposition(parent);
                    pos(1:2) = max(1, pp(1:2) + (pp(3:4) - sz) / 2);
                catch
                end
            end
            obj.Fig = uifigure('Name', 'Data tip fields', 'Position', pos, 'Visible', 'off', 'WindowStyle', 'modal', ...
                'CloseRequestFcn', @(~, ~) obj.cancel());
            heights = [{'fit'} repmat({'fit'}, 1, numel(sections)) {'1x', 34}];
            main = uigridlayout(obj.Fig, [numel(heights) 1], 'RowHeight', heights, 'Padding', 10, 'RowSpacing', 8);
            uilabel(main, 'WordWrap', 'on', 'Text', ['What a data tip of a figure shows when you click a point ' ...
                '(a line, raster tick, bar or heat map cell). Kept as your preference, for every figure.']);
            for s = reshape(sections, 1, [])
                rows = find(T.Section == s).';
                p = uipanel(main, 'Title', char(s), 'FontWeight', 'bold');
                g = uigridlayout(p, [ceil(numel(rows) / 2) 2], 'RowHeight', repmat({22}, 1, ceil(numel(rows) / 2)), ...
                    'Padding', [8 4 8 4], 'RowSpacing', 2, 'ColumnSpacing', 10);
                for r = rows
                    key = T.Key(r);
                    obj.Boxes.(key) = uicheckbox(g, 'Text', char(T.Label(r)), 'Tooltip', char(T.Description(r)), ...
                        'Value', any(obj.Chosen == key), 'ValueChangedFcn', @(b, ~) obj.setField(key, b.Value));
                end
            end
            uilabel(main, 'Text', '');
            bg = uigridlayout(main, [1 6], 'ColumnWidth', {64, 64, 64, '1x', 90, 90}, 'Padding', 0, 'ColumnSpacing', 6);
            bt(1) = uibutton(bg, 'Text', 'All', 'ButtonPushedFcn', @(~, ~) obj.all(), 'Tooltip', 'Tick every field');
            bt(2) = uibutton(bg, 'Text', 'None', 'ButtonPushedFcn', @(~, ~) obj.none(), ...
                'Tooltip', 'Untick every field: the tips say X and Y only');
            bt(3) = uibutton(bg, 'Text', 'Reset', 'ButtonPushedFcn', @(~, ~) obj.reset(), 'Tooltip', 'The default fields');
            uilabel(bg, 'Text', '');
            bt(4) = uibutton(bg, 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) obj.cancel(), 'Tooltip', 'Close, keeping nothing');
            okb = uibutton(bg, 'Text', 'OK', 'ButtonPushedFcn', @(~, ~) obj.ok(), ...
                'Tooltip', 'Keep these fields for every figure, and show them on the figures on screen now');
            styleButton(bt);
            styleButton(okb, "confirm");
            if visible; obj.Fig.Visible = 'on'; end
        end

        function show(obj)
            %show  The check boxes as Chosen says.
            for key = reshape(obj.Fields.Key, 1, [])
                if isfield(obj.Boxes, key) && isvalid(obj.Boxes.(key))
                    obj.Boxes.(key).Value = any(obj.Chosen == key);
                end
            end
        end
    end
end
