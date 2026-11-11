classdef ProbePickDialog < handle
    %ProbePickDialog  Shanks and recording channels picked by clicking a dataset's probe, in a small modal window.
    %   The window holds a Shanks and a Channels field over the probe drawn
    %   at its true site positions (ProbePicker, as the dataset browser's
    %   Channels tab draws it): a click on a site picks or drops its
    %   channel, a click on a shank picks or drops the shank, and the fields
    %   follow; a field typed redraws the pick. A site is kept when both
    %   lists hold it (blank = all, the rule of selectUnits): kept sites
    %   are filled, a picked site on a shank left out is ringed. All clears
    %   both. A line under the probe counts the sites kept and names the
    %   picks this probe does not have. The window only holds the pending
    %   pick; nothing changes until OK. The analysis app opens it from the
    %   Probe... button beside each Channels field of the Figures tab's
    %   editor (EphysFigGenApp.pickChannels), on the active dataset's probe.
    %
    %     dlg = ProbePickDialog(channels, shanks, Probe=src.probe, Dataset=src.name, ...
    %         Parent=app.Fig, OnDone=@(r) apply(r));
    %
    %   CHANNELS are recording channels, 1-based (the probe map's chanMap
    %   + 1); SHANKS the probe map's kcoords values; [] = all. Options:
    %     Probe         the probe map (decoded JSON: chanMap, xc, yc,
    %                   kcoords, connected; loadAnalysisSource's src.probe);
    %                   [] = none
    %     Dataset       the name of the dataset the probe is ("" = none open)
    %     NoProbe       the note in the probe's place without one ("" = "No
    %                   dataset open", or "<Dataset> has no probe map")
    %     Shanks        false: a pick of channels only (a signal's columns):
    %                   no Shanks field, and a click on a shank picks every
    %                   channel of its sites, or drops them all
    %                   (ProbePicker's ShankPick "channels"); default true
    %     Title         the window's title ("Pick channels on the probe")
    %     Intro         what the pick is for, a line over the fields ("" =
    %                   none); how to click is said under it either way
    %     ChannelsName  the channels' name in a script, in the field's
    %                   tooltip ("" = none), e.g. "observe.units.channels"
    %     ShanksName    the shanks' name in a script ("" = none)
    %     OnDone        called once as OnDone(R) when the window closes
    %     Parent        the uifigure to center on ([] = none)
    %     Visible       false builds the window hidden (tests)
    %
    %   The window is modal but does not block (no uiwait): the caller
    %   applies the result in OnDone. R is [] when the window is canceled,
    %   closed, or OK changes nothing; otherwise a struct with fields
    %   channels and shanks, each [] (all) or a sorted row of numbers
    %   (shanks always [] with Shanks=false).
    %
    %   Properties (read-only): Fig, Ctl (the controls: Intro, Shanks (not
    %   with Shanks=false), Channels, All, Note, Count, Error, Cancel, OK),
    %   Picker (the ProbePicker), Channels and Shanks (the pending pick, []
    %   = all), ErrorText. Methods, the same paths as the controls:
    %   setChannels(V) and setShanks(V) (V numbers or text, "" = all; bad
    %   text stays in the field, marked), click(KIND, VALUE) (a click on
    %   the probe: "site" and a recording channel, "shank" and a kcoords
    %   value), pickAll (All: both blank), ok, cancel, isOpen.
    %
    %   See also ProbePicker, DatasetBrowser, EphysFigGenApp, parseNumbers, numbersText.

    properties (SetAccess = private)
        Fig = []                     % the uifigure
        Ctl = struct()               % the controls
        Picker = []                  % the ProbePicker drawing the probe
        Channels (1,:) double = []   % the pending recording channels ([] = all)
        Shanks (1,:) double = []     % the pending shanks, kcoords ([] = all)
    end

    properties
        OnDone = []                  % called once as OnDone(result) when the window closes
    end

    properties (Dependent)
        ErrorText                    % the inline message ("" when none)
    end

    properties (Access = private)
        Original = struct('channels', [], 'shanks', [])   % the pick the window was opened with
        HasShanks (1,1) logical = true
        Done (1,1) logical = false
        Why = struct('Shanks', "", 'Channels', "")   % what is wrong with each field ("" = fine): the inline message joins them
    end

    methods
        function obj = ProbePickDialog(channels, shanks, opts)
            arguments
                channels = []
                shanks = []
                opts.Probe = []
                opts.Dataset (1,1) string = ""
                opts.NoProbe (1,1) string = ""
                opts.Shanks (1,1) logical = true
                opts.Title (1,1) string = "Pick channels on the probe"
                opts.Intro (1,1) string = ""
                opts.ChannelsName (1,1) string = ""
                opts.ShanksName (1,1) string = ""
                opts.OnDone = []
                opts.Parent = []
                opts.Visible (1,1) logical = true
            end
            obj.HasShanks = opts.Shanks;
            obj.Channels = ProbePickDialog.row(channels);
            if obj.HasShanks; obj.Shanks = ProbePickDialog.row(shanks); end
            obj.Original = obj.pick();
            obj.OnDone = opts.OnDone;
            obj.build(opts);
        end

        function delete(obj)
            if ~isempty(obj.Fig) && isvalid(obj.Fig); delete(obj.Fig); end
        end

        function t = get.ErrorText(obj)
            t = "";
            if isfield(obj.Ctl, 'Error') && isvalid(obj.Ctl.Error)
                t = join(reshape(string(obj.Ctl.Error.Text), 1, []), newline);
            end
        end

        function tf = isOpen(obj)
            tf = isvalid(obj) && ~obj.Done && ~isempty(obj.Fig) && isvalid(obj.Fig);
        end

        function setChannels(obj, v)
            %setChannels  The Channels field: numbers or text ("" = all); a bad text stays in the field, marked.
            obj.Ctl.Channels.Value = char(ProbePickDialog.asText(v));
            obj.readField("Channels");
        end

        function setShanks(obj, v)
            %setShanks  The Shanks field: numbers or text ("" = all); a bad text stays in the field, marked.
            if ~obj.HasShanks
                error('ProbePickDialog:NoShanks', 'This pick has channels only: a click on a shank picks its channels.');
            end
            obj.Ctl.Shanks.Value = char(ProbePickDialog.asText(v));
            obj.readField("Shanks");
        end

        function click(obj, kind, value)
            %click  A click on the probe: KIND "site" toggles recording channel VALUE, "shank" the kcoords shank VALUE.
            obj.Picker.click(kind, value);   % (its OnPick: onPick)
        end

        function pickAll(obj)
            %pickAll  Every shank and every channel: both fields blank (the All button).
            obj.onPick([], []);
        end

        function ok(obj)
            %ok  Read the fields; a bad one keeps the window open with the reason; else hand the pick to OnDone and close.
            if obj.Done; return; end
            bad = false;
            for f = obj.fields()
                bad = obj.readField(f) ~= "" || bad;
            end
            if bad; return; end   % (the inline message says why)
            r = obj.pick();
            if isequal(r, obj.Original); r = []; end
            obj.finish(r);
        end

        function cancel(obj)
            obj.finish([]);
        end
    end

    methods (Access = private)
        function f = fields(obj)
            %fields  The pick's fields, in order: Shanks (when it has them) and Channels.
            f = "Channels";
            if obj.HasShanks; f = ["Shanks" "Channels"]; end
        end

        function r = pick(obj)
            %pick  The pending pick as OnDone gets it: channels and shanks, [] when blank.
            r = struct('channels', blankEmpty(obj.Channels), 'shanks', blankEmpty(obj.Shanks));
        end

        function why = readField(obj, name)
            %readField  Field NAME's text into the pick (blank = all); WHY says what is wrong ("" when fine).
            c = obj.Ctl;
            h = c.(name);
            why = "";
            try
                v = ProbePickDialog.row(parseNumbers(h.Value, name));
                if name == "Channels" && any(~isfinite(v) | v < 1 | v ~= round(v))
                    why = "Channels: recording channels are whole numbers from 1 (the probe map's chanMap + 1).";
                elseif name == "Shanks" && any(~isfinite(v) | v ~= round(v))
                    why = "Shanks: whole numbers (the probe map's kcoords values).";
                end
            catch ME
                why = string(ME.message);
            end
            if why == ""
                obj.(name) = v;
                h.Value = char(numbersText(v));
                obj.Picker.select(obj.Channels, obj.Shanks);
            end
            obj.Why.(name) = why;
            obj.showWhy();
            obj.refreshCount();
        end

        function showWhy(obj)
            %showWhy  Each field marked while its text is bad, and the inline message: their reasons, Shanks first.
            c = obj.Ctl;
            reasons = strings(1, 0);
            for f = obj.fields()
                bad = obj.Why.(f) ~= "";
                c.(f).BackgroundColor = ternary(bad, [1 0.9 0.9], [1 1 1]);
                if bad; reasons(end+1) = obj.Why.(f); end %#ok<AGROW>
            end
            c.Error.Text = strjoin(reasons, newline);
        end

        function onPick(obj, channels, shanks)
            %onPick  A click on the probe (or All): the pick and the fields follow.
            c = obj.Ctl;
            obj.Channels = ProbePickDialog.row(channels);
            if obj.HasShanks
                obj.Shanks = ProbePickDialog.row(shanks);
                c.Shanks.Value = char(numbersText(obj.Shanks));
            end
            c.Channels.Value = char(numbersText(obj.Channels));
            obj.Why = struct('Shanks', "", 'Channels', "");   % both fields hold the pick now
            obj.showWhy();
            obj.Picker.select(obj.Channels, obj.Shanks);
            obj.refreshCount();
        end

        function build(obj, opts)
            fig = uifigure("Name", opts.Title, "Visible", "off", "Position", [100 100 480 660], ...
                "WindowStyle", "modal", "Tag", "ProbePickDialog");
            parent = opts.Parent;
            if ~isempty(parent) && isvalid(parent)
                p = parent.Position;
                fig.Position(1:2) = p(1:2) + max(0, (p(3:4) - fig.Position(3:4)) / 2);
            end
            fig.CloseRequestFcn = @(~, ~) obj.cancel();
            obj.Fig = fig;
            gray = [0.38 0.38 0.38];

            g = uigridlayout(fig, [7 1], "RowHeight", {'fit', 26, 'fit', '1x', 'fit', 'fit', 34}, "RowSpacing", 6);
            c = struct();
            how = "Click a site to pick or drop its channel, a shank to pick or drop the shank: the filled sites are kept. " + ...
                "Or type the numbers, e.g. 1:16 or 3 7 12. Blank = all.";
            if ~obj.HasShanks
                how = "Click a site to pick or drop its channel, a shank to pick or drop all its channels: the filled sites " + ...
                    "are kept. Or type the numbers, e.g. 1:16 or 3 7 12. Blank = all.";
            end
            intro = how;
            if opts.Intro ~= ""; intro = opts.Intro + " " + how; end
            c.Intro = uilabel(g, "WordWrap", "on", "Text", intro);

            script = @(name) ternary(name == "", "", " Script name: " + name);
            chTip = "The recording channels kept (1-based: the probe map's chanMap + 1), e.g. 1:16 or 3 7 12; blank = all. " + ...
                "Click a site on the probe to pick or drop its channel." + script(opts.ChannelsName);
            if obj.HasShanks
                r = uigridlayout(g, [1 5], "ColumnWidth", {'fit', '1x', 'fit', '1x', 50}, "RowHeight", {'1x'}, ...
                    "Padding", [0 0 0 0], "ColumnSpacing", 6);
                uilabel(r, "Text", "Shanks");
                c.Shanks = uieditfield(r, "text", "Placeholder", "all", "Value", char(numbersText(obj.Shanks)), ...
                    "ValueChangedFcn", @(~, ~) obj.readField("Shanks"), ...
                    "Tooltip", "The probe shanks kept (the probe map's kcoords), e.g. 1:4 or 1 3; blank = every shank. " + ...
                    "Click a shank on the probe to pick or drop it." + script(opts.ShanksName));
            else
                r = uigridlayout(g, [1 3], "ColumnWidth", {'fit', '1x', 50}, "RowHeight", {'1x'}, ...
                    "Padding", [0 0 0 0], "ColumnSpacing", 6);
            end
            uilabel(r, "Text", "Channels");
            c.Channels = uieditfield(r, "text", "Placeholder", "all", "Value", char(numbersText(obj.Channels)), ...
                "ValueChangedFcn", @(~, ~) obj.readField("Channels"), "Tooltip", chTip);
            c.All = uibutton(r, "Text", "All", "ButtonPushedFcn", @(~, ~) obj.pickAll(), ...
                "Tooltip", ternary(obj.HasShanks, "Every shank and every channel (both fields blank).", "Every channel (the field blank)."));
            c.Note = uilabel(g, "Text", "", "WordWrap", "on", "FontColor", gray);
            P = ProbePicker(g);
            P.Axes.Layout.Row = 4;
            if ~obj.HasShanks; P.ShankPick = "channels"; end
            P.OnPick = @(ch, sh) obj.onPick(ch, sh);
            obj.Picker = P;
            c.Count = uilabel(g, "Text", "", "WordWrap", "on");
            c.Error = uilabel(g, "Text", "", "FontColor", [0.75 0.1 0.1], "WordWrap", "on");
            bg = uigridlayout(g, [1 3], "ColumnWidth", {'1x', 90, 90}, "RowHeight", {30}, "Padding", [0 0 0 0]);
            c.Cancel = uibutton(bg, "Text", "Cancel", "ButtonPushedFcn", @(~, ~) obj.cancel());
            c.Cancel.Layout.Column = 2;
            c.OK = uibutton(bg, "Text", "OK", "Tooltip", "Use these shanks and channels.", "ButtonPushedFcn", @(~, ~) obj.ok());
            c.OK.Layout.Column = 3;
            styleButton(c.Cancel);
            styleButton(c.OK, "confirm");
            obj.Ctl = c;

            % the probe, drawn once the window has its size (ProbePicker writes the channels beside the sites when they fit)
            fig.Visible = matlab.lang.OnOffSwitchState(opts.Visible);
            if opts.Visible; drawnow; end
            P.select(obj.Channels, obj.Shanks);
            none = opts.NoProbe;
            if none == "" && opts.Dataset == ""
                none = "No dataset open";
            elseif none == ""
                none = opts.Dataset + " has no probe map";
            end
            P.setProbe(opts.Probe, none);
            S = P.Sites;
            if height(S) == 0
                c.Note.Text = none + ": type the " + ternary(obj.HasShanks, "shanks and channels", "channels") + ".";
                if opts.Dataset == "" && opts.NoProbe == ""
                    c.Note.Text = "No dataset open: scan the root and pick a dataset to draw its probe here. " + ...
                        "The fields still take the numbers typed.";
                end
            else
                [~, C] = probeColumns(S.x, S.shank);
                name = opts.Dataset;
                if name == ""; name = "The probe"; end
                c.Note.Text = sprintf("%s: %d sites on %d shank%s.", name, height(S), numel(C.center), ...
                    repmat('s', 1, numel(C.center) ~= 1));
            end
            obj.refreshCount();
        end

        function refreshCount(obj)
            %refreshCount  The line under the probe: the sites kept, and the picks this probe does not have.
            c = obj.Ctl;
            S = obj.Picker.Sites;
            if height(S) == 0
                c.Count.Text = "";
                return
            end
            n = nnz(obj.Picker.kept());
            if isempty(obj.Channels) && isempty(obj.Shanks)
                txt = sprintf("Kept: every site (%d).", height(S));
            else
                txt = sprintf("Kept: %d of %d sites.", n, height(S));
            end
            noCh = setdiff(obj.Channels, S.channel);
            noSh = setdiff(obj.Shanks, S.shank);
            if ~isempty(noCh)
                txt = txt + " Not on this probe: channel" + repmat('s', 1, numel(noCh) ~= 1) + " " + numbersText(noCh) + ".";
            end
            if ~isempty(noSh)
                txt = txt + " Not on this probe: shank" + repmat('s', 1, numel(noSh) ~= 1) + " " + numbersText(noSh) + ".";
            end
            c.Count.Text = txt;
            c.Count.FontColor = ternary(n == 0, [0.75 0.1 0.1], [0.10 0.10 0.10]);
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

    methods (Static, Access = private)
        function v = row(v)
            %row  Numbers as a sorted row of distinct values (blank: 1x0).
            v = sort(unique(reshape(double(v), 1, [])));
        end

        function t = asText(v)
            %asText  A field's text from numbers (numbersText) or text as given.
            if isnumeric(v)
                t = numbersText(v);
            else
                t = strtrim(string(v));
            end
        end
    end
end


function v = blankEmpty(v)
%blankEmpty  [] for an empty pick (all), else the row.
if isempty(v); v = []; end
end


function v = ternary(tf, a, b)
if tf; v = a; else; v = b; end
end


function closeFig(fig)
if ~isempty(fig) && isvalid(fig); delete(fig); end
end
