classdef PlotPanelNode < PlotNode
    %PlotPanelNode  One panel of an analysis app's figure, from the command line: its parts, looks and settings.
    %   pn = app.Plots.Figure("unit_card").Panel("psth_1")
    %   (PlotFigureNode.Panel: by id or by number). Typed alone, pn says
    %   what it holds.
    %
    %     pn.rateFill              a part drawn in the panel, by its role
    %                              (PlotPartNode): .axes (a raster's:
    %                              .rasterAxes), .xlabel, .ylabel,
    %                              .tileTitle, .sem, .zeroLine, ...;
    %                              pn.Part("rateFill") is the same, and
    %                              pn.rateFill("Go") one group of it
    %     pn.rateFill.FaceColor = "red"
    %                              a look of this panel alone, remembered
    %                              with the figure
    %     pn.Settings              the panel's settings, as the config
    %                              holds them (title, xLabel, yLabel,
    %                              xSide, ySide, xShow, yShow, box, rect,
    %                              ref, window, selection, layers, options,
    %                              note, overlays); one is set with
    %                              pn.Settings.options.yLim = [0 50]
    %     pn.Parts                 what the app's preview draws in it: a
    %                              table Panel, Part, Group, Type, Label
    %     pn.Looks                 the looks remembered for this panel
    %     pn.forget()              forget them
    %     pn.Id, pn.Type, pn.Index its id, its type and its place among
    %                              the figure's panels, now
    %
    %   The panel is found by its figure's id and its own each time; once
    %   it is removed, using pn raises PlotConsole:Gone. Its id and type
    %   are not set here (PlotConsole:NoSetting): a type change resets the
    %   type's options, which the Figures tab does.
    %
    %   See also PlotConsole, PlotFigureNode, PlotPartNode, EphysAnalysisConfig.

    properties (Dependent, SetAccess = private)
        Id          % the panel's id
        Type        % its type ("psth", "raster", ...)
        Index       % its place among the figure's panels
        Parts       % what the app's preview draws in it: a table (no rows until the figure is previewed)
        Looks       % the looks remembered for this panel: a table
        Settings    % its settings, as the config holds them (a struct); set one with pn.Settings.<name> = value
    end

    properties (Constant, Hidden)
        NotSettings = ["id" "type"]   % a panel's fields Settings leaves out
    end

    methods
        function obj = PlotPanelNode(console, figureId, panelId)
            %PlotPanelNode  Panel PANELID of figure FIGUREID of CONSOLE's app (PlotFigureNode.Panel makes it).
            arguments
                console (1,1) PlotConsole
                figureId (1,1) string
                panelId (1,1) string
            end
            obj@PlotNode(console, figureId, panelId);
        end

        function id = get.Id(obj)
            p = panelAt(obj.Console, obj.FigureId, obj.PanelId);
            id = p.id;
        end

        function t = get.Type(obj)
            p = panelAt(obj.Console, obj.FigureId, obj.PanelId);
            t = p.type;
        end

        function j = get.Index(obj)
            [~, j] = panelAt(obj.Console, obj.FigureId, obj.PanelId);
        end

        function T = get.Parts(obj)
            T = PlotPartNode.partsTable(drawnParts(obj.Console, obj.FigureId, obj.PanelId));
        end

        function T = get.Looks(obj)
            [~, ~, fig] = panelAt(obj.Console, obj.FigureId, obj.PanelId);
            R = fig.aesthetics;
            if ~isempty(R); R = R([R.panel] == obj.PanelId); end
            T = PlotPartNode.looksTable(R);
        end

        function S = get.Settings(obj)
            p = panelAt(obj.Console, obj.FigureId, obj.PanelId);
            S = rmfield(p, cellstr(obj.NotSettings));
        end

        function p = Part(obj, role, group)
            %Part  A part drawn in the panel, by its role: Part("rateFill"), the same as pn.rateFill; Part("rateFill", "Go") one group of it.
            arguments
                obj (1,1) PlotPanelNode
                role (1,1) string
                group (1,1) string = ""
            end
            p = PlotPartNode(obj.Console, obj.FigureId, obj.PanelId, role, group);
        end

        function obj = forget(obj)
            %forget  Forget the looks remembered for this panel (the figure's own, for every panel, stay).
            arguments
                obj (1,1) PlotPanelNode
            end
            [~, ~, fig] = panelAt(obj.Console, obj.FigureId, obj.PanelId);
            R = fig.aesthetics;
            if isempty(R) || ~any([R.panel] == obj.PanelId); return; end
            change(obj.Console, PlotConsole.newOp("forget", obj.FigureId, Panel=obj.PanelId, ...
                Text="forget the looks of " + obj.PanelId));
        end

        function disp(obj)
            %disp  The panel's parts and looks, and what can be typed next.
            if ~isscalar(obj)
                fprintf('  %s array of PlotPanelNode\n\n', strjoin(string(size(obj)), 'x'));
                return
            end
            try
                [p, j, fig] = panelAt(obj.Console, obj.FigureId, obj.PanelId);
            catch ME
                fprintf('  Panel "%s" of figure "%s": %s\n\n', obj.PanelId, obj.FigureId, ME.message);
                return
            end
            [T, look] = drawnParts(obj.Console, obj.FigureId, obj.PanelId);
            fprintf('  Panel "%s" (%s; number %d of %d) of figure "%s"\n\n', p.id, p.type, j, numel(fig.panels), fig.id);
            PlotPartNode.printParts(T, look, "the panel", "pn");
            n = 0;
            if ~isempty(fig.aesthetics); n = nnz([fig.aesthetics.panel] == obj.PanelId); end
            fprintf('    Looks remembered for this panel: %d (Looks lists them, forget() drops them).\n', n);
            fprintf('    Settings: %s\n', strjoin(setdiff(string(fieldnames(p)).', obj.NotSettings, 'stable'), ", "));
            fprintf('      (pn.Settings shows them; pn.Settings.yLabel = "..." sets one)\n\n');
        end
    end

    methods (Access = protected)
        function names = dotMethods(~)
            names = ["Part" "forget"];
        end

        function names = dotProperties(~)
            names = ["Id" "Type" "Index" "Parts" "Looks" "Settings"];
        end

        function [v, usedArgs] = dotOther(obj, name, args, called)
            %dotOther  pn.<role>: that part of the panel; pn.<role>("group") one group of it.
            [v, usedArgs] = PlotPartNode.byRole(obj.Console, obj.FigureId, obj.PanelId, name, args, called);
        end

        function done = assign(obj, name, rest, value)
            %assign  pn.Settings.<path> = VALUE: one setting of the panel; the rest as any node.
            if name == "Settings"
                changeSetting(obj.Console, obj.FigureId, obj.PanelId, obj.NotSettings, rest, value);
                done = true;
            else
                done = assign@PlotNode(obj, name, rest, value);
            end
        end

        function s = nodeWord(obj)
            s = "panel """ + obj.PanelId + """";
        end
    end
end
