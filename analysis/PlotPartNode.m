classdef PlotPartNode < PlotNode
    %PlotPartNode  One part of an analysis app's figure, from the command line: its properties read and set.
    %   A part is what the aesthetics editor calls a component: everything
    %   a figure draws with one role -- the PSTH's line (rate), the fill
    %   of its bars (rateFill), its error
    %   band (sem), the raster's ticks (rasterTicks), a panel's axes, its
    %   x and y label (xlabel, ylabel) and title (tileTitle), the legend,
    %   the figure's title (plotTitle), ...: PlotAesthetics.roles() lists
    %   the roles. It is reached through a figure or a panel:
    %
    %     pn = app.Plots.Figure("unit_card").Panel("psth_1");
    %     pt = pn.rate;                 % the PSTH line of that panel (pn.Part("rate") is the same)
    %     pt = pn.rate("Go");           % ... of the trial group "Go" only
    %     pt = app.Plots.Figure("unit_card").xlabel;   % every panel's x label
    %
    %   Typed alone, pt lists its properties: what each takes, its value
    %   as the preview draws it and the value remembered.
    %
    %     pt.Color                      read one: as remembered, else as drawn
    %     pt.Color = "red";             set one: a color is a name, "#1f77b4" or [r g b]
    %     pt.LineStyle = "dashed";      a choice by its word or its symbol ("--")
    %     pt.Visible = false;           on / off as true / false or "on" / "off"
    %     pt.set(Color="red", LineWidth=2);   several, as one change
    %     pt.get("Color")               the same as pt.Color
    %     pt.Color = [];                forget one: drawn as the design has it again
    %     pt.forget()                   forget them all; pt.forget("Color", "LineWidth") those
    %     pt("Go")                      the part narrowed to one group
    %     pt.Properties                 the list as a table
    %     pt.Groups                     the groups of it the preview draws
    %     pt.Role, pt.Label, pt.Group, pt.Panel, pt.Figure   where it is
    %
    %   A property set is remembered with the figure as a look: a
    %   PlotAesthetics rule (role, group, property, value) in the figure's
    %   aesthetics, naming the panel when the part was reached through one,
    %   exactly as the aesthetics editor's "Remember for this figure"
    %   keeps it. So it is saved with the config, drawn by runs, reports
    %   and generated scripts, listed by the figure's Looks, and undone by
    %   Edit > Undo. A later, wider change wins over an earlier, narrower
    %   one (PlotAesthetics.mergeRules): the x label of every panel set
    %   after one panel's replaces that panel's.
    %
    %   A value is checked as it is typed (PlotAesthetics.typedValue,
    %   strict: PlotAesthetics:BadValue); a property the part's objects do
    %   not have, PlotConsole:NoProperty. A part the preview does not draw
    %   can be set all the same, with the warning PlotConsole:NotDrawn:
    %   the look shows once the figure draws that part.
    %
    %   See also PlotConsole, PlotFigureNode, PlotPanelNode, PlotAesthetics, PlotAestheticsDialog.

    properties (Dependent, SetAccess = private)
        Role        % the part's role (PlotAesthetics.roles)
        Label       % the role's name for people ("PSTH", "Error band")
        Group       % the group it is narrowed to ("" = every group)
        Panel       % the panel it is in ("" = every panel of the figure)
        Figure      % its figure's id, now
        Groups      % the groups of it the app's preview draws (a string row)
        Properties  % its properties: a table Property, Label, Takes, Drawn, Remembered
    end

    methods
        function obj = PlotPartNode(console, figureId, panelId, role, group)
            %PlotPartNode  The part ROLE (group GROUP; "" = every group) of figure FIGUREID, in its panel PANELID ("" = every panel).
            arguments
                console (1,1) PlotConsole
                figureId (1,1) string
                panelId (1,1) string
                role (1,1) string
                group (1,1) string = ""
            end
            role = roleNamed(console, figureId, panelId, role);
            obj@PlotNode(console, figureId, panelId, role, group);
        end

        function r = get.Role(obj);  r = obj.RoleName; end
        function s = get.Label(obj); s = PlotAesthetics.roleLabel(obj.RoleName); end
        function g = get.Group(obj); g = obj.GroupName; end
        function p = get.Panel(obj); p = obj.PanelId; end

        function id = get.Figure(obj)
            [~, ~, id] = figureAt(obj.Console, obj.FigureId);
        end

        function g = get.Groups(obj)
            T = drawnParts(obj.Console, obj.FigureId, obj.PanelId);
            g = strings(1, 0);
            if isempty(T); return; end
            g = reshape(unique(T.Group(T.Role == obj.RoleName & T.Group ~= ""), 'stable'), 1, []);
        end

        function T = get.Properties(obj)
            [P, H] = propertiesOf(obj);
            R = rulesOf(obj);
            n = numel(P);
            Property = strings(n, 1); Label = strings(n, 1); Takes = strings(n, 1);
            Drawn = strings(n, 1); Remembered = strings(n, 1);
            for i = 1:n
                Property(i) = P(i).Name;
                Label(i) = P(i).Label;
                Takes(i) = takesText(P(i));
                [vals, same] = drawnValues(H, P(i).Name);
                if ~isempty(vals)
                    Drawn(i) = "(differs)";
                    if same; Drawn(i) = PlotPartNode.shortText(vals{1}, true, true); end
                end
                [has, v] = remembered(obj, R, P(i).Name);
                if has; Remembered(i) = PlotPartNode.shortText(v, true, true); end
            end
            T = table(Property, Label, Takes, Drawn, Remembered);
        end

        function v = get(obj, name)
            %get  The value of property NAME: as remembered for this part, else as the app's preview draws it.
            %   The value remembered is the one the looks give the whole
            %   part (the last rule that reaches it, when that rule covers
            %   it: the changes kept while Immediate is off count). Without
            %   one, the value drawn: one value when every object of the
            %   part has it, else a table Panel, Group, Value of those
            %   drawn. missing when nothing is remembered and the figure
            %   has no drawing kept.
            arguments
                obj (1,1) PlotPartNode
                name (1,1) string
            end
            [P, H] = propertiesOf(obj);
            name = propertyNamed(obj, P, name);
            [has, v] = remembered(obj, rulesOf(obj), name);
            if has; return; end
            [vals, same, T] = drawnValues(H, name);
            if isempty(vals)
                v = missing;
            elseif same
                v = vals{1};
            else
                v = T;
            end
        end

        function obj = set(obj, varargin)
            %set  Set properties of the part: set("Color", "red", "LineWidth", 2) or set(Color="red", LineWidth=2), as one change.
            %   A value [] (or missing) forgets what is remembered for
            %   that property. The change is made at once, or kept while
            %   the console's Immediate is off (PlotConsole.apply).
            if isempty(varargin) || mod(numel(varargin), 2) ~= 0
                error('PlotConsole:NoProperty', 'set takes names and values in pairs: set("Color", "red") or set(Color="red").');
            end
            [P, H] = propertiesOf(obj);
            ops = [];
            for i = 1:2:numel(varargin)
                nm = varargin{i};
                if ~(ischar(nm) || (isstring(nm) && isscalar(nm)))
                    error('PlotConsole:NoProperty', 'set takes names and values in pairs: set("Color", "red") or set(Color="red").');
                end
                ops = [ops lookOp(obj, P, string(nm), varargin{i+1})]; %#ok<AGROW>
            end
            warnNotDrawn(obj, H);
            change(obj.Console, ops);
        end

        function obj = forget(obj, varargin)
            %forget  Forget what is remembered for the part: forget() every property, forget("Color", "LineWidth") those.
            %   Only the looks of this part as it was reached: a part of
            %   one panel, that panel's; of one group, that group's. A part
            %   of the whole figure forgets its panels' too.
            names = string.empty(1, 0);
            if ~isempty(varargin)
                P = propertiesOf(obj);
                for i = 1:numel(varargin)
                    names(end+1) = propertyNamed(obj, P, string(varargin{i})); %#ok<AGROW>
                end
            end
            if isempty(names); names = ""; end
            ops = [];
            for nm = names
                ops = [ops forgetOp(obj, nm)]; %#ok<AGROW>
            end
            change(obj.Console, ops);
        end

        function disp(obj)
            %disp  Where the part is, its groups and its properties, and what can be typed next.
            if ~isscalar(obj)
                fprintf('  %s array of PlotPartNode\n\n', strjoin(string(size(obj)), 'x'));
                return
            end
            try
                T = obj.Properties;
                fig = obj.Figure;
                [~, look] = drawnParts(obj.Console, obj.FigureId, obj.PanelId);
            catch ME
                fprintf('  Part %s of figure "%s": %s\n\n', obj.RoleName, obj.FigureId, ME.message);
                return
            end
            fprintf('  %s\n\n', whereText(obj, fig));
            g = obj.Groups;
            if ~isempty(g) && obj.GroupName == ""
                fprintf('    Groups drawn: %s\n', strjoin("""" + g + """", ", "));
                fprintf('      (pt("%s") is that group alone)\n\n', g(1));
            end
            switch look
                case "none",   fprintf('    The preview holds no drawing of the figure: Drawn is blank, and every property is listed.\n\n');
                case "failed", fprintf('    The figure''s preview failed: Drawn is blank, and every property is listed.\n\n');
                case "stale",  fprintf('    The preview is out of date: Drawn is as it was last drawn.\n\n');
            end
            disp(T);
            fprintf('  pt.Color = "red" sets one, pt.set(Color="red", LineWidth=2) several;\n');
            fprintf('  pt.Color = [] forgets one, pt.forget() all.\n\n');
        end
    end

    methods (Static, Access = ?PlotNode)
        function [p, usedArgs] = byRole(console, figureId, panelId, name, args, called)
            %byRole  node.<name> on a figure or panel: the part of that role; node.<name>("group") one group of it.
            group = "";
            usedArgs = false;
            if called
                usedArgs = true;
                if isscalar(args) && (ischar(args{1}) || (isstring(args{1}) && isscalar(args{1})))
                    group = string(args{1});
                elseif ~isempty(args)
                    error('PlotConsole:NoPart', 'A part takes one group''s name in text: .%s("group").', name);
                end
            end
            p = PlotPartNode(console, figureId, panelId, name, group);
        end

        function P = partsTable(T)
            %partsTable  drawnParts' rows as a node's Parts shows them: Panel, Part, Group, Type, Label.
            names = ["Panel" "Part" "Group" "Type" "Label"];
            if isempty(T)
                e = strings(0, 1);
                P = table(e, e, e, e, e, 'VariableNames', names);
            else
                P = table(T.Panel, T.Role, T.Group, T.Type, T.Label, 'VariableNames', names);
            end
        end

        function L = looksTable(R)
            %looksTable  Rules as a node's Looks shows them: Panel, Part, Group, Property, Value.
            n = numel(R);
            Panel = strings(n, 1); Part = strings(n, 1); Group = strings(n, 1); Property = strings(n, 1); Value = strings(n, 1);
            for i = 1:n
                Panel(i) = R(i).panel;
                Part(i) = R(i).role;
                Group(i) = R(i).group;
                Property(i) = R(i).property;
                Value(i) = PlotAesthetics.valueText(R(i).value);
            end
            L = table(Panel, Part, Group, Property, Value);
        end

        function printParts(T, look, what, var)
            %printParts  A node's disp: the roles drawn in it (T: drawnParts' rows), or why none is listed.
            if isempty(T)
                switch look
                    case "failed", why = "The figure's preview failed";
                    otherwise,     why = "The preview holds no drawing of the figure";
                end
                if look ~= "none" && look ~= "failed"; why = "The preview draws no part in " + what; end
                fprintf('    %s: no part is listed (show() draws the figure).\n', why);
                fprintf('      A part can be named all the same: %s.rate, %s.xlabel (PlotAesthetics.roles() lists the roles).\n', var, var);
                return
            end
            roles = reshape(unique(T.Role, 'stable'), 1, []);
            stale = "";
            if look == "stale"; stale = " (the preview is out of date: as last drawn)"; end
            fprintf('    Parts drawn%s, %s.<part> or Part("<part>"):\n', stale, var);
            line = "     ";
            for r = roles
                if strlength(line) + strlength(r) > 92
                    fprintf('%s\n', line);
                    line = "     ";
                end
                line = line + " " + r;
            end
            fprintf('%s\n', line);
            fprintf('      (Parts lists them with their groups)\n');
        end

        function s = shortText(v, plain, look)
            %shortText  A value in a few characters, for a table or a message: text quoted, numbers as typed, a struct by its size.
            %   PLAIN (default false): text plain, not quoted (a table's
            %   cell). LOOK (default false): a look's value, three numbers
            %   0-1 as a color, #rrggbb (PlotAesthetics.valueText).
            if nargin < 2; plain = false; end
            if nargin < 3; look = false; end
            if ischar(v); v = string(v); end
            if isstring(v) && isscalar(v)
                if ismissing(v)
                    s = "<missing>";
                elseif plain
                    s = v;
                else
                    s = """" + v + """";
                end
            elseif isstring(v)
                s = "[" + strjoin("""" + reshape(v, 1, []) + """", " ") + "]";
            elseif (isnumeric(v) || islogical(v)) && numel(v) <= 6
                if isempty(v)
                    s = "[]";
                elseif islogical(v)
                    s = string(mat2str(v));
                elseif look
                    s = PlotAesthetics.valueText(double(v));
                else
                    s = string(mat2str(double(v), 5));
                end
            elseif isnumeric(v) || islogical(v)
                s = sprintf("<%s %s>", strjoin(string(size(v)), "x"), class(v));
            elseif isstruct(v)
                s = sprintf("<%s struct>", strjoin(string(size(v)), "x"));
            else
                s = "<" + string(class(v)) + ">";
            end
            if strlength(s) > 40; s = extractBefore(s, 38) + "..."; end
        end
    end

    methods (Access = protected)
        function names = dotMethods(~)
            names = ["set" "get" "forget"];
        end

        function names = dotProperties(~)
            names = ["Role" "Label" "Group" "Panel" "Figure" "Groups" "Properties"];
        end

        function [v, usedArgs] = dotOther(obj, name, ~, ~)
            %dotOther  pt.<Property>: its value (get).
            usedArgs = false;
            v = get(obj, name);
        end

        function v = parenGet(obj, args)
            %parenGet  pt("group"): the part narrowed to that group.
            if ~(isscalar(args) && (ischar(args{1}) || (isstring(args{1}) && isscalar(args{1}))))
                error('PlotConsole:NoPart', 'A part takes one group''s name in text: pt("group") (pt.Groups lists those drawn).');
            end
            v = PlotPartNode(obj.Console, obj.FigureId, obj.PanelId, obj.RoleName, string(args{1}));
        end

        function done = assign(obj, name, rest, value)
            %assign  pt.<Property> = VALUE: set it (set); the node's own names as any node.
            if ismember(name, [dotProperties(obj) dotMethods(obj)]) || isprop(obj, name)
                done = assign@PlotNode(obj, name, rest, value);
                return
            end
            if ~isempty(rest)
                error('PlotConsole:ReadOnly', 'Assign the whole value of %s: pt.%s = value (a color: [r g b], a name or "#rrggbb").', name, name);
            end
            set(obj, name, value);
            done = true;
        end

        function s = nodeWord(obj)
            s = "the part " + obj.RoleName;
        end
    end

    methods (Access = private)
        function [P, H] = propertiesOf(obj)
            %propertiesOf  The properties the part takes (PlotAesthetics.editableProperties' entries) and its objects drawn, H.
            %   Those of the objects the app's preview draws for it (each
            %   kind of object once); every property the editor knows
            %   (PlotAesthetics.catalog) while none is drawn.
            if obj.PanelId == ""
                figureAt(obj.Console, obj.FigureId);   % (PlotConsole:Gone when the figure is)
            else
                panelAt(obj.Console, obj.FigureId, obj.PanelId);
            end
            H = handlesOf(obj);
            if isempty(H.h)
                C = struct2cell(PlotAesthetics.catalog());
                P = [C{:}];
                return
            end
            P = [];
            seen = strings(1, 0);
            types = arrayfun(@PlotAesthetics.typeName, H.h);
            [~, first] = unique(types, 'stable');
            for i = reshape(first, 1, [])
                E = PlotAesthetics.editableProperties(H.h(i));
                if isempty(E); continue; end
                E = E(~ismember([E.Name], seen));
                if isempty(E); continue; end
                P = [P E]; %#ok<AGROW>
                seen = [seen E.Name]; %#ok<AGROW>
            end
            if isempty(P)
                C = struct2cell(PlotAesthetics.catalog());
                P = [C{:}];
            end
        end

        function H = handlesOf(obj)
            %handlesOf  The part's objects in the app's preview: H.h (a row), each one's H.panel and H.group; H.drawing says whether the figure has a drawing at all.
            T = drawnParts(obj.Console, obj.FigureId, obj.PanelId);
            H = struct('h', gobjects(1, 0), 'panel', strings(1, 0), 'group', strings(1, 0), 'drawing', ~isempty(T));
            if isempty(T); return; end
            rows = find(T.Role == obj.RoleName & (obj.GroupName == "" | T.Group == obj.GroupName)).';
            for r = rows
                h = reshape(T.Handles{r}, 1, []);
                h = h(isgraphics(h));
                H.h = [H.h h];
                H.panel = [H.panel repmat(T.Panel(r), 1, numel(h))];
                H.group = [H.group repmat(T.Group(r), 1, numel(h))];
            end
        end

        function R = rulesOf(obj)
            %rulesOf  The figure's looks with the changes kept, those of this part's role.
            fig = figureAt(obj.Console, obj.FigureId);
            R = fig.aesthetics;
            if ~isempty(R); R = R([R.role] == obj.RoleName); end
        end

        function [has, v] = remembered(obj, R, name)
            %remembered  The value the looks R (rulesOf) give the whole part for property NAME: the last rule that reaches it, when that rule covers it.
            %   A rule reaches the part when their panels and their groups
            %   can meet ("" meets any), and covers it when the rule's
            %   panel and group are the part's or "" (every one). A last
            %   rule that reaches only some of the part (one panel of a
            %   figure's part, one group) gives it no one value: HAS false.
            has = false;
            v = [];
            if isempty(R); return; end
            p = obj.PanelId;
            g = obj.GroupName;
            reach = [R.property] == name & (p == "" | [R.panel] == "" | [R.panel] == p) & (g == "" | [R.group] == "" | [R.group] == g);
            k = find(reach, 1, 'last');
            if isempty(k); return; end
            if (R(k).panel == "" || R(k).panel == p) && (R(k).group == "" || R(k).group == g)
                has = true;
                v = R(k).value;
            end
        end

        function name = propertyNamed(obj, P, name)
            %propertyNamed  NAME as one of the part's properties P is spelled (whatever the case); PlotConsole:NoProperty when it has none.
            names = [P.Name];
            k = find(names == name, 1);
            if isempty(k); k = find(strcmpi(names, name), 1); end
            if isempty(k)
                error('PlotConsole:NoProperty', '%s has no property "%s". It has: %s.', whatText(obj), name, strjoin(names, ", "));
            end
            name = names(k);
        end

        function op = lookOp(obj, P, name, value)
            %lookOp  The change that sets property NAME of the part to VALUE (checked: PlotAesthetics.typedValue), or forgets it (VALUE [] or missing).
            name = propertyNamed(obj, P, name);
            if (isnumeric(value) && isempty(value)) || (isscalar(value) && (isa(value, 'missing') || (isstring(value) && ismissing(value))))
                op = forgetOp(obj, name);
                return
            end
            v = PlotAesthetics.typedValue(P([P.Name] == name), value, Strict=true);
            op = PlotConsole.newOp("look", obj.FigureId, Panel=obj.PanelId, Role=obj.RoleName, Group=obj.GroupName, ...
                Property=name, Value=v, Text=pathText(obj) + "." + name + " = " + PlotPartNode.shortText(v, false, true));
        end

        function op = forgetOp(obj, name)
            %forgetOp  The change that forgets what is remembered for property NAME of the part ("": every property).
            what = pathText(obj);
            if name ~= ""; what = what + "." + name; end
            op = PlotConsole.newOp("forget", obj.FigureId, Panel=obj.PanelId, Role=obj.RoleName, Group=obj.GroupName, ...
                Property=name, Text="forget " + what);
        end

        function warnNotDrawn(obj, H)
            %warnNotDrawn  Say so when the figure has a drawing and it shows no object of this part (PlotConsole:NotDrawn): the look is kept all the same.
            if ~H.drawing || ~isempty(H.h); return; end
            warning('PlotConsole:NotDrawn', ['The preview drawn shows no %s: the look is remembered, and shows when the figure draws it. ' ...
                'Parts lists what is drawn.'], whatText(obj));
        end

        function s = pathText(obj)
            %pathText  The part as it is typed, for a change's line: psth_1.rate("Go").
            s = obj.PanelId;
            if s == ""; s = obj.FigureId; end
            s = s + "." + obj.RoleName;
            if obj.GroupName ~= ""; s = s + "(""" + obj.GroupName + """)"; end
        end

        function s = whatText(obj)
            %whatText  The part in words, for a message: the PSTH (rate) of panel "psth_1", group "Go".
            s = PlotAesthetics.roleLabel(obj.RoleName) + " (" + obj.RoleName + ")";
            if obj.PanelId ~= ""; s = s + " of panel """ + obj.PanelId + """"; end
            if obj.GroupName ~= ""; s = s + ", group """ + obj.GroupName + """"; end
        end

        function s = whereText(obj, fig)
            %whereText  disp's first line: the part, its panel (or every panel), its figure, its group (or every group).
            s = PlotAesthetics.roleLabel(obj.RoleName) + " (" + obj.RoleName + ")";
            if obj.PanelId ~= ""
                s = s + " of panel """ + obj.PanelId + """ in figure """ + fig + """";
            else
                s = s + " of figure """ + fig + """, in every panel";
            end
            if obj.GroupName ~= ""
                s = s + ", group """ + obj.GroupName + """";
            else
                s = s + ", every group";
            end
        end
    end
end


function role = roleNamed(console, figureId, panelId, name)
%roleNamed  NAME as a role is spelled (whatever the case): one the app's preview draws there, or one of PlotAesthetics.roles; PlotConsole:NoPart when it is neither.
if panelId == ""
    fig = figureAt(console, figureId);
    where = "Figure """ + fig.id + """";
else
    panelAt(console, figureId, panelId);
    where = "Panel """ + panelId + """";
end
T = drawnParts(console, figureId, panelId);
drawn = strings(1, 0);
if ~isempty(T); drawn = reshape(unique(T.Role, 'stable'), 1, []); end
known = [drawn reshape(PlotAesthetics.roles().Role, 1, [])];
k = find(known == name, 1);
if isempty(k); k = find(strcmpi(known, name), 1); end
if isempty(k)
    if isempty(drawn)
        error('PlotConsole:NoPart', '%s has nothing named "%s", and no part has that role (PlotAesthetics.roles() lists the roles: rate, sem, axes, xlabel, ...).', ...
            where, name);
    end
    error('PlotConsole:NoPart', '%s has nothing named "%s", and no part has that role. The parts drawn there: %s (PlotAesthetics.roles() lists every role).', ...
        where, name, strjoin(drawn, ", "));
end
role = known(k);
end


function [vals, same, T] = drawnValues(H, name)
%drawnValues  The values of property NAME of the objects H (handlesOf) that have it: VALS (a cell), whether they are all the SAME, and a table Panel, Group, Value of them.
vals = {};
same = true;
T = table();
if isempty(H.h); return; end
has = arrayfun(@(h) PlotAesthetics.hasProperty(h, name), H.h);
if ~any(has); return; end
h = H.h(has);
vals = arrayfun(@(x) PlotAesthetics.getValue(x, name), h, 'UniformOutput', false);
same = all(cellfun(@(v) isequaln(v, vals{1}), vals));
if nargout > 2 && ~same
    Panel = reshape(H.panel(has), [], 1);
    Group = reshape(H.group(has), [], 1);
    Value = reshape(vals, [], 1);
    [~, first] = unique(Panel + "|" + Group, 'stable');   % one row per panel and group: its first object's value
    T = table(Panel(first), Group(first), Value(first), 'VariableNames', ["Panel" "Group" "Value"]);
end
end


function s = takesText(P)
%takesText  What a property takes, for the Properties table.
switch P.Type
    case "color",    s = "a color: a name, #rrggbb, [r g b]";
    case "number",   s = sprintf("a number, %g to %g", P.Limits(1), P.Limits(2));
    case "vector",   s = "two numbers";
    case "choice",   s = strjoin(P.Choices, " | ");
    case "onoff",    s = "on | off";
    case "font",     s = "a font's name";
    case "colormap", s = "a colormap's name";
    otherwise,       s = P.Type;
end
if strlength(s) > 44; s = extractBefore(s, 42) + "..."; end
end
