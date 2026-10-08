classdef PlotAesthetics
    %PlotAesthetics  Colours, lines, markers and fonts of a drawn plot's components.
    %   The analysis renderers name what they draw (tagPart): an object's Tag
    %   is its role ("rate", "sem", "rasterTicks", ...: roles lists them)
    %   and the group, series or channel it draws is its "PlotGroup"
    %   appdata. Titles, axis labels, legends and colour bars are found
    %   through their axes. A rule -- role, group, property, value -- sets
    %   that property on every component of the role, in every tile; group
    %   "" means every group. renderPlot applies the user's rules for the
    %   plot's kind (preferences) and then the plot's own (its aesthetics
    %   field, saved in the config), and in a visible figure lets a
    %   right-click on any component open PlotAestheticsDialog.
    %
    %   Rules
    %     R = PlotAesthetics.emptyRules()          1x0 struct: role, group, property, value
    %     R = PlotAesthetics.normalizeRules(V)      from a struct array, a cell (jsondecode) or []
    %     R = PlotAesthetics.mergeRules(R, NEW)     NEW added; the rules they cover dropped
    %     n = PlotAesthetics.apply(TARGET, R)       set on what is drawn in TARGET (n: values set)
    %     R = PlotAesthetics.userRules(KIND)        the user's rules for a plot kind
    %     PlotAesthetics.setUserRules(KIND, R)      ([] forgets them)
    %   The user's rules are preferences (AppPrefs group "PlotAesthetics",
    %   one per kind), so they follow the user, not the config.
    %
    %   Components
    %     T = PlotAesthetics.components(TARGET)     one row per component (see components)
    %     P = PlotAesthetics.editableProperties(H)  what the editor offers for object H
    %     v = PlotAesthetics.getValue(H, NAME)      PlotAesthetics.setValue(H, NAME, V)
    %   Editing
    %     PlotAesthetics.enableEditing(TARGET, CONTEXT)   right-click menu (renderPlot)
    %     d = PlotAesthetics.edit(H)                      the editor on component H
    %
    %   See also PlotAestheticsDialog, renderPlot, tagPart, AppPrefs.

    properties (Constant)
        PrefGroup = "PlotAesthetics"            % AppPrefs group: one rule set per plot kind
        ContextKey = "PlotAestheticsContext"    % appdata of renderPlot's target
        MenuTag = "PlotAestheticsMenu"
    end

    methods (Static)
        %% --- rules ------------------------------------------------------------
        function R = emptyRules()
            %emptyRules  No rules: a 1x0 struct with fields role, group, property, value.
            R = repmat(struct('role', "", 'group', "", 'property', "", 'value', []), 1, 0);
        end

        function R = normalizeRules(v, path)
            %normalizeRules  Rules from a struct array, a cell of structs (jsondecode) or [].
            %   Each rule needs a role and a property the editor knows
            %   (editableProperties); group defaults to "" (every group). A
            %   value is a number, a colour [r g b] (a column from JSON becomes
            %   a row), or text ("none", "--", "bold", "on"). Raises
            %   PlotAesthetics:BadRule naming PATH (default "aesthetics").
            arguments
                v = []
                path (1,1) string = "aesthetics"
            end
            R = PlotAesthetics.emptyRules();
            if isempty(v); return; end
            if isstruct(v)
                v = num2cell(v);
            elseif ~iscell(v)
                error('PlotAesthetics:BadRule', '%s must be a list of rules (role, group, property, value).', path);
            end
            known = string(fieldnames(PlotAesthetics.catalogue())).';
            for k = 1:numel(v)
                r = v{k};
                where = sprintf('%s(%d)', path, k);
                if ~isstruct(r) || ~isscalar(r) || ~all(isfield(r, {'role', 'property', 'value'}))
                    error('PlotAesthetics:BadRule', '%s must have a role, a property and a value.', where);
                end
                role = textOf(r.role);
                prop = textOf(r.property);
                group = "";
                if isfield(r, 'group'); group = textOf(r.group); end
                if ismissing(role) || role == "" || ismissing(prop) || ismissing(group)
                    error('PlotAesthetics:BadRule', '%s: role, group and property must be text.', where);
                end
                if ~ismember(prop, known)
                    error('PlotAesthetics:BadRule', '%s: unknown property "%s" (one of %s).', where, prop, strjoin(known, ", "));
                end
                R(1, end+1) = struct('role', role, 'group', group, 'property', prop, ...
                    'value', PlotAesthetics.normalizeValue(r.value, where)); %#ok<AGROW>
            end
        end

        function R = mergeRules(R, new)
            %mergeRules  Add NEW to R, each replacing the rules it covers.
            %   A new rule replaces the rules of its role and property for its
            %   group; one for every group (group "") replaces that role and
            %   property's rules for any group. Later rules win when applied,
            %   so the order is kept.
            R = PlotAesthetics.normalizeRules(R);
            new = PlotAesthetics.normalizeRules(new);
            for n = new
                if isempty(R)
                    drop = false(1, 0);
                else
                    drop = [R.role] == n.role & [R.property] == n.property & (n.group == "" | [R.group] == n.group);
                end
                R = [R(~drop) n];
            end
        end

        function n = apply(target, rules)
            %apply  Set RULES on the components drawn in TARGET; n = values set.
            %   Rules go in order (later ones win). A rule whose property a
            %   component lacks is skipped there; a value its object refuses
            %   raises the warning PlotAesthetics:BadValue (once per rule).
            n = 0;
            rules = PlotAesthetics.normalizeRules(rules);
            if isempty(rules); return; end
            T = PlotAesthetics.components(target);
            for r = rules
                hit = find(T.Role == r.role & (r.group == "" | T.Group == r.group));
                failed = "";
                for i = hit(:).'
                    for h = reshape(T.Handles{i}, 1, [])
                        if ~PlotAesthetics.hasProperty(h, r.property); continue; end
                        try
                            PlotAesthetics.setValue(h, r.property, r.value);
                            n = n + 1;
                        catch ME
                            failed = string(ME.message);
                        end
                    end
                end
                if failed ~= ""
                    warning('PlotAesthetics:BadValue', 'Cannot set %s of %s to %s: %s', r.property, ...
                        PlotAesthetics.roleLabel(r.role), PlotAesthetics.valueText(r.value), failed);
                end
            end
        end

        function R = userRules(kind)
            %userRules  The user's remembered rules for plots of KIND (preferences).
            %   An unreadable preference gives no rules and the warning
            %   PlotAesthetics:BadPreference.
            arguments
                kind (1,1) string
            end
            R = PlotAesthetics.emptyRules();
            if ~isvarname(kind) || ~AppPrefs.ispref(PlotAesthetics.PrefGroup, kind); return; end
            try
                R = PlotAesthetics.normalizeRules(AppPrefs.getpref(PlotAesthetics.PrefGroup, kind), kind);
            catch ME
                warning('PlotAesthetics:BadPreference', 'Your remembered %s aesthetics are not readable: %s', kind, ME.message);
            end
        end

        function setUserRules(kind, R)
            %setUserRules  Remember R for every plot of KIND (empty: forget them).
            arguments
                kind (1,1) string {mustBeValidVariableName}
                R = []
            end
            R = PlotAesthetics.normalizeRules(R, kind);
            if isempty(R)
                if AppPrefs.ispref(PlotAesthetics.PrefGroup, kind)
                    AppPrefs.rmpref(PlotAesthetics.PrefGroup, kind);
                end
            else
                AppPrefs.setpref(PlotAesthetics.PrefGroup, kind, R);
            end
        end

        %% --- components ----------------------------------------------------------
        function T = components(target)
            %components  What is drawn in TARGET, one row per component.
            %   TARGET is what renderPlot drew into (or its layout or axes).
            %   Columns: Handles (cell: the objects, e.g. every patch of one
            %   SEM band), Role, Group, Tile (axes number in tile order; 0 =
            %   the whole plot), TileName (the unit, channel or group it
            %   shows), Type (Line, Patch, Text, ...), Label (role and group,
            %   for people) and Key (tile, role and group: the same component
            %   after a redraw). The plot's own rows come first, then each
            %   tile's, the tiles that share a name (a unit's raster and rate
            %   panels) together. Untagged objects are listed on their own with
            %   role "". Titles, axis labels, legends and colour bars count
            %   when they show something.
            C = struct('h', {}, 'role', {}, 'group', {}, 'tile', {}, 'name', {});
            for tl = PlotAesthetics.layoutsIn(target)
                C = addText(C, tl.Title, "plotTitle", 0, "Plot");
                C = addText(C, tl.Subtitle, "plotSubtitle", 0, "Plot");
            end
            for host = reshape(flipud(findall(target, 'Type', 'axes', 'Tag', 'legendHost')), 1, [])
                if ~isempty(host.Legend) && isvalid(host.Legend)   % a legend outside the grid belongs to the plot
                    C(end+1) = struct('h', host.Legend, 'role', "legend", 'group', "", 'tile', 0, 'name', "Plot"); %#ok<AGROW>
                end
            end
            axs = PlotAesthetics.axesIn(target);
            for t = 1:numel(axs)
                ax = axs(t);
                name = string(getappdata(ax, 'PlotTile'));
                if isempty(name) || name == ""; name = strjoin(string(ax.Title.String), " "); end
                if name == ""; name = "Tile " + t; end
                role = string(ax.Tag);
                if ~ismember(role, ["axes" "rasterAxes"]); role = "axes"; end
                C(end+1) = struct('h', ax, 'role', role, 'group', "", 'tile', t, 'name', name); %#ok<AGROW>
                C = addText(C, ax.Title, "tileTitle", t, name);
                C = addText(C, ax.Subtitle, "tileSubtitle", t, name);
                C = addText(C, ax.XLabel, "xlabel", t, name);
                if numel(ax.YAxis) > 1
                    C = addText(C, ax.YAxis(1).Label, "ylabel", t, name);
                    C = addText(C, ax.YAxis(2).Label, "ylabelRight", t, name);
                else
                    C = addText(C, ax.YLabel, "ylabel", t, name);
                end
                if ~isempty(ax.Legend) && isvalid(ax.Legend)
                    C(end+1) = struct('h', ax.Legend, 'role', "legend", 'group', "", 'tile', t, 'name', name); %#ok<AGROW>
                end
                if ~isempty(ax.Colorbar) && isvalid(ax.Colorbar)
                    C(end+1) = struct('h', ax.Colorbar, 'role', "colorbar", 'group', "", 'tile', t, 'name', name); %#ok<AGROW>
                end
                kids = flipud(allchild(ax));
                for c = reshape(kids, 1, [])
                    g = string(getappdata(c, 'PlotGroup'));
                    if isempty(g); g = ""; end
                    C(end+1) = struct('h', c, 'role', string(c.Tag), 'group', g, 'tile', t, 'name', name); %#ok<AGROW>
                end
            end
            % One row per tile, role and group (untagged objects each alone).
            n = numel(C);
            key = strings(n, 1);
            for i = 1:n
                if C(i).role == ""
                    key(i) = C(i).tile + "|#" + i;
                else
                    key(i) = C(i).tile + "|" + C(i).role + "|" + C(i).group;
                end
            end
            [Key, first, which] = unique(key, 'stable');
            m = numel(Key);
            Handles = cell(m, 1);
            for j = 1:m
                Handles{j} = [C(which == j).h];
            end
            Role = reshape([C(first).role], [], 1);
            Group = reshape([C(first).group], [], 1);
            Tile = reshape([C(first).tile], [], 1);
            TileName = reshape([C(first).name], [], 1);
            if m == 0
                Role = strings(0, 1); Group = strings(0, 1); Tile = zeros(0, 1); TileName = strings(0, 1);
            end
            Type = strings(m, 1);
            Label = strings(m, 1);
            for j = 1:m
                Type(j) = PlotAesthetics.typeName(Handles{j}(1));
                if Role(j) == ""
                    Label(j) = Type(j) + " (untagged)";
                else
                    Label(j) = PlotAesthetics.roleLabel(Role(j));
                end
                if Group(j) ~= ""; Label(j) = Label(j) + " · " + Group(j); end
            end
            T = table(Handles, Role, Group, Tile, TileName, Type, Label, Key);
            % A tile's axes together (a PSTH's raster and rate panels share their unit's name).
            [~, ~, byName] = unique(TileName, 'stable');
            byName(Tile == 0) = 0;
            [~, o] = sortrows([byName Tile (1:m).']);
            T = T(o, :);
        end

        function T = roles()
            %roles  Every role the renderers give, with its name for people.
            x = [ ...
                "plotTitle"    "Plot title"
                "plotSubtitle" "Plot subtitle"
                "axes"         "Axes"
                "rasterAxes"   "Raster axes"
                "tileTitle"    "Tile title"
                "tileSubtitle" "Tile subtitle"
                "xlabel"       "X label"
                "ylabel"       "Y label"
                "ylabelRight"  "Right y label"
                "legend"       "Legend"
                "colorbar"     "Colour bar"
                "rate"         "PSTH"
                "rateFill"     "PSTH fill"
                "sem"          "SEM band"
                "stopLine"     "Stop event (mean)"
                "stackBase"    "Row baseline"
                "zeroLine"     "Event line (t = 0)"
                "chanceLine"   "auROC 0.5 line"
                "modWindow"    "auROC modulation window"
                "modMarks"     "auROC modulation calls"
                "rasterTicks"  "Raster ticks"
                "rasterBand"   "Raster group band"
                "rasterStop"   "Raster stop dots"
                "rasterEvent"  "Raster event marks"
                "trace"        "Mean trace"
                "channelTrace" "Channel trace"
                "bar"          "Bar"
                "errorBar"     "Error bar"
                "box"          "Box"
                "points"       "Epoch points"
                "meanBar"      "Mean bar"
                "curve"        "Tuning curve"
                "behaviorMean" "Mean +/- SEM"
                "swarm"        "Swarm points"
                "violin"       "Violin"
                "image"        "Image"
                "sites"        "Sites"
                "emptySites"   "Sites without a value"
                "siteLabels"   "Site labels"
                "shankLabels"  "Shank labels"
                "unitDots"     "Unit positions"
                "waveBox"      "Waveform box"
                "waveSpikes"   "Waveform spikes"
                "waveMean"     "Waveform mean"
                "waveLabel"    "Waveform amplitude"];
            T = table(x(:, 1), x(:, 2), 'VariableNames', ["Role" "Label"]);
        end

        function s = roleLabel(role)
            %roleLabel  A role's name for people (the role itself when unknown).
            T = PlotAesthetics.roles();
            s = string(role);
            k = find(T.Role == s, 1);
            if ~isempty(k); s = T.Label(k); end
        end

        %% --- properties ------------------------------------------------------------
        function P = editableProperties(h)
            %editableProperties  The properties the editor offers for object H, in order.
            %   P: a struct array (Name, Label, Type, Limits, Step, Choices,
            %   ChoiceLabels, Hint). Type is "color" (an RGB triplet, or a
            %   word such as none / flat where the object takes one),
            %   "number", "choice", "onoff", "font" or "colormap" (axes holding
            %   an image or coloured markers: a colormap name).
            C = PlotAesthetics.catalogue();
            L = PlotAesthetics.classLists();
            type = PlotAesthetics.typeName(h);
            if isfield(L, type)
                names = L.(type);
            else
                names = string(fieldnames(C)).';
            end
            names = names(arrayfun(@(n) PlotAesthetics.hasProperty(h, n), names));
            P = repmat(C.Visible, 1, 0);
            O = PlotAesthetics.classLabels();
            for n = names
                p = C.(n);
                if isfield(O, type) && isfield(O.(type), n); p.Label = O.(type).(n); end
                P(end+1) = p; %#ok<AGROW>
            end
        end

        function tf = hasProperty(h, name)
            %hasProperty  True when H has the property NAME (Colormap: axes only).
            name = string(name);
            if name == "Colormap"
                tf = isa(h, 'matlab.graphics.axis.Axes');
            else
                tf = isprop(h, name);
            end
        end

        function v = getValue(h, name)
            %getValue  The value of property NAME of H, as a rule stores it.
            %   On / off as "on" / "off", text as a string, numbers as double;
            %   Colormap is the axes' colormap matrix.
            v = get(h, char(name));
            if isa(v, 'matlab.lang.OnOffSwitchState') || ischar(v) || iscellstr(v)
                v = string(v);
            elseif isnumeric(v) || islogical(v)
                v = double(v);
            end
        end

        function setValue(h, name, v)
            %setValue  Set property NAME of H to V (a Colormap name sets the axes' colormap).
            name = string(name);
            if name == "Colormap" && (isstring(v) || ischar(v))
                colormap(h, feval(char(v), 256));
            elseif isstring(v)
                set(h, char(name), char(v));
            else
                set(h, char(name), v);
            end
        end

        function [v, ok] = parseColor(txt)
            %parseColor  A colour from text: a name, #rrggbb, "r g b" (0-1 or 0-255), or a word.
            %   The words none, flat, auto and interp are kept as text (the
            %   object decides whether it takes them). OK is false when TXT
            %   is none of these.
            txt = lower(strtrim(string(txt)));
            ok = true;
            if any(txt == ["none" "flat" "auto" "interp"])
                v = txt;
                return
            end
            nums = str2double(split(strtrim(regexprep(txt, '[\[\],;]', ' '))));
            if numel(nums) == 3 && all(isfinite(nums))
                if any(nums > 1); nums = nums / 255; end
                v = reshape(min(max(nums, 0), 1), 1, 3);
                return
            end
            try
                v = validatecolor(txt);
            catch
                v = [];
                ok = false;
            end
        end

        function s = valueText(v)
            %valueText  A rule value for people: #rrggbb for a colour, else the value.
            if isnumeric(v) && numel(v) == 3 && all(v >= 0 & v <= 1)
                s = string(sprintf('#%02X%02X%02X', round(255 * v)));
            elseif isnumeric(v) && isscalar(v)
                s = string(sprintf('%.4g', v));
            elseif isnumeric(v)
                s = string(mat2str(v, 4));
            else
                s = string(v);
            end
        end

        %% --- editing --------------------------------------------------------------
        function enableEditing(target, context)
            %enableEditing  Right-click any component drawn in TARGET to edit its aesthetics.
            %   CONTEXT (a struct; renderPlot builds it) is kept on TARGET:
            %   kind, id, title, root (the layout or axes drawn), target
            %   (TARGET), plotRules,
            %   onRemember (called with the plot's new rules; [] = they cannot
            %   be saved with the plot) and redraw (draws the plot again with
            %   given plot rules). Every component gets its own context menu
            %   (UserData = the component), since a uifigure does not say which
            %   object was right-clicked.
            fig = ancestor(target, 'figure');
            if isempty(fig); return; end
            setappdata(target, PlotAesthetics.ContextKey, context);
            T = PlotAesthetics.components(context.root);
            for i = find(ismember(T.Role, ["legend" "colorbar"])).'
                setappdata(T.Handles{i}(1), 'PlotAestheticsHolder', target);   % not inside TARGET when it is an axes
            end
            objs = [PlotAesthetics.layoutsIn(context.root), T.Handles{:}];
            objs = objs(isvalid(objs));
            objs = objs(arrayfun(@(o) isprop(o, 'ContextMenu'), objs));
            old = findall(fig, 'Type', 'uicontextmenu', 'Tag', PlotAesthetics.MenuTag);
            for k = 1:numel(old)
                if ~isgraphics(old(k).UserData) || any(old(k).UserData == objs)
                    delete(old(k));   % its object was redrawn away, or is given a fresh menu below
                end
            end
            % One menu per object: a uifigure's opening event does not say which object was right-clicked.
            for o = objs
                cm = uicontextmenu(fig, 'Tag', PlotAesthetics.MenuTag, 'UserData', o);
                uimenu(cm, 'Text', 'Edit aesthetics...', 'MenuSelectedFcn', @PlotAesthetics.onMenuEdit);
                o.ContextMenu = cm;
            end
        end

        function d = edit(h)
            %edit  Open the aesthetics editor on component H of a plot renderPlot drew.
            %   Errors (PlotAesthetics:NotEditable) when H is not part of an
            %   editable plot.
            ctx = PlotAesthetics.contextOf(h);
            if isempty(ctx)
                error('PlotAesthetics:NotEditable', 'This is not part of a plot drawn by renderPlot in a visible figure.');
            end
            d = PlotAestheticsDialog(ctx, h);
        end

        function [ctx, holder] = contextOf(h)
            %contextOf  The editing context of the plot H belongs to ([] when none).
            ctx = [];
            holder = [];
            o = h;
            while ~isempty(o) && isvalid(o)
                if isappdata(o, PlotAesthetics.ContextKey)
                    c = getappdata(o, PlotAesthetics.ContextKey);
                    if isstruct(c) && isgraphics(c.root)
                        ctx = c;
                        holder = o;
                    end
                    return
                end
                if isappdata(o, 'PlotAestheticsHolder')
                    o = getappdata(o, 'PlotAestheticsHolder');
                    continue
                end
                o = o.Parent;
            end
        end
    end

    methods (Static, Hidden)
        function onMenuEdit(menu, ~)
            %onMenuEdit  "Edit aesthetics...": the editor on the right-clicked object.
            h = menu.Parent.UserData;
            if isempty(h) || ~isvalid(h); return; end
            try
                PlotAesthetics.edit(h);
            catch ME
                fig = ancestor(h, 'figure');
                if ~isempty(fig); uialert(fig, ME.message, 'Plot aesthetics'); end
            end
        end

        function L = layoutsIn(target)
            %layoutsIn  The tiled layouts in TARGET (and TARGET itself), as a row.
            L = findall(target, 'Type', 'tiledlayout');
            L = reshape(flipud(L(:)), 1, []);
        end

        function axs = axesIn(target)
            %axesIn  The axes in TARGET, in tile order (then the order drawn).
            if isa(target, 'matlab.graphics.axis.Axes')
                axs = target;
                return
            end
            axs = flipud(findall(target, 'Type', 'axes'));
            axs = axs(~strcmp({axs.Tag}, 'legendHost'));   % placeLegend's hidden hosts of legends outside the grid
            n = numel(axs);
            tile = inf(n, 2);   % the tile, then the tile within a nested layout (a PSTH's raster and rate panel)
            for k = 1:n
                L = axs(k).Layout;
                if isprop(L, 'Tile') && isnumeric(L.Tile); tile(k, :) = [L.Tile 0]; end
                p = axs(k).Parent;
                if isa(p, 'matlab.graphics.layout.TiledChartLayout') && isa(p.Parent, 'matlab.graphics.layout.TiledChartLayout') ...
                        && isnumeric(p.Layout.Tile) && isfinite(tile(k, 1))
                    tile(k, :) = [p.Layout.Tile tile(k, 1)];
                end
            end
            [~, o] = sortrows([tile (1:n).']);
            axs = reshape(axs(o), 1, []);
        end

        function s = typeName(h)
            %typeName  The short class name of H (Line, Patch, Axes, ...).
            parts = split(string(class(h)), ".");
            s = parts(end);
        end

        function v = normalizeValue(v, where)
            %normalizeValue  A rule value: a double row, or a string scalar.
            if isa(v, 'matlab.lang.OnOffSwitchState'); v = string(v); end
            if ischar(v) || (isstring(v) && isscalar(v))
                v = string(v);
            elseif isnumeric(v) || islogical(v)
                v = reshape(double(v), 1, []);
                if size(v, 2) ~= 3 && ~isscalar(v)
                    error('PlotAesthetics:BadRule', '%s: a value is a number, a colour [r g b] or text.', where);
                end
            else
                error('PlotAesthetics:BadRule', '%s: a value is a number, a colour [r g b] or text.', where);
            end
        end

        function C = catalogue()
            %catalogue  Every property the editor knows: label, control type and limits.
            lineStyles = ["-" "--" ":" "-." "none"];
            lineLabels = ["solid" "dashed" "dotted" "dash-dot" "none"];
            markers = ["none" "o" "square" "diamond" "^" "v" ">" "<" "+" "*" "." "x" "_" "|" "pentagram" "hexagram"];
            markerLabels = ["none" "circle" "square" "diamond" "triangle up" "triangle down" "triangle right" ...
                "triangle left" "plus" "asterisk" "point" "cross" "horizontal line" "vertical line" "pentagram" "hexagram"];
            locations = ["best" "bestoutside" "north" "south" "east" "west" "northeast" "northwest" "southeast" ...
                "southwest" "northoutside" "southoutside" "eastoutside" "westoutside" "layout" "none"];
            colorHint = "A name (red), #rrggbb or r g b";
            C = struct();
            C.Visible = prop("Visible", "onoff");
            C.Color = prop("Colour", "color", Hint=colorHint + "; none hides it");
            C.FaceColor = prop("Fill colour", "color", Hint=colorHint + "; none, or flat (per-point colours)");
            C.EdgeColor = prop("Edge colour", "color", Hint=colorHint + "; none, or flat");
            C.MarkerEdgeColor = prop("Marker edge colour", "color", Hint=colorHint + "; auto (the line's), none, or flat");
            C.MarkerFaceColor = prop("Marker fill colour", "color", Hint=colorHint + "; auto, none, or flat");
            C.BackgroundColor = prop("Background", "color", Hint=colorHint + "; none");
            C.XColor = prop("X axis colour", "color", Hint=colorHint);
            C.YColor = prop("Y axis colour", "color", Hint=colorHint);
            C.GridColor = prop("Grid colour", "color", Hint=colorHint);
            C.TextColor = prop("Text colour", "color", Hint=colorHint);
            C.BoxFaceColor = prop("Box fill colour", "color", Hint=colorHint);
            C.BoxEdgeColor = prop("Box edge colour", "color", Hint=colorHint);
            C.BoxMedianLineColor = prop("Median colour", "color", Hint=colorHint);
            C.WhiskerLineColor = prop("Whisker colour", "color", Hint=colorHint);
            C.MarkerColor = prop("Outlier colour", "color", Hint=colorHint);
            C.LineStyle = prop("Line style", "choice", Choices=lineStyles, ChoiceLabels=lineLabels);
            C.WhiskerLineStyle = prop("Whisker style", "choice", Choices=lineStyles, ChoiceLabels=lineLabels);
            C.GridLineStyle = prop("Grid style", "choice", Choices=lineStyles, ChoiceLabels=lineLabels);
            C.LineWidth = prop("Line width", "number", Limits=[0.1 20], Step=0.25);
            C.Marker = prop("Marker", "choice", Choices=markers, ChoiceLabels=markerLabels);
            C.MarkerStyle = prop("Outlier marker", "choice", Choices=markers, ChoiceLabels=markerLabels);
            C.MarkerSize = prop("Marker size", "number", Limits=[0.5 60], Step=1);
            C.SizeData = prop("Marker area", "number", Limits=[1 2000], Step=5, Hint="Points squared");
            C.FaceAlpha = prop("Fill opacity", "number", Limits=[0 1], Step=0.05);
            C.EdgeAlpha = prop("Edge opacity", "number", Limits=[0 1], Step=0.05);
            C.Alpha = prop("Opacity", "number", Limits=[0 1], Step=0.05);
            C.MarkerFaceAlpha = prop("Marker fill opacity", "number", Limits=[0 1], Step=0.05);
            C.MarkerEdgeAlpha = prop("Marker edge opacity", "number", Limits=[0 1], Step=0.05);
            C.BoxFaceAlpha = prop("Box fill opacity", "number", Limits=[0 1], Step=0.05);
            C.GridAlpha = prop("Grid opacity", "number", Limits=[0 1], Step=0.05);
            C.BarWidth = prop("Bar width", "number", Limits=[0.05 1], Step=0.05, Hint="Share of the space between bars");
            C.BoxWidth = prop("Box width", "number", Limits=[0.01 5], Step=0.05, Hint="In x units");
            C.CapSize = prop("Cap size", "number", Limits=[0 40], Step=1);
            C.FontSize = prop("Font size", "number", Limits=[4 48], Step=1);
            C.FontWeight = prop("Font weight", "choice", Choices=["normal" "bold"]);
            C.FontAngle = prop("Font angle", "choice", Choices=["normal" "italic"]);
            C.FontName = prop("Font", "font");
            C.TickDir = prop("Tick direction", "choice", Choices=["in" "out" "both" "none"]);
            C.TickDirection = prop("Tick direction", "choice", Choices=["in" "out" "both"]);
            C.Box = prop("Box", "onoff");
            C.XGrid = prop("X grid", "onoff");
            C.YGrid = prop("Y grid", "onoff");
            C.XMinorTick = prop("X minor ticks", "onoff");
            C.YMinorTick = prop("Y minor ticks", "onoff");
            C.Location = prop("Location", "choice", Choices=locations);
            C.Orientation = prop("Orientation", "choice", Choices=["vertical" "horizontal"]);
            C.NumColumns = prop("Columns", "number", Limits=[1 12], Step=1);
            C.Colormap = prop("Colormap", "colormap", Hint="A colormap function: parula, turbo, hot, gray, blueWhiteRed, ...");
            for f = string(fieldnames(C)).'
                C.(f).Name = f;
            end
        end

        function L = classLists()
            %classLists  The properties offered per object type, in the editor's order.
            L = struct();
            marker = ["Marker" "MarkerSize" "MarkerEdgeColor" "MarkerFaceColor"];
            L.Line = ["Visible" "Color" "LineStyle" "LineWidth" marker];
            L.Stair = L.Line;
            L.Patch = ["Visible" "FaceColor" "FaceAlpha" "EdgeColor" "EdgeAlpha" "LineStyle" "LineWidth"];
            L.Area = L.Patch;
            L.ConstantLine = ["Visible" "Color" "Alpha" "LineStyle" "LineWidth"];
            L.Bar = ["Visible" "FaceColor" "FaceAlpha" "EdgeColor" "EdgeAlpha" "LineStyle" "LineWidth" "BarWidth"];
            L.ErrorBar = ["Visible" "Color" "LineStyle" "LineWidth" "CapSize" marker];
            L.BoxChart = ["Visible" "BoxFaceColor" "BoxFaceAlpha" "BoxEdgeColor" "BoxMedianLineColor" ...
                "WhiskerLineColor" "WhiskerLineStyle" "LineWidth" "BoxWidth" "MarkerStyle" "MarkerSize" "MarkerColor"];
            L.Scatter = ["Visible" "Marker" "SizeData" "MarkerFaceColor" "MarkerEdgeColor" "MarkerFaceAlpha" ...
                "MarkerEdgeAlpha" "LineWidth"];
            L.ViolinPlot = ["Visible" "FaceColor" "FaceAlpha" "EdgeColor" "LineStyle" "LineWidth"];
            L.Image = "Visible";
            L.Text = ["Visible" "Color" "FontSize" "FontWeight" "FontAngle" "FontName" "BackgroundColor" "EdgeColor"];
            L.Axes = ["Visible" "Color" "XColor" "YColor" "LineWidth" "FontSize" "FontName" "TickDir" "Box" ...
                "XGrid" "YGrid" "GridColor" "GridAlpha" "GridLineStyle" "XMinorTick" "YMinorTick" "Colormap"];
            L.Legend = ["Visible" "FontSize" "Location" "Orientation" "NumColumns" "Box" "Color" "EdgeColor" "TextColor"];
            L.ColorBar = ["Visible" "FontSize" "Color" "LineWidth" "TickDirection" "Box"];
        end

        function O = classLabels()
            %classLabels  Labels that differ by object type.
            O = struct();
            O.Axes = struct('Color', "Background", 'LineWidth', "Axis line width", 'FontSize', "Tick font size");
            O.Legend = struct('Color', "Background", 'EdgeColor', "Box colour");
            O.ColorBar = struct('Color', "Tick colour", 'LineWidth', "Outline width");
            O.Text = struct('EdgeColor', "Box colour");
            O.Patch = struct('LineStyle', "Edge style", 'LineWidth', "Edge width");
            O.Bar = struct('LineStyle', "Edge style", 'LineWidth', "Edge width");
            O.Scatter = struct('LineWidth', "Marker edge width");
        end
    end
end


function C = addText(C, h, role, tile, name)
%addText  A title or label, when it shows something.
if isempty(h) || ~isvalid(h); return; end
s = h.String;
if isempty(s) || all(strlength(string(s)) == 0); return; end
C(end+1) = struct('h', h, 'role', role, 'group', "", 'tile', tile, 'name', name);
end


function p = prop(label, type, o)
%prop  One catalogue entry (PlotAesthetics.catalogue).
arguments
    label (1,1) string
    type (1,1) string
    o.Limits (1,2) double = [-Inf Inf]
    o.Step (1,1) double = 1
    o.Choices (1,:) string = string.empty(1, 0)
    o.ChoiceLabels (1,:) string = string.empty(1, 0)
    o.Hint (1,1) string = ""
end
if isempty(o.ChoiceLabels); o.ChoiceLabels = o.Choices; end
p = struct('Name', "", 'Label', label, 'Type', type, 'Limits', o.Limits, 'Step', o.Step, ...
    'Choices', o.Choices, 'ChoiceLabels', o.ChoiceLabels, 'Hint', o.Hint);
end


function s = textOf(v)
%textOf  A text field of a rule as a string scalar (missing when it is not text).
if ischar(v) || (isstring(v) && isscalar(v))
    s = string(v);
elseif isempty(v) && (isnumeric(v) || isstring(v))
    s = "";
else
    s = string(missing);
end
end
