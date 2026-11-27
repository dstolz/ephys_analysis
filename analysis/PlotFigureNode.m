classdef PlotFigureNode < PlotNode
    %PlotFigureNode  One figure of an analysis app, from the command line: its panels, parts, looks and settings.
    %   f = app.Plots.Figure("unit_card") (PlotConsole.Figure: by id, by
    %   number, or none for the figure shown). Typed alone, f says what it
    %   holds.
    %
    %     f.Panel("psth_1")       a panel, by id or by number (PlotPanelNode)
    %     f.xlabel                a part of the figure, by its role
    %                             (PlotPartNode): that part in every panel,
    %                             or the figure's own (plotTitle, a legend
    %                             outside the panels). f.Part("xlabel") is
    %                             the same; f.rate("Go") one group of it
    %     f.xlabel.FontSize = 11  a look, remembered with the figure
    %     f.Settings              the figure's settings, as the config
    %                             holds them (title, style, size, observe,
    %                             ref, window, selection, sessions, probe,
    %                             latency, layout, enabled); one is set
    %                             with f.Settings.style.FontSize = 9
    %     f.Panels                its panels' ids
    %     f.Parts                 what the app's preview of it draws: a
    %                             table Panel, Part, Group, Type, Label
    %                             (no rows until it is previewed)
    %     f.Looks                 the looks remembered with it: a table
    %                             Panel, Part, Group, Property, Value
    %     f.forget()              forget them all (as the editor's Forget)
    %     f.show()                show it on the Figures tab and draw its
    %                             preview when that is not current
    %     f.Id, f.Index           its id and its place in the list, now
    %
    %   The figure is found by its id each time, following a rename (an
    %   automatic id that followed an edit); once it is removed, using f
    %   raises PlotConsole:Gone. The id, the panels and the looks are not
    %   set through Settings (PlotConsole:NoSetting): looks through the
    %   parts, panels in the Figures tab.
    %
    %   See also PlotConsole, PlotPanelNode, PlotPartNode, EphysAnalysisConfig.

    properties (Dependent, SetAccess = private)
        Id          % the figure's id, now
        Index       % its place in the app's list of figures
        Panels      % its panels' ids (a string row)
        Parts       % what the app's preview of it draws: a table (no rows until it is previewed)
        Looks       % the looks remembered with it: a table
        Settings    % its settings, as the config holds them (a struct); set one with f.Settings.<name> = value
    end

    properties (Constant, Hidden)
        NotSettings = ["id" "autoId" "panels" "aesthetics"]   % a figure's fields Settings leaves out: set by the app, through Panel(...) and through the parts
    end

    methods
        function obj = PlotFigureNode(console, id)
            %PlotFigureNode  The figure ID of CONSOLE's app (PlotConsole.Figure makes it).
            arguments
                console (1,1) PlotConsole
                id (1,1) string
            end
            obj@PlotNode(console, id);
        end

        function id = get.Id(obj)
            [~, ~, id] = figureAt(obj.Console, obj.FigureId);
        end

        function k = get.Index(obj)
            [~, k] = figureAt(obj.Console, obj.FigureId);
        end

        function ids = get.Panels(obj)
            fig = figureAt(obj.Console, obj.FigureId);
            ids = [string.empty(1, 0) fig.panels.id];
        end

        function T = get.Parts(obj)
            T = PlotPartNode.partsTable(drawnParts(obj.Console, obj.FigureId, ""));
        end

        function T = get.Looks(obj)
            fig = figureAt(obj.Console, obj.FigureId);
            T = PlotPartNode.looksTable(fig.aesthetics);
        end

        function S = get.Settings(obj)
            fig = figureAt(obj.Console, obj.FigureId);
            S = rmfield(fig, cellstr(obj.NotSettings));
        end

        function p = Panel(obj, id)
            %Panel  A panel of the figure: Panel("id"), or Panel(k) by its place in the figure's list of panels.
            arguments
                obj (1,1) PlotFigureNode
                id
            end
            fig = figureAt(obj.Console, obj.FigureId);
            ids = [string.empty(1, 0) fig.panels.id];
            if isnumeric(id) && isscalar(id)
                j = double(id);
                if j ~= fix(j) || j < 1 || j > numel(ids)
                    error('PlotConsole:NoPanel', 'Figure "%s" has no panel %g: it has %d panel(s).', fig.id, j, numel(ids));
                end
            elseif ischar(id) || (isstring(id) && isscalar(id))
                j = find(ids == string(id));
                if isempty(j); j = find(strcmpi(ids, string(id))); end   % whatever the case, when only one is meant
                if ~isscalar(j)
                    error('PlotConsole:NoPanel', 'Figure "%s" has no panel "%s". Its panels: %s.', fig.id, string(id), ...
                        strjoin("""" + ids + """", ", "));
                end
            else
                error('PlotConsole:NoPanel', 'A panel is named by its id (text) or its number.');
            end
            p = PlotPanelNode(obj.Console, obj.FigureId, ids(j));
        end

        function p = Part(obj, role, group)
            %Part  A part of the figure by its role, in every panel: Part("xlabel"), the same as f.xlabel; Part("rate", "Go") one group of it.
            arguments
                obj (1,1) PlotFigureNode
                role (1,1) string
                group (1,1) string = ""
            end
            p = PlotPartNode(obj.Console, obj.FigureId, "", role, group);
        end

        function obj = forget(obj)
            %forget  Forget every look remembered with the figure, its panels' too (as the editor's Forget).
            arguments
                obj (1,1) PlotFigureNode
            end
            fig = figureAt(obj.Console, obj.FigureId);
            if isempty(fig.aesthetics); return; end
            change(obj.Console, PlotConsole.newOp("forget", obj.FigureId, Text="forget the looks of " + fig.id));
        end

        function obj = show(obj)
            %show  Show the figure on the app's Figures tab, and draw its preview when that is not current (the Preview button).
            arguments
                obj (1,1) PlotFigureNode
            end
            app = openApp(obj.Console);
            k = app.figureIndexOf(obj.FigureId);
            if k < 1; figureAt(obj.Console, obj.FigureId); end   % (raises PlotConsole:Gone)
            if app.Tabs.SelectedTab ~= app.TabFigures; app.selectTab(app.TabFigures); end
            if app.SelectedFigure ~= k; app.onFigureSelected(k); end
            [~, look] = app.figureDrawing(obj.FigureId);
            if look ~= "fresh"; app.refreshFigurePreview(Force=true); end
        end

        function disp(obj)
            %disp  The figure's panels, parts and looks, and what can be typed next.
            if ~isscalar(obj)
                fprintf('  %s array of PlotFigureNode\n\n', strjoin(string(size(obj)), 'x'));
                return
            end
            try
                [fig, k] = figureAt(obj.Console, obj.FigureId);
                app = openApp(obj.Console);
            catch ME
                fprintf('  Figure "%s": %s\n\n', obj.FigureId, ME.message);
                return
            end
            where = "";
            if k == app.SelectedFigure; where = ", the figure shown"; end
            [T, look] = drawnParts(obj.Console, obj.FigureId, "");
            fprintf('  Figure "%s" (number %d of %d%s)\n\n', fig.id, k, numel(app.Config.Figures), where);
            if isempty(fig.panels)
                fprintf('    No panels.\n');
            else
                fprintf('    Panels, Panel("id") or Panel(k):\n');
                for j = 1:numel(fig.panels)
                    fprintf('      %d  %s  (%s)\n', j, fig.panels(j).id, fig.panels(j).type);
                end
            end
            PlotPartNode.printParts(T, look, "the figure", "f");
            fprintf('    Looks remembered: %d (Looks lists them, forget() drops them).\n', numel(fig.aesthetics));
            fprintf('    Settings: %s\n', strjoin(setdiff(string(fieldnames(fig)).', obj.NotSettings, 'stable'), ", "));
            fprintf('      (f.Settings shows them; f.Settings.title = "..." sets one)\n\n');
        end
    end

    methods (Access = protected)
        function names = dotMethods(~)
            names = ["Panel" "Part" "forget" "show"];
        end

        function names = dotProperties(~)
            names = ["Id" "Index" "Panels" "Parts" "Looks" "Settings"];
        end

        function [v, usedArgs] = dotOther(obj, name, args, called)
            %dotOther  f.<role>: that part in every panel; f.<role>("group") one group of it.
            [v, usedArgs] = PlotPartNode.byRole(obj.Console, obj.FigureId, "", name, args, called);
        end

        function done = assign(obj, name, rest, value)
            %assign  f.Settings.<path> = VALUE: one setting of the figure; the rest as any node.
            if name == "Settings"
                changeSetting(obj.Console, obj.FigureId, "", obj.NotSettings, rest, value);
                done = true;
            else
                done = assign@PlotNode(obj, name, rest, value);
            end
        end

        function s = nodeWord(obj)
            s = "figure """ + obj.FigureId + """";
        end
    end
end
