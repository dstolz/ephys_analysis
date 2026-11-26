classdef LocalReferenceDialog < handle
    %LocalReferenceDialog  A local reference channel per shank or per probe, picked by clicking the probe, in a modal window.
    %   The window draws a dataset's probe at its true site positions
    %   (ProbePicker) and holds a pending local reference map
    %   (EphysDataset.LocalReferenceMap): which channels have which
    %   reference channel subtracted from them before the common reference
    %   (EphysDataset.applyLocalReference). The sites and shanks are colored
    %   by the reference they are assigned, each reference site drawn as a
    %   diamond in its color; unassigned sites are white.
    %
    %   Scope "One reference per shank": click a site to make it the
    %   reference of its own shank; or click one or more shanks (outlined)
    %   and then a site, which becomes the reference of the shanks clicked,
    %   on whichever shank it sits. Scope "One reference for the whole
    %   probe": click a site to make it the reference of every shank. The
    %   table lists the shanks (physical shanks, left to right, named by
    %   their kcoords group) with their channels and reference; typing a
    %   channel number in the Reference column sets it too (also a channel
    %   off the probe, such as a separate reference wire), and clearing it
    %   leaves the shank without one. Clear all empties the map.
    %
    %   A reference on its own shank (in its own group) becomes zeros, and
    %   every step leaves it out (EphysDataset.localReferenceZeroed); the
    %   summary says so. The problems a run would stop on (CheckFcn: every
    %   shank needs a reference, a reference must not be excluded or bad)
    %   are listed in red; the map can be saved with them, and a run stops
    %   until they are fixed.
    %
    %     dlg = LocalReferenceDialog(ds.LocalReferenceMap, Probe=readJsonFile(pf), ...
    %         NumChannels=ds.NumChannels, Dataset=ds.Name, ProbeName="probe.json", ...
    %         CheckFcn=@(m) ds.localReferenceProblems(Map=m, ProbeFile=pf), ...
    %         OnSave=@(m, ticked) save(m, ticked), Ticked=3, Parent=app.Fig);
    %
    %   MAP is a struct array (reference, channels) or [] for none. Options:
    %     Probe        the probe map (decoded JSON: chanMap, xc, yc, kcoords,
    %                  connected); [] = none (the window says so)
    %     NumChannels  the recording's channel count: probe sites past it
    %                  are not drawn into groups (default Inf)
    %     Dataset      the dataset's name, in the title and the summary
    %     ProbeName    the probe file's name, in the title
    %     CheckFcn     P = CheckFcn(MAP): what a run would say of MAP, a
    %                  string row ([] = only the shanks without a
    %                  reference are checked, here)
    %     OnSave       WHY = OnSave(MAP, TICKED): saves MAP, on the active
    %                  dataset (TICKED false, Save) or on the datasets ticked
    %                  in the Project table (TICKED true); WHY is "" when it
    %                  was saved, else the reason, shown, and the window
    %                  stays open
    %     OnSaveDefault WHY = OnSaveDefault(MAP): Save and use for new
    %                  datasets saves MAP on the active dataset and keeps it
    %                  as its probe's default, which every dataset on that
    %                  probe without a map of its own takes
    %                  (Reference.LocalAutoAssign); WHY as for OnSave ([] =
    %                  the button is off)
    %     Ticked       how many datasets are ticked (0: Save to ticked is off)
    %     Parent       the uifigure to center on ([] = none)
    %     Visible      false builds the window hidden (tests)
    %
    %   The window is modal but does not block (no uiwait): OnSave saves.
    %   Cancel or closing it saves nothing.
    %
    %   Properties (read-only): Fig, Ctl (the controls: Intro, Scope, Table,
    %   ClearSelection, ClearAll, Summary, Problems, SaveDefault, Cancel,
    %   SaveTicked, Save), Picker (the ProbePicker), Map (the pending map), Scope
    %   ("shank" | "probe"), Selected (the shanks the next site click
    %   assigns: body indices, left to right), Problems, Colors (one RGB row
    %   per reference of Map, in its order). Methods, the paths the controls
    %   take: clickSite(CH), clickShank(B), setScope(S), setReference(B, CH)
    %   (NaN: none), clearSelection, clearAll, save(TICKED), saveDefault,
    %   cancel, isOpen,
    %   siteColors (each drawn site's fill, as ProbePicker.siteColors).
    %
    %   See also EphysDataset.applyLocalReference, EphysDataset.localReferenceProblems,
    %   ProbePicker, EphysPipelineApp.

    properties (SetAccess = private)
        Fig = []                                   % the uifigure
        Ctl = struct()                             % the controls
        Picker = []                                % the ProbePicker drawing the probe
        Scope (1,1) string = "shank"               % "shank" | "probe": what a site click assigns
        Selected (1,:) double = []                 % the shanks (bodies, left to right) the next site click assigns
        Problems (1,:) string = string.empty(1, 0) % what a run would say of the pending map (CheckFcn)
    end

    properties (Dependent)
        Map                                        % the pending map (EphysDataset.LocalReferenceMap)
        Colors                                     % [k x 3] the color of each group of Map, in its order
    end

    properties
        OnSave = []                                % WHY = OnSave(MAP, TICKED)
        OnSaveDefault = []                         % WHY = OnSaveDefault(MAP)
        CheckFcn = []                              % P = CheckFcn(MAP)
    end

    properties (Access = private)
        SiteCh (1,:) double = []                   % the channels drawn (connected sites, within NumChannels)
        Ref (1,:) double = []                      % the reference of each of SiteCh (NaN: none)
        Others = struct('reference', {}, 'channels', {})   % the map's channels that are not drawn, kept as they were
        BodyCh = {}                                % {1 x nBody} the channels of each shank, within SiteCh
        NumChannels (1,1) double = Inf
        Dataset (1,1) string = ""
        Done (1,1) logical = false
    end

    properties (Constant)
        % One color per reference (as many as the probe has shanks, then again).
        Palette = [0.00 0.45 0.74; 0.85 0.33 0.10; 0.13 0.55 0.13; 0.49 0.18 0.56; ...
                   0.93 0.69 0.13; 0.00 0.60 0.60; 0.64 0.08 0.18; 0.30 0.70 0.95; ...
                   0.47 0.67 0.19; 0.25 0.25 0.60; 0.80 0.40 0.70; 0.55 0.40 0.20]
    end

    methods
        function obj = LocalReferenceDialog(map, opts)
            arguments
                map = []
                opts.Probe = []
                opts.NumChannels (1,1) double = Inf
                opts.Dataset (1,1) string = ""
                opts.ProbeName (1,1) string = ""
                opts.CheckFcn = []
                opts.OnSave = []
                opts.OnSaveDefault = []
                opts.Ticked (1,1) double = 0
                opts.Parent = []
                opts.Visible (1,1) logical = true
            end
            obj.NumChannels = opts.NumChannels;
            if ~(obj.NumChannels > 0); obj.NumChannels = Inf; end
            obj.Dataset = opts.Dataset;
            obj.CheckFcn = opts.CheckFcn;
            obj.OnSave = opts.OnSave;
            obj.OnSaveDefault = opts.OnSaveDefault;
            obj.build(opts);
            obj.load(EphysDataset.normalizeLocalReferenceMap(map));
        end

        function delete(obj)
            if ~isempty(obj.Fig) && isvalid(obj.Fig); delete(obj.Fig); end
        end

        function M = get.Map(obj)
            M = obj.buildMap();
        end

        function C = get.Colors(obj)
            M = obj.buildMap();
            C = obj.colorsOf([M.reference]);
        end

        function tf = isOpen(obj)
            tf = isvalid(obj) && ~obj.Done && ~isempty(obj.Fig) && isvalid(obj.Fig);
        end

        function clickSite(obj, ch)
            %clickSite  A click on the site of channel CH: it becomes the reference of the shanks selected, else of its own shank (or of every shank, Scope "probe").
            if ~ismember(ch, obj.SiteCh)
                obj.showMessage(sprintf("Channel %d is not on the probe drawn.", ch));
                return
            end
            if obj.Scope == "probe"
                obj.Ref(:) = ch;
            else
                b = obj.Selected;
                if isempty(b)
                    b = find(cellfun(@(c) ismember(ch, c), obj.BodyCh), 1);
                end
                for k = b
                    obj.Ref(ismember(obj.SiteCh, obj.BodyCh{k})) = ch;
                end
            end
            obj.Selected = [];
            obj.refresh();
        end

        function clickShank(obj, b)
            %clickShank  A click on shank (body) B: picked for the next site click, or dropped when picked (Scope "shank").
            if b < 1 || b > numel(obj.BodyCh); return; end
            if obj.Scope == "probe"
                obj.showMessage("One reference for the whole probe: click the site to use.");
                return
            end
            if ismember(b, obj.Selected)
                obj.Selected = obj.Selected(obj.Selected ~= b);
            else
                obj.Selected = sort([obj.Selected b]);
            end
            obj.refresh();
        end

        function setScope(obj, s)
            %setScope  "shank" (a reference per shank) or "probe" (one for the whole probe). The map stays until a site is clicked.
            s = string(s);
            if ~ismember(s, ["shank" "probe"])
                error('LocalReferenceDialog:BadScope', 'The scope is "shank" or "probe".');
            end
            obj.Scope = s;
            obj.Ctl.Scope.Value = char(s);
            obj.Selected = [];
            obj.refresh();
        end

        function setReference(obj, b, ch)
            %setReference  Shank B's reference: channel CH (any channel of the recording), NaN for none; Scope "probe": every shank's.
            ch = double(ch);
            if isempty(ch); ch = NaN; end
            if ~(isscalar(ch) && (isnan(ch) || (ch >= 1 && ch == round(ch) && ch <= obj.NumChannels)))
                obj.showMessage(sprintf("A reference is one channel of the recording, 1 to %g.", obj.NumChannels));
                obj.refresh();
                return
            end
            if obj.Scope == "probe"
                obj.Ref(:) = ch;
            elseif b >= 1 && b <= numel(obj.BodyCh)
                obj.Ref(ismember(obj.SiteCh, obj.BodyCh{b})) = ch;
            end
            obj.Selected = [];
            obj.refresh();
        end

        function clearSelection(obj)
            %clearSelection  No shank picked.
            obj.Selected = [];
            obj.refresh();
        end

        function clearAll(obj)
            %clearAll  No reference anywhere: the map empty.
            obj.Ref(:) = NaN;
            obj.Others = struct('reference', {}, 'channels', {});
            obj.Selected = [];
            obj.refresh();
        end

        function C = siteColors(obj)
            %siteColors  Each drawn site's fill (ProbePicker.Sites order): its reference's color, white when it has none.
            C = obj.Picker.siteColors();
        end

        function save(obj, ticked)
            %save  OnSave(Map, TICKED); the window closes when it saved, else shows why.
            if nargin < 2; ticked = false; end
            if obj.Done; return; end
            why = "";
            if ~isempty(obj.OnSave)
                why = string(obj.OnSave(obj.Map, logical(ticked)));
            end
            if why ~= ""
                obj.showMessage(why);
                return
            end
            obj.finish();
        end

        function saveDefault(obj)
            %saveDefault  OnSaveDefault(Map): saved on the dataset and kept as its probe's default; closes when it saved, else shows why.
            if obj.Done || isempty(obj.OnSaveDefault); return; end
            why = string(obj.OnSaveDefault(obj.Map));
            if why ~= ""
                obj.showMessage(why);
                return
            end
            obj.finish();
        end

        function cancel(obj)
            obj.finish();
        end
    end

    methods (Access = private)
        function build(obj, opts)
            name = "Local reference";
            if opts.Dataset ~= ""; name = name + ": " + opts.Dataset; end
            if opts.ProbeName ~= ""; name = name + " on " + opts.ProbeName; end
            fig = uifigure("Name", name, "Visible", "off", "Position", [100 100 1000 700], ...
                "WindowStyle", "modal", "Tag", "LocalReferenceDialog");
            parent = opts.Parent;
            if ~isempty(parent) && isvalid(parent)
                p = parent.Position;
                fig.Position(1:2) = p(1:2) + max(0, (p(3:4) - fig.Position(3:4)) / 2);
            end
            fig.CloseRequestFcn = @(~, ~) obj.cancel();
            obj.Fig = fig;
            gray = [0.38 0.38 0.38];

            g = uigridlayout(fig, [5 1], "RowHeight", {'fit', 26, '1x', 'fit', 34}, "RowSpacing", 6);
            c = struct();
            c.Intro = uilabel(g, "WordWrap", "on", "Text", ...
                "Each channel of a shank has the shank's reference channel, as recorded, subtracted from it, sample " + ...
                "by sample, before the common reference. Click a site to make it the reference of its own shank, or " + ...
                "click one or more shanks first, then the site. Or type a channel in the table. A reference on its own " + ...
                "shank becomes zeros and is left out of every step.");

            r = uigridlayout(g, [1 4], "ColumnWidth", {'fit', 260, '1x', 'fit'}, "RowHeight", {'1x'}, ...
                "Padding", [0 0 0 0], "ColumnSpacing", 6);
            uilabel(r, "Text", "Reference:");
            c.Scope = uidropdown(r, "Items", {'One reference per shank', 'One reference for the whole probe'}, ...
                "ItemsData", {'shank', 'probe'}, "Value", 'shank', ...
                "Tooltip", "Per shank: a site click sets the reference of its own shank, or of the shanks clicked " + ...
                "before it. Whole probe: a site click sets the reference of every shank.", ...
                "ValueChangedFcn", @(src, ~) obj.setScope(src.Value));
            c.Message = uilabel(r, "Text", "", "FontColor", [0.75 0.1 0.1]);
            c.Message.Layout.Column = 3;

            m = uigridlayout(g, [1 2], "ColumnWidth", {'1x', 430}, "Padding", [0 0 0 0], "ColumnSpacing", 10);
            P = ProbePicker(m);
            P.Axes.Layout.Column = 1;
            P.OnClick = @(kind, v) obj.onProbeClick(kind, v);
            obj.Picker = P;
            side = uigridlayout(m, [2 1], "RowHeight", {'1x', 30}, "Padding", [0 0 0 0], "RowSpacing", 6);
            side.Layout.Column = 2;
            c.Table = uitable(side, "RowName", {}, "ColumnName", {'Shank', 'Channels', 'Reference', 'Note'}, ...
                "ColumnWidth", {60, 90, 70, 'auto'}, "ColumnEditable", [false false true false], ...
                "ColumnFormat", {'char', 'char', 'numeric', 'char'}, ...
                "Tooltip", "Type a channel in Reference to set a shank's reference (any channel of the recording); " + ...
                "clear it to leave the shank without one.", ...
                "CellEditCallback", @(~, e) obj.onTableEdit(e));
            bg = uigridlayout(side, [1 2], "ColumnWidth", {'1x', '1x'}, "RowHeight", {30}, "Padding", [0 0 0 0]);
            c.ClearSelection = uibutton(bg, "Text", "Unpick shanks", "ButtonPushedFcn", @(~, ~) obj.clearSelection(), ...
                "Tooltip", "Drop the shanks picked for the next site click.");
            c.ClearAll = uibutton(bg, "Text", "Clear all", "ButtonPushedFcn", @(~, ~) obj.clearAll(), ...
                "Tooltip", "No reference anywhere (the map empty; saved only with Save).");
            styleButton([c.ClearSelection, c.ClearAll]);

            info = uigridlayout(g, [2 1], "RowHeight", {'fit', 'fit'}, "Padding", [0 0 0 0], "RowSpacing", 2);
            c.Summary = uilabel(info, "Text", "", "WordWrap", "on", "FontColor", gray);
            c.Problems = uilabel(info, "Text", "", "WordWrap", "on", "FontColor", [0.75 0.1 0.1]);

            fg = uigridlayout(g, [1 5], "ColumnWidth", {'fit', '1x', 90, 190, 90}, "RowHeight", {30}, "Padding", [0 0 0 0]);
            probeName = "its probe";
            if opts.ProbeName ~= ""; probeName = opts.ProbeName; end
            c.SaveDefault = uibutton(fg, "Text", "Save and use for new datasets", ...
                "Enable", matlab.lang.OnOffSwitchState(~isempty(opts.OnSaveDefault)), ...
                "ButtonPushedFcn", @(~, ~) obj.saveDefault(), ...
                "Tooltip", "Save this map on the active dataset, and keep it as the default of " + probeName + ...
                ": every dataset on that probe without a local reference of its own takes it, on its own channels, " + ...
                "on Scan and when a run starts (Give new datasets their probe's default, which this ticks). " + ...
                "With no reference set, the probe's default is removed. Save the config to keep it.");
            c.SaveDefault.Layout.Column = 1;
            c.Cancel = uibutton(fg, "Text", "Cancel", "ButtonPushedFcn", @(~, ~) obj.cancel(), ...
                "Tooltip", "Close, saving nothing.");
            c.Cancel.Layout.Column = 3;
            c.SaveTicked = uibutton(fg, "Text", sprintf("Save to %d ticked dataset(s)", opts.Ticked), ...
                "Enable", matlab.lang.OnOffSwitchState(opts.Ticked > 0), "ButtonPushedFcn", @(~, ~) obj.save(true), ...
                "Tooltip", "Save this map on every dataset ticked in the Project table that is on the same probe " + ...
                "(the others are skipped and named), in their manifests.");
            c.SaveTicked.Layout.Column = 4;
            c.Save = uibutton(fg, "Text", "Save", "ButtonPushedFcn", @(~, ~) obj.save(false), ...
                "Tooltip", "Save this map on the active dataset, in its manifest.");
            c.Save.Layout.Column = 5;
            styleButton([c.SaveDefault, c.Cancel, c.SaveTicked]);
            styleButton(c.Save, "confirm");
            obj.Ctl = c;

            % the probe, drawn once the window has its size (ProbePicker writes the channels beside the sites when they fit)
            fig.Visible = matlab.lang.OnOffSwitchState(opts.Visible);
            if opts.Visible; drawnow; end
            none = "No probe map";
            if opts.Dataset ~= ""; none = opts.Dataset + " has no probe map"; end
            P.setProbe(opts.Probe, none);
            S = P.Sites;
            keep = S.channel <= obj.NumChannels;
            obj.SiteCh = reshape(S.channel(keep), 1, []);
            obj.BodyCh = cellfun(@(ch) ch(ch <= obj.NumChannels), P.BodyChannels, 'UniformOutput', false);
        end

        function load(obj, M)
            %load  The map M into the per-site model: the drawn channels' references, the rest kept as they are.
            obj.Ref = NaN(1, numel(obj.SiteCh));
            obj.Others = struct('reference', {}, 'channels', {});
            for k = 1:numel(M)
                on = ismember(obj.SiteCh, M(k).channels);
                obj.Ref(on) = M(k).reference;
                rest = setdiff(M(k).channels, obj.SiteCh);
                if ~isempty(rest)
                    obj.Others(end + 1) = struct('reference', M(k).reference, 'channels', rest);
                end
            end
            refs = unique(obj.Ref(~isnan(obj.Ref)));
            if isscalar(refs) && all(~isnan(obj.Ref)) && numel(obj.BodyCh) > 1
                obj.Scope = "probe";   % one reference over every shank
                obj.Ctl.Scope.Value = 'probe';
            end
            obj.refresh();
        end

        function M = buildMap(obj)
            %buildMap  The pending map: a group per reference, its drawn channels and the others kept.
            refs = unique([obj.Ref(~isnan(obj.Ref)), [obj.Others.reference]]);
            M = struct('reference', {}, 'channels', {});
            for r = refs
                ch = obj.SiteCh(obj.Ref == r);
                for k = find([obj.Others.reference] == r)
                    ch = [ch, obj.Others(k).channels]; %#ok<AGROW>
                end
                M(end + 1) = struct('reference', r, 'channels', unique(ch)); %#ok<AGROW>
            end
            M = EphysDataset.normalizeLocalReferenceMap(M);
        end

        function C = colorsOf(obj, refs)
            %colorsOf  A color per reference REFS: by the first shank each one serves, left to right.
            order = zeros(1, 0);
            for b = 1:numel(obj.BodyCh)
                r = obj.Ref(ismember(obj.SiteCh, obj.BodyCh{b}));
                order = [order, r(~isnan(r))]; %#ok<AGROW>
            end
            order = unique([order, [obj.Others.reference]], 'stable');
            pal = LocalReferenceDialog.Palette;
            C = zeros(numel(refs), 3);
            for k = 1:numel(refs)
                j = find(order == refs(k), 1);
                if isempty(j); j = numel(order) + k; end
                C(k, :) = pal(mod(j - 1, size(pal, 1)) + 1, :);
            end
        end

        function onProbeClick(obj, kind, v)
            obj.showMessage("");
            switch kind
                case "site"; obj.clickSite(v);
                case "body"; obj.clickShank(v);
            end
        end

        function onTableEdit(obj, e)
            obj.showMessage("");
            obj.setReference(e.Indices(1), e.NewData);
        end

        function showMessage(obj, t)
            obj.Ctl.Message.Text = string(t);
        end

        function refresh(obj)
            %refresh  The colors on the probe, the table, the summary and the problems, from the pending map.
            M = obj.buildMap();
            refs = reshape([M.reference], 1, []);
            C = obj.colorsOf(refs);
            P = obj.Picker;
            S = P.Sites;
            nB = numel(obj.BodyCh);

            % the probe: each site in its reference's color, a shank tinted when one reference serves all of it
            siteColor = NaN(height(S), 3);
            [on, j] = ismember(S.channel, obj.SiteCh);
            for i = find(on).'
                r = obj.Ref(j(i));
                if ~isnan(r); siteColor(i, :) = C(refs == r, :); end
            end
            bodyColor = NaN(nB, 3);
            bodyRef = NaN(1, nB);
            for b = 1:nB
                r = unique(obj.Ref(ismember(obj.SiteCh, obj.BodyCh{b})));
                if isscalar(r) && ~isnan(r)
                    bodyRef(b) = r;
                    bodyColor(b, :) = C(refs == r, :);
                elseif numel(r) > 1
                    bodyRef(b) = -1;   % mixed (a map made by hand)
                end
            end
            marked = struct('channel', {}, 'color', {});
            for k = 1:numel(refs)
                marked(k) = struct('channel', refs(k), 'color', C(k, :));
            end
            if height(S) > 0
                P.paintGroups(siteColor, bodyColor, marked);
                P.outlineBodies(obj.Selected);
            end

            % the table: a row per shank
            zeroed = refs(arrayfun(@(g) ismember(g.reference, g.channels), M));
            D = cell(nB, 4);
            for b = 1:nB
                D{b, 1} = char(P.BodyNames(b));
                D{b, 2} = char(EphysDataset.formatChannelList(obj.BodyCh{b}));
                D{b, 3} = bodyRef(b);
                if bodyRef(b) == -1
                    D{b, 3} = [];
                    D{b, 4} = 'mixed: its channels have different references';
                elseif isnan(bodyRef(b))
                    D{b, 3} = [];
                    D{b, 4} = 'no reference';
                else
                    D{b, 4} = char(obj.where(bodyRef(b), b, ismember(bodyRef(b), zeroed)));
                end
            end
            t = obj.Ctl.Table;
            t.Data = D;
            removeStyle(t);
            for b = find(~isnan(bodyColor(:, 1))).'
                addStyle(t, uistyle("BackgroundColor", 0.6 + 0.4 * bodyColor(b, :)), "cell", [b 3]);
            end
            for b = find(isnan(bodyRef) | bodyRef == -1)
                addStyle(t, uistyle("FontColor", [0.75 0.1 0.1]), "cell", [b 4]);
            end
            obj.Ctl.ClearSelection.Enable = matlab.lang.OnOffSwitchState(~isempty(obj.Selected));

            % the summary and what a run would say
            obj.Ctl.Summary.Text = obj.summary(M, bodyRef, zeroed);
            p = strings(1, 0);
            if ~isempty(obj.CheckFcn)
                try
                    p = reshape(string(obj.CheckFcn(M)), 1, []);
                catch ME
                    p = "The map cannot be checked: " + string(ME.message);
                end
            elseif any(isnan(obj.Ref))
                p = "No reference for channel(s) " + EphysDataset.formatChannelList(obj.SiteCh(isnan(obj.Ref))) + ...
                    ": every shank on the probe needs one.";
            end
            obj.Problems = p;
            if isempty(p)
                obj.Ctl.Problems.Text = "";
            else
                obj.Ctl.Problems.Text = "A run would stop: " + strjoin(p, " ");
            end
        end

        function s = where(obj, r, b, zero)
            %where  Where reference R of shank B sits, for the table's Note.
            home = find(cellfun(@(c) ismember(r, c), obj.BodyCh), 1);
            if isempty(home)
                s = "off the probe drawn";
            elseif home == b && zero
                s = "on this shank: becomes zeros, left out";
            elseif home == b
                s = "on this shank";
            else
                s = "on " + lower(obj.Picker.BodyNames(home));
            end
        end

        function t = summary(obj, M, bodyRef, zeroed)
            %summary  The line under the probe: the shanks with a reference, the references, the channels made zeros.
            nB = numel(obj.BodyCh);
            if height(obj.Picker.Sites) == 0
                t = "No probe to draw: the map can only be set in a script (EphysDataset.LocalReferenceMap).";
                return
            end
            what = "One reference per shank";
            if obj.Scope == "probe"; what = "One reference for the whole probe"; end
            t = sprintf("%s. %d of %d shank(s) have a reference", what, nnz(bodyRef > 0), nB);
            if isempty(M)
                t = t + ".";
            else
                t = t + sprintf("; %d reference channel(s): %s.", numel(M), ...
                    strjoin(string([M.reference]), ", "));
            end
            if ~isempty(obj.Selected)
                t = t + " Picked: " + strjoin(obj.Picker.BodyNames(obj.Selected), ", ") + ...
                    "; click the site to use as their reference.";
            end
            if ~isempty(zeroed)
                t = t + sprintf(" Channel(s) %s: a reference on its own shank, so zeros after the subtraction; " + ...
                    "every step leaves them out.", EphysDataset.formatChannelList(zeroed));
            end
            if ~isempty(obj.Others)
                t = t + sprintf(" Also referenced, off the probe drawn: channel(s) %s.", ...
                    EphysDataset.formatChannelList([obj.Others.channels]));
            end
        end

        function finish(obj)
            if obj.Done; return; end
            obj.Done = true;
            if ~isempty(obj.Fig) && isvalid(obj.Fig); delete(obj.Fig); end
        end
    end
end
