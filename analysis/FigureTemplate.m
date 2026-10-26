classdef FigureTemplate
    %FigureTemplate  Figures kept as templates of yours: a figure's settings, to apply to other figures.
    %   A template is everything a figure is set to in the config -- what it
    %   observes, its event reference, epoch window and trial selection, its
    %   page size, the grid with every panel (type, place, options, own
    %   alignment, layers, text note, overlays, waveform), the spacing, the
    %   Appearance, the looks remembered from the preview and the Sessions
    %   settings -- but what makes a figure that figure: its id (and
    %   whether the id is automatic), its title and whether it is enabled.
    %   An event reference, window or selection the figure takes from the
    %   config's Defaults stays "default": a figure the template is applied
    %   to takes them from its own config's Defaults.
    %
    %   Applying a template copies its settings into a figure once
    %   (EphysAnalysisApp.onApplyTemplate). There is no link: a template
    %   changed later reaches a figure only when it is applied again, so
    %   apply it to all the figures that should follow it at once.
    %
    %   Templates are JSON files, one per template, named by their file
    %   name, in your templates folder (folder) -- beside your plot designs
    %   (PlotDesign), in the same way. Export writes one anywhere, Import
    %   copies one into your folder (a colleague's, say).
    %
    %   Making and keeping
    %     t = FigureTemplate.fromFigure(FIG)   a figure (a Figures entry) as a template
    %     f = FigureTemplate.save(t, NAME)     into your folder (Overwrite=true to replace)
    %     T = FigureTemplate.list()            Name, Description, Summary, Saved, File, Problem
    %     t = FigureTemplate.load(NAME)        one of yours by name (any case), or a file
    %     FigureTemplate.remove(NAME)          delete one of yours
    %     n = FigureTemplate.import(FILE)      copy a template file into your folder
    %     FigureTemplate.export(NAME, FILE)    write one of yours to FILE
    %     f = FigureTemplate.folder()          your templates folder; FigureTemplate.setFolder(F)
    %   Using
    %     fig = FigureTemplate.figureOf(t)     the figure to apply (no id: automatic)
    %     I = FigureTemplate.check(t, D)       the config's checks of its figure (validate)
    %     s = FigureTemplate.summary(FIG)      "2 x 1: raster, psth; observes units"
    %
    %   A template struct has: name, description, saved (when it was made
    %   from a figure, "yyyy-MM-dd HH:mm"), from (the id of that figure),
    %   version (of its file), figure (the figure, normalized: its id "",
    %   autoId true, title "", enabled true), notes (what reading it
    %   reported, a string row) and file ("" until saved).
    %
    %   The file:
    %     {"schema": "ephys-figure-template", "version": 1, "name": ...,
    %      "description": ..., "saved": ..., "from": ..., "figure": {...}}
    %   "figure" is a Figures entry of an analysis config as Save config
    %   writes it (Inf and NaN as strings), without id, autoId, title and
    %   enabled (left out when read, if a file holds them).
    %
    %   Later versions of the code
    %   A template is read through the code of the day: its figure is
    %   normalized as a config's figures are (EphysAnalysisConfig
    %   .normalizeFigure), so a setting added since takes its default and
    %   a value is coerced as a config's would be. What the code no longer
    %   knows -- a field dropped or renamed, a template written by a newer
    %   version -- does not stop it: the field is dropped and named in the
    %   template's notes (the app shows them). Only a file that is not a
    %   template, or a value the config itself would refuse, is an error
    %   (FigureTemplate:Bad). save writes the current Version.
    %
    %   Errors: FigureTemplate:Bad (not a template), FigureTemplate:Unknown
    %   (no such template), FigureTemplate:BadName (not a file name),
    %   FigureTemplate:Exists (one of yours has the name; Overwrite=true).
    %
    %   See also EphysAnalysisApp, copyFigureSettings, PlotDesign,
    %   EphysAnalysisConfig.normalizeFigure, EphysAnalysisConfig.figureTemplates.

    properties (Constant)
        Schema = "ephys-figure-template"
        Version = 1
        PrefGroup = "FigureTemplate"        % AppPrefs: Folder (yours, when you chose one)
        % what makes a figure that figure: never held by a template, never copied by applying one
        IdentityFields = ["id" "autoId" "title" "enabled"]
    end

    methods (Static)
        %% --- making ---------------------------------------------------------------
        function t = fromFigure(fig, opts)
            %fromFigure  Figure FIG (a Figures entry) as a template: every setting but its id, title and enabled.
            %   Name= and Description= fill those fields; From= the figure's
            %   id by default. The figure is normalized (normalizeFigure),
            %   so a partial figure struct is fine.
            arguments
                fig (1,1) struct
                opts.Name (1,1) string = ""
                opts.Description (1,1) string = ""
                opts.From (1,1) string = string(missing)
            end
            from = opts.From;
            if ismissing(from)
                from = "";
                if isfield(fig, 'id'); from = string(fig.id); end
            end
            t = FigureTemplate.blank();
            t.name = opts.Name;
            t.description = opts.Description;
            t.saved = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm'));
            t.from = from;
            t.figure = EphysAnalysisConfig.normalizeFigure(withoutIdentity(fig), "figure");
        end

        function file = save(t, name, opts)
            %save  Write template T into your templates folder as NAME (the file NAME.json).
            %   A name that cannot be a file name raises
            %   FigureTemplate:BadName; one of yours that exists raises
            %   FigureTemplate:Exists unless Overwrite is true. The file is
            %   written in the current Version.
            arguments
                t (1,1) struct
                name (1,1) string
                opts.Overwrite (1,1) logical = false
            end
            name = FigureTemplate.checkName(name);
            folder = FigureTemplate.folder();
            file = string(fullfile(folder, name + ".json"));
            old = FigureTemplate.fileOf(name);
            if old ~= "" && ~opts.Overwrite
                error('FigureTemplate:Exists', 'You already have a template called "%s".', name);
            end
            if ~isfolder(folder); mkdir(folder); end
            if old ~= "" && ~strcmp(old, file); delete(old); end   % the same name in another case: one file, of the new name's case
            t.name = name;
            writeJsonFile(file, FigureTemplate.toStruct(t), NonFinite="string");
        end

        function remove(name)
            %remove  Delete your template NAME (its file).
            arguments
                name (1,1) string
            end
            file = FigureTemplate.fileOf(name);
            if file == ""
                error('FigureTemplate:Unknown', 'There is no template called "%s".', name);
            end
            delete(file);
        end

        function [name, t] = import(file, opts)
            %import  Copy template FILE into your templates folder; NAME is what it is called there.
            %   The name is the file's own name field, else its file name;
            %   Name= gives another. Overwrite=true replaces one of yours.
            %   T is the template as read (its notes say what was dropped).
            arguments
                file (1,1) string
                opts.Name (1,1) string = ""
                opts.Overwrite (1,1) logical = false
            end
            t = FigureTemplate.read(file);
            name = opts.Name;
            if name == ""
                name = t.name;
                try
                    s = readJsonFile(file);
                    if isfield(s, 'name') && (ischar(s.name) || isstring(s.name)) && strtrim(string(s.name)) ~= ""
                        name = strtrim(string(s.name));
                    end
                catch
                end
            end
            FigureTemplate.save(t, name, Overwrite=opts.Overwrite);
            name = FigureTemplate.checkName(name);
            t.name = name;
            t.file = FigureTemplate.fileOf(name);
        end

        function export(name, file)
            %export  Write your template NAME to FILE (a .json anywhere), to share it.
            %   What is written is the template as this code reads it (the
            %   current Version).
            arguments
                name (1,1) string
                file (1,1) string
            end
            t = FigureTemplate.load(name);
            writeJsonFile(file, FigureTemplate.toStruct(t), NonFinite="string");
        end

        %% --- finding -------------------------------------------------------------
        function T = list()
            %list  Your templates, by name: Name, Description, Summary, Saved, File, Problem.
            %   Summary is summary(figure); Problem is "" for a template that
            %   reads cleanly, else the reason it cannot be read or the notes
            %   reading it gave (it can still be applied then).
            Name = strings(0, 1); Description = strings(0, 1); Summary = strings(0, 1);
            Saved = strings(0, 1); File = strings(0, 1); Problem = strings(0, 1);
            d = dir(fullfile(FigureTemplate.folder(), '*.json'));
            [~, o] = sort(lower(string({d.name})));
            for f = reshape(d(o), 1, [])
                file = string(fullfile(f.folder, f.name));
                [~, stem] = fileparts(file);
                try
                    t = FigureTemplate.read(file);
                    desc = t.description;
                    shape = FigureTemplate.summary(t.figure);
                    saved = t.saved;
                    problem = strjoin(t.notes, "; ");
                catch ME
                    desc = "";
                    shape = "";
                    saved = "";
                    problem = "Not readable: " + string(ME.message);
                end
                Name(end+1, 1) = stem; %#ok<AGROW>
                Description(end+1, 1) = desc; %#ok<AGROW>
                Summary(end+1, 1) = shape; %#ok<AGROW>
                Saved(end+1, 1) = saved; %#ok<AGROW>
                File(end+1, 1) = file; %#ok<AGROW>
                Problem(end+1, 1) = problem; %#ok<AGROW>
            end
            T = table(Name, Description, Summary, Saved, File, Problem);
        end

        function t = load(name)
            %load  Your template NAME (any case), or the template in file NAME (a .json path).
            arguments
                name (1,1) string
            end
            if endsWith(name, ".json", 'IgnoreCase', true) && isfile(name)
                t = FigureTemplate.read(name);
                return
            end
            file = FigureTemplate.fileOf(name);
            if file == ""
                error('FigureTemplate:Unknown', 'There is no template called "%s".', name);
            end
            t = FigureTemplate.read(file);
        end

        function t = read(file)
            %read  The template in FILE, named by the file name.
            file = string(file);
            if ~isfile(file)
                error('FigureTemplate:Unknown', 'There is no template file %s.', file);
            end
            try
                s = readJsonFile(file);
            catch ME
                error('FigureTemplate:Bad', 'Cannot read %s: %s', file, ME.message);
            end
            [~, stem] = fileparts(file);
            t = FigureTemplate.normalize(s, stem);
            t.name = string(stem);
            t.file = file;
        end

        function f = folder()
            %folder  Your templates folder.
            %   Your choice (setFolder), else EphysFigureTemplates beside
            %   MATLAB's preferences folder (beside EphysPlotDesigns, the
            %   same for every MATLAB release). With the apps' preferences in
            %   a file (AppPrefs.useTemporary: tests), a folder beside that
            %   file.
            f = "";
            try
                if AppPrefs.ispref(FigureTemplate.PrefGroup, "Folder")
                    f = string(AppPrefs.getpref(FigureTemplate.PrefGroup, "Folder"));
                end
            catch
            end
            if isscalar(f) && ~ismissing(f) && f ~= ""; return; end
            store = AppPrefs.storeFile();
            if store ~= ""
                [p, stem] = fileparts(store);
                f = string(fullfile(p, stem + "_templates"));
            else
                f = string(fullfile(fileparts(prefdir), 'EphysFigureTemplates'));
            end
        end

        function setFolder(f)
            %setFolder  Keep your templates in folder F ("" = the default); e.g. one the lab shares.
            arguments
                f (1,1) string
            end
            if f == ""
                if AppPrefs.ispref(FigureTemplate.PrefGroup, "Folder"); AppPrefs.rmpref(FigureTemplate.PrefGroup, "Folder"); end
            else
                AppPrefs.setpref(FigureTemplate.PrefGroup, "Folder", char(f));
            end
        end

        %% --- using ---------------------------------------------------------------
        function fig = figureOf(t)
            %figureOf  The figure template T gives: its settings, with an automatic id, no title, enabled.
            fig = t.figure;
            fig.id = "";
            fig.autoId = true;
            fig.title = "";
            fig.enabled = true;
        end

        function issues = check(t, D)
            %check  The analysis config's checks (validate) of template T's figure, with Defaults D.
            %   ISSUES is validate's table (Section, Field, Severity,
            %   Message) cut to the figure's rows, its Field without the
            %   figure's id ("panels", "psth_1.options.yLim"). D defaults to
            %   a new config's Defaults.
            arguments
                t (1,1) struct
                D = []
            end
            cfg = EphysAnalysisConfig();
            if ~isempty(D); cfg.Defaults = D; end
            f = FigureTemplate.figureOf(t);
            f.id = "template";
            f.autoId = false;
            cfg.Figures = f;
            issues = cfg.validate(CheckPaths=false);
            if isempty(issues); return; end
            field = string(issues.Field);
            keep = startsWith(field, "template.") | field == "template";
            issues = issues(keep, :);
            issues.Field = extractAfter(string(issues.Field), "template.");
            issues.Field(ismissing(issues.Field)) = "";
        end

        function s = summary(fig)
            %summary  A figure's shape in a line: "2 x 1: raster, psth; observes units".
            %   With a page size of its own, and across sessions, it says so.
            types = strings(1, 0);
            if ~isempty(fig.panels); types = string([fig.panels.type]); end
            what = "no panels";
            if ~isempty(types); what = strjoin(types, ", "); end
            s = string(sprintf("%d x %d: %s; observes %s", fig.grid.rows, fig.grid.cols, what, fig.observe.data));
            if fig.size.source == "own"; s = s + sprintf(", %g x %g %s", fig.size.width, fig.size.height, fig.size.units); end
            if fig.sessions.enabled; s = s + ", across sessions"; end
        end

        function s = toStruct(t)
            %toStruct  Template T as its file holds it (the current Version; the figure without its identity).
            s = struct('schema', FigureTemplate.Schema, 'version', FigureTemplate.Version, 'name', string(t.name), ...
                'description', string(t.description), 'saved', string(t.saved), 'from', string(t.from), ...
                'figure', withoutIdentity(t.figure));
        end

        function t = normalize(s, where)
            %normalize  A template from a struct (a decoded file); FigureTemplate:Bad names WHERE.
            %   What the code does not know is dropped and said in T.notes:
            %   a newer version, unknown fields of the file or of its figure.
            arguments
                s
                where (1,1) string = "template"
            end
            if ~isstruct(s) || ~isscalar(s)
                error('FigureTemplate:Bad', '%s is not a figure template (a JSON object).', where);
            end
            if ~isfield(s, 'schema') || ~(ischar(s.schema) || isstring(s.schema)) || string(s.schema) ~= FigureTemplate.Schema
                error('FigureTemplate:Bad', '%s is not a figure template (schema "%s").', where, FigureTemplate.Schema);
            end
            if ~isfield(s, 'figure') || ~isstruct(s.figure) || ~isscalar(s.figure)
                error('FigureTemplate:Bad', '%s holds no figure.', where);
            end
            t = FigureTemplate.blank();
            if isfield(s, 'version') && isnumeric(s.version) && isscalar(s.version); t.version = double(s.version); end
            if t.version > FigureTemplate.Version
                t.notes(end+1) = sprintf("made by a newer version of the code (template version %g; this code reads %d)", ...
                    t.version, FigureTemplate.Version);
            end
            for f = ["name" "description" "saved" "from"]
                if isfield(s, f) && (ischar(s.(f)) || isstring(s.(f))) && ~isempty(s.(f)); t.(f) = strtrim(string(s.(f))); end
            end
            try
                [t.figure, unknown] = EphysAnalysisConfig.normalizeFigure(withoutIdentity(s.figure), "figure");
            catch ME
                error('FigureTemplate:Bad', '%s: %s', where, ME.message);
            end
            if ~isempty(unknown)
                t.notes(end+1) = "dropped unknown field(s) " + strjoin(unknown, ", ");
            end
            extra = setdiff(string(fieldnames(s)).', ["schema" "version" "name" "description" "saved" "from" "figure"]);
            if ~isempty(extra)
                t.notes(end+1) = "dropped unknown field(s) " + strjoin(extra, ", ");
            end
        end
    end

    methods (Static, Hidden)
        function t = blank()
            %blank  An empty template: a blank figure, nothing named.
            t = struct('name', "", 'description', "", 'saved', "", 'from', "", 'version', FigureTemplate.Version, ...
                'figure', EphysAnalysisConfig.normalizeFigure(struct(), "figure"), 'notes', strings(1, 0), 'file', "");
        end

        function name = checkName(name)
            %checkName  NAME trimmed; FigureTemplate:BadName when it cannot name a template's file.
            name = strtrim(string(name));
            if ~isscalar(name) || ismissing(name) || name == "" || ~isempty(regexp(name, '[\\/:*?"<>|]', 'once')) || startsWith(name, ".")
                error('FigureTemplate:BadName', 'A template''s name is its file name: give one without \\ / : * ? " < > |.');
            end
        end

        function file = fileOf(name)
            %fileOf  The file of your template NAME (any case), "" when there is none.
            file = "";
            name = strtrim(string(name));
            f = FigureTemplate.folder();
            if name == "" || ~isfolder(f); return; end
            d = dir(fullfile(f, '*.json'));
            d = d(strcmpi(erase(string({d.name}), ".json"), name));
            if ~isempty(d); file = string(fullfile(d(1).folder, d(1).name)); end
        end
    end
end


function fig = withoutIdentity(fig)
%withoutIdentity  FIG without the fields that make a figure that figure (FigureTemplate.IdentityFields).
drop = intersect(FigureTemplate.IdentityFields, string(fieldnames(fig)).');
if ~isempty(drop); fig = rmfield(fig, drop); end
end
