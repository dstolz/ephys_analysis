classdef PlotConsole < PlotNode
    %PlotConsole  An analysis app's figures from the command line: figures, panels, parts and their properties as a tree of objects.
    %   Every EphysFigGenApp has one, app.Plots. It changes what the
    %   Figures tab's editor and the right-click aesthetics editor change,
    %   by typing: each change goes into the app's config as one step of
    %   its undo history, the preview follows, and Save, runs, reports and
    %   generated scripts take it like any other edit.
    %
    %     app = EphysFigGenApp.current();     % the app open now (or keep the handle: app = EphysFigGenApp(...))
    %     p = app.Plots;
    %
    %   The tree
    %     p                                   the console: typed alone, it lists the figures
    %     p.Figure("unit_card")               a figure, by id or by number (PlotFigureNode); p.Figure() is the one shown
    %       .Panel("psth_1")                  a panel of it, by id or by number (PlotPanelNode)
    %         .rate                           a part drawn in it, by its role (PlotPartNode): .axes, .xlabel, .sem, ...
    %           ("Go")                        ... of one group only: a trial group, a series, a channel
    %             .Color                      a property of the part
    %   A part named on a figure, p.Figure("unit_card").xlabel, is that
    %   part in every panel. Each object typed alone says what it holds
    %   and what can follow it; Parts, Looks and Properties list it as a
    %   table.
    %
    %   Changing the look of a part
    %     f = p.Figure("unit_card");
    %     f.Panel("psth_1").rate.Color = "red";          % the PSTH's line: a name, "#1f77b4", or [r g b]
    %     f.Panel("psth_1").rateFill.FaceAlpha = 0.4;    % the fill of its bars
    %     f.Panel("psth_1").rate("Go").LineWidth = 2;    % one trial group's line
    %     f.Panel("raster_1").axes.Box = "off";
    %     f.xlabel.FontSize = 11;                        % every panel's x label
    %     f.legend.FontSize = 8;
    %     f.Panel("psth_1").sem.set(FaceAlpha=0.2, EdgeColor="none");   % several at once
    %     f.Panel("psth_1").rate.Color = [];             % forget it: as the design draws it
    %   Each is remembered with the figure as a look (a PlotAesthetics
    %   rule in its aesthetics, for the panel named), as the aesthetics
    %   editor's "Remember for this figure" does.
    %
    %   Changing a setting (what the Figures tab's editor shows; the names
    %   are the config's: documentation/EphysAnalysisConfig.md)
    %     f.Settings.title = "Unit {unit}";
    %     f.Settings.style.FontSize = 9;
    %     f.Panel("psth_1").Settings.yLabel = "Rate (sp/s)";
    %     f.Panel("psth_1").Settings.options.histStyle = "line";
    %
    %   At once, or together: one switch
    %     p.Immediate = true     (the default) each change is made as it is
    %                            typed: one undo step, the preview follows
    %     p.Immediate = false    the changes are kept (p.Pending lists them)
    %                            and nothing changes in the app until
    %       p.apply()            makes them all: one undo step, one redraw
    %       p.discard()          or drops them
    %     Turning Immediate on again makes the changes kept. While changes
    %     are kept, what is read (a property, Settings, Looks) is the
    %     figure as it will be with them.
    %
    %   What follows a change in the app: a look alone redraws the figure
    %   shown from the result its preview holds, nothing computed, when
    %   that drawing was current; any other change follows the Auto slider
    %   as an edit in the editor does. A figure not shown is marked out of
    %   date in the tree; p.Figure(id).show() shows and draws it. Edit >
    %   Undo takes a change back.
    %
    %   Errors: PlotConsole:Closed (the app's window is closed),
    %   PlotConsole:NoFigure, PlotConsole:NoPanel, PlotConsole:NoPart,
    %   PlotConsole:NoProperty, PlotConsole:NoSetting, PlotConsole:Gone (a
    %   figure or panel kept in a variable is no longer there),
    %   PlotConsole:ReadOnly, PlotConsole:Invalid (a setting the config's
    %   validate refuses), PlotAesthetics:BadValue (a value the property
    %   does not take). Warnings: PlotConsole:NotDrawn (the preview drawn
    %   shows no such part: the look is kept all the same),
    %   PlotConsole:Skipped (a kept change whose figure or panel is gone),
    %   PlotConsole:Check (a new warning of the config's validate).
    %
    %   See also EphysFigGenApp, PlotFigureNode, PlotPanelNode, PlotPartNode, PlotAesthetics, EphysAnalysisConfig.

    properties
        Immediate (1,1) matlab.lang.OnOffSwitchState = matlab.lang.OnOffSwitchState.on   % on (default): each change is made at once; off: kept for apply
    end

    properties (Dependent, SetAccess = private)
        Pending     % the changes kept while Immediate is off: a table, Figure, Panel, Change
        Figures     % the figures' ids, in the app's order (a string row)
    end

    properties (SetAccess = private, Hidden)
        App = []                        % the EphysFigGenApp
        Queue = repmat(struct('kind', "", 'figure', "", 'panel', "", 'role', "", 'group', "", 'property', "", ...
            'path', "", 'value', [], 'text', ""), 1, 0)   % the changes kept (newOp)
    end

    methods
        function obj = PlotConsole(app)
            %PlotConsole  The console of APP (EphysFigGenApp makes its own: app.Plots).
            arguments
                app (1,1) EphysFigGenApp
            end
            obj.App = app;
        end

        function set.Immediate(obj, tf)
            obj.Immediate = tf;
            if obj.Immediate && ~isempty(obj.Queue) %#ok<MCSUP>
                apply(obj);   % on again: the changes kept are made
            end
        end

        function T = get.Pending(obj)
            q = obj.Queue;
            n = numel(q);
            Figure = strings(n, 1);
            Panel = strings(n, 1);
            Change = strings(n, 1);
            for i = 1:n
                Figure(i) = q(i).figure;
                Panel(i) = q(i).panel;
                Change(i) = q(i).text;
            end
            T = table(Figure, Panel, Change);
        end

        function ids = get.Figures(obj)
            app = openApp(obj);
            ids = app.Config.figureIds();
        end

        function f = Figure(obj, id)
            %Figure  A figure of the app: Figure("id"), Figure(k) by its place in the list, Figure() the one shown.
            arguments
                obj (1,1) PlotConsole
                id = []
            end
            app = openApp(obj);
            ids = app.Config.figureIds();
            if isempty(id)
                k = app.SelectedFigure;
                if k < 1 || k > numel(ids)
                    error('PlotConsole:NoFigure', 'The app shows no figure. Name one: Figure("id") (Figures lists the ids).');
                end
            elseif isnumeric(id) && isscalar(id)
                k = double(id);
                if k ~= fix(k) || k < 1 || k > numel(ids)
                    error('PlotConsole:NoFigure', 'There is no figure %g: the app has %d figure(s).', k, numel(ids));
                end
            elseif ischar(id) || (isstring(id) && isscalar(id))
                k = app.figureIndexOf(string(id));
                if k < 1; k = find(strcmpi(ids, string(id))); end   % whatever the case, when only one is meant
                if ~isscalar(k) || k < 1
                    error('PlotConsole:NoFigure', 'There is no figure "%s". The figures: %s.', string(id), listText(ids));
                end
            else
                error('PlotConsole:NoFigure', 'A figure is named by its id (text) or its number.');
            end
            f = PlotFigureNode(obj, ids(k));
        end

        function obj = apply(obj)
            %apply  Make the changes kept while Immediate is off: one step of the app's undo history, one redraw.
            %   The changes are made on the app's config as it is now, so
            %   an edit made in the window meanwhile is kept. A change
            %   whose figure or panel is gone is left out, with the warning
            %   PlotConsole:Skipped.
            arguments
                obj (1,1) PlotConsole
            end
            if isempty(obj.Queue); return; end
            app = openApp(obj);
            [cfg, made] = replay(obj, app.Config, obj.Queue, false);
            checkSettings(app.Config, cfg, made);
            obj.Queue = obj.Queue([]);
            commit(obj, cfg, made);
        end

        function obj = discard(obj)
            %discard  Drop the changes kept while Immediate is off; the app has none of them.
            arguments
                obj (1,1) PlotConsole
            end
            obj.Queue = obj.Queue([]);
        end

        function disp(obj)
            %disp  The figures, and what can be typed next.
            if ~isscalar(obj)
                fprintf('  %s array of PlotConsole\n\n', strjoin(string(size(obj)), 'x'));
                return
            end
            app = obj.App;
            if isempty(app) || ~isvalid(app) || isempty(app.Fig) || ~isvalid(app.Fig)
                fprintf('  PlotConsole of an analysis app that is closed.\n\n');
                return
            end
            cfg = app.Config;
            name = string(cfg.Name);
            if name == ""; name = "(no name)"; end
            fprintf('  Figures of the analysis app, config %s. Immediate: %s\n\n', name, string(obj.Immediate));
            F = cfg.Figures;
            if isempty(F)
                fprintf('    The config has no figure: add one in the Figures tab.\n\n');
            else
                n = numel(F);
                No = (1:n).';
                Figure = strings(n, 1); Panels = strings(n, 1); Looks = zeros(n, 1); Preview = strings(n, 1);
                for k = 1:n
                    Figure(k) = F(k).id;
                    if k == app.SelectedFigure; Figure(k) = Figure(k) + "  (shown)"; end
                    Panels(k) = strjoin([string.empty(1, 0) F(k).panels.id], ", ");
                    Looks(k) = numel(F(k).aesthetics);
                    [~, look] = app.figureDrawing(F(k).id);
                    Preview(k) = previewWord(look);
                end
                disp(table(No, Figure, Panels, Looks, Preview));
            end
            fprintf('  Figure("id") or Figure(k) is a figure; Figure() the one shown.\n');
            np = numel(obj.Queue);
            if np > 0
                fprintf('  %d change(s) kept, not made yet: apply() makes them, discard() drops them; Pending lists them.\n', np);
            elseif ~obj.Immediate
                fprintf('  Immediate is off: changes are kept until apply().\n');
            else
                fprintf('  Immediate = false keeps the changes until apply(); now each is made at once.\n');
            end
            fprintf('  help PlotConsole shows the syntax.\n\n');
        end
    end

    %% --- what the nodes use ---------------------------------------------------
    methods (Access = ?PlotNode)
        function app = openApp(obj)
            %openApp  The app, while its window is open (PlotConsole:Closed otherwise).
            app = obj.App;
            if isempty(app) || ~isvalid(app) || isempty(app.Fig) || ~isvalid(app.Fig)
                error('PlotConsole:Closed', 'The analysis app these figures belong to is closed.');
            end
        end

        function [fig, k, id] = figureAt(obj, id)
            %figureAt  The figure ID names now, as it will be with the changes kept: its struct, index and id (PlotConsole:Gone when it is gone).
            app = openApp(obj);
            [k, idNow] = app.figureIndexOf(id);
            if k < 1
                error('PlotConsole:Gone', 'Figure "%s" is no longer in the app. The figures: %s.', id, listText(app.Config.figureIds()));
            end
            cfg = replay(obj, app.Config, obj.Queue, false, true);
            fig = cfg.Figures(k);
            id = idNow;
        end

        function [panel, j, fig, k] = panelAt(obj, figureId, panelId)
            %panelAt  Panel PANELID of the figure FIGUREID names now, with the changes kept (PlotConsole:Gone when it is gone).
            [fig, k] = figureAt(obj, figureId);
            j = [];
            if ~isempty(fig.panels); j = find([fig.panels.id] == panelId, 1); end
            if isempty(j)
                error('PlotConsole:Gone', 'Figure "%s" has no panel "%s" any more. Its panels: %s.', fig.id, panelId, ...
                    listText([string.empty(1, 0) fig.panels.id]));
            end
            panel = fig.panels(j);
        end

        function [T, look] = drawnParts(obj, figureId, panelId)
            %drawnParts  The parts the app's preview of figure FIGUREID holds, those of panel PANELID ("" = all): PlotAesthetics.components' rows with a role.
            %   Empty (no rows) when the figure has no drawing kept. LOOK
            %   says whether that drawing is current (figureDrawing).
            app = openApp(obj);
            [P, look] = app.figureDrawing(figureId);
            T = table();
            if isempty(P); return; end
            T = PlotAesthetics.components(P);
            T = T(T.Role ~= "", :);
            Panel = T.TileName;
            Panel(T.Tile == 0) = "";   % the figure's own: its title, a legend outside the panels
            T.Panel = Panel;
            if panelId ~= ""; T = T(T.Panel == panelId, :); end
        end

        function changeSetting(obj, figureId, panelId, notSettings, rest, value)
            %changeSetting  node.Settings<REST> = VALUE: one setting of figure FIGUREID (PANELID "") or of its panel PANELID.
            %   REST are the subscripts typed after Settings: the names
            %   down to the setting (.style.FontSize), then, when only a
            %   piece of its value is given, the index of that piece
            %   (.rect(3), .layers(2).name: the setting is then set whole,
            %   with the piece changed). A name that is no setting there,
            %   or one of NOTSETTINGS (what Settings leaves out), raises
            %   PlotConsole:NoSetting; a value the setting does not take
            %   EphysAnalysisConfig:BadValue, or PlotConsole:Invalid (the
            %   config's validate).
            if panelId == ""
                cur = figureAt(obj, figureId);
                scope = cur.id;
            else
                cur = panelAt(obj, figureId, panelId);
                scope = panelId;
            end
            n = 0;
            names = strings(1, 0);
            while n < numel(rest) && strcmp(rest(n+1).type, '.')
                n = n + 1;
                names(end+1) = string(rest(n).subs); %#ok<AGROW>
            end
            if n == 0
                error('PlotConsole:NoSetting', ['Set one setting at a time: node.Settings.<name> = value. ' ...
                    'The settings of %s: %s.'], scope, strjoin(setdiff(string(fieldnames(cur)).', notSettings, 'stable'), ", "));
            end
            if ismember(names(1), notSettings)
                error('PlotConsole:NoSetting', '"%s" is not set through Settings (the app keeps it).', names(1));
            end
            v = cur;
            for i = 1:n
                at = scope;
                if i > 1; at = strjoin(names(1:i-1), "."); end
                if ~isstruct(v)
                    error('PlotConsole:NoSetting', '%s holds no "%s": it is one value here, set whole (node.Settings.%s = value).', ...
                        at, names(i), at);
                elseif ~isscalar(v)
                    error('PlotConsole:NoSetting', '%s holds %d entries: name one, %s(1).%s.', at, numel(v), at, names(i));
                elseif ~isfield(v, names(i))
                    error('PlotConsole:NoSetting', '%s has no setting "%s". It has: %s.', at, names(i), ...
                        strjoin(string(fieldnames(v)).', ", "));
                end
                v = v.(names(i));
            end
            if n < numel(rest)
                value = subsasgn(v, rest(n+1:end), value);   % a piece of it: the whole value, with the piece changed
            end
            path = strjoin(names, ".");
            change(obj, PlotConsole.newOp("setting", figureId, Panel=panelId, Path=path, Value=value, ...
                Text=scope + "." + path + " = " + PlotPartNode.shortText(value)));
        end

        function change(obj, ops)
            %change  Make the changes OPS (newOp): at once when Immediate is on, else kept for apply.
            %   Either way they are tried first on the config as it is with
            %   the changes kept, so a change that cannot be made raises
            %   its error here and is not kept.
            app = openApp(obj);
            [cfg, made] = replay(obj, app.Config, obj.Queue, false);
            before = cfg;
            cfg = replay(obj, cfg, ops, true);
            checkSettings(before, cfg, ops);
            if obj.Immediate
                obj.Queue = obj.Queue([]);
                commit(obj, cfg, [made ops]);
            else
                obj.Queue = [made ops];
            end
        end
    end

    methods (Static, Access = ?PlotNode)
        function op = newOp(kind, figure, o)
            %newOp  One change: KIND "look" (a rule), "forget" (rules dropped) or "setting" (a config value at PATH).
            arguments
                kind (1,1) string
                figure (1,1) string
                o.Panel (1,1) string = ""
                o.Role (1,1) string = ""
                o.Group (1,1) string = ""
                o.Property (1,1) string = ""
                o.Path (1,1) string = ""
                o.Value = []
                o.Text (1,1) string = ""
            end
            op = struct('kind', kind, 'figure', figure, 'panel', o.Panel, 'role', o.Role, 'group', o.Group, ...
                'property', o.Property, 'path', o.Path, 'value', {o.Value}, 'text', o.Text);
        end
    end

    methods (Access = protected)
        function names = dotMethods(~)
            names = ["Figure" "apply" "discard"];
        end

        function names = dotProperties(~)
            names = ["Immediate" "Pending" "Figures"];
        end

        function names = dotSettable(~)
            names = "Immediate";
        end

        function [v, usedArgs] = dotOther(obj, name, args, called) %#ok<INUSD,STOUT>
            ids = obj.Figures;
            error('PlotConsole:NoSuchName', ['The console has no "%s". It has Figure("id") (the figures: %s), Figures, ' ...
                'Immediate, Pending, apply() and discard().'], name, listText(ids));
        end
    end

    methods (Access = private)
        function [cfg, made] = replay(obj, cfg, ops, strict, quiet)
            %replay  CFG with the changes OPS made on its figures; MADE are those made.
            %   STRICT: a change whose figure or panel is gone is an error
            %   (PlotConsole:Gone); else it is left out, with the warning
            %   PlotConsole:Skipped unless QUIET. The figures are given
            %   back to CFG once (which normalizes them, and raises
            %   EphysAnalysisConfig:BadValue for a value a setting does
            %   not take).
            if nargin < 5; quiet = false; end
            made = ops([]);
            if isempty(ops); return; end
            app = obj.App;
            F = cfg.Figures;
            skipped = strings(1, 0);
            for op = reshape(ops, 1, [])
                k = app.figureIndexOf(op.figure);
                j = 0;
                gone = "";
                if k < 1
                    gone = "figure """ + op.figure + """ is gone";
                elseif op.panel ~= ""
                    j = [];
                    if ~isempty(F(k).panels); j = find([F(k).panels.id] == op.panel, 1); end
                    if isempty(j); gone = "figure """ + F(k).id + """ has no panel """ + op.panel + """ any more"; end
                end
                if gone ~= ""
                    if strict; error('PlotConsole:Gone', '%s: %s.', op.text, gone); end
                    skipped(end+1) = op.text + " (" + gone + ")"; %#ok<AGROW>
                    continue
                end
                F(k) = changed(F(k), j, op);
                made(end+1) = op; %#ok<AGROW>
            end
            if ~isempty(made); cfg.Figures = F; end
            if ~isempty(skipped) && ~quiet
                warning('PlotConsole:Skipped', 'Left out, since what it changes is no longer there: %s.', strjoin(skipped, "; "));
            end
        end

        function commit(obj, cfg, ops)
            %commit  Give the app CFG, the config with the changes OPS made, as one step of its undo history.
            if isempty(ops); return; end
            label = "Command line: " + ops(1).text;
            if numel(ops) > 1; label = sprintf("Command line: %d changes", numel(ops)); end
            if strlength(label) > 70; label = extractBefore(label, 68) + "..."; end
            obj.App.changeFigures(cfg, label);
        end
    end
end


function fig = changed(fig, j, op)
%changed  Figure FIG (its panel J; 0: the figure itself) with the change OP made.
switch op.kind
    case "look"
        fig.aesthetics = PlotAesthetics.mergeRules(fig.aesthetics, ...
            PlotAesthetics.rule(op.role, op.property, op.value, Group=op.group, Panel=op.panel));
    case "forget"   % the rules of the scope named: "" names any
        R = fig.aesthetics;
        if ~isempty(R)
            hit = (op.panel == "" | [R.panel] == op.panel) & (op.role == "" | [R.role] == op.role) ...
                & (op.group == "" | [R.group] == op.group) & (op.property == "" | [R.property] == op.property);
            fig.aesthetics = R(~hit);
        end
    case "setting"
        parts = cellstr(split(op.path, "."));
        if j > 0
            p = fig.panels(j);
            p = setfield(p, parts{:}, op.value);
            fig.panels(j) = p;
        else
            fig = setfield(fig, parts{:}, op.value);
        end
end
end


function checkSettings(before, after, ops)
%checkSettings  Refuse settings the config's validate refuses: an error AFTER has that BEFORE had not (PlotConsole:Invalid); a new warning is passed on (PlotConsole:Check).
%   Looks need no check (a rule is checked when it is made), so the
%   configs are validated only when OPS hold a setting.
if isempty(ops) || ~any([ops.kind] == "setting"); return; end
A = after.validate();
if isempty(A); return; end
B = before.validate();
isNew = true(height(A), 1);
if ~isempty(B)
    isNew = ~ismember(strcat(string(A.Section), "|", string(A.Field), "|", string(A.Message)), ...
        strcat(string(B.Section), "|", string(B.Field), "|", string(B.Message)));
end
A = A(isNew, :);
bad = A(string(A.Severity) == "error", :);
if ~isempty(bad)
    error('PlotConsole:Invalid', 'Not changed: %s', strjoin(reshape(string(bad.Field) + ": " + string(bad.Message), 1, []), " "));
end
if ~isempty(A)
    warning('PlotConsole:Check', '%s', strjoin(reshape(string(A.Field) + ": " + string(A.Message), 1, []), " "));
end
end


function s = listText(ids)
%listText  Ids for a message: "a", "b", "c" (none: "none").
if isempty(ids)
    s = "none";
else
    s = strjoin("""" + reshape(string(ids), 1, []) + """", ", ");
end
end


function w = previewWord(look)
%previewWord  figureViewFresh's look of a figure's preview, in words.
switch look
    case "fresh",  w = "drawn";
    case "stale",  w = "out of date";
    case "failed", w = "failed";
    otherwise,     w = "not drawn";
end
end
