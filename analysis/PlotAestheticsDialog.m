classdef PlotAestheticsDialog < handle
    %PlotAestheticsDialog  Edit the colors, lines, markers and fonts of a drawn plot.
    %   D = PlotAestheticsDialog(CONTEXT, H) opens a modal window on the plot
    %   CONTEXT describes, with component H selected. renderPlot keeps a
    %   context on the plot's target (PlotAesthetics.enableEditing), so in
    %   practice: right-click any component of a plot and pick "Edit
    %   aesthetics..." (PlotAesthetics.edit(H) does the same).
    %
    %   The list on the left is every component drawn: the plot's title, each
    %   tile's axes, titles, labels, legend and color bar, and what the
    %   renderer drew there, by role and group (PlotAesthetics.components).
    %   Click a row to edit it; each change shows on the plot at once.
    %     Apply to   this one; the same component (role and group) in every
    %                tile; every group of its role; or the rows ticked in the
    %                list (the buttons under it tick like rows)
    %     Remember   on OK the changes become rules, kept with this plot (its
    %                config entry, through CONTEXT.onRemember) or for every
    %                plot of its kind (your preferences). A rule matches by
    %                role and group, so a change to one tile is remembered for
    %                every tile. The Remembered tab lists both sets and
    %                forgets rules; the plot is redrawn without them on OK
    %     Reset      undoes everything since the window opened
    %     Cancel     the same, and closes the window (so does closing it)
    %     OK         keeps the changes (and remembers them when asked)
    %
    %   The same without the mouse (tests, scripts):
    %     d.select(K)                 edit row K of d.Components (or its Key)
    %     d.setProperty(NAME, VALUE)  change a property (missing: back to as drawn)
    %     d.setApplyTo(MODE)          "one" | "same" | "role" | "ticked"
    %     d.tick(ROWS, TF), d.tickLike(HOW)   HOW: "same" | "role" | "tile" | "none"
    %     d.setRemember(TF, SCOPE)    SCOPE: "plot" | "user"
    %     T = d.remembered(); d.forget(ROWS)
    %     d.reset(); d.cancel(); d.ok()
    %
    %   See also PlotAesthetics, renderPlot, EphysAnalysisApp.

    properties (SetAccess = private)
        Fig                                 % the dialog's uifigure
        Context struct                      % from renderPlot (PlotAesthetics.enableEditing)
        Components table                    % PlotAesthetics.components of the plot
        Selected (1,1) double = 1           % the row being edited
        ApplyTo (1,1) string = "one"        % "one" | "same" | "role" | "ticked"
        Ticked (:,1) logical                % ticked rows of Components
        Remember (1,1) logical = false      % make rules of the changes on OK
        Scope (1,1) string = "plot"         % "plot" (the config) | "user" (preferences)
        PlotRules                           % the plot's rules (less the ones forgotten)
        UserRules                           % the user's rules for this kind (likewise)
        Edits                               % changes made: rows, keys, props, applyTo, source
        Status (1,1) string = ""            % the last message shown
    end

    properties (Access = private)
        Pending = struct()                  % the change in progress (property -> value)
        PendingBase                         % values the change in progress replaced (Map)
        Original                            % values when the window opened (Map)
        PlotRules0
        UserRules0
        Ui = struct()
        Controls = struct()
    end

    properties (Constant, Access = private)
        PrefGroup = "PlotAestheticsDialog"
        Modes = ["one" "same" "role" "ticked"]
    end

    methods
        function obj = PlotAestheticsDialog(context, h, opts)
            arguments
                context (1,1) struct
                h = []
                opts.Visible (1,1) logical = true
            end
            if ~isfield(context, 'root') || ~isgraphics(context.root)
                error('PlotAesthetics:NotEditable', 'The plot is no longer drawn.');
            end
            obj.Context = context;
            obj.Components = PlotAesthetics.components(context.root);
            if height(obj.Components) == 0
                error('PlotAesthetics:NotEditable', 'The plot has no components to edit.');
            end
            obj.Ticked = false(height(obj.Components), 1);
            obj.PlotRules = PlotAesthetics.normalizeRules(context.plotRules);
            obj.UserRules = PlotAesthetics.userRules(context.kind);
            obj.PlotRules0 = obj.PlotRules;
            obj.UserRules0 = obj.UserRules;
            obj.Edits = struct('rows', {}, 'keys', {}, 'props', {}, 'applyTo', {}, 'source', {});
            obj.PendingBase = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.Original = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.loadChoices();
            obj.Selected = obj.rowOf(h);
            obj.build(opts.Visible);
            obj.showSelected();
            obj.refreshRemembered();
        end

        function delete(obj)
            if ~isempty(obj.Fig) && isvalid(obj.Fig); delete(obj.Fig); end
        end

        %% --- what the controls do --------------------------------------------
        function select(obj, k)
            %select  Edit component K (a row of Components, or its Key).
            if isstring(k) || ischar(k)
                k = find(obj.Components.Key == string(k), 1);
            end
            if isempty(k) || k < 1 || k > height(obj.Components)
                error('PlotAesthetics:BadRow', 'No component %s.', string(k));
            end
            obj.commitPending();
            obj.Selected = k;
            obj.showSelected();
        end

        function setProperty(obj, name, value)
            %setProperty  Change property NAME of what Apply to covers (shown at once).
            %   VALUE as the property takes it ("on" / "off", a number, an RGB
            %   triplet or a word); a color may also be text (parseColor).
            %   missing takes the property back to how the plot was drawn.
            obj.change(string(name), value);
            obj.showSelected();
        end

        function setApplyTo(obj, mode)
            %setApplyTo  "one", "same" (role and group, every tile), "role" (every group) or "ticked".
            mode = string(mode);
            if ~ismember(mode, obj.Modes)
                error('PlotAesthetics:BadMode', 'Apply to is one of %s.', strjoin(obj.Modes, ", "));
            end
            obj.ApplyTo = mode;
            obj.retarget();
        end

        function tick(obj, rows, tf)
            %tick  Tick (TF true, the default) or untick ROWS of the list.
            if nargin < 3; tf = true; end
            obj.Ticked(rows) = tf;
            obj.showTicks();
            if any(obj.Ticked) && obj.ApplyTo ~= "ticked"
                obj.ApplyTo = "ticked";
            end
            obj.retarget();
        end

        function tickLike(obj, how)
            %tickLike  Tick the rows like the selected one: "same", "role", "tile"; "none" unticks all.
            T = obj.Components;
            s = obj.Selected;
            switch string(how)
                case "same", rows = T.Role == T.Role(s) & T.Group == T.Group(s);
                case "role", rows = T.Role == T.Role(s);
                case "tile", rows = T.Tile == T.Tile(s);
                case "none"
                    obj.Ticked(:) = false;
                    obj.showTicks();
                    if obj.ApplyTo == "ticked"; obj.ApplyTo = "one"; end
                    obj.retarget();
                    return
                otherwise
                    error('PlotAesthetics:BadMode', 'Tick like is "same", "role", "tile" or "none".');
            end
            if T.Role(s) == ""; rows = false(height(T), 1); rows(s) = true; end
            obj.tick(find(rows), true);
        end

        function setRemember(obj, tf, scope)
            %setRemember  Make rules of the changes on OK (TF), kept with "plot" or "user".
            obj.Remember = logical(tf);
            if nargin > 2
                scope = string(scope);
                if ~ismember(scope, ["plot" "user"])
                    error('PlotAesthetics:BadScope', 'Remember for "plot" or "user".');
                end
                if scope == "plot" && isempty(obj.Context.onRemember)
                    error('PlotAesthetics:BadScope', 'This plot cannot keep rules (it is not in a config); remember them for "user".');
                end
                obj.Scope = scope;
            end
            obj.showRemember();
        end

        function T = remembered(obj)
            %remembered  The rules remembered now: this plot's, then the user's for its kind.
            T = rulesTable(obj.PlotRules, "This plot");
            T = [T; rulesTable(obj.UserRules, "My " + obj.kindLabel() + " plots")];
        end

        function forget(obj, rows)
            %forget  Forget rows of remembered() (on OK; the plot is redrawn without them).
            nP = numel(obj.PlotRules);
            rows = unique(rows(:)).';
            p = rows(rows <= nP);
            u = rows(rows > nP) - nP;
            obj.PlotRules(p) = [];
            obj.UserRules(u) = [];
            obj.refreshRemembered();
            obj.say(sprintf("%d setting(s) will be forgotten on OK (the plot is redrawn without them).", numel(rows)));
        end

        function reset(obj)
            %reset  Undo every change since the window opened (and forget nothing).
            obj.restorePending();
            obj.Pending = struct();
            for k = string(keys(obj.Original))
                s = obj.Original(char(k));
                if isvalid(s.h)
                    try PlotAesthetics.setValue(s.h, s.name, s.value); catch; end
                end
            end
            clearMap(obj.Original);
            obj.Edits = obj.Edits([]);
            obj.PlotRules = obj.PlotRules0;
            obj.UserRules = obj.UserRules0;
            obj.showSelected();
            obj.refreshRemembered();
            obj.say("Back to how the plot was when this window opened.");
        end

        function cancel(obj)
            %cancel  Undo every change and close.
            obj.reset();
            obj.close();
        end

        function ok(obj)
            %ok  Keep the changes; remember them when asked; forget what was forgotten.
            obj.commitPending();
            newPlot = obj.PlotRules;
            newUser = obj.UserRules;
            if obj.Remember && ~isempty(obj.Edits)
                R = obj.rulesFromEdits();
                if obj.Scope == "plot" && ~isempty(obj.Context.onRemember)
                    newPlot = PlotAesthetics.mergeRules(newPlot, R);
                else
                    newUser = PlotAesthetics.mergeRules(newUser, R);
                end
            end
            plotChanged = ~isequaln(newPlot, obj.PlotRules0);
            userChanged = ~isequaln(newUser, obj.UserRules0);
            if userChanged
                PlotAesthetics.setUserRules(obj.Context.kind, newUser);
            end
            if plotChanged && ~isempty(obj.Context.onRemember)
                obj.Context.onRemember(newPlot);
            end
            obj.saveChoices();
            edits = obj.Edits;
            ctx = obj.Context;
            remembered = obj.Remember;
            obj.close();
            if plotChanged || userChanged
                % Redraw, so the plot shows what is remembered (every tile, nothing forgotten).
                ctx.redraw(newPlot);
                if ~remembered
                    PlotAestheticsDialog.reapply(ctx.target, edits);
                end
            else
                ctx.plotRules = newPlot;
                setappdata(ctx.target, PlotAesthetics.ContextKey, ctx);
            end
        end
    end

    methods (Access = private)
        %% --- changes ----------------------------------------------------------
        function change(obj, name, value)
            %change  Set (or, with missing, drop) NAME in the change in progress and apply it.
            P = PlotAesthetics.editableProperties(obj.Components.Handles{obj.Selected}(1));
            k = find([P.Name] == name, 1);
            if isempty(k)
                error('PlotAesthetics:BadProperty', '%s has no editable property %s.', obj.Components.Label(obj.Selected), name);
            end
            if ~isnumeric(value) && isscalar(value) && ismissing(value)
                if isfield(obj.Pending, name); obj.Pending = rmfield(obj.Pending, name); end
            else
                if P(k).Type == "color" && (isstring(value) || ischar(value))
                    [value, good] = PlotAesthetics.parseColor(value);
                    if ~good
                        error('PlotAesthetics:BadValue', '"%s" is not a color.', string(value));
                    end
                elseif P(k).Type == "onoff" && (islogical(value) || isnumeric(value))
                    value = string(matlab.lang.OnOffSwitchState(value));
                end
                obj.Pending.(name) = value;
            end
            obj.retarget(name);
        end

        function retarget(obj, changed)
            %retarget  Undo the change in progress and apply it again to what Apply to covers now.
            if nargin < 2; changed = ""; end
            obj.restorePending();
            rows = obj.targetRows();
            names = string(fieldnames(obj.Pending)).';
            nSet = 0;
            refused = strings(1, 0);
            for nm = names
                v = obj.Pending.(nm);
                ok = 0;
                for r = rows
                    for h = reshape(obj.Components.Handles{r}, 1, [])
                        if ~isvalid(h) || ~PlotAesthetics.hasProperty(h, nm); continue; end
                        key = snapKey(h, nm);
                        was = PlotAesthetics.getValue(h, nm);
                        try
                            PlotAesthetics.setValue(h, nm, v);
                        catch ME
                            refused(end+1) = string(ME.message); %#ok<AGROW>
                            continue
                        end
                        if ~isKey(obj.PendingBase, key); obj.PendingBase(key) = struct('h', h, 'name', nm, 'value', was); end
                        if ~isKey(obj.Original, key); obj.Original(key) = struct('h', h, 'name', nm, 'value', was); end
                        ok = ok + 1;
                    end
                end
                nSet = nSet + ok;
                if ok == 0 && nm == changed && ~isempty(refused)
                    obj.Pending = rmfield(obj.Pending, nm);
                end
            end
            obj.showTargets(rows);
            if ~isempty(refused) && changed ~= ""
                obj.say("Not taken: " + refused(end));
            elseif changed ~= ""
                obj.say(sprintf("%d value(s) set on %d component(s).", nSet, numel(rows)));
            else
                obj.say(sprintf("Changes go to %d component(s), shaded in the list.", numel(rows)));
            end
        end

        function restorePending(obj)
            %restorePending  Put back what the change in progress replaced.
            for k = string(keys(obj.PendingBase))
                s = obj.PendingBase(char(k));
                if isvalid(s.h)
                    try PlotAesthetics.setValue(s.h, s.name, s.value); catch; end
                end
            end
            clearMap(obj.PendingBase);
        end

        function commitPending(obj)
            %commitPending  The change in progress becomes an edit (it stays on the plot).
            if isempty(fieldnames(obj.Pending)); return; end
            rows = obj.targetRows();
            obj.Edits(end+1) = struct('rows', rows, 'keys', obj.Components.Key(rows), 'props', obj.Pending, ...
                'applyTo', obj.ApplyTo, 'source', obj.Selected);
            obj.Pending = struct();
            clearMap(obj.PendingBase);
        end

        function rows = targetRows(obj, mode)
            %targetRows  The rows Apply to covers (MODE, default the current one).
            if nargin < 2; mode = obj.ApplyTo; end
            T = obj.Components;
            s = obj.Selected;
            if T.Role(s) == "" && mode ~= "ticked"; mode = "one"; end
            switch mode
                case "one",    rows = s;
                case "same",   rows = find(T.Role == T.Role(s) & T.Group == T.Group(s)).';
                case "role",   rows = find(T.Role == T.Role(s)).';
                case "ticked", rows = find(obj.Ticked).';
            end
        end

        function R = rulesFromEdits(obj)
            %rulesFromEdits  Rules for the edits: by role and group (or every group).
            T = obj.Components;
            R = PlotAesthetics.emptyRules();
            for e = obj.Edits
                s = e.source;
                for nm = string(fieldnames(e.props)).'
                    switch e.applyTo
                        case {"one" "same"}, pairs = [T.Role(s) T.Group(s)];
                        case "role",         pairs = [T.Role(s) ""];
                        case "ticked",       pairs = tickedPairs(T, e.rows, nm);
                    end
                    for i = 1:size(pairs, 1)
                        if pairs(i, 1) == ""; continue; end
                        R(end+1) = struct('role', pairs(i, 1), 'group', pairs(i, 2), 'property', nm, ...
                            'value', e.props.(nm)); %#ok<AGROW>
                    end
                end
            end
            R = PlotAesthetics.mergeRules(PlotAesthetics.emptyRules(), R);
        end

        %% --- window -----------------------------------------------------------
        function build(obj, visible)
            ctx = obj.Context;
            name = "Plot aesthetics";
            if isfield(ctx, 'title') && ctx.title ~= ""; name = name + ": " + ctx.title; end
            sz = [880 580];
            pos = [100 100 sz];
            parent = ancestor(ctx.root, 'figure');
            try
                pp = getpixelposition(parent);
                pos(1:2) = max(1, pp(1:2) + (pp(3:4) - sz) / 2);
            catch
            end
            obj.Fig = uifigure('Name', char(name), 'Position', pos, 'Visible', 'off', 'WindowStyle', 'modal', ...
                'CloseRequestFcn', @(~, ~) obj.cancel());
            main = uigridlayout(obj.Fig, [2 1], 'RowHeight', {'1x', 36}, 'Padding', 8, 'RowSpacing', 8);
            top = uigridlayout(main, [1 2], 'ColumnWidth', {400, '1x'}, 'Padding', 0, 'ColumnSpacing', 10);

            left = uigridlayout(top, [3 1], 'RowHeight', {20, '1x', 30}, 'Padding', 0, 'RowSpacing', 4);
            uilabel(left, 'Text', 'Components: click one to edit it; tick several to change them together', ...
                'FontWeight', 'bold');
            T = obj.Components;
            obj.Ui.List = uitable(left, 'Data', [num2cell(obj.Ticked) cellstr(T.TileName) cellstr(T.Label) cellstr(T.Type)], ...
                'ColumnName', {'✓', 'Tile', 'Component', 'Type'}, 'RowName', {}, ...
                'ColumnEditable', [true false false false], 'ColumnWidth', {28, 90, 'auto', 92}, ...
                'CellEditCallback', @(~, e) obj.onTickEdited(e), 'CellSelectionCallback', @(~, e) obj.onListClicked(e));
            b = uigridlayout(left, [1 4], 'ColumnWidth', {'1x', '1x', '1x', '1x'}, 'Padding', 0, 'ColumnSpacing', 4);
            bt(1) = uibutton(b, 'Text', 'Tick like it', 'ButtonPushedFcn', @(~, ~) obj.tickLike("same"), ...
                'Tooltip', 'Tick the same component (role and group) in every tile');
            bt(2) = uibutton(b, 'Text', 'Tick its role', 'ButtonPushedFcn', @(~, ~) obj.tickLike("role"), ...
                'Tooltip', 'Tick every group of this role in every tile');
            bt(3) = uibutton(b, 'Text', 'Tick its tile', 'ButtonPushedFcn', @(~, ~) obj.tickLike("tile"), ...
                'Tooltip', 'Tick everything in this tile');
            bt(4) = uibutton(b, 'Text', 'Untick all', 'ButtonPushedFcn', @(~, ~) obj.tickLike("none"));

            tabs = uitabgroup(top);
            et = uitab(tabs, 'Title', 'Edit');
            eg = uigridlayout(et, [5 1], 'RowHeight', {24, '1x', 30, 30, 34}, 'Padding', 8, 'RowSpacing', 6);
            obj.Ui.Header = uilabel(eg, 'Text', '', 'FontWeight', 'bold', 'FontSize', 13);
            obj.Ui.Props = uipanel(eg, 'BorderType', 'none', 'Scrollable', 'on');
            ag = uigridlayout(eg, [1 2], 'ColumnWidth', {70, '1x'}, 'Padding', 0);
            uilabel(ag, 'Text', 'Apply to:', 'FontWeight', 'bold');
            obj.Ui.ApplyTo = uidropdown(ag, 'Items', {'This one'}, 'ItemsData', {'one'}, ...
                'ValueChangedFcn', @(s, ~) obj.setApplyTo(s.Value), ...
                'Tooltip', 'Which components the changes go to; the list shades them');
            rg = uigridlayout(eg, [1 2], 'ColumnWidth', {190, '1x'}, 'Padding', 0);
            obj.Ui.Remember = uicheckbox(rg, 'Text', 'Remember for future plots:', 'FontWeight', 'bold', ...
                'ValueChangedFcn', @(s, ~) obj.setRemember(s.Value), ...
                'Tooltip', 'On OK the changes are kept as rules by component and group, so a change to one tile applies to every tile');
            obj.Ui.Scope = uidropdown(rg, 'Items', {'x'}, 'ValueChangedFcn', @(s, ~) obj.setRemember(obj.Remember, s.Value));
            obj.Ui.Status = uilabel(eg, 'Text', 'Changes show on the plot as you make them.', 'WordWrap', 'on', ...
                'FontColor', [0.35 0.35 0.35]);

            rt = uitab(tabs, 'Title', 'Remembered');
            rgl = uigridlayout(rt, [3 1], 'RowHeight', {36, '1x', 30}, 'Padding', 8, 'RowSpacing', 6);
            uilabel(rgl, 'WordWrap', 'on', 'Text', ['Settings drawn every time: this plot''s (kept in the config) ' ...
                'win over your own for every plot of the kind (kept in your preferences).']);
            obj.Ui.Remembered = uitable(rgl, 'RowName', {}, 'ColumnName', {'Kept for', 'Component', 'Group', 'Property', 'Value'}, ...
                'ColumnWidth', {110, 'auto', 70, 'auto', 80}, 'SelectionType', 'row', 'Multiselect', 'on');
            fg = uigridlayout(rgl, [1 3], 'ColumnWidth', {140, 140, '1x'}, 'Padding', 0);
            bt(5) = uibutton(fg, 'Text', 'Forget selected', 'ButtonPushedFcn', @(~, ~) obj.forgetSelected());
            bt(6) = uibutton(fg, 'Text', 'Forget all', 'ButtonPushedFcn', @(~, ~) obj.forget(1:height(obj.remembered())));

            bg = uigridlayout(main, [1 4], 'ColumnWidth', {'1x', 110, 110, 110}, 'Padding', 0, 'ColumnSpacing', 8);
            uilabel(bg, 'Text', '');
            bt(7) = uibutton(bg, 'Text', 'Reset', 'ButtonPushedFcn', @(~, ~) obj.reset(), ...
                'Tooltip', 'Undo every change since this window opened');
            bt(8) = uibutton(bg, 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) obj.cancel(), ...
                'Tooltip', 'Undo every change and close');
            okb = uibutton(bg, 'Text', 'OK', 'ButtonPushedFcn', @(~, ~) obj.ok(), ...
                'Tooltip', 'Keep the changes (and remember them when ticked)');
            styleButton(bt);
            styleButton(okb, "confirm");
            obj.showRemember();
            obj.Fig.Visible = matlab.lang.OnOffSwitchState(visible);
        end

        function showSelected(obj)
            %showSelected  The selected component's properties, the list shading and Apply to.
            T = obj.Components;
            s = obj.Selected;
            hs = T.Handles{s};
            where = T.TileName(s);
            obj.Ui.Header.Text = sprintf('%s  ·  %s  (%s%s)', T.Label(s), where, T.Type(s), plural(numel(hs)));
            delete(obj.Ui.Props.Children);
            h = hs(1);
            P = PlotAesthetics.editableProperties(h);
            obj.Controls = struct();
            if isempty(P)
                uilabel(uigridlayout(obj.Ui.Props, [1 1]), 'Text', 'Nothing to edit here.');
            else
                g = uigridlayout(obj.Ui.Props, [numel(P) 2], 'ColumnWidth', {150, '1x'}, ...
                    'RowHeight', repmat({26}, 1, numel(P)), 'Padding', [0 0 10 0], 'RowSpacing', 4);
                for p = P
                    uilabel(g, 'Text', p.Label, 'Tooltip', p.Hint);
                    if isfield(obj.Pending, p.Name)
                        v = obj.Pending.(p.Name);
                    else
                        v = PlotAesthetics.getValue(h, p.Name);
                    end
                    obj.Controls.(p.Name) = obj.control(g, p, v);
                end
            end
            obj.showApplyTo();
            obj.retarget();
            try scroll(obj.Ui.List, 'row', s); catch; end
        end

        function c = control(obj, g, p, v)
            %control  The control for one property, showing value V.
            nm = p.Name;
            switch p.Type
                case "onoff"
                    c = uicheckbox(g, 'Text', '', 'Value', string(v) == "on", ...
                        'ValueChangedFcn', @(s, ~) obj.fromControl(nm, string(matlab.lang.OnOffSwitchState(s.Value))));
                case "number"
                    x = p.Limits(1);
                    if isnumeric(v) && ~isempty(v) && isfinite(v(1)); x = v(1); end
                    x = min(max(x, p.Limits(1)), p.Limits(2));
                    c = uispinner(g, 'Limits', p.Limits, 'Step', p.Step, 'Value', x, 'ValueDisplayFormat', '%.4g', ...
                        'ValueChangedFcn', @(s, ~) obj.fromControl(nm, s.Value), 'Tooltip', p.Hint);
                    if ~(isnumeric(v) && isscalar(v)); c.Tooltip = "Now: " + PlotAesthetics.valueText(v); end
                case "vector"
                    c = uieditfield(g, 'text', 'Value', char(strjoin(compose("%.4g", double(v)), " ")), 'Tooltip', p.Hint, ...
                        'ValueChangedFcn', @(s, e) obj.fromVectorText(nm, s, e));
                case "choice"
                    items = p.Choices; labels = p.ChoiceLabels;
                    cur = string(v);
                    if ~isscalar(cur); cur = items(1); end
                    if ~ismember(cur, items); items = [items cur]; labels = [labels cur]; end
                    c = uidropdown(g, 'Items', cellstr(labels), 'ItemsData', cellstr(items), 'Value', char(cur), ...
                        'ValueChangedFcn', @(s, ~) obj.fromControl(nm, string(s.Value)));
                case "font"
                    fonts = unique(["Helvetica" "Arial" "Calibri" "Segoe UI" "Times New Roman" "Courier New" "Consolas" string(v)], 'stable');
                    c = uidropdown(g, 'Editable', 'on', 'Items', cellstr(fonts), 'Value', char(string(v)), ...
                        'ValueChangedFcn', @(s, ~) obj.fromControl(nm, string(s.Value)));
                case "colormap"
                    maps = ["(as drawn)" "parula" "turbo" "hot" "cool" "gray" "bone" "copper" "jet" "sky" "abyss" "blueWhiteRed"];
                    cur = "(as drawn)";
                    if isstring(v) && isscalar(v); cur = v; end
                    if ~ismember(cur, maps); maps = [maps cur]; end
                    c = uidropdown(g, 'Editable', 'on', 'Items', cellstr(maps), 'Value', char(cur), 'Tooltip', p.Hint, ...
                        'ValueChangedFcn', @(s, ~) obj.fromColormap(s));
                case "color"
                    sub = uigridlayout(g, [1 2], 'ColumnWidth', {40, '1x'}, 'Padding', 0, 'ColumnSpacing', 4);
                    rgb = [1 1 1];
                    if isnumeric(v) && numel(v) == 3; rgb = v; end
                    if isMATLABReleaseOlderThan("R2024a")   % no uicolorpicker: a swatch that opens uisetcolor
                        c.Picker = uibutton(sub, 'Text', '', 'BackgroundColor', rgb, ...
                            'ButtonPushedFcn', @(s, ~) obj.fromSwatch(nm, s));
                    else
                        c.Picker = uicolorpicker(sub, 'Value', rgb, 'ValueChangedFcn', @(s, ~) obj.fromPicker(nm, s.Value));
                    end
                    c.Text = uieditfield(sub, 'text', 'Value', char(PlotAesthetics.valueText(v)), 'Tooltip', p.Hint, ...
                        'ValueChangedFcn', @(s, e) obj.fromColorText(nm, s, e));
                otherwise
                    c = uilabel(g, 'Text', PlotAesthetics.valueText(v));
            end
        end

        function fromControl(obj, name, value)
            try
                obj.change(name, value);
            catch ME
                obj.say(string(ME.message));
            end
        end

        function fromPicker(obj, name, rgb)
            obj.fromControl(name, rgb);
            c = obj.Controls.(name);
            c.Text.Value = char(PlotAesthetics.valueText(rgb));
            setSwatch(c.Picker, rgb);
        end

        function fromSwatch(obj, name, button)
            rgb = uisetcolor(button.BackgroundColor);
            if numel(rgb) == 3; obj.fromPicker(name, rgb); end
        end

        function fromColorText(obj, name, field, evt)
            [v, good] = PlotAesthetics.parseColor(field.Value);
            if ~good
                field.Value = evt.PreviousValue;
                obj.say(sprintf('"%s" is not a color: a name (red), #rrggbb, r g b, or none / flat / auto.', evt.Value));
                return
            end
            obj.fromControl(name, v);
            if isnumeric(v)
                setSwatch(obj.Controls.(name).Picker, v);
                field.Value = char(PlotAesthetics.valueText(v));
            end
        end

        function fromVectorText(obj, name, field, evt)
            v = str2double(split(strtrim(regexprep(string(field.Value), '[\[\],;]', ' '))));
            v = reshape(v(~isnan(v)), 1, []);
            if numel(v) ~= 2
                field.Value = evt.PreviousValue;
                obj.say(sprintf('"%s" is not two numbers.', evt.Value));
                return
            end
            obj.fromControl(name, v);
        end

        function fromColormap(obj, dd)
            v = string(dd.Value);
            if v == "(as drawn)"
                obj.fromControl("Colormap", missing);
                return
            end
            if ~any(exist(char(v)) == [2 5 6]) %#ok<EXIST>
                obj.say(sprintf('"%s" is not a colormap function.', v));
                dd.Value = '(as drawn)';
                return
            end
            obj.fromControl("Colormap", v);
        end

        function onListClicked(obj, evt)
            if isempty(evt.Indices); return; end
            ij = evt.Indices(end, :);
            if ij(2) == 1; return; end   % the tick column ticks, it does not select
            if ij(1) ~= obj.Selected; obj.select(ij(1)); end
        end

        function onTickEdited(obj, evt)
            obj.tick(evt.Indices(1), logical(evt.NewData));
        end

        function forgetSelected(obj)
            rows = obj.Ui.Remembered.Selection;
            if isempty(rows)
                obj.say("Select the rows to forget first.");
                return
            end
            obj.forget(rows(:));
        end

        function showTicks(obj)
            d = obj.Ui.List.Data;
            d(:, 1) = num2cell(obj.Ticked);
            obj.Ui.List.Data = d;
        end

        function showTargets(obj, rows)
            %showTargets  Shade the rows a change goes to; the selected one darker.
            L = obj.Ui.List;
            removeStyle(L);
            if ~isempty(rows)
                addStyle(L, uistyle('BackgroundColor', [0.91 0.95 1]), 'row', rows);
            end
            addStyle(L, uistyle('BackgroundColor', [0.78 0.87 1], 'FontWeight', 'bold'), 'row', obj.Selected);
            obj.showApplyTo();
        end

        function showApplyTo(obj)
            T = obj.Components;
            s = obj.Selected;
            n = arrayfun(@(m) numel(obj.targetRows(m)), obj.Modes);
            what = PlotAesthetics.roleLabel(T.Role(s));
            items = ["This one only" ...
                sprintf("The same %s in every tile (%d)", T.Label(s), n(2)) ...
                sprintf("Every %s, all groups and tiles (%d)", what, n(3)) ...
                sprintf("The ticked rows (%d)", n(4))];
            if T.Role(s) == ""
                items(2:3) = ["(untagged: this one only)" "(untagged: this one only)"];
            end
            set(obj.Ui.ApplyTo, 'Items', cellstr(items), 'ItemsData', cellstr(obj.Modes), 'Value', char(obj.ApplyTo));
        end

        function showRemember(obj)
            items = "Every " + obj.kindLabel() + " plot (my preferences)";
            data = "user";
            if ~isempty(obj.Context.onRemember)
                items = ["This plot (saved in the config)" items];
                data = ["plot" data];
            elseif obj.Scope == "plot"
                obj.Scope = "user";
            end
            set(obj.Ui.Scope, 'Items', cellstr(items), 'ItemsData', cellstr(data), 'Value', char(obj.Scope), ...
                'Enable', matlab.lang.OnOffSwitchState(obj.Remember));
            obj.Ui.Remember.Value = obj.Remember;
        end

        function refreshRemembered(obj)
            T = obj.remembered();
            obj.Ui.Remembered.Data = T;
        end

        function say(obj, msg)
            obj.Status = string(msg);
            if isfield(obj.Ui, 'Status') && isvalid(obj.Ui.Status)
                obj.Ui.Status.Text = char(obj.Status);
            end
        end

        function close(obj)
            if ~isempty(obj.Fig) && isvalid(obj.Fig); delete(obj.Fig); end
        end

        %% --- helpers ------------------------------------------------------------
        function k = rowOf(obj, h)
            %rowOf  The row holding H (a layout picks its title; else the first row).
            k = 1;
            if isempty(h) || ~isvalid(h); return; end
            T = obj.Components;
            if isa(h, 'matlab.graphics.layout.TiledChartLayout')
                j = find(T.Role == "plotTitle", 1);
                if ~isempty(j); k = j; end
                return
            end
            for i = 1:height(T)
                if any(arrayfun(@(x) isequal(x, h), T.Handles{i}))
                    k = i;
                    return
                end
            end
            ax = ancestor(h, 'axes');
            for i = find(ismember(T.Role, ["axes" "rasterAxes"])).'
                if isequal(T.Handles{i}(1), ax); k = i; return; end
            end
        end

        function s = kindLabel(obj)
            K = EphysAnalysisConfig.plotKinds();
            s = string(obj.Context.kind);
            j = find(K.Kind == s, 1);
            if ~isempty(j); s = K.Label(j); end
        end

        function loadChoices(obj)
            g = obj.PrefGroup;
            try
                if AppPrefs.ispref(g, 'Remember'); obj.Remember = isequal(AppPrefs.getpref(g, 'Remember'), true); end
                if AppPrefs.ispref(g, 'Scope')
                    sc = string(AppPrefs.getpref(g, 'Scope'));
                    if ismember(sc, ["plot" "user"]); obj.Scope = sc; end
                end
            catch
            end
            if isempty(obj.Context.onRemember); obj.Scope = "user"; end
        end

        function saveChoices(obj)
            try
                AppPrefs.setpref(obj.PrefGroup, 'Remember', obj.Remember);
                AppPrefs.setpref(obj.PrefGroup, 'Scope', char(obj.Scope));
            catch
            end
        end
    end

    methods (Static, Access = private)
        function reapply(target, edits)
            %reapply  Put edits that were not remembered back on a redrawn plot (by component key).
            if isempty(edits); return; end
            ctx = getappdata(target, PlotAesthetics.ContextKey);
            if ~isstruct(ctx) || ~isgraphics(ctx.root); return; end
            T = PlotAesthetics.components(ctx.root);
            for e = edits
                for r = find(ismember(T.Key, e.keys)).'
                    for h = reshape(T.Handles{r}, 1, [])
                        for nm = string(fieldnames(e.props)).'
                            if PlotAesthetics.hasProperty(h, nm)
                                try PlotAesthetics.setValue(h, nm, e.props.(nm)); catch; end
                            end
                        end
                    end
                end
            end
        end
    end
end


function setSwatch(p, rgb)
%setSwatch  Show RGB on a color picker (or, before R2024a, a swatch button).
if isprop(p, 'Value'); p.Value = rgb; else; p.BackgroundColor = rgb; end
end


function clearMap(M)
%clearMap  Empty a containers.Map (a handle).
if M.Count > 0; remove(M, keys(M)); end
end


function k = snapKey(h, name)
%snapKey  One key per object and property.
k = sprintf('%.17g|%s', double(h), name);
end


function s = plural(n)
if n > 1; s = sprintf(', %d objects', n); else; s = ''; end
end


function T = rulesTable(R, where)
%rulesTable  Rules as the Remembered tab lists them.
n = numel(R);
KeptFor = repmat(string(where), n, 1);
Component = strings(n, 1); Group = strings(n, 1); Property = strings(n, 1); Value = strings(n, 1);
C = PlotAesthetics.catalog();
for i = 1:n
    Component(i) = PlotAesthetics.roleLabel(R(i).role);
    Group(i) = R(i).group;
    if Group(i) == ""; Group(i) = "(every)"; end
    Property(i) = R(i).property;
    if isfield(C, R(i).property); Property(i) = C.(R(i).property).Label; end
    Value(i) = PlotAesthetics.valueText(R(i).value);
end
T = table(KeptFor, Component, Group, Property, Value);
end


function P = tickedPairs(T, rows, name)
%tickedPairs  Role / group pairs for ticked rows that have property NAME: a role
%   whose every component in the plot is ticked is one pair for every group ("").
rows = rows(arrayfun(@(r) PlotAesthetics.hasProperty(T.Handles{r}(1), name), rows));
P = strings(0, 2);
roles = unique(T.Role(rows), 'stable').';
for role = roles(roles ~= "")
    mine = rows(T.Role(rows) == role);
    if all(ismember(find(T.Role == role), mine))
        P(end+1, :) = [role ""]; %#ok<AGROW>
    else
        g = unique(T.Group(mine), 'stable');
        P = [P; [repmat(role, numel(g), 1) g]]; %#ok<AGROW>
    end
end
end
