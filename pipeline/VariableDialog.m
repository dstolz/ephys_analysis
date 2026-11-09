classdef VariableDialog < handle
    % VariableDialog  Edit the variables of one or more datasets in a grid: a row per dataset, a column per variable.
    %   A small modal window over a set of targets (datasets). The grid has
    %   a row per target and a column per variable; a cell holds that
    %   target's value (a number or text), and an empty cell means the
    %   target does not have the variable. Click a column to edit its
    %   definition on the right: the label people read ("Probe Depth"), the
    %   name data structures use (probeDepth), the units and a
    %   description, shared by every target. While the name is left alone
    %   it follows the label (DatasetVariables.suggestName); once you type
    %   a name of your own it stays. Every rule is DatasetVariables'; the
    %   window only holds the pending edit, and nothing reaches the targets
    %   until OK.
    %
    %     dlg = VariableDialog({ds.Variables}, DatasetVariables.vocabulary({P.Datasets.Variables}), ...
    %         Labels=[ds.Name], Parent=app.Fig, OnDone=@(r) apply(r));
    %
    %   SETS is a cell array of the targets' current sets (DatasetVariables:
    %   a struct of entries, struct() for none), one per target.
    %   VOCABULARY is the variables in use elsewhere
    %   (DatasetVariables.vocabulary), offered under Use existing so one
    %   variable keeps one name, label and units across datasets. Options:
    %     Labels   string array naming the targets, one per set (the grid's
    %              rows; default "dataset 1", ...)
    %     OnDone   called once as OnDone(R) when the window closes
    %     Parent   the uifigure to center on ([] = none)
    %     Visible  false builds the window hidden (tests)
    %     Noun     what a target is, for the texts (default "dataset")
    %
    %   The window is modal but does not block (no uiwait): the caller
    %   writes the result in OnDone. R is [] when the window is canceled,
    %   closed, or OK changes no target; otherwise a struct:
    %     sets     1 x M cell, the new set of each target (in SETS order;
    %              entries without created/updated: the writer stamps them)
    %     renamed  1 x M cell, each a [k x 2] string (old name, new name)
    %              of the target's variables renamed
    %     changed  1 x M logical: the targets whose set changed
    %   so the caller writes R.sets{k} with Renamed=R.renamed{k} where
    %   R.changed(k) (EphysDataset.setVariables, writeManifestVariables).
    %
    %   The Type of a variable is Automatic (a number when every value
    %   typed reads as a number, else text), Number or Text. A value the
    %   window was opened with stays as it was (a text "007" stays text)
    %   until it is typed again or the type is chosen by hand.
    %
    %   Properties (read-only): Fig, Ctl (the controls), Defs (the
    %   variables shown, one per column), Cells (the grid's text, M x K),
    %   Current (the column whose definition is shown, 0 for none),
    %   ErrorText. Methods, the same paths as the controls: newVariable,
    %   useExisting, removeVariable, select, setLabel, setName, setUnits,
    %   setType, setDescription, setValue, fillColumn, clearColumn, ok,
    %   cancel. VariableDialog.describe(ADDED, LABELS) words what an OK
    %   did for a status line. Opened by EphysPipelineApp (onEditVariables),
    %   EphysFigGenApp (Data tab) and DatasetBrowser (editVariables).
    %
    %   See also DatasetVariables, writeManifestVariables, TagDialog.

    properties (SetAccess = private)
        Fig                          % the uifigure
        Ctl = struct()               % the controls
        Defs                         % struct column, one per grid column (see emptyDef)
        Cells string = strings(0, 0) % M x K: the text of each cell ("" = not set)
        Current (1,1) double = 0     % the column whose definition is shown (0 = none)
    end

    properties
        OnDone = []                  % called once as OnDone(result) when the window closes
    end

    properties (Dependent)
        ErrorText                    % the inline message ("" when none)
    end

    properties (Access = private)
        Sets = {}                    % 1 x M cell, the targets' sets as given
        Labels (1,:) string          % 1 x M names of the targets
        Vocabulary                   % struct column, DatasetVariables.vocabulary
        Noun (1,1) string = "dataset"
        Original = {}                % M x K cell: the value each cell was opened with ([] when none)
        Edited logical = false(0, 0) % M x K: typed since the window opened
        NextId (1,1) double = 1
        Done (1,1) logical = false
    end

    properties (Constant, Access = private)
        ErrorColor = [0.75 0.1 0.1]
        NoticeColor = [0.35 0.35 0.35]
        TypeItems = {'Automatic', 'Number', 'Text'}
        TypeData = {'auto', 'number', 'text'}
    end

    methods
        function obj = VariableDialog(sets, vocabulary, opts)
            %VariableDialog  The window over the sets SETS (a cell, one per target).
            %   dlg = VariableDialog(SETS, VOCABULARY, Labels=, OnDone=, Parent=, Visible=, Noun=)
            arguments
                sets cell
                vocabulary = []
                opts.Labels string = strings(1, 0)
                opts.OnDone = []
                opts.Parent = []
                opts.Visible (1,1) logical = true
                opts.Noun (1,1) string = "dataset"
            end
            if isempty(sets)
                error('VariableDialog:NoTargets', 'VariableDialog needs at least one target.');
            end
            m = numel(sets);
            obj.Sets = cell(1, m);
            for k = 1:m
                obj.Sets{k} = DatasetVariables.parse(sets{k});
            end
            if isempty(vocabulary); vocabulary = DatasetVariables.vocabulary({}); end
            obj.Vocabulary = vocabulary(:);
            obj.Noun = opts.Noun;
            labels = reshape(opts.Labels, 1, []);
            if numel(labels) ~= m; labels = opts.Noun + " " + (1:m); end
            obj.Labels = labels;
            obj.OnDone = opts.OnDone;
            obj.loadSets();
            obj.build(opts.Parent, opts.Visible);
            if ~isempty(obj.Defs); obj.Current = 1; end
            obj.refresh();
        end

        function delete(obj)
            if ~isempty(obj.Fig) && isvalid(obj.Fig); delete(obj.Fig); end
        end

        function t = get.ErrorText(obj)
            t = join(reshape(string(obj.Ctl.Error.Text), 1, []), newline);
        end

        %% --- Variables (columns) -----------------------------------------
        function newVariable(obj, label)
            %newVariable  Add a column for a new variable and show its definition; LABEL (optional) fills the label.
            arguments
                obj
                label (1,1) string = ""
            end
            d = obj.emptyDef();
            obj.addDef(d);
            if label ~= ""; obj.setLabel(label); end
            obj.showMessage([]);
            obj.refresh();
            if obj.Fig.Visible == "on"
                try focus(obj.Ctl.Label); catch; end
            end
        end

        function useExisting(obj, name)
            %useExisting  Add a column for variable NAME of the vocabulary (its name, label, units, description, type).
            name = string(name);
            if name == ""; return; end
            i = find(string({obj.Vocabulary.name}) == name, 1);
            if isempty(i)
                obj.showMessage(sprintf('No variable "%s" is in use elsewhere.', name));
                return
            end
            j = find(lower(string([obj.Defs.name])) == lower(name), 1);
            if ~isempty(j)
                obj.Current = j;
                obj.showMessage(sprintf('%s is in the grid already.', name), obj.NoticeColor);
                obj.refresh();
                return
            end
            v = obj.Vocabulary(i);
            d = obj.emptyDef();
            d.name = string(v.name); d.label = string(v.label); d.units = string(v.units);
            d.description = string(v.description);
            d.nameTouched = true;
            if ismember(v.type, ["number" "text"]); d.type = string(v.type); end
            obj.addDef(d);
            obj.showMessage([]);
            obj.refresh();
        end

        function removeVariable(obj, j)
            %removeVariable  Take column J (default: the current one) out: the variable is removed from every target on OK.
            if nargin < 2; j = obj.Current; end
            if j < 1 || j > numel(obj.Defs); return; end
            obj.Defs(j) = [];
            obj.Cells(:, j) = [];
            obj.Original(:, j) = [];
            obj.Edited(:, j) = [];
            obj.Current = min(j, numel(obj.Defs));
            obj.showMessage([]);
            obj.refresh();
        end

        function select(obj, j)
            %select  Show the definition of column J.
            if j < 1 || j > numel(obj.Defs); return; end
            obj.Current = j;
            obj.refresh();
        end

        %% --- The current variable's definition ---------------------------
        function setLabel(obj, text)
            %setLabel  The current variable's label; its name follows while you have not typed one.
            j = obj.need();
            if j == 0; return; end
            obj.Defs(j).label = string(text);
            obj.followLabel(j);
            obj.showMessage([]);
            obj.refresh();
        end

        function setName(obj, text)
            %setName  The current variable's name, as typed; "" hands it back to the label's suggestion.
            j = obj.need();
            if j == 0; return; end
            text = strtrim(string(text));
            obj.Defs(j).nameTouched = text ~= "";
            if text == ""
                obj.followLabel(j);
            else
                obj.Defs(j).name = text;
            end
            obj.showMessage([]);
            obj.refresh();
        end

        function setUnits(obj, text)
            j = obj.need();
            if j == 0; return; end
            obj.Defs(j).units = strtrim(string(text));
            obj.refresh();
        end

        function setType(obj, type)
            %setType  "auto", "number" or "text" for the current variable; every value is read again by it.
            j = obj.need();
            if j == 0; return; end
            type = string(type);
            if ~ismember(type, string(obj.TypeData))
                error('VariableDialog:BadType', 'Type is "auto", "number" or "text".');
            end
            obj.Defs(j).type = type;
            obj.Defs(j).typeTouched = true;
            obj.showMessage([]);
            obj.refresh();
        end

        function setDescription(obj, text)
            j = obj.need();
            if j == 0; return; end
            text = string(text);
            if ~isscalar(text); text = join(text, newline); end
            obj.Defs(j).description = strtrim(text);
            obj.refresh();
        end

        %% --- Values (cells) ----------------------------------------------
        function setValue(obj, row, col, text)
            %setValue  Type TEXT in cell (ROW, COL); COL is a column index or a variable's name. "" clears it.
            col = obj.columnOf(col);
            if col == 0 || row < 1 || row > numel(obj.Sets); return; end
            obj.Cells(row, col) = strtrim(string(text));
            obj.Edited(row, col) = true;
            obj.Current = col;
            obj.showMessage([]);
            obj.refresh();
        end

        function fillColumn(obj, text, col)
            %fillColumn  Type TEXT in every cell of a column (default: the current one).
            if nargin < 3; col = obj.Current; end
            col = obj.columnOf(col);
            if col == 0; return; end
            obj.Cells(:, col) = strtrim(string(text));
            obj.Edited(:, col) = true;
            obj.Current = col;
            obj.showMessage([]);
            obj.refresh();
        end

        function clearColumn(obj, col)
            %clearColumn  Empty every cell of a column (default: the current one): no target keeps the variable.
            if nargin < 2; col = obj.Current; end
            obj.fillColumn("", col);
        end

        %% --- Closing -----------------------------------------------------
        function ok(obj)
            %ok  Check everything, then hand the new sets to OnDone and close; problems stay in the window.
            if obj.Done; return; end
            [r, why] = obj.result();
            if ~isempty(why)
                obj.showMessage(why);
                return
            end
            obj.finish(r);
        end

        function cancel(obj)
            obj.finish([]);
        end
    end

    methods (Static)
        function text = describe(added, labels, noun)
            %describe  What an OK did, for a status line: TEXT = VariableDialog.describe(ADDED, LABELS, NOUN).
            %   ADDED is a cell, the history rows each target's write added
            %   (EphysDataset.setVariables, writeManifestVariables), LABELS
            %   the targets' names. TEXT is "Variables of recA: probeDepth
            %   created, cohort updated." for one target, "Variables of 3
            %   datasets: 3 created, 1 updated, 2 removed." for more, or
            %   "No variable changed."
            arguments
                added cell
                labels (1,:) string
                noun (1,1) string = "dataset"
            end
            rows = cellfun(@(a) numel(a), added);
            if ~any(rows); text = "No variable changed."; return; end
            if nnz(rows) == 1
                k = find(rows, 1);
                a = added{k};
                text = "Variables of " + labels(k) + ": " + join(string({a.name}) + " " + string({a.action}), ", ") + ".";
                return
            end
            every = vertcat(added{:});
            acts = string({every.action});
            parts = strings(1, 0);
            for a = DatasetVariables.Actions
                n = nnz(acts == a);
                if n > 0; parts(end+1) = n + " " + a; end %#ok<AGROW>
            end
            text = sprintf("Variables of %d %ss: %s.", nnz(rows), noun, join(parts, ", "));
        end
    end

    methods (Access = private)
        function loadSets(obj)
            %loadSets  A column per variable of any target (first-seen order), the cells from their values.
            m = numel(obj.Sets);
            obj.Defs = repmat(obj.emptyDef(), 0, 1);
            names = strings(1, 0);
            for k = 1:m
                names = [names, setdiff(DatasetVariables.names(obj.Sets{k}), names, 'stable')]; %#ok<AGROW>
            end
            K = numel(names);
            obj.Cells = strings(m, K);
            obj.Original = cell(m, K);
            obj.Edited = false(m, K);
            for j = 1:K
                d = obj.emptyDef();
                d.name = names(j); d.origName = names(j); d.nameTouched = true;
                types = strings(1, 0);
                for k = 1:m
                    s = obj.Sets{k};
                    if ~isfield(s, names(j)); continue; end
                    e = s.(names(j));
                    if d.label == ""
                        d.label = e.label; d.units = e.units; d.description = e.description;
                    end
                    obj.Cells(k, j) = DatasetVariables.valueText(e.value);
                    obj.Original{k, j} = e.value;
                    types(end+1) = DatasetVariables.typeOf(e.value); %#ok<AGROW>
                end
                if all(types == "number")
                    d.type = "number";
                elseif all(types == "text")
                    d.type = "text";
                end
                obj.Defs(j, 1) = d;
            end
        end

        function d = emptyDef(obj)
            d = struct('id', obj.NextId, 'name', "", 'origName', "", 'label', "", 'units', "", ...
                'description', "", 'type', "auto", 'nameTouched', false, 'typeTouched', false);
            obj.NextId = obj.NextId + 1;
        end

        function addDef(obj, d)
            obj.Defs(end+1, 1) = d;
            m = numel(obj.Sets);
            obj.Cells(:, end+1) = strings(m, 1);
            obj.Original(:, end+1) = cell(m, 1);
            obj.Edited(:, end+1) = false(m, 1);
            obj.Current = numel(obj.Defs);
        end

        function j = need(obj)
            j = obj.Current;
            if j < 1 || j > numel(obj.Defs)
                j = 0;
                obj.showMessage("Choose a variable first: click its column, or press New variable.");
            end
        end

        function j = columnOf(obj, col)
            if isnumeric(col)
                j = col;
                if j < 1 || j > numel(obj.Defs); j = 0; end
            else
                j = find(string([obj.Defs.name]) == string(col), 1);
                if isempty(j); j = 0; end
            end
        end

        function followLabel(obj, j)
            %followLabel  The name suggested from the label (while the name is the label's).
            if obj.Defs(j).nameTouched; return; end
            others = string([obj.Defs([1:j-1, j+1:end]).name]);
            obj.Defs(j).name = DatasetVariables.suggestName(obj.Defs(j).label, others(others ~= ""));
        end

        function [v, ok, why] = cellValue(obj, k, j)
            %cellValue  The value of cell (K, J) as OK would save it ([] when empty).
            d = obj.Defs(j);
            t = obj.Cells(k, j);
            if ~obj.Edited(k, j) && ~d.typeTouched && ~isempty(obj.Original{k, j})
                v = obj.Original{k, j}; ok = true; why = "";
                return
            end
            type = d.type;
            if type == "auto" && obj.columnIsText(j); type = "text"; end
            [v, ok, why] = DatasetVariables.parseValue(t, type);
        end

        function tf = columnIsText(obj, j)
            %columnIsText  Automatic type: text when any typed value does not read as a number.
            tf = false;
            for k = 1:size(obj.Cells, 1)
                t = obj.Cells(k, j);
                if t == ""; continue; end
                if ~obj.Edited(k, j) && ~isempty(obj.Original{k, j})
                    if isstring(obj.Original{k, j}); tf = true; return; end
                    continue
                end
                [v, ~] = DatasetVariables.parseValue(t, "auto");
                if isstring(v); tf = true; return; end
            end
        end

        function t = effectiveType(obj, j)
            t = obj.Defs(j).type;
            if t == "auto"
                if obj.columnIsText(j); t = "text"; else; t = "number"; end
            end
        end

        function [r, why] = result(obj)
            %result  The new sets, or why OK cannot save (a string column).
            r = [];
            why = strings(0, 1);
            K = numel(obj.Defs);
            names = string([obj.Defs.name]);
            for j = 1:K
                d = obj.Defs(j);
                what = "Column " + j;
                if d.label ~= ""; what = """" + d.label + """"; end
                [ok, w] = DatasetVariables.checkLabel(d.label);
                if ~ok; why(end+1, 1) = what + ": " + w; end %#ok<AGROW>
                [ok, w] = DatasetVariables.checkName(d.name, names([1:j-1, j+1:end]));
                if ~ok; why(end+1, 1) = what + ": " + w; end %#ok<AGROW>
                if strlength(d.units) > DatasetVariables.MaxUnitsLength
                    why(end+1, 1) = what + sprintf(": units are at most %d characters.", DatasetVariables.MaxUnitsLength); %#ok<AGROW>
                end
                if strlength(d.description) > DatasetVariables.MaxDescriptionLength
                    why(end+1, 1) = what + sprintf(": the description is at most %d characters.", DatasetVariables.MaxDescriptionLength); %#ok<AGROW>
                end
                if all(obj.Cells(:, j) == "")
                    why(end+1, 1) = what + ": type a value for at least one " + obj.Noun + ", or remove the variable."; %#ok<AGROW>
                end
                for k = 1:numel(obj.Sets)
                    [~, ok, w] = obj.cellValue(k, j);
                    if ~ok; why(end+1, 1) = what + ", " + obj.Labels(k) + ": " + w; end %#ok<AGROW>
                end
            end
            if ~isempty(why); return; end
            m = numel(obj.Sets);
            r = struct('sets', {cell(1, m)}, 'renamed', {cell(1, m)}, 'changed', false(1, m));
            for k = 1:m
                old = obj.Sets{k};
                s = struct();
                ren = strings(0, 2);
                for j = 1:K
                    d = obj.Defs(j);
                    v = obj.cellValue(k, j);
                    if isempty(v); continue; end
                    s.(d.name) = DatasetVariables.entry(d.label, v, Units=d.units, Description=d.description);
                    if d.origName ~= "" && d.origName ~= d.name && isfield(old, d.origName)
                        ren(end+1, :) = [d.origName d.name]; %#ok<AGROW>
                    end
                end
                r.sets{k} = s;
                r.renamed{k} = ren;
                r.changed(k) = ~sameSet(old, s);
            end
            if ~any(r.changed); r = []; end
        end

        function build(obj, parent, visible)
            m = numel(obj.Sets);
            fig = uifigure("Name", "Variables", "Visible", "off", "Position", [100 100 940 560], ...
                "WindowStyle", "modal");
            if ~isempty(parent) && isvalid(parent)
                p = parent.Position;
                fig.Position(1:2) = p(1:2) + max(0, (p(3:4) - fig.Position(3:4)) / 2);
            end
            fig.CloseRequestFcn = @(~, ~) obj.cancel();
            obj.Fig = fig;

            g = uigridlayout(fig, [5 1]);
            g.RowHeight = {'fit', 'fit', '1x', 'fit', 34};
            c = struct();
            if m == 1
                txt = "Variables of " + obj.Labels(1);
            else
                txt = sprintf("Variables of %d %ss", m, obj.Noun);
            end
            c.Title = uilabel(g, "Text", txt, "FontWeight", "bold", "FontSize", 14);
            uilabel(g, "WordWrap", "on", "FontColor", obj.NoticeColor, "Text", ...
                "A row per " + obj.Noun + ", a column per variable. Type a value in a cell, a number or text; " + ...
                "leave it empty when the " + obj.Noun + " does not have the variable. Click a column to edit its " + ...
                "label, name, units and description on the right. Only the latest values are kept; the manifest records when each variable changed.");

            mid = uigridlayout(g, [1 2]);
            mid.ColumnWidth = {'1x', 330};
            mid.Padding = [0 0 0 0];

            left = uigridlayout(mid, [3 1]);
            left.RowHeight = {'1x', 32, 32};
            left.Padding = [0 0 0 0];
            c.Grid = uitable(left, "RowName", {}, "ColumnSortable", false, ...
                "Tooltip", "Type a value in a cell (Enter to keep it); clear it to take the variable off that " + obj.Noun + ".", ...
                "CellEditCallback", @(~, evt) obj.onCellEdit(evt), ...
                "CellSelectionCallback", @(~, evt) obj.onCellSelect(evt));
            vb = uigridlayout(left, [1 4]);
            vb.ColumnWidth = {'fit', '1x', 'fit', 'fit'};
            vb.Padding = [0 0 0 0];
            vb.RowHeight = {30};
            c.New = uibutton(vb, "Text", "New variable", "Tooltip", "Add a column for a new variable, then give it a label.", ...
                "ButtonPushedFcn", @(~, ~) obj.newVariable());
            c.Existing = uidropdown(vb, "Items", {'Use a variable from other datasets...'}, "ItemsData", {''}, ...
                "Tooltip", "Add a column for a variable already in use, with its name, label, units and description.", ...
                "ValueChangedFcn", @(src, ~) obj.onPickExisting(src));
            c.Remove = uibutton(vb, "Text", "Remove variable", ...
                "Tooltip", "Take the selected column out: on OK the variable is removed from every " + obj.Noun + " (the history keeps it).", ...
                "ButtonPushedFcn", @(~, ~) obj.removeVariable());
            c.Remove.Layout.Column = 4;
            fb = uigridlayout(left, [1 4]);
            fb.ColumnWidth = {'fit', '1x', 'fit', 'fit'};
            fb.Padding = [0 0 0 0];
            fb.RowHeight = {30};
            uilabel(fb, "Text", "Same value for all:");
            c.FillValue = uieditfield(fb, "text", "Placeholder", "a number or text", ...
                "Tooltip", "Type a value, then Fill column to put it in every row of the selected column.");
            c.Fill = uibutton(fb, "Text", "Fill column", "ButtonPushedFcn", @(~, ~) obj.fillColumn(obj.Ctl.FillValue.Value));
            c.Clear = uibutton(fb, "Text", "Clear column", "Tooltip", "Empty every cell of the selected column.", ...
                "ButtonPushedFcn", @(~, ~) obj.clearColumn());

            p = uipanel(mid, "Title", "Selected variable");
            pg = uigridlayout(p, [7 2]);
            pg.ColumnWidth = {'fit', '1x'};
            pg.RowHeight = {30, 30, 'fit', 30, 30, '1x', 'fit'};
            uilabel(pg, "Text", "Label");
            c.Label = uieditfield(pg, "text", "Placeholder", "e.g. Probe Depth", ...
                "Tooltip", "The name people read: tables, the manifest viewer, figure labels.", ...
                "ValueChangingFcn", @(~, evt) obj.onLabelTyping(evt.Value), ...
                "ValueChangedFcn", @(src, ~) obj.setLabel(src.Value));
            uilabel(pg, "Text", "Name");
            c.Name = uieditfield(pg, "text", "Placeholder", "e.g. probeDepth", ...
                "Tooltip", "The name data structures use (info.variables.probeDepth, table column var_probeDepth): " + ...
                "a letter first, then letters, digits and _. Suggested from the label until you type your own; clear it to get the suggestion back.", ...
                "ValueChangedFcn", @(src, ~) obj.setName(src.Value));
            c.NameNote = uilabel(pg, "Text", "", "FontColor", obj.NoticeColor, "FontSize", 11, "WordWrap", "on");
            c.NameNote.Layout.Column = [1 2];
            uilabel(pg, "Text", "Units");
            c.Units = uieditfield(pg, "text", "Placeholder", "optional, e.g. µm", ...
                "Tooltip", "Optional: shown after the label, “Probe Depth (µm)”.", ...
                "ValueChangedFcn", @(src, ~) obj.setUnits(src.Value));
            uilabel(pg, "Text", "Type");
            c.Type = uidropdown(pg, "Items", obj.TypeItems, "ItemsData", obj.TypeData, ...
                "Tooltip", "Automatic: a number when every value reads as one, else text. Number: every value must be a number. Text: kept as typed (“007” stays 007).", ...
                "ValueChangedFcn", @(src, ~) obj.setType(src.Value));
            dl = uilabel(pg, "Text", "Description");
            dl.VerticalAlignment = "top";
            c.Description = uitextarea(pg, "Placeholder", "optional", ...
                "Tooltip", "Optional: what the variable means, how it was measured.", ...
                "ValueChangedFcn", @(src, ~) obj.setDescription(src.Value));
            c.Known = uilabel(pg, "Text", "", "FontColor", obj.NoticeColor, "FontSize", 11, "WordWrap", "on");
            c.Known.Layout.Column = [1 2];

            c.Error = uilabel(g, "Text", "", "WordWrap", "on", "FontColor", obj.ErrorColor);

            bg = uigridlayout(g, [1 3]);
            bg.ColumnWidth = {'1x', 'fit', 'fit'};
            bg.Padding = [0 0 0 0];
            bg.RowHeight = {30};
            c.Cancel = uibutton(bg, "Text", "Cancel", "ButtonPushedFcn", @(~, ~) obj.cancel());
            c.Cancel.Layout.Column = 2;
            c.OK = uibutton(bg, "Text", "OK", "Tooltip", "Save the variables to each " + obj.Noun + "'s manifest.", ...
                "ButtonPushedFcn", @(~, ~) obj.ok());
            c.OK.Layout.Column = 3;
            styleButton([c.Fill c.Clear c.Cancel]);
            styleButton(c.New, "primary");
            styleButton(c.Remove, "danger");
            styleButton(c.OK, "confirm");
            obj.Ctl = c;
            fig.Visible = matlab.lang.OnOffSwitchState(visible);
        end

        function refresh(obj)
            c = obj.Ctl;
            K = numel(obj.Defs);
            heads = strings(1, K);
            for j = 1:K
                d = obj.Defs(j);
                h = d.label;
                if h == ""; h = "(new)"; end
                heads(j) = DatasetVariables.displayLabel(h, d.units);
            end
            first = upper(extractBefore(obj.Noun, 2)) + extractAfter(obj.Noun, 1);
            c.Grid.ColumnName = cellstr([first, heads]);
            c.Grid.Data = cellstr([reshape(obj.Labels, [], 1), obj.Cells]);
            c.Grid.ColumnEditable = [false, true(1, K)];
            c.Grid.ColumnWidth = [{160}, repmat({'auto'}, 1, K)];
            removeStyle(c.Grid);
            if obj.Current >= 1 && obj.Current <= K
                addStyle(c.Grid, uistyle("BackgroundColor", [0.88 0.94 1]), "column", obj.Current + 1);
            end
            addStyle(c.Grid, uistyle("FontColor", [0.3 0.3 0.3]), "column", 1);

            % Use existing: the vocabulary's variables not in the grid.
            taken = lower(string([obj.Defs.name]));
            V = obj.Vocabulary;
            if ~isempty(V); V = V(~ismember(lower(string({V.name})), taken)); end
            items = {'Use a variable from other datasets...'};
            data = {''};
            for i = 1:numel(V)
                items{end+1} = char(DatasetVariables.displayLabel(V(i).label, V(i).units) + "  (" + V(i).name + ", " + V(i).type + ")"); %#ok<AGROW>
                data{end+1} = char(V(i).name); %#ok<AGROW>
            end
            c.Existing.Items = items;
            c.Existing.ItemsData = data;
            c.Existing.Value = '';
            c.Existing.Enable = matlab.lang.OnOffSwitchState(numel(items) > 1);

            j = obj.Current;
            on = j >= 1 && j <= K;
            set([c.Label c.Name c.Units c.Type c.Description c.Remove c.Fill c.Clear c.FillValue], ...
                "Enable", matlab.lang.OnOffSwitchState(on));
            if ~on
                c.Label.Value = ''; c.Name.Value = ''; c.Units.Value = ''; c.Description.Value = {''};
                c.Type.Value = 'auto';
                c.NameNote.Text = "";
                if K == 0
                    c.Known.Text = "No variables yet: press New variable, or use one from other datasets.";
                else
                    c.Known.Text = "Click a column to edit its variable.";
                end
                return
            end
            d = obj.Defs(j);
            c.Label.Value = char(d.label);
            c.Name.Value = char(d.name);
            c.Units.Value = char(d.units);
            c.Type.Value = char(d.type);
            c.Description.Value = cellstr(splitlines(d.description));
            if d.nameTouched && d.origName ~= "" && d.origName ~= d.name
                c.NameNote.Text = "Renamed from " + d.origName + ": data structures use the new name from now on.";
            elseif d.nameTouched
                c.NameNote.Text = "";
            elseif d.name ~= ""
                c.NameNote.Text = "Suggested from the label. Type a name of your own to keep it.";
            else
                c.NameNote.Text = "The name follows the label as you type it.";
            end
            if d.type == "auto" && any(obj.Cells(:, j) ~= "")
                c.NameNote.Text = strtrim(c.NameNote.Text + " Automatic type: " + obj.effectiveType(j) + ".");
            end
            c.Known.Text = obj.knownText(d);
        end

        function t = knownText(obj, d)
            %knownText  How the variable is used on other datasets, when it is.
            t = "";
            V = obj.Vocabulary;
            if isempty(V) || d.name == ""; return; end
            i = find(lower(string({V.name})) == lower(d.name), 1);
            if isempty(i); return; end
            v = V(i);
            t = sprintf("In use on %d %s(s) as %s, labeled ""%s""", v.count, obj.Noun, v.type, ...
                DatasetVariables.displayLabel(v.label, v.units));
            t = t + ".";
            if string(v.name) ~= d.name
                t = t + " There it is named " + v.name + ": use the same name to keep them one variable.";
            elseif string(v.label) ~= d.label || string(v.units) ~= d.units
                t = t + " Label and units are shared per " + obj.Noun + "; keep them alike.";
            end
        end

        function onCellEdit(obj, evt)
            j = evt.Indices(2) - 1;
            if j < 1; return; end
            obj.setValue(evt.Indices(1), j, evt.NewData);
        end

        function onCellSelect(obj, evt)
            if isempty(evt.Indices); return; end
            j = evt.Indices(end, 2) - 1;
            if j >= 1 && j ~= obj.Current
                obj.Current = j;
                obj.refresh();
            end
        end

        function onLabelTyping(obj, text)
            %onLabelTyping  As the label is typed: the suggested name and the column's heading follow.
            j = obj.Current;
            if j < 1 || j > numel(obj.Defs); return; end
            obj.Defs(j).label = string(text);
            obj.followLabel(j);
            obj.Ctl.Name.Value = char(obj.Defs(j).name);
        end

        function onPickExisting(obj, src)
            name = string(src.Value);
            src.Value = '';
            obj.useExisting(name);
        end

        function showMessage(obj, lines, color)
            if nargin < 3; color = obj.ErrorColor; end
            if isempty(lines); lines = ""; end
            obj.Ctl.Error.Text = reshape(string(lines), [], 1);
            obj.Ctl.Error.FontColor = color;
        end

        function finish(obj, r)
            if obj.Done; return; end
            obj.Done = true;
            fig = obj.Fig;
            closer = onCleanup(@() closeFig(fig));
            if ~isempty(obj.OnDone)
                obj.OnDone(r);
            end
            clear closer
        end
    end
end


function tf = sameSet(a, b)
%sameSet  Two sets alike in names, order aside, and in every entry's label, value, units and description.
na = sort(DatasetVariables.names(a));
nb = sort(DatasetVariables.names(b));
tf = isequal(na, nb);
if ~tf; return; end
for n = na
    for f = DatasetVariables.Fields
        x = a.(n).(f); y = b.(n).(f);
        if ~(strcmp(class(x), class(y)) && isequal(x, y)); tf = false; return; end
    end
end
end


function closeFig(fig)
if ~isempty(fig) && isvalid(fig); delete(fig); end
end
