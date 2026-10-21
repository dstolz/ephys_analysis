classdef NotePad < handle
    %NotePad  A little window to write the note on a dataset, a channel or a unit (DatasetNotes).
    %   P = NotePad(ITEM) opens the note of ITEM, a struct:
    %     notes   the dataset's DatasetNotes
    %     level   "dataset" | "channel" | "unit"
    %     id      the channel, or the unit's cluster id (NaN for the dataset)
    %     title   what it is, as the window names it ("subj1_day1 · unit 12")
    %   The window stays above the app, so it can stay open while you step
    %   through units. The note is written into the dataset's
    %   <Name>_notes.json when the text box loses focus, on Save (or
    %   Ctrl+S), before another note is opened in the window (open) and when
    %   it closes, so moving on never loses it. Blank text is no note. When
    %   it cannot be written (a read-only share) the text stays in the box
    %   and the line under it says why; closing again then discards it. A
    %   notes file that cannot be read cannot be edited (DatasetNotes.Problem).
    %
    %   Options
    %     Parent    the figure to place the window over, at its top right
    %               ([] = none)
    %     Visible   false builds it hidden (tests)
    %     SavedFcn  called as SavedFcn(ITEM) after the note of ITEM was
    %               written (the app marks it)
    %
    %   The same without the mouse (tests, scripts):
    %     p.open(ITEM)    another note: the text in the box written first;
    %                     false (the window left on its note) when that fails
    %     p.setText(TXT)  the box's text, as if typed (not written yet)
    %     p.save()        write the note now; false when it cannot be
    %     p.close()       write it and close
    %
    %   Properties (read-only): Item, Text (the box's text as one string),
    %   Dirty (typed since written), Fig, Area, TitleLabel, StateLabel,
    %   SaveButton.
    %
    %   See also DatasetNotes, NoteSearch, EphysAnalysisApp.

    properties (SetAccess = private)
        Item = []                       % the note in the window: struct(notes, level, id, title)
        Dirty (1,1) logical = false     % the box was typed in since the note was written or read
        Fig                             % the window
        Area                            % its text box
        TitleLabel                      % what the note is on
        StateLabel                      % written when, or why not
        SaveButton
    end

    properties (Dependent)
        Text
    end

    properties (Access = private)
        Typed = []                      % the box's text while typing (ValueChangingFcn), [] once it has its Value
        CloseAsked (1,1) logical = false   % a close was refused because the note could not be written
        Opening (1,1) logical = false      % open is writing the note it leaves (its SavedFcn may call open again)
        SavedFcn = []
    end

    methods
        function obj = NotePad(item, opts)
            arguments
                item (1,1) struct
                opts.Parent = []
                opts.Visible (1,1) logical = true
                opts.SavedFcn = []
            end
            obj.SavedFcn = opts.SavedFcn;
            obj.build(opts.Parent);
            obj.show(item);
            if opts.Visible; obj.Fig.Visible = "on"; end
        end

        function delete(obj)
            if ~isempty(obj.Fig) && isvalid(obj.Fig); delete(obj.Fig); end
        end

        function t = get.Text(obj)
            if ~isempty(obj.Typed)
                t = obj.Typed;
            else
                t = obj.Area.Value;
            end
            t = string(t);
            t = strjoin(reshape(t, 1, []), newline);
        end

        function ok = open(obj, item)
            %open  Show the note of ITEM, the one in the box written first (false, and nothing changes, when it cannot be).
            ok = true;
            if obj.Opening; return; end   % SavedFcn below may follow the app back here: this call shows ITEM
            if sameItem(obj.Item, item)
                obj.Item.title = item.title;
                obj.showState();
                return
            end
            obj.Opening = true;
            done = onCleanup(@() obj.endOpening());
            if obj.Dirty && ~obj.save()
                ok = false;
                return
            end
            obj.show(item);
        end

        function setText(obj, txt)
            %setText  Put TXT in the box as if typed (written on save, open or close).
            obj.Typed = [];
            obj.Area.Value = cellstr(splitlines(string(txt)));
            obj.Dirty = true;
            obj.showState();
        end

        function ok = save(obj)
            %save  Write the note in the box (blank: no note); false when it cannot be, the line under the box saying why.
            ok = ~obj.Dirty;
            it = obj.Item;
            if ok || isempty(it) || it.notes.Problem ~= ""; return; end
            try
                it.notes.setNote(it.level, it.id, obj.Text);
            catch ME
                obj.showState("Not written: " + string(ME.message));
                return
            end
            obj.Dirty = false;   % the box keeps the text as typed (and its cursor): Ctrl+S may come mid-typing
            obj.CloseAsked = false;
            obj.showState();
            ok = true;
            if ~isempty(obj.SavedFcn); obj.SavedFcn(it); end
        end

        function close(obj)
            %close  Write the note and close; when it cannot be written the window stays, and a second close discards it.
            if obj.Dirty && ~obj.save() && ~obj.CloseAsked
                obj.CloseAsked = true;
                obj.StateLabel.Text = obj.StateLabel.Text + " Close again to discard the text.";
                return
            end
            delete(obj);
        end
    end

    methods (Access = private)
        function build(obj, parent)
            sz = [380 300];
            pos = [200 200 sz];
            if ~isempty(parent) && isgraphics(parent)
                try
                    pp = getpixelposition(parent);
                    pos(1:2) = max(1, [pp(1) + pp(3) - sz(1) - 24, pp(2) + pp(4) - sz(2) - 110]);
                catch
                end
            end
            obj.Fig = uifigure("Name", "Note", "Position", pos, "Visible", "off", "WindowStyle", "alwaysontop", ...
                "CloseRequestFcn", @(~, ~) obj.close(), "WindowKeyPressFcn", @(~, evt) obj.onKey(evt));
            g = uigridlayout(obj.Fig, [4 1], "RowHeight", {'fit', '1x', 'fit', 30}, "Padding", 10, "RowSpacing", 6);
            obj.TitleLabel = uilabel(g, "FontWeight", "bold", "WordWrap", "on");
            obj.Area = uitextarea(g, "WordWrap", "on", "Placeholder", "Type a note ...", ...
                "ValueChangingFcn", @(~, evt) obj.onTyping(evt.Value), ...
                "ValueChangedFcn", @(~, ~) obj.onLeftBox());
            obj.StateLabel = uilabel(g, "WordWrap", "on", "FontColor", [0.35 0.35 0.35]);
            bg = uigridlayout(g, [1 3], "ColumnWidth", {'1x', 80, 80}, "Padding", 0, "ColumnSpacing", 6);
            uilabel(bg, "Text", "");
            closeButton = uibutton(bg, "Text", "Close", "ButtonPushedFcn", @(~, ~) obj.close(), ...
                "Tooltip", "Write the note and close the window (Esc)");
            obj.SaveButton = uibutton(bg, "Text", "Save", "ButtonPushedFcn", @(~, ~) obj.save(), ...
                "Tooltip", "Write the note now (Ctrl+S); it is also written when you leave the box or close the window");
            styleButton(closeButton);
            styleButton(obj.SaveButton, "confirm");
        end

        function show(obj, item)
            %show  The note of ITEM in the box, as written.
            obj.Item = item;
            obj.Typed = [];
            obj.Dirty = false;
            obj.CloseAsked = false;
            obj.Area.Value = cellstr(splitlines(item.notes.note(item.level, item.id)));
            obj.Area.Editable = matlab.lang.OnOffSwitchState(item.notes.Problem == "");
            obj.SaveButton.Enable = obj.Area.Editable;
            obj.showState();
        end

        function showState(obj, problem)
            %showState  The title, and the line under the box: where the note is kept and when it was written, or PROBLEM.
            arguments
                obj
                problem (1,1) string = ""
            end
            it = obj.Item;
            obj.Fig.Name = char("Note: " + it.title);
            obj.TitleLabel.Text = it.title;
            [~, f, e] = fileparts(it.notes.File);
            gray = [0.35 0.35 0.35];
            if problem == "" && it.notes.Problem ~= ""
                problem = "Cannot be edited: " + it.notes.Problem;
            end
            if problem ~= ""
                set(obj.StateLabel, "Text", problem, "FontColor", [0.75 0.15 0.10]);
            elseif obj.Dirty
                set(obj.StateLabel, "Text", "Typing: written when you leave the box, Save (Ctrl+S) or close.", "FontColor", gray);
            else
                [txt, when] = it.notes.note(it.level, it.id);
                if txt == ""
                    set(obj.StateLabel, "Text", "No note yet. It is kept in " + f + e + " beside the dataset's outputs.", ...
                        "FontColor", gray);
                else
                    when.Format = 'yyyy-MM-dd HH:mm';
                    set(obj.StateLabel, "Text", "Written " + string(when) + " in " + f + e + ".", "FontColor", gray);
                end
            end
        end

        function endOpening(obj)
            if isvalid(obj); obj.Opening = false; end
        end

        function onTyping(obj, value)
            obj.Typed = value;
            if ~obj.Dirty
                obj.Dirty = true;
                obj.showState();
            end
        end

        function onLeftBox(obj)
            %onLeftBox  The box lost focus: write what was typed.
            obj.Typed = [];
            if obj.Dirty; obj.save(); end
        end

        function onKey(obj, evt)
            if evt.Key == "escape"
                obj.close();
            elseif evt.Key == "s" && any(ismember(evt.Modifier, ["control" "command"]))
                obj.save();
            end
        end
    end
end


function tf = sameItem(a, b)
tf = ~isempty(a) && a.notes == b.notes && a.level == b.level && isequaln(a.id, b.id);
end
