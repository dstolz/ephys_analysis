classdef LabLocatorDialog < handle
    % LabLocatorDialog  Pick recordings from the lab database and open them where they are on this computer.
    %   dlg = LabLocatorDialog.open(Parent=fig, OnDone=@(folders) ..., What="outputs")
    %
    %   Filters: subject, project, the date range of the recordings
    %   (uidatepicker), tags. Search (Enter) asks the database
    %   (LabLocator.sessions; the last answer while it does not answer, with
    %   its date). The table lists each session: subject, session, started,
    %   where it is here, and its output folders. Open (Ctrl+Enter) calls
    %   OnDone(FOLDERS) with the selected sessions' folders here:
    %
    %     What="outputs"   the folders that hold their outputs (the analysis
    %                      app's "folders" source)
    %     What="sessions"  the session folders themselves
    %
    %   A session whose root is not mapped here, or whose folder is not
    %   there, has none and is named in the message. Esc cancels; Ctrl+?
    %   lists the keys.
    %
    %   Methods, the same paths as the controls (tests): search(), select(rows),
    %   ok(), cancel(). Results (the last search) and Folders (what OK gave).
    %
    %   See also LabLocator, EphysFigGenApp.

    properties (SetAccess = private)
        Fig = []
        Ctl struct = struct()
        Results table = LabLocator.empty()
        Folders (1,:) string = strings(1, 0)
        What (1,1) string = "outputs"
    end

    properties (Access = private)
        OnDone = []
    end

    methods (Static)
        function dlg = open(opts)
            arguments
                opts.Parent = []
                opts.OnDone = []
                opts.What (1,1) string {mustBeMember(opts.What, ["outputs" "sessions"])} = "outputs"
                opts.Visible (1,1) logical = true
            end
            dlg = LabLocatorDialog(opts);
        end
    end

    methods
        function T = search(obj)
            %search  Ask the database with the filters (Enter).
            c = obj.Ctl;
            tags = strtrim(split(string(c.Tags.Value), [",", " "]));
            tags = reshape(tags(tags ~= ""), 1, []);
            proj = "";
            if ~isempty(c.Project.Value); proj = string(c.Project.Value); end
            [T, asOf, note] = LabLocator.sessions(Subject=strtrim(string(c.Subject.Value)), Project=proj, ...
                From=LabLocatorDialog.day(c.From.Value), To=LabLocatorDialog.day(c.To.Value), Tags=tags);
            obj.Results = T;
            data = cell(height(T), 5);
            for k = 1:height(T)
                here = T.folder(k);
                if here == ""
                    here = "root " + T.root(k) + " not mapped here";
                elseif ~T.reachable(k)
                    here = here + " (not there now)";
                end
                st = "";
                if ~isnat(T.started_at(k)); st = string(T.started_at(k), "yyyy-MM-dd HH:mm"); end
                data(k, :) = {char(T.subject_id(k)), char(T.label(k)), char(st), char(here), ...
                    char(strjoin(T.outputs{k}, "; "))};
            end
            c.Table.Data = data;
            msg = sprintf('%d session(s).', height(T));
            if note ~= ""; msg = note + " " + msg; end
            if isnat(asOf) && note ~= ""; msg = note; end
            obj.say(msg);
        end

        function select(obj, rows)
            %select  Select rows ROWS of the results.
            obj.Ctl.Table.Selection = reshape(rows, [], 1);
        end

        function F = ok(obj)
            %ok  The selected sessions' folders here, to OnDone (Ctrl+Enter).
            F = strings(1, 0);
            sel = obj.Ctl.Table.Selection;
            if isempty(sel)
                obj.say("Select the sessions to open first.");
                return
            end
            rows = unique(sel(:, 1)).';
            T = obj.Results(rows, :);
            missing = strings(1, 0);
            for k = 1:height(T)
                if obj.What == "outputs"
                    f = reshape(string(T.outputs{k}), 1, []);
                else
                    f = T.folder(k);
                    if ~T.reachable(k); f = strings(1, 0); end
                end
                if isempty(f); missing(end + 1) = T.label(k); end %#ok<AGROW>
                F = [F, f]; %#ok<AGROW>
            end
            F = unique(F, "stable");
            if isempty(F)
                obj.say("None of them is on this computer: " + strjoin(missing, ", ") + ...
                    ". Map their storage root in the Database window.");
                return
            end
            obj.Folders = F;
            done = obj.OnDone;
            delete(obj.Fig);
            if ~isempty(done); done(F); end
            if ~isempty(missing)
                warning("LabLocatorDialog:NotHere", "Not on this computer, so not opened: %s", strjoin(missing, ", "));
            end
        end

        function cancel(obj)
            if ~isempty(obj.Fig) && isvalid(obj.Fig); delete(obj.Fig); end
        end
    end

    methods (Access = private)
        function obj = LabLocatorDialog(opts)
            obj.OnDone = opts.OnDone;
            obj.What = opts.What;
            pos = [100 100 820 520];
            p = opts.Parent;
            if ~isempty(p) && isvalid(p)
                pp = p.Position;
                pos(1:2) = pp(1:2) + max(0, (pp(3:4) - pos(3:4)) / 2);
            end
            f = uifigure("Name", "Open from the lab database", "Position", pos, "Visible", "off", ...
                "Tag", "LabLocatorDialog", "KeyPressFcn", @(~, e) obj.onKey(e));
            obj.Fig = f;
            g = uigridlayout(f, [4 1]);
            g.RowHeight = {'fit', '1x', 'fit', 30};
            fg = uigridlayout(g, [2 6]);
            fg.ColumnWidth = {60, '1x', 60, '1x', 50, '1x'};
            fg.Padding = [0 0 0 0];
            c = struct();
            uilabel(fg, "Text", "Subject");
            c.Subject = uieditfield(fg, "text", "Placeholder", "any");
            uilabel(fg, "Text", "Project");
            [items, data] = LabLocatorDialog.projects();
            c.Project = uidropdown(fg, "Items", items, "ItemsData", data);
            uilabel(fg, "Text", "Tags");
            c.Tags = uieditfield(fg, "text", "Placeholder", "e.g. stage:raw, qc:pass");
            uilabel(fg, "Text", "From");
            c.From = uidatepicker(fg, "Placeholder", "any day");
            uilabel(fg, "Text", "To");
            c.To = uidatepicker(fg, "Placeholder", "any day");
            c.SearchButton = uibutton(fg, "Text", "Search", "Tooltip", "Ask the lab database (Enter)", ...
                "ButtonPushedFcn", @(~, ~) obj.search());
            c.SearchButton.Layout.Column = [5 6];
            c.Table = uitable(g, "ColumnName", {'Subject', 'Session', 'Started', 'Here', 'Outputs'}, ...
                "ColumnWidth", {90, 170, 120, '1x', '1x'}, "RowName", {}, "SelectionType", "row", ...
                "Multiselect", "on", "DoubleClickedFcn", @(~, ~) obj.ok());
            c.Message = uilabel(g, "Text", "", "WordWrap", "on");
            bg = uigridlayout(g, [1 3]);
            bg.ColumnWidth = {'1x', 100, 100};
            bg.Padding = [0 0 0 0];
            uilabel(bg, "Text", "");
            uibutton(bg, "Text", "Open", "Tooltip", "Open the selected sessions (Ctrl+Enter)", ...
                "ButtonPushedFcn", @(~, ~) obj.ok());
            uibutton(bg, "Text", "Cancel", "Tooltip", "Esc", "ButtonPushedFcn", @(~, ~) obj.cancel());
            obj.Ctl = c;
            if opts.Visible; f.Visible = "on"; end
        end

        function onKey(obj, e)
            mods = string(e.Modifier);
            ctrl = any(mods == "control") || any(mods == "command");
            key = string(e.Key);
            if ctrl && (ismember(key, ["slash", "questionmark"]) || string(e.Character) == "?")
                uialert(obj.Fig, sprintf(['Enter        Search\n' ...
                    'Ctrl+Enter   Open the selected sessions\n' ...
                    'Esc          Cancel\n' ...
                    'Ctrl+?       This list']), "Keyboard shortcuts", "Icon", "info");
            elseif key == "return" && ctrl
                obj.ok();
            elseif key == "return"
                obj.search();
            elseif key == "escape"
                obj.cancel();
            end
        end

        function say(obj, text)
            if ~isempty(obj.Fig) && isvalid(obj.Fig); obj.Ctl.Message.Text = char(text); end
        end
    end

    methods (Static, Access = private)
        function [items, data] = projects()
            %projects  The project dropdown: any, then the database's projects (none while it does not answer).
            items = {'any project'};
            data = {''};
            b = LabDB.connect(MaxWait=2);
            if isempty(b); return; end
            try
                P = b.projects();
                items = [items, reshape(cellstr(string(P.project_id) + " - " + string(P.name)), 1, [])];
                data = [data, reshape(cellstr(string(P.project_id)), 1, [])];
            catch
            end
        end

        function d = day(v)
            %day  A date picker's value as a datetime (NaT when none).
            d = NaT;
            if isdatetime(v) && ~isempty(v) && ~isnat(v); d = v; end
        end
    end
end
