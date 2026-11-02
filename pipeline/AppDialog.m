classdef AppDialog
    %AppDialog  What the apps say when something stops: one voice for failures and for "no project yet".
    %   EphysPipelineApp, EphysAnalysisApp and DatasetBrowser word their
    %   failures the same way, so a person learns it once:
    %
    %     AppDialog.failure(ACTION, SUBJECT, MESSAGE, Try=, Details=)
    %         "Could not <action> on <subject>." then the message, "Try: ..."
    %         (the next step) and "Details: ..." (where the whole story is)
    %     AppDialog.alertFailure(FIG, TITLE, ACTION, SUBJECT, CAUSE, ...)
    %         the same as an alert; CAUSE is an MException or the message text
    %     AppDialog.noProject(Where=)    the one "No project is loaded" text
    %     AppDialog.alertNoProject(FIG, GOTOFCN, ...)
    %         that text as an alert with a "Go to <tab>" button
    %     AppDialog.alert(FIG, MESSAGE, TITLE, ...)
    %         uialert; every alert of these helpers goes through it
    %     AppDialog.showText(TITLE, TEXT, Parent=FIG)
    %         a small window that lists TEXT (the Help menus' "Keyboard
    %         shortcuts and right-click menus")
    %
    %   The tests read the alerts instead of showing them: AppDialog.capture(true)
    %   keeps every AppDialog.alert in AppDialog.captured() and shows none (a
    %   headless run never waits on a dialog); capture(false) shows them
    %   again, and captured(Clear=true) empties the list.
    %
    %   Nothing here knows either app: the caller names the tab and the
    %   next step.
    %
    %   See also EphysPipelineApp, EphysAnalysisApp, DatasetBrowser, uialert.

    methods (Static)

        function alert(fig, message, title, varargin)
            %alert  uialert(FIG, MESSAGE, TITLE, ...), or kept for the tests when capture is on.
            %   FIG may be empty or deleted (nothing shows then). With
            %   capture on, the alert is recorded, not shown, and its
            %   CloseFcn is not called.
            arguments
                fig
                message (1,1) string
                title (1,1) string = "Message"
            end
            arguments (Repeating)
                varargin
            end
            S = AppDialog.store("get");
            if S.On
                S.Items(end+1, 1) = struct('Message', message, 'Title', title, 'Options', {AppDialog.optionsOf(varargin)});
                AppDialog.store("set", S);
                return
            end
            if isempty(fig) || ~isvalid(fig); return; end
            uialert(fig, message, title, varargin{:});
        end

        function tf = capture(on)
            %capture  Keep the alerts instead of showing them (true) or show them again (false); the previous setting is returned.
            arguments
                on (1,1) logical
            end
            S = AppDialog.store("get");
            tf = S.On;
            S.On = on;
            AppDialog.store("set", S);
        end

        function A = captured(opts)
            %captured  The alerts kept while capture was on: a struct column with Message, Title and Options.
            arguments
                opts.Clear (1,1) logical = false
            end
            S = AppDialog.store("get");
            A = S.Items;
            if opts.Clear
                S.Items = AppDialog.emptyItems();
                AppDialog.store("set", S);
            end
        end

        function text = failure(action, subject, message, opts)
            %failure  "Could not <action> on <subject>.", the message, the next step and where the details are.
            %   TEXT = AppDialog.failure("detect artifacts", "recA", "no signal",
            %   Try="run Signals first", Details="Run tab > Open log") is
            %       Could not detect artifacts on recA.
            %       no signal
            %       Try: run Signals first.
            %       Details: Run tab > Open log
            %   A line is left out when its text is empty; without a SUBJECT
            %   the first line is "Could not <action>.".
            arguments
                action (1,1) string
                subject (1,1) string
                message (1,1) string
                opts.Try (1,1) string = ""
                opts.Details (1,1) string = ""
            end
            if ismissing(subject); subject = ""; end   % a name not known yet
            if ismissing(message); message = ""; end
            head = "Could not " + action;
            if strip(subject) ~= ""; head = head + " on " + subject; end
            lines = head + ".";
            message = strip(message);
            if message ~= ""; lines(end+1) = message; end
            try_ = strip(opts.Try);
            if try_ ~= ""
                try_ = regexprep(try_, '\.$', '');
                lines(end+1) = "Try: " + try_ + ".";
            end
            if strip(opts.Details) ~= ""; lines(end+1) = "Details: " + strip(opts.Details); end
            text = strjoin(lines, newline);
        end

        function alertFailure(fig, title, action, subject, cause, opts)
            %alertFailure  The failure text (failure) as an alert; CAUSE is an MException or text.
            %   The message of an MException is its message; Try and
            %   Details are as for failure.
            arguments
                fig
                title (1,1) string
                action (1,1) string
                subject (1,1) string
                cause
                opts.Try (1,1) string = ""
                opts.Details (1,1) string = ""
            end
            if isa(cause, 'MException')
                msg = string(cause.message);
            else
                msg = string(cause);
            end
            AppDialog.alert(fig, AppDialog.failure(action, subject, msg, Try=opts.Try, Details=opts.Details), title, "Icon", "error");
        end

        function text = noProject(opts)
            %noProject  The one message for "nothing is scanned yet".
            %   Where names the tab that holds the project root and the Scan
            %   button (default "Project"); Action is what to do there
            %   (default "press Scan").
            arguments
                opts.Where (1,1) string = "Project"
                opts.Action (1,1) string = "press Scan"
            end
            text = "No project is loaded. On the " + opts.Where + " tab choose the folder that holds your recordings " + ...
                "(the project root) and " + opts.Action + ".";
        end

        function alertNoProject(fig, gotoFcn, opts)
            %alertNoProject  noProject as an alert with a "Go to <tab> tab" button that calls GOTOFCN().
            %   Without GOTOFCN (or captured for the tests) it is a plain
            %   alert. TITLE defaults to "No project".
            arguments
                fig
                gotoFcn = []
                opts.Where (1,1) string = "Project"
                opts.Title (1,1) string = "No project"
            end
            msg = AppDialog.noProject(Where=opts.Where);
            if isempty(gotoFcn)
                AppDialog.alert(fig, msg, opts.Title, "Icon", "warning");
                return
            end
            goto = "Go to " + opts.Where + " tab";
            AppDialog.alert(fig, msg, opts.Title, "Icon", "warning", "Options", [goto, "Close"], "DefaultOption", 1, ...
                "CancelOption", 2, "CloseFcn", @(~, evt) pickedGoto(evt, goto, gotoFcn));
        end

        function fig = showText(title, text, opts)
            %showText  A small window that lists TEXT (lines), read only, with a Close button.
            %   FIG is the window (the caller keeps it, or ignores it). The
            %   window opens beside Parent when given.
            arguments
                title (1,1) string
                text (:,1) string
                opts.Parent = []
                opts.Size (1,2) double = [560 420]
                opts.Visible (1,1) logical = true
            end
            pos = [200 200 opts.Size];
            try
                if ~isempty(opts.Parent) && isvalid(opts.Parent)
                    p = opts.Parent.Position;
                    pos(1:2) = p(1:2) + [40 p(4) - opts.Size(2) - 40];
                end
            catch
            end
            fig = uifigure("Name", title, "Position", pos, "Tag", "AppDialogText", "Visible", opts.Visible);
            g = uigridlayout(fig, [2 1], "RowHeight", {'1x', 34}, "Padding", [10 10 10 10], "RowSpacing", 8);
            area = uitextarea(g, "Value", cellstr(text), "Editable", "off", "FontName", "Consolas", "FontSize", 13);
            area.Layout.Row = 1;
            b = uibutton(g, "Text", "Close", "ButtonPushedFcn", @(~, ~) delete(fig));
            b.Layout.Row = 2;
            styleButton(b);
        end

    end

    methods (Static, Access = private)

        function S = store(op, S)
            %store  The capture switch and the alerts kept (persistent; one per MATLAB session).
            persistent state
            if isempty(state)
                state = struct('On', false, 'Items', AppDialog.emptyItems());
            end
            if op == "set"; state = S; end
            S = state;
        end

        function T = emptyItems()
            T = repmat(struct('Message', "", 'Title', "", 'Options', {{}}), 0, 1);
        end

        function o = optionsOf(args)
            %optionsOf  The Name-Value pairs of an alert as a struct (a function handle is kept as is).
            o = {};
            for k = 1:2:numel(args) - 1
                if (ischar(args{k}) || isstring(args{k})) && string(args{k}) == "Options"
                    o = cellstr(string(args{k + 1}));
                end
            end
        end

    end
end


function pickedGoto(evt, goto, gotoFcn)
%pickedGoto  CloseFcn of the "Go to <tab> tab" alert: call GOTOFCN when that button was pressed.
if string(evt.SelectedOption) == goto
    gotoFcn();
end
end
