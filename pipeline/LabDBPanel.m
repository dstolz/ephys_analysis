classdef LabDBPanel < handle
    % LabDBPanel  The Database window: set up the lab database on this computer and see its state.
    %   p = LabDBPanel.open()                 % one window per MATLAB; again brings it to the front
    %   p = LabDBPanel.open(Parent=appFigure) % placed over the app that asked
    %
    %   It holds the settings LabDBSettings keeps (turn the database on or
    %   off, the server, the database, your login, the zone old times are
    %   read in), sets your password with MATLAB's own vault dialog
    %   (LabDBSecrets; it is never shown or stored here), tests the
    %   connection, and maps the lab's storage roots to folders on this
    %   computer (LabRoots): pick a folder and the root's name; a root that
    %   is not in the database yet (this workstation's data disk, say) can
    %   be registered in it, and a marker file is written at its top.
    %
    %   Keys: Ctrl+S save · F5 test the connection · Esc or Ctrl+W close ·
    %   Ctrl+? list the keys.
    %
    %   The apps open it from File > Database... and from the Database lamp
    %   in their status bar (LabDBLamp).
    %
    %   See also LabDB, LabDBSettings, LabDBSecrets, LabRoots.

    properties (SetAccess = private)
        Fig = []
        Ctl struct = struct()
        Roots struct = struct("Name", {}, "Path", {})
    end

    properties (Access = private)
        Listener = []
    end

    methods (Static)
        function p = open(opts)
            %open  Show the Database window (one per MATLAB).
            arguments
                opts.Parent = []
                opts.Visible (1,1) logical = true
            end
            persistent current
            if ~isempty(current) && isvalid(current) && ~isempty(current.Fig) && isvalid(current.Fig)
                if opts.Visible
                    current.Fig.Visible = "on";
                    figure(current.Fig);
                end
                p = current;
                return
            end
            current = LabDBPanel(opts.Parent, opts.Visible);
            p = current;
        end
    end

    methods
        function s = formSettings(obj)
            %formSettings  The settings as the form shows them (not yet saved).
            c = obj.Ctl;
            s = LabDBSettings.load();
            s.Enabled = c.Enabled.Value;
            s.Server = string(c.Server.Value);
            s.Port = c.Port.Value;
            s.DatabaseName = string(c.Database.Value);
            s.Username = string(c.Username.Value);
            s.PersonEmail = string(c.PersonEmail.Value);
            s.LabTimeZone = string(c.TimeZone.Value);
            s.Roots = obj.Roots;
        end

        function ok = save(obj)
            %save  Store the form's settings (Ctrl+S); false, with a message, when one is wrong.
            ok = false;
            try
                LabDBSettings.save(obj.formSettings());
            catch ME
                obj.say(string(ME.message), true);
                return
            end
            LabDB.disconnect();
            obj.say("Saved.", false);
            ok = true;
        end

        function testConnection(obj)
            %testConnection  Save, connect now and say what came of it (F5).
            if ~obj.save()
                return
            end
            obj.say("Connecting...", false);
            drawnow limitrate
            b = LabDB.connect(Force=true);
            st = LabDB.status();
            if isempty(b)
                obj.say(st.Message, st.State ~= "off");
                return
            end
            msg = st.Message;
            try
                who = b.person();
                s = LabDBSettings.load();
                if strlength(who.PersonId) > 0 && ~ismissing(who.PersonId)
                    s.PersonId = who.PersonId;
                    LabDBSettings.save(s);
                    msg = msg + " You are lab.person " + who.PersonId + ".";
                else
                    msg = msg + " Your login is mapped to no lab.person: ask the " + ...
                        "database administrator, or give your email.";
                end
                obj.markRoots(b);
            catch ME
                msg = msg + " (" + string(ME.message) + ")";
            end
            obj.say(msg, false);
        end

        function setPassword(obj)
            %setPassword  Ask for the password with MATLAB's vault dialog (setSecret).
            if ~obj.save()
                return
            end
            s = LabDBSettings.load();
            if strlength(s.Username) == 0 || strlength(s.Server) == 0
                obj.say("Name the server and your login first.", true);
                return
            end
            try
                LabDBSecrets.prompt(s);
                obj.say("Password stored in the MATLAB vault as " + ...
                    LabDBSecrets.secretName(s) + ".", false);
            catch ME
                obj.say(string(ME.message), true);
            end
        end

        function addRoot(obj, name, folder)
            %addRoot  Map storage root NAME to FOLDER on this computer.
            name = strtrim(string(name));
            folder = strtrim(string(folder));
            if name == "" || folder == ""
                obj.say("Give the root's name and pick its folder.", true);
                return
            end
            if ~isfolder(folder)
                obj.say("There is no folder " + folder + ".", true);
                return
            end
            if any([obj.Roots.Name] == name)
                obj.say("Storage root " + name + " is mapped already: remove it first.", true);
                return
            end
            probe = struct("Roots", struct("Name", name, "Path", folder));
            [ok, why] = LabRoots.checkMarker(name, probe);
            if ~ok
                obj.say(why, true);
                return
            end
            obj.Roots(end+1) = struct("Name", name, "Path", folder);
            obj.showRoots();
            obj.say("Mapped " + name + " to " + folder + " (not saved yet).", false);
        end

        function removeRoot(obj, name)
            %removeRoot  Forget the mapping of storage root NAME (the database is not changed).
            obj.Roots = obj.Roots([obj.Roots.Name] ~= string(name));
            obj.showRoots();
        end

        function registerRoot(obj, name)
            %registerRoot  Add storage root NAME (mapped here) to the database, and mark its folder.
            name = string(name);
            k = find([obj.Roots.Name] == name, 1);
            if isempty(k)
                obj.say("Map " + name + " to a folder first.", true);
                return
            end
            b = LabDB.connect(Force=true);
            if isempty(b)
                obj.say("Not connected: " + LabDB.status().Message, true);
                return
            end
            try
                R = b.storageRoots();
                hit = string(R.name) == name;
                if any(hit)
                    id = double(R.root_id(find(hit, 1)));
                else
                    id = b.addStorageRoot(name, "Registered from " + string(getenv("COMPUTERNAME")) + ...
                        " for " + obj.Roots(k).Path);
                end
                LabRoots.writeMarker(obj.Roots(k).Path, name, id);
                obj.say("Storage root " + name + " is lab.storage_root " + string(id) + ...
                    "; its folder is marked.", false);
                obj.markRoots(b);
            catch ME
                obj.say(string(ME.message), true);
            end
        end

        function close(obj)
            if ~isempty(obj.Fig) && isvalid(obj.Fig)
                delete(obj.Fig);
            end
        end

        function delete(obj)
            if ~isempty(obj.Listener) && isvalid(obj.Listener)
                delete(obj.Listener);
            end
        end
    end

    methods (Access = private)
        function obj = LabDBPanel(parent, visible)
            s = LabDBSettings.load();
            obj.Roots = s.Roots;
            pos = [100 100 720 560];
            if ~isempty(parent) && isvalid(parent)
                pp = parent.Position;
                pos(1:2) = pp(1:2) + max(0, (pp(3:4) - pos(3:4)) / 2);
            end
            f = uifigure("Name", "Lab database", "Position", pos, "Visible", "off", ...
                "Tag", "LabDBPanel", "KeyPressFcn", @(~, e) obj.onKey(e));
            obj.Fig = f;
            g = uigridlayout(f, [4 1]);
            g.RowHeight = {'fit', 'fit', '1x', 'fit'};
            g.Padding = [12 12 12 12];

            % settings
            form = uigridlayout(g, [4 4]);
            form.ColumnWidth = {130, '1x', 110, '1x'};
            form.RowHeight = repmat({24}, 1, 4);
            c = struct();
            c.Enabled = uicheckbox(form, "Text", "Use the lab database on this computer", ...
                "Value", s.Enabled);
            c.Enabled.Layout.Column = [1 4];
            uilabel(form, "Text", "Server");
            c.Server = uieditfield(form, "text", "Value", char(s.Server), ...
                "Placeholder", "e.g. labdb.example.edu");
            uilabel(form, "Text", "Port");
            c.Port = uieditfield(form, "numeric", "Value", s.Port, "Limits", [1 65535], ...
                "RoundFractionalValues", "on", "ValueDisplayFormat", "%d");
            uilabel(form, "Text", "Database");
            c.Database = uieditfield(form, "text", "Value", char(s.DatabaseName));
            uilabel(form, "Text", "Your login");
            c.Username = uieditfield(form, "text", "Value", char(s.Username), ...
                "Tooltip", "Your own database login: never a shared one");
            uilabel(form, "Text", "Your email (optional)");
            c.PersonEmail = uieditfield(form, "text", "Value", char(s.PersonEmail), ...
                "Tooltip", "Only when your login is not mapped to you in the database");
            uilabel(form, "Text", "Lab time zone");
            c.TimeZone = uieditfield(form, "text", "Value", char(s.LabTimeZone), ...
                "Tooltip", "Times written without a zone (old files, rig clocks) are read in this zone");

            buttons = uigridlayout(g, [1 5]);
            buttons.ColumnWidth = {'fit', 'fit', 'fit', '1x', 'fit'};
            buttons.Padding = [0 0 0 0];
            uibutton(buttons, "Text", "Set password...", "Tooltip", ...
                "Store your password in the MATLAB vault (it is never shown or saved here)", ...
                "ButtonPushedFcn", @(~, ~) obj.setPassword());
            uibutton(buttons, "Text", "Test connection", "Tooltip", "Save and connect now (F5)", ...
                "ButtonPushedFcn", @(~, ~) obj.testConnection());
            uibutton(buttons, "Text", "Save", "Tooltip", "Save the settings (Ctrl+S)", ...
                "ButtonPushedFcn", @(~, ~) obj.save());
            c.State = uilabel(buttons, "Text", "", "FontWeight", "bold");
            uibutton(buttons, "Text", "Close", "Tooltip", "Close (Esc)", ...
                "ButtonPushedFcn", @(~, ~) obj.close());

            % storage roots
            rp = uipanel(g, "Title", "Storage roots on this computer");
            rg = uigridlayout(rp, [2 5]);
            rg.RowHeight = {'1x', 26};
            rg.ColumnWidth = {'1x', 140, 'fit', 'fit', 'fit'};
            c.Roots = uitable(rg, "ColumnName", {'Root', 'Folder here', 'Marker'}, ...
                "ColumnWidth", {150, 'auto', 220}, "RowName", {});
            c.Roots.Layout.Column = [1 5];
            c.RootFolder = uieditfield(rg, "text", "Placeholder", "folder (Browse...)");
            c.RootName = uieditfield(rg, "text", "Placeholder", "root name, e.g. nas-main");
            uibutton(rg, "Text", "Browse...", "ButtonPushedFcn", @(~, ~) obj.browse());
            uibutton(rg, "Text", "Add", "ButtonPushedFcn", @(~, ~) ...
                obj.addRoot(c.RootName.Value, c.RootFolder.Value));
            uibutton(rg, "Text", "Remove / Register...", "Tooltip", ...
                "Remove the selected mapping, or register the selected root in the database", ...
                "ButtonPushedFcn", @(~, ~) obj.rootAction());

            c.Message = uilabel(g, "Text", "", "WordWrap", "on");
            obj.Ctl = c;
            obj.showRoots();
            obj.showState();
            obj.Listener = listener(LabDB.instance(), "StateChanged", @(~, ~) obj.showState());
            addlistener(f, "ObjectBeingDestroyed", @(~, ~) obj.delete());
            if visible
                f.Visible = "on";
            end
        end

        function onKey(obj, e)
            mods = string(e.Modifier);
            ctrl = any(mods == "control") || any(mods == "command");
            key = string(e.Key);
            if ctrl && (ismember(key, ["slash", "questionmark"]) || string(e.Character) == "?")
                uialert(obj.Fig, sprintf(['Ctrl+S   Save the settings\n' ...
                    'F5       Test the connection (saves first)\n' ...
                    'Esc      Close (also Ctrl+W)\n' ...
                    'Ctrl+?   This list']), "Keyboard shortcuts", "Icon", "info");
            elseif ctrl && key == "s"
                obj.save();
            elseif key == "f5"
                obj.testConnection();
            elseif key == "escape" || (ctrl && key == "w")
                obj.close();
            end
        end

        function browse(obj)
            d = uigetdir("", "The folder the storage root is on this computer");
            figure(obj.Fig);
            if ischar(d)
                obj.Ctl.RootFolder.Value = d;
            end
        end

        function rootAction(obj)
            sel = obj.Ctl.Roots.Selection;
            if isempty(sel)
                obj.say("Select a root in the table first.", true);
                return
            end
            name = obj.Roots(sel(1)).Name;
            answer = uiconfirm(obj.Fig, "Storage root " + name + ": remove its mapping on this " + ...
                "computer, or register it in the lab database (and mark its folder)?", ...
                "Storage root", "Options", {'Register', 'Remove mapping', 'Cancel'}, ...
                "DefaultOption", 3, "CancelOption", 3);
            switch answer
                case "Register"
                    obj.registerRoot(name);
                case "Remove mapping"
                    obj.removeRoot(name);
            end
        end

        function showRoots(obj, inDb)
            if nargin < 2
                inDb = strings(0, 1);
            end
            n = numel(obj.Roots);
            data = cell(n, 3);
            for k = 1:n
                data{k, 1} = char(obj.Roots(k).Name);
                data{k, 2} = char(obj.Roots(k).Path);
                [ok, why] = LabRoots.checkMarker(obj.Roots(k).Name, struct("Roots", obj.Roots(k)));
                if ~ok
                    data{k, 3} = char("refused: " + why);
                elseif isfile(fullfile(obj.Roots(k).Path, LabRoots.MarkerFile))
                    data{k, 3} = 'marked';
                elseif ~isempty(inDb) && ~any(inDb == obj.Roots(k).Name)
                    data{k, 3} = 'not in the database';
                else
                    data{k, 3} = 'no marker yet';
                end
            end
            obj.Ctl.Roots.Data = data;
        end

        function markRoots(obj, b)
            R = b.storageRoots();
            obj.showRoots(string(R.name));
        end

        function showState(obj)
            if isempty(obj.Fig) || ~isvalid(obj.Fig)
                return
            end
            st = LabDB.status();
            [label, color] = LabDBLamp.look(st.State);
            obj.Ctl.State.Text = "Database: " + label;
            obj.Ctl.State.FontColor = color;
            obj.Ctl.State.Tooltip = char(st.Message);
        end

        function say(obj, text, isError)
            if isempty(obj.Fig) || ~isvalid(obj.Fig)
                return
            end
            obj.Ctl.Message.Text = char(text);
            if isError
                obj.Ctl.Message.FontColor = [0.75 0.10 0.10];
            else
                obj.Ctl.Message.FontColor = [0.15 0.15 0.15];
            end
        end
    end
end
