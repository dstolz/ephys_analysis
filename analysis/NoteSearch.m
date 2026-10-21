classdef NoteSearch < handle
    %NoteSearch  A window to search the notes of many datasets (DatasetNotes) and go to the dataset of one.
    %   S = NoteSearch(ENTRIES) lists ENTRIES, a table with one row per note
    %   (the app's noteEntries):
    %     dataset  the dataset's index in the caller's list of datasets
    %     name     the dataset's name
    %     level, id, label, text, updated, current
    %              as DatasetNotes.list(AllSorts=true): current is false for
    %              a unit's note on another sort than the one in use
    %   Type in the search field: the list keeps the notes holding every
    %   word of it, in any case, in their dataset's name, what they are on
    %   ("unit 12") or their text, as you type. The Note column shows the
    %   first line holding the first word (else the note's first line);
    %   pick a row to read the whole note under the list. Go to (or a
    %   double-click) calls GoToFcn(ENTRY), the row of ENTRIES picked: the
    %   app opens its dataset. Edit note calls EditFcn(ENTRY), off for a
    %   note on another sort.
    %
    %   Options
    %     Parent     the figure to center the window over ([] = none)
    %     Visible    false builds it hidden (tests)
    %     GoToFcn    called as GoToFcn(ENTRY)
    %     EditFcn    called as EditFcn(ENTRY)
    %     EmptyText  what the list says when there are no notes at all
    %
    %   The same without the mouse (tests, scripts):
    %     s.search(QUERY), s.pick(K) (row K of Matches), s.goTo(), s.edit(),
    %     s.setEntries(E) (new notes: the query kept, and the pick when its
    %     note is still there), s.close()
    %
    %   Properties (read-only): Entries, Query, Matches (the rows of Entries
    %   listed, in their order), Picked (the row of Matches picked, 0 for
    %   none), Fig, Field, CountLabel, Table, Preview, GoToButton,
    %   EditButton.
    %
    %   See also DatasetNotes, NotePad, EphysAnalysisApp.

    properties (SetAccess = private)
        Entries table = table()
        Query (1,1) string = ""
        Matches (:,1) double = zeros(0, 1)
        Picked (1,1) double = 0
        Fig
        Field
        CountLabel
        Table
        Preview
        GoToButton
        EditButton
    end

    properties (Access = private)
        GoToFcn = []
        EditFcn = []
        EmptyText (1,1) string = "No notes yet."
    end

    methods
        function obj = NoteSearch(entries, opts)
            arguments
                entries table
                opts.Parent = []
                opts.Visible (1,1) logical = true
                opts.GoToFcn = []
                opts.EditFcn = []
                opts.EmptyText (1,1) string = "No notes yet."
            end
            obj.GoToFcn = opts.GoToFcn;
            obj.EditFcn = opts.EditFcn;
            obj.EmptyText = opts.EmptyText;
            obj.build(opts.Parent);
            obj.setEntries(entries);
            if opts.Visible
                obj.Fig.Visible = "on";
                try
                    focus(obj.Field);
                catch
                end
            end
        end

        function delete(obj)
            if ~isempty(obj.Fig) && isvalid(obj.Fig); delete(obj.Fig); end
        end

        function setEntries(obj, entries)
            %setEntries  New notes to search: the query kept, and the pick while its note is still there.
            was = [];
            if obj.Picked > 0; was = obj.Entries(obj.Matches(obj.Picked), :); end
            obj.Entries = entries;
            obj.search(obj.Query);
            if isempty(was) || isempty(obj.Matches); return; end
            E = obj.Entries(obj.Matches, :);
            k = find(E.dataset == was.dataset & E.level == was.level & (E.id == was.id | (isnan(E.id) & isnan(was.id))) ...
                & E.current == was.current, 1);
            if ~isempty(k); obj.pick(k); end
        end

        function search(obj, query)
            %search  List the notes holding every word of QUERY (any case) in their dataset name, item or text.
            obj.Query = string(query);
            E = obj.Entries;
            n = height(E);
            words = split(lower(strtrim(obj.Query)));
            words = words(words ~= "");
            keep = true(n, 1);
            if n > 0 && ~isempty(words)
                hay = lower(E.name + " " + E.label + " " + E.text);
                for w = reshape(words, 1, [])
                    keep = keep & contains(hay, w);
                end
            end
            obj.Matches = find(keep);
            obj.Picked = 0;
            M = E(obj.Matches, :);
            first = "";
            if ~isempty(words); first = words(1); end
            Note = strings(height(M), 1);
            for k = 1:height(M)
                Note(k) = snippet(M.text(k), first);
            end
            when = M.updated;
            if ~isempty(when); when.Format = 'yyyy-MM-dd HH:mm'; end
            Updated = string(when);
            Updated(ismissing(Updated)) = "";
            obj.Table.Data = table(M.name, M.label, Note, Updated, 'VariableNames', ["Dataset" "Item" "Note" "Updated"]);
            if n == 0
                obj.CountLabel.Text = obj.EmptyText;
            elseif isempty(words)
                obj.CountLabel.Text = sprintf("%d note%s", n, repmat('s', 1, n ~= 1));
            else
                obj.CountLabel.Text = sprintf("%d of %d note%s match", numel(obj.Matches), n, repmat('s', 1, n ~= 1));
            end
            obj.showPicked();
        end

        function pick(obj, k)
            %pick  Row K of the list picked: its whole note under the list (K 0: none).
            if k < 0 || k > numel(obj.Matches); k = 0; end
            obj.Picked = k;
            obj.showPicked();
        end

        function goTo(obj)
            %goTo  Open the dataset of the note picked (GoToFcn).
            if obj.Picked < 1 || isempty(obj.GoToFcn); return; end
            obj.GoToFcn(obj.Entries(obj.Matches(obj.Picked), :));
        end

        function edit(obj)
            %edit  Edit the note picked (EditFcn); not a note on another sort.
            if obj.Picked < 1 || isempty(obj.EditFcn); return; end
            e = obj.Entries(obj.Matches(obj.Picked), :);
            if ~e.current; return; end
            obj.EditFcn(e);
        end

        function close(obj)
            delete(obj);
        end
    end

    methods (Access = private)
        function build(obj, parent)
            sz = [720 520];
            pos = [150 150 sz];
            if ~isempty(parent) && isgraphics(parent)
                try
                    pp = getpixelposition(parent);
                    pos(1:2) = max(1, pp(1:2) + (pp(3:4) - sz) / 2);
                catch
                end
            end
            obj.Fig = uifigure("Name", "Search notes", "Position", pos, "Visible", "off", ...
                "CloseRequestFcn", @(~, ~) obj.close(), "WindowKeyPressFcn", @(~, evt) obj.onKey(evt));
            g = uigridlayout(obj.Fig, [5 1], "RowHeight", {30, '2x', 'fit', '1x', 30}, "Padding", 10, "RowSpacing", 6);
            sg = uigridlayout(g, [1 3], "ColumnWidth", {'fit', '1x', 'fit'}, "Padding", 0, "ColumnSpacing", 8);
            uilabel(sg, "Text", "Search:");
            obj.Field = uieditfield(sg, "text", "Placeholder", "words in the dataset name, unit / channel or note", ...
                "Tooltip", "Every word must appear, in any case, in the dataset's name, what the note is on (""unit 12"") or its text.", ...
                "ValueChangingFcn", @(~, evt) obj.search(evt.Value), "ValueChangedFcn", @(f, ~) obj.search(f.Value));
            obj.CountLabel = uilabel(sg, "Text", "", "FontColor", [0.35 0.35 0.35]);
            obj.Table = uitable(g, "RowName", {}, "ColumnName", {'Dataset', 'Item', 'Note', 'Updated'}, ...
                "ColumnWidth", {150, 120, '1x', 110}, "ColumnSortable", true, "SelectionType", "row", ...
                "Multiselect", "off", ...
                "CellSelectionCallback", @(~, evt) obj.onSelected(evt), ...
                "DoubleClickedFcn", @(~, evt) obj.onDoubleClicked(evt));
            uilabel(g, "Text", "The note picked:", "FontColor", [0.35 0.35 0.35]);
            obj.Preview = uitextarea(g, "Editable", "off", "WordWrap", "on");
            bg = uigridlayout(g, [1 4], "ColumnWidth", {'1x', 110, 'fit', 90}, "Padding", 0, "ColumnSpacing", 6);
            uilabel(bg, "Text", "Double-click a note, or pick it and press Go to, to open its dataset (and its unit or channel).", ...
                "FontColor", [0.35 0.35 0.35], "WordWrap", "on");
            obj.EditButton = uibutton(bg, "Text", "Edit note", "Enable", "off", "ButtonPushedFcn", @(~, ~) obj.edit(), ...
                "Tooltip", "Open the note picked in the notepad");
            closeButton = uibutton(bg, "Text", "Close", "ButtonPushedFcn", @(~, ~) obj.close(), "Tooltip", "Close the window (Esc)");
            obj.GoToButton = uibutton(bg, "Text", "Go to", "Enable", "off", "ButtonPushedFcn", @(~, ~) obj.goTo(), ...
                "Tooltip", "Make the note's dataset the active one, and pick its unit or channel for the Figures tab's preview");
            styleButton([obj.EditButton closeButton]);
            styleButton(obj.GoToButton, "primary");
        end

        function showPicked(obj)
            %showPicked  The note picked in full, and the buttons for it.
            k = obj.Picked;
            if k < 1
                obj.Preview.Value = "";
                obj.GoToButton.Enable = "off";
                obj.EditButton.Enable = "off";
                return
            end
            e = obj.Entries(obj.Matches(k), :);
            obj.Preview.Value = cellstr(splitlines(e.text));
            obj.GoToButton.Enable = "on";
            obj.EditButton.Enable = matlab.lang.OnOffSwitchState(e.current);
            tip = "Open the note picked in the notepad";
            if ~e.current
                tip = "A note on a unit of another sort than the one in use: it is edited when that sort is in use again";
            end
            obj.EditButton.Tooltip = tip;
        end

        function onSelected(obj, evt)
            if isempty(evt.Indices); obj.pick(0); return; end
            obj.pick(evt.Indices(1, 1));   % a row of Data, whatever the sort shows
        end

        function onDoubleClicked(obj, evt)
            info = evt.InteractionInformation;
            if isempty(info.Row); return; end
            obj.pick(info.Row(1));
            obj.goTo();
        end

        function onKey(obj, evt)
            if evt.Key == "escape"
                obj.close();
            end
        end
    end
end


function s = snippet(text, word)
%snippet  The first line of TEXT holding WORD (any case; else its first line that is not blank), spaces collapsed, at most 120 characters.
lines = strtrim(splitlines(text));
lines = lines(lines ~= "");
if isempty(lines); s = ""; return; end
k = 1;
if word ~= ""
    hit = find(contains(lower(lines), word), 1);
    if ~isempty(hit); k = hit; end
end
s = regexprep(lines(k), '\s+', ' ');
if numel(lines) > 1; s = s + " ..."; end
if strlength(s) > 120; s = extractBefore(s, 118) + " ..."; end
end
