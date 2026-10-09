classdef PlotDesign
    %PlotDesign  Whole looks for the analysis plots: built in, or saved by you.
    %   A design is one look for every plot renderPlot draws: the ground the
    %   plot sits on, the group colors, the colormaps of images, and
    %   aesthetics rules (PlotAesthetics) for its components -- axes, ticks,
    %   axis labels, titles, legends, color bars, lines, marks and fills.
    %   renderPlot draws with the design you chose (a preference), then your
    %   rules for the plot's kind, then the plot's own rules, so the later
    %   win. Choosing a design redraws every plot open on screen at once.
    %
    %   Designs are JSON files, named by their file name: the built-in ones
    %   in analysis/designs, yours in your designs folder (folder). Default
    %   is no file: the plots as the renderers draw them.
    %
    %   Choosing
    %     T = PlotDesign.list()            Name, Description, Source ("built-in" | "mine"), File
    %     n = PlotDesign.currentName()     the design chosen (DefaultName when none)
    %     D = PlotDesign.current()         ... loaded (Default when it cannot be read)
    %     PlotDesign.use(NAME)             choose it; every open plot is redrawn
    %     D = PlotDesign.load(NAME)        a design by name, or from a file
    %   Making
    %     D = PlotDesign.capture(H)        the look of the plot H is part of, as a design
    %     f = PlotDesign.save(D, NAME)     into your designs folder (Overwrite=true to replace)
    %     PlotDesign.remove(NAME)          delete one of yours
    %     n = PlotDesign.import(FILE)      copy a design file into your folder
    %     f = PlotDesign.folder()          your designs folder; PlotDesign.setFolder(F)
    %   Drawing (renderPlot)
    %     R = PlotDesign.rulesFor(D, KIND) the rules D gives plots of KIND
    %     PlotDesign.paint(ROOT, D)        the ground behind the plot drawn as ROOT
    %     M = PlotDesign.colormap(SPEC, N) N colors of a colormap name or anchor colors
    %     PlotDesign.listen(OWNER, FCN)    FCN() after the chosen design changes
    %
    %   File fields (all optional):
    %     name, description
    %     background  the ground behind the plot ("" = as drawn)
    %     palette     the colors of the groups, in order
    %     single      the color of a plot with one group
    %     sequential  the colors of ordered groups (a numeric parameter with
    %                 more than two values) and an evoked butterfly's depths
    %     heat        images: heat map, probe map
    %     diverging   signed images: correlation map, auROC heat map
    %     rules       PlotAesthetics rules (role, group, property, value) for
    %                 every plot
    %     kinds       rules for one kind of plot, drawn after the common ones:
    %                 {"heatmap": [...], "corrmap": [...]}
    %   A color is a name, #rrggbb or [r g b]; a colormap is the name of a
    %   colormap function or a list of colors, spread evenly from the
    %   lowest value to the highest. A FontName may list fallbacks
    %   ("Palatino Linotype, Georgia"): the first one installed is used. A
    %   plot's own Appearance settings choose the colors only when its group
    %   colors are "lines" and its heat colors "auto".
    %
    %   See also PlotAesthetics, renderPlot, PlotAestheticsDialog.

    properties (Constant)
        Schema = "ephys-plot-design"
        Version = 1
        DefaultName = "Default"
        PrefGroup = "PlotDesign"            % AppPrefs: Design (the chosen name), Folder (yours)
        MenuTag = "PlotDesignMenu"
    end

    methods (Static)
        %% --- choosing ------------------------------------------------------------
        function D = none()
            %none  The Default design: nothing changed (the renderers' own look).
            D = struct('name', PlotDesign.DefaultName, ...
                'description', "The plots as the renderers draw them.", ...
                'file', "", 'source', "built-in", 'background', [], 'palette', zeros(0, 3), 'single', [], ...
                'sequential', [], 'heat', [], 'diverging', [], 'rules', PlotAesthetics.emptyRules(), 'kinds', struct());
        end

        function T = list()
            %list  Every design: Default, the built-in ones, then yours (by name).
            %   A file of yours named like a built-in design is left out; one
            %   that cannot be read is listed with the reason as its
            %   description.
            Name = PlotDesign.DefaultName;
            Description = PlotDesign.none().description;
            Source = "built-in";
            File = "";
            sources = ["built-in" "mine"];
            folders = [PlotDesign.builtinFolder() PlotDesign.folder()];
            for s = 1:2
                d = dir(fullfile(folders(s), '*.json'));
                [~, o] = sort(lower(string({d.name})));
                for f = reshape(d(o), 1, [])
                    file = string(fullfile(f.folder, f.name));
                    [~, stem] = fileparts(file);
                    if any(strcmpi(Name, stem)); continue; end
                    try
                        D = PlotDesign.read(file);
                        desc = D.description;
                    catch ME
                        desc = "Not readable: " + string(ME.message);
                    end
                    Name(end+1, 1) = stem; %#ok<AGROW>
                    Description(end+1, 1) = desc; %#ok<AGROW>
                    Source(end+1, 1) = sources(s); %#ok<AGROW>
                    File(end+1, 1) = file; %#ok<AGROW>
                end
            end
            T = table(Name, Description, Source, File);
        end

        function name = currentName()
            %currentName  The name of the design you chose (DefaultName when none).
            name = PlotDesign.DefaultName;
            try
                if AppPrefs.ispref(PlotDesign.PrefGroup, "Design")
                    name = string(AppPrefs.getpref(PlotDesign.PrefGroup, "Design"));
                end
            catch
            end
            if ~isscalar(name) || ismissing(name) || name == ""; name = PlotDesign.DefaultName; end
        end

        function D = current()
            %current  The design you chose, loaded.
            %   One that cannot be read gives Default and the warning
            %   PlotDesign:Unusable (once per name and reason).
            persistent warned
            name = PlotDesign.currentName();
            try
                D = PlotDesign.load(name);
            catch ME
                key = name + "|" + string(ME.message);
                if ~isequal(warned, key)
                    warned = key;
                    warning('PlotDesign:Unusable', 'Your plot design "%s" cannot be used (%s): the plots are drawn as by default.', ...
                        name, ME.message);
                end
                D = PlotDesign.none();
            end
        end

        function use(name)
            %use  Choose design NAME for every plot, and redraw the plots open on screen.
            %   Raises PlotDesign:Unknown or PlotDesign:Bad when it cannot be
            %   read (and nothing changes).
            arguments
                name (1,1) string
            end
            D = PlotDesign.load(name);
            AppPrefs.setpref(PlotDesign.PrefGroup, "Design", char(D.name));
            PlotDesign.redrawAll();
            PlotDesign.notifyChanged();
        end

        function D = load(name)
            %load  The design called NAME (any case), or the design in file NAME.
            arguments
                name (1,1) string
            end
            if name == "" || strcmpi(name, PlotDesign.DefaultName)
                D = PlotDesign.none();
                return
            end
            if endsWith(name, ".json", 'IgnoreCase', true) && isfile(name)
                D = PlotDesign.read(name);
                return
            end
            file = "";
            for f = [PlotDesign.builtinFolder() PlotDesign.folder()]
                d = dir(fullfile(f, name + ".json"));   % one file, not the folder (a shared one may be slow); its name as stored
                if isempty(d)   % a case-sensitive file system: look through the folder
                    d = dir(fullfile(f, '*.json'));
                    d = d(strcmpi(erase(string({d.name}), ".json"), name));
                end
                if ~isempty(d)
                    file = string(fullfile(d(1).folder, d(1).name));
                    break
                end
            end
            if file == ""
                error('PlotDesign:Unknown', 'There is no plot design called "%s".', name);
            end
            D = PlotDesign.read(file);
        end

        %% --- making --------------------------------------------------------------
        function D = capture(h, opts)
            %capture  The look of a drawn plot, as a design.
            %   D = PlotDesign.capture(H) takes the plot H belongs to (a
            %   component of it, or the target renderPlot drew into) and reads
            %   every property the aesthetics editor offers, for every
            %   component: a value all the components of a role share becomes
            %   a rule for that role (every group). The colors the groups are
            %   drawn in become the palette (or, for ordered groups, the
            %   sequential colors; one group: single), the ground becomes the
            %   background and an image's colormap its heat or diverging
            %   colors. A color that differs from group to group belongs to
            %   the palette, not a rule. What the plot does not show comes from
            %   Base (default: the design it was drawn with). From a heat map,
            %   probe map or correlation map, whose axes are drawn their own
            %   way, the rules are kept for that kind of plot only (kinds);
            %   from any other plot, for every plot.
            %
            %   Options: Base (a design or a name), Name, Description.
            arguments
                h
                opts.Base = []
                opts.Name (1,1) string = ""
                opts.Description (1,1) string = ""
            end
            ctx = PlotDesign.contextIn(h);
            if isempty(ctx)
                error('PlotDesign:NoPlot', 'This is not part of a plot drawn by renderPlot.');
            end
            base = opts.Base;
            if isempty(base)
                base = PlotDesign.none();
                if isfield(ctx, 'design') && isstruct(ctx.design); base = ctx.design; end
            elseif ~isstruct(base)
                base = PlotDesign.load(string(base));
            end
            D = base;
            D.name = opts.Name;
            D.description = opts.Description;
            D.file = "";
            D.source = "mine";

            T = PlotAesthetics.components(ctx.root);
            T = T(T.Role ~= "" & ~ismember(T.Role, ["overlayLine" "overlayRegion"]), :);   % a plot's overlays are its own, not the design's
            captured = captureRules(T);
            kind = string(ctx.kind);
            if ismember(kind, ["heatmap" "corrmap" "probemap"])
                own = PlotAesthetics.emptyRules();
                if isfield(D.kinds, kind); own = D.kinds.(kind); end
                D.kinds.(kind) = PlotAesthetics.mergeRules(own, captured);
            else
                D.rules = PlotAesthetics.mergeRules(D.rules, captured);
                if isfield(D.kinds, kind) && ~isempty(D.kinds.(kind)) && ~isempty(captured)
                    % The kind's own rules come after the common ones: drop those the capture covers.
                    own = D.kinds.(kind);
                    covered = ismember([own.role] + "|" + [own.property], [captured.role] + "|" + [captured.property]);
                    D.kinds.(kind) = own(~covered);
                end
            end

            [ground, prop] = groundOf(ctx.root);
            if ~isempty(ground); D.background = reshape(double(validatecolor(get(ground, prop))), 1, 3); end

            cols = groupColors(T);
            n = size(cols, 1);
            ordinal = isfield(ctx, 'ordinal') && ctx.ordinal;
            if ordinal && n > 2
                D.sequential = cols;
            elseif n == 1
                D.single = cols;
            elseif n > 1
                D.palette = [cols; D.palette(n+1:end, :)];
            end

            mapField = "";
            if isfield(ctx, 'mapField'); mapField = string(ctx.mapField); end
            if mapField ~= ""
                ims = T.Handles(ismember(T.Role, ["image" "sites"]));
                if ~isempty(ims)
                    ax = ancestor(ims{1}(1), 'axes');
                    cm = ax.Colormap;
                    D.(mapField) = cm(round(linspace(1, size(cm, 1), min(size(cm, 1), 11))), :);
                end
            end
        end

        function file = save(D, name, opts)
            %save  Write design D into your designs folder as NAME (the file NAME.json).
            %   A name of a built-in design, or one that cannot be a file
            %   name, raises PlotDesign:BadName; one of yours that exists
            %   raises PlotDesign:Exists unless Overwrite is true.
            arguments
                D (1,1) struct
                name (1,1) string
                opts.Overwrite (1,1) logical = false
            end
            name = PlotDesign.checkName(name);
            folder = PlotDesign.folder();
            file = string(fullfile(folder, name + ".json"));
            if isfile(file) && ~opts.Overwrite
                error('PlotDesign:Exists', 'You already have a design called "%s".', name);
            end
            if ~isfolder(folder); mkdir(folder); end
            D.name = name;
            writeJsonFile(file, PlotDesign.toStruct(D));
            PlotDesign.cache(file, []);
            PlotDesign.notifyChanged();
        end

        function remove(name)
            %remove  Delete your design NAME (the built-in ones stay); Default is chosen if it was.
            arguments
                name (1,1) string
            end
            D = PlotDesign.load(name);
            if D.source ~= "mine"
                error('PlotDesign:BuiltIn', '"%s" is a built-in design: it cannot be deleted.', D.name);
            end
            delete(D.file);
            PlotDesign.cache(D.file, []);
            if strcmpi(PlotDesign.currentName(), D.name)
                PlotDesign.use(PlotDesign.DefaultName);
            else
                PlotDesign.notifyChanged();
            end
        end

        function name = import(file, opts)
            %import  Copy design FILE into your designs folder; NAME is what it is called there.
            %   The name is the file's own name field, else its file name;
            %   Name= gives another. Overwrite=true replaces one of yours.
            arguments
                file (1,1) string
                opts.Name (1,1) string = ""
                opts.Overwrite (1,1) logical = false
            end
            try
                s = jsondecode(fileread(file));
            catch ME
                error('PlotDesign:Bad', 'Cannot read %s as a design: %s', file, ME.message);
            end
            D = PlotDesign.normalize(s, file);
            name = opts.Name;
            if name == ""
                [~, name] = fileparts(file);
                if isfield(s, 'name') && (ischar(s.name) || isstring(s.name)) && strtrim(string(s.name)) ~= ""
                    name = strtrim(string(s.name));
                end
            end
            PlotDesign.save(D, name, Overwrite=opts.Overwrite);
            name = PlotDesign.checkName(name);
        end

        function f = folder()
            %folder  Your designs folder.
            %   Your choice (setFolder), else EphysPlotDesigns beside MATLAB's
            %   preferences folder (the same for every MATLAB release). With
            %   the apps' preferences in a file (AppPrefs.useTemporary: tests),
            %   a folder beside that file.
            f = "";
            try
                if AppPrefs.ispref(PlotDesign.PrefGroup, "Folder")
                    f = string(AppPrefs.getpref(PlotDesign.PrefGroup, "Folder"));
                end
            catch
            end
            if isscalar(f) && ~ismissing(f) && f ~= ""; return; end
            store = AppPrefs.storeFile();
            if store ~= ""
                [p, stem] = fileparts(store);
                f = string(fullfile(p, stem + "_designs"));
            else
                f = string(fullfile(fileparts(prefdir), 'EphysPlotDesigns'));
            end
        end

        function setFolder(f)
            %setFolder  Keep your designs in folder F ("" = the default); e.g. one the lab shares.
            arguments
                f (1,1) string
            end
            if f == ""
                if AppPrefs.ispref(PlotDesign.PrefGroup, "Folder"); AppPrefs.rmpref(PlotDesign.PrefGroup, "Folder"); end
            else
                AppPrefs.setpref(PlotDesign.PrefGroup, "Folder", char(f));
            end
            PlotDesign.notifyChanged();
        end

        %% --- drawing -------------------------------------------------------------
        function R = rulesFor(D, kind)
            %rulesFor  The rules design D gives plots of KIND: the common ones, then the kind's.
            R = D.rules;
            kind = string(kind);
            if isvarname(kind) && isfield(D.kinds, kind)
                R = [R D.kinds.(kind)];
            end
        end

        function paint(root, D)
            %paint  Color the ground behind the plot drawn as ROOT with D's background.
            %   The ground is the figure, panel, tab or grid the plot's layout
            %   sits in (a plot drawn into an axes has none). Its color before
            %   the first design is remembered and comes back with a design
            %   that has no background.
            [obj, prop] = groundOf(root);
            if isempty(obj); return; end
            key = 'PlotDesignGround';
            if ~isappdata(obj, key); setappdata(obj, key, get(obj, prop)); end
            if isempty(D.background)
                set(obj, prop, getappdata(obj, key));
            else
                set(obj, prop, D.background);
            end
        end

        function M = colormap(spec, n)
            %colormap  N colors (N x 3) of a colormap function's name or of anchor colors (K x 3, spread evenly).
            if nargin < 2; n = 256; end
            if isstring(spec) || ischar(spec)
                M = feval(char(spec), n);
            else
                M = interp1(linspace(0, 1, size(spec, 1)), spec, linspace(0, 1, n));
            end
        end

        function listen(owner, fcn)
            %listen  Call FCN() whenever the chosen design or the list changes, while OWNER exists.
            L = PlotDesign.listeners();
            L(end+1) = struct('owner', owner, 'fcn', fcn);
            setappdata(groot, 'PlotDesignListeners', L);
        end

        function track(target)
            %track  Redraw the plot renderPlot drew into TARGET when the design changes (enableEditing).
            t = PlotDesign.liveTargets();
            if ~any(t == target)
                setappdata(groot, 'PlotDesignTargets', [t target]);
            end
        end

        function n = redrawAll()
            %redrawAll  Redraw every plot on screen that follows the chosen design; N = how many.
            n = 0;
            for t = PlotDesign.liveTargets()
                ctx = getappdata(t, PlotAesthetics.ContextKey);
                if ~isfield(ctx, 'redraw') || ~isfield(ctx, 'followsDesign') || ~ctx.followsDesign; continue; end
                try
                    ctx.redraw(ctx.plotRules);
                    n = n + 1;
                catch ME
                    warning('PlotDesign:Redraw', 'A plot could not be redrawn in the new design: %s', ME.message);
                end
            end
        end

        function s = toStruct(D)
            %toStruct  Design D as its file holds it (colors as #rrggbb).
            s = struct('schema', PlotDesign.Schema, 'version', PlotDesign.Version, 'name', D.name, ...
                'description', D.description, 'background', hexOf(D.background), 'palette', {hexList(D.palette)}, ...
                'single', hexOf(D.single), 'sequential', {mapOut(D.sequential)}, 'heat', {mapOut(D.heat)}, ...
                'diverging', {mapOut(D.diverging)}, 'rules', {rulesOut(D.rules)}, 'kinds', struct());
            for k = string(fieldnames(D.kinds)).'
                s.kinds.(k) = rulesOut(D.kinds.(k));
            end
        end

        function D = normalize(s, where)
            %normalize  A design from a struct (a decoded file); PlotDesign:Bad names WHERE.
            arguments
                s
                where (1,1) string = "design"
            end
            if ~isstruct(s) || ~isscalar(s)
                error('PlotDesign:Bad', '%s is not a design (a JSON object).', where);
            end
            D = PlotDesign.none();
            D.name = "";
            D.description = "";
            if isfield(s, 'name'); D.name = textOf(s.name, where + ".name"); end
            if isfield(s, 'description'); D.description = textOf(s.description, where + ".description"); end
            if isfield(s, 'background'); D.background = colorOf(s.background, where + ".background"); end
            if isfield(s, 'palette'); D.palette = colorList(s.palette, where + ".palette", 0); end
            if isfield(s, 'single'); D.single = colorOf(s.single, where + ".single"); end
            for f = ["sequential" "heat" "diverging"]
                if isfield(s, f); D.(f) = mapOf(s.(f), where + "." + f); end
            end
            if isfield(s, 'rules'); D.rules = designRules(s.rules, where + ".rules"); end
            if isfield(s, 'kinds') && ~isempty(s.kinds)
                if ~isstruct(s.kinds) || ~isscalar(s.kinds)
                    error('PlotDesign:Bad', '%s.kinds is an object of rule lists by plot kind.', where);
                end
                for k = string(fieldnames(s.kinds)).'
                    if ~ismember(k, EphysAnalysisConfig.Kinds)
                        error('PlotDesign:Bad', '%s.kinds: "%s" is not a plot kind (%s).', where, k, ...
                            strjoin(EphysAnalysisConfig.Kinds, ", "));
                    end
                    D.kinds.(k) = designRules(s.kinds.(k), where + ".kinds." + k);
                end
            end
        end

        function D = read(file)
            %read  The design in FILE (cached until the file changes); named by the file name.
            file = string(file);
            info = dir(file);
            if isempty(info)
                error('PlotDesign:Unknown', 'There is no design file %s.', file);
            end
            stamp = [info.datenum info.bytes];
            hit = PlotDesign.cache(file);
            if ~isempty(hit) && isequal(hit.stamp, stamp)
                D = hit.D;
                return
            end
            try
                s = jsondecode(fileread(file));
            catch ME
                error('PlotDesign:Bad', 'Cannot read %s: %s', file, ME.message);
            end
            [~, stem] = fileparts(file);
            D = PlotDesign.normalize(s, stem);
            D.name = string(stem);
            D.file = file;
            D.source = "mine";
            if startsWith(file, PlotDesign.builtinFolder()); D.source = "built-in"; end
            PlotDesign.cache(file, struct('stamp', stamp, 'D', D));
        end
    end

    methods (Static, Hidden)
        function f = builtinFolder()
            %builtinFolder  The built-in designs (analysis/designs).
            f = string(fullfile(fileparts(mfilename('fullpath')), 'designs'));
        end

        function name = checkName(name)
            %checkName  NAME trimmed; PlotDesign:BadName when it cannot name one of your designs.
            name = strtrim(string(name));
            if name == "" || ~isempty(regexp(name, '[\\/:*?"<>|]', 'once')) || startsWith(name, ".")
                error('PlotDesign:BadName', 'A design''s name is its file name: give one without \\ / : * ? " < > |.');
            end
            builtin = [PlotDesign.DefaultName erase(string({dir(fullfile(PlotDesign.builtinFolder(), '*.json')).name}), ".json")];
            if any(strcmpi(builtin, name))
                error('PlotDesign:BadName', '"%s" is a built-in design: give yours another name.', name);
            end
        end

        function fillMenu(menu, h)
            %fillMenu  The Design submenu of a plot's right-click menu: every design, then save.
            delete(menu.Children);
            T = PlotDesign.list();
            cur = PlotDesign.currentName();
            for k = 1:height(T)
                name = T.Name(k);
                uimenu(menu, 'Text', char(name), 'Checked', matlab.lang.OnOffSwitchState(strcmpi(name, cur)), ...
                    'Separator', matlab.lang.OnOffSwitchState(k > 1 && T.Source(k) ~= T.Source(k - 1)), ...
                    'Tooltip', char(T.Description(k)), 'MenuSelectedFcn', @(~, ~) PlotDesign.useFrom(h, name));
            end
            uimenu(menu, 'Text', 'Save this look as a design...', 'Separator', 'on', ...
                'MenuSelectedFcn', @(~, ~) PlotDesign.saveFrom(h));
        end

        function useFrom(h, name)
            %useFrom  A Design menu item: choose NAME, or say why not over H's figure.
            try
                PlotDesign.use(name);
            catch ME
                alertOver(h, ME.message);
            end
        end

        function saveFrom(h, name, description)
            %saveFrom  Save the look of H's plot as one of your designs, and choose it.
            %   Asks for the name and description over H's figure unless
            %   given; asks before replacing a design of yours.
            try
                fig = ancestor(h, 'figure');
                if nargin < 2
                    [name, description, ok] = PlotDesign.askName(fig);
                    if ~ok; return; end
                end
                D = PlotDesign.capture(h, Name=name, Description=description);
                PlotDesign.save(D, name, Overwrite=true);
                PlotDesign.use(PlotDesign.checkName(name));
            catch ME
                alertOver(h, ME.message);
            end
        end

        function [name, description, ok] = askName(fig, name, description)
            %askName  Ask for a new design's name and description in a small modal window over FIG.
            %   OK is false when it was canceled. A name of yours that exists
            %   is replaced only when the user agrees.
            if nargin < 2; name = ""; end
            if nargin < 3; description = ""; end
            [name, description, ok] = askDesignName(fig, name, description);
        end

        function hit = cache(file, entry)
            %cache  Read designs by file: cache(FILE) looks one up, cache(FILE, ENTRY) keeps ([] drops) it.
            persistent C
            if isempty(C); C = containers.Map('KeyType', 'char', 'ValueType', 'any'); end
            key = char(lower(string(file)));
            hit = [];
            if nargin > 1
                if isempty(entry)
                    if isKey(C, key); remove(C, key); end
                else
                    C(key) = entry;
                end
            elseif isKey(C, key)
                hit = C(key);
            end
        end

        function t = liveTargets()
            %liveTargets  The targets of the plots on screen (the ones renderPlot made editable).
            t = getappdata(groot, 'PlotDesignTargets');
            if isempty(t); t = gobjects(1, 0); end
            t = t(isgraphics(t));
            t = t(arrayfun(@(x) isappdata(x, PlotAesthetics.ContextKey), t));
            t = reshape(t, 1, []);
            setappdata(groot, 'PlotDesignTargets', t);
        end

        function L = listeners()
            %listeners  The listen() calls whose owner still exists.
            L = getappdata(groot, 'PlotDesignListeners');
            if isempty(L); L = struct('owner', {}, 'fcn', {}); end
            L = L(arrayfun(@(x) isvalid(x.owner), L));
        end

        function notifyChanged()
            %notifyChanged  Tell the listeners the chosen design or the list changed.
            L = PlotDesign.listeners();
            setappdata(groot, 'PlotDesignListeners', L);
            for k = 1:numel(L)
                try
                    L(k).fcn();
                catch ME
                    warning('PlotDesign:Listener', 'A design listener failed: %s', ME.message);
                end
            end
        end

        function ctx = contextIn(h)
            %contextIn  The editing context of the plot H is part of, or of the plot drawn into H.
            ctx = PlotAesthetics.contextOf(h);
            if ~isempty(ctx) || ~isgraphics(h); return; end
            o = findobj(h, '-function', @(x) isappdata(x, PlotAesthetics.ContextKey));
            if ~isempty(o); ctx = PlotAesthetics.contextOf(o(1)); end
        end
    end
end


%% --- capture -----------------------------------------------------------------
function R = captureRules(T)
%captureRules  A rule (every group) for each property all the components of a role share.
%   Skipped: the legend's place (the plot's Legend settings decide it), a
%   colormap (the design's heat colors), widths in x units, a color that
%   is the group's own (it differs from group to group, or there is only
%   one group to tell), and the color of a waveform's spikes (an [r g b]
%   rule would drop their transparency).
skip = ["Colormap" "Location" "Orientation" "NumColumns" "BoxWidth" "BarWidth"];
C = PlotAesthetics.catalog();
R = PlotAesthetics.emptyRules();
for role = unique(T.Role, 'stable').'
    rows = find(T.Role == role);
    hs = gobjects(1, 0);
    grp = strings(1, 0);
    for r = rows.'
        x = reshape(T.Handles{r}, 1, []);
        x = x(isgraphics(x));
        hs = [hs x]; %#ok<AGROW>
        grp = [grp repmat(T.Group(r), 1, numel(x))]; %#ok<AGROW>
    end
    if isempty(hs); continue; end
    nGroups = numel(unique(grp(grp ~= "")));
    grouped = nGroups > 0;
    names = strings(1, 0);
    for k = 1:numel(hs)
        p = PlotAesthetics.editableProperties(hs(k));
        names = [names setdiff([p.Name], names, 'stable')]; %#ok<AGROW>
    end
    for nm = setdiff(names, skip, 'stable')
        if role == "waveSpikes" && nm == "Color"; continue; end
        has = arrayfun(@(o) PlotAesthetics.hasProperty(o, nm), hs);
        if ~any(has); continue; end
        vals = arrayfun(@(o) PlotAesthetics.getValue(o, nm), hs(has), 'UniformOutput', false);
        if ~all(cellfun(@(v) isequaln(v, vals{1}), vals)); continue; end
        v = vals{1};
        if C.(nm).Type == "color" && isnumeric(v) && grouped && numel(unique(grp(has))) < 2
            continue   % a group's own color: the palette's
        end
        try
            v = PlotAesthetics.normalizeRules(struct('role', role, 'property', nm, 'value', v)).value;
        catch
            continue   % not a value a rule can hold
        end
        R(end+1) = struct('role', role, 'group', "", 'property', nm, 'value', v); %#ok<AGROW>
    end
end
end


function cols = groupColors(T)
%groupColors  The color each group is drawn in, groups in the order they are drawn.
roles = ["rate" "rateFill" "trace" "curve" "bar" "points" "box" "swarm" "violin" "behaviorMean"];
T = T(ismember(T.Role, roles) & T.Group ~= "", :);
cols = zeros(0, 3);
for g = unique(T.Group, 'stable').'
    hs = [T.Handles{T.Group == g}];
    c = [];
    for h = reshape(hs, 1, [])
        order = ["Color" "FaceColor" "BoxFaceColor" "MarkerFaceColor" "CData" "MarkerEdgeColor"];
        if strcmp(h.Tag, 'behaviorMean'); order = ["MarkerFaceColor" order]; end   % its line is a darker edge
        for nm = order
            if isprop(h, nm)
                v = get(h, nm);
                if isnumeric(v) && numel(v) == 3; c = reshape(double(v), 1, 3); break; end
            end
        end
        if ~isempty(c); break; end
    end
    if ~isempty(c); cols(end+1, :) = c; end %#ok<AGROW>
end
end


%% --- drawing -----------------------------------------------------------------
function [obj, prop] = groundOf(root)
%groundOf  The figure, panel, tab or grid behind the plot's outer layout, and its color property.
obj = [];
prop = '';
if isempty(root) || ~isgraphics(root) || ~isa(root, 'matlab.graphics.layout.TiledChartLayout'); return; end
p = root.Parent;
while isa(p, 'matlab.graphics.layout.TiledChartLayout'); p = p.Parent; end
if isa(p, 'matlab.ui.Figure')
    obj = p; prop = 'Color';
elseif isprop(p, 'BackgroundColor')
    obj = p; prop = 'BackgroundColor';
end
end


function alertOver(h, msg)
%alertOver  Show MSG over H's figure (or as a warning when there is none).
fig = [];
if isgraphics(h); fig = ancestor(h, 'figure'); end
if isempty(fig)
    warning('PlotDesign:Failed', '%s', msg);
else
    uialert(fig, msg, 'Plot design');
end
end


%% --- file fields -------------------------------------------------------------
function R = designRules(v, where)
%designRules  Rules from a file: colors as text become [r g b]; a FontName list picks an installed font.
R = PlotAesthetics.normalizeRules(v, where);
C = PlotAesthetics.catalog();
for k = 1:numel(R)
    v = R(k).value;
    if C.(R(k).property).Type == "color" && isstring(v)
        [c, ok] = PlotAesthetics.parseColor(v);
        if ~ok
            error('PlotDesign:Bad', '%s(%d): "%s" is not a color.', where, k, v);
        end
        R(k).value = c;
    elseif R(k).property == "FontName" && isstring(v)
        R(k).value = pickFont(v);
    end
end
end


function f = pickFont(v)
%pickFont  The first installed font of a comma-separated list (the last when none is).
names = strtrim(split(v, ","));
names = names(names ~= "");
if numel(names) < 2
    f = strtrim(v);
    return
end
persistent installed
if isempty(installed)
    try
        installed = lower(string(listfonts));
    catch
        installed = strings(0, 1);
    end
end
f = names(end);
for n = names.'
    if any(installed == lower(n)); f = n; return; end
end
end


function s = textOf(v, where)
if ischar(v) || (isstring(v) && isscalar(v))
    s = string(v);
elseif isempty(v)
    s = "";
else
    error('PlotDesign:Bad', '%s must be text.', where);
end
end


function c = colorOf(v, where)
%colorOf  A color field: [] when empty ("" or []), else [r g b].
c = [];
if isempty(v) || ((ischar(v) || isstring(v)) && strtrim(string(v)) == ""); return; end
if isnumeric(v) && numel(v) == 3
    c = reshape(double(v), 1, 3);
    if any(c > 1); c = c / 255; end
    return
end
if ischar(v) || (isstring(v) && isscalar(v))
    [c, ok] = PlotAesthetics.parseColor(v);
    if ok && isnumeric(c); return; end
end
error('PlotDesign:Bad', '%s must be a color: a name, #rrggbb or [r g b].', where);
end


function C = colorList(v, where, atLeast)
%colorList  A list of colors (text, or rows of [r g b]) as N x 3.
C = zeros(0, 3);
if isempty(v); return; end
if isnumeric(v) && size(v, 2) == 3
    C = double(v);
    if any(C(:) > 1); C = C / 255; end
else
    if ischar(v) || isstring(v); v = cellstr(v); end
    if ~iscell(v)
        error('PlotDesign:Bad', '%s must be a list of colors.', where);
    end
    C = zeros(numel(v), 3);
    for k = 1:numel(v)
        C(k, :) = colorOf(v{k}, sprintf('%s(%d)', where, k));
    end
end
if size(C, 1) < atLeast
    error('PlotDesign:Bad', '%s needs at least %d colors.', where, atLeast);
end
end


function m = mapOf(v, where)
%mapOf  A colormap field: [] when empty, a colormap function's name, or anchor colors (K x 3).
m = [];
if isempty(v); return; end
if (ischar(v) && isrow(v)) || (isstring(v) && isscalar(v))
    v = strtrim(string(v));
    if v == ""; return; end
    if ~startsWith(v, "#")
        if ~any(exist(char(v)) == [2 3 5 6]) %#ok<EXIST>
            error('PlotDesign:Bad', '%s: "%s" is not a colormap function.', where, v);
        end
        m = v;
        return
    end
end
m = colorList(v, where, 2);
end


%% --- writing -----------------------------------------------------------------
function s = hexOf(c)
if isempty(c); s = ""; else; s = PlotAesthetics.valueText(c); end
end


function c = hexList(C)
c = cell(1, size(C, 1));
for k = 1:size(C, 1); c{k} = char(hexOf(C(k, :))); end
end


function v = mapOut(m)
if isempty(m)
    v = "";
elseif isstring(m) || ischar(m)
    v = string(m);
else
    v = hexList(m);
end
end


function R = rulesOut(R)
%rulesOut  Rules as a file holds them: colors as #rrggbb.
C = PlotAesthetics.catalog();
for k = 1:numel(R)
    if C.(R(k).property).Type == "color" && isnumeric(R(k).value) && numel(R(k).value) == 3
        R(k).value = PlotAesthetics.valueText(R(k).value);
    end
end
if isempty(R); R = {}; end
end
