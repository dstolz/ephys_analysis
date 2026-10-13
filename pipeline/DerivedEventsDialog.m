classdef DerivedEventsDialog < handle
    % DerivedEventsDialog  Define derived events: a line's intervals in the trials that meet conditions.
    %   A window that edits a list of derived-event definitions (the
    %   pipeline config's Behavior.DerivedEvents; see deriveEvents). Each
    %   one names a new line, the line its intervals come from ("Trial" =
    %   the trial line), one or more conditions on the trial parameters
    %   (e.g. "Depth >= -6", "Depth < -6 & Depth >= -10"), whether a trial
    %   must meet all of them or any, and whether the line also goes into
    %   the original dataset (the extract's events and a logical trials
    %   column). The conditions are kept as typed, so they can be changed
    %   later.
    %
    %     dlg = DerivedEventsDialog(cfg.Behavior.DerivedEvents, OnChange=@(defs) disp(defs));
    %     dlg.setPreview(P.events, [session P.columns], P.trialLine, "rec1");
    %
    %   With a preview (a paired dataset's events and trials) each event's
    %   counts on it are listed, and a definition that cannot be made there
    %   says why; the trial parameters and their values are listed for
    %   writing conditions. Every edit calls OnChange(defs) at once.
    %
    %   Properties: Fig, Defs (1 x n DerivedEvent structs), Selected, Results
    %   (per definition: nTrials, nIntervals, message), ResultText, OnChange. Methods:
    %   setDefinitions, setPreview, select, add, duplicate, remove, move,
    %   edit (as typing into the window), delete. Opened by EphysPipelineApp
    %   from the Trials tab (onTrialsDerivedEvents).
    %
    %   See also deriveEvents, EphysDataset.behaviorStruct, tableFilterFcn.

    properties (SetAccess = private)
        Fig                          % the uifigure
        Defs                         % 1 x n EphysPipelineConfig.defaults("DerivedEvent")
        Selected (1,1) double = 0    % the definition in the editor (0 = none)
        Results                      % 1 x n struct: nTrials, nIntervals (NaN without a preview), message
    end

    properties
        OnChange = []                % called as OnChange(defs) after each edit
    end

    properties (Dependent)
        ResultText                   % what the editor says of the selected definition (its counts, or what is wrong)
    end

    properties (Access = private)
        Events = []                  % preview: events struct (polarity applied); [] = none
        Trials = []                  % preview: trials with the pairing columns
        TrialLine (1,1) string = ""
        DatasetName (1,1) string = ""
        Ctl = struct()               % the controls
    end

    properties (Constant, Access = private)
        % Trial columns of the pairing, not parameters to write conditions on.
        PairingColumns = ["TrialInterval" "TrialOnset" "TrialOffset" "TrialOnsetSample" ...
            "TrialOffsetSample" "PairingFlag" "TrialEvents" "TrialEventSamples"]
    end

    methods
        function obj = DerivedEventsDialog(defs, opts)
            %DerivedEventsDialog  The window over the definitions DEFS ([] = none yet).
            %   dlg = DerivedEventsDialog(DEFS, OnChange=, Parent=, Visible=)
            arguments
                defs = []
                opts.OnChange = []
                opts.Parent = []
                opts.Visible (1,1) logical = true
            end
            obj.OnChange = opts.OnChange;
            obj.Defs = DerivedEventsDialog.normalize(defs);
            obj.build(opts.Parent, opts.Visible);
            obj.recompute();
            obj.select(min(1, numel(obj.Defs)));
        end

        function delete(obj)
            if ~isempty(obj.Fig) && isvalid(obj.Fig); delete(obj.Fig); end
        end

        function t = get.ResultText(obj)
            t = string(obj.Ctl.Result.Text);
        end

        function setDefinitions(obj, defs)
            %setDefinitions  Show other definitions (a config loaded); OnChange is not called.
            obj.Defs = DerivedEventsDialog.normalize(defs);
            obj.recompute();
            obj.select(min(max(obj.Selected, 1), numel(obj.Defs)));
        end

        function setPreview(obj, events, trials, trialLine, name)
            %setPreview  Count each event on a paired dataset (EVENTS [] = no preview).
            arguments
                obj (1,1) DerivedEventsDialog
                events = []
                trials = []
                trialLine (1,1) string = ""
                name (1,1) string = ""
            end
            if ~isstruct(events) || ~istable(trials) || ~ismember("TrialOnset", string(trials.Properties.VariableNames))
                events = []; trials = []; name = "";
            end
            obj.Events = events;
            obj.Trials = trials;
            obj.TrialLine = trialLine;
            obj.DatasetName = name;
            obj.recompute();
            obj.refreshParams();
            obj.select(obj.Selected);
        end

        function select(obj, k)
            %select  Show definition K in the editor (0 = none).
            k = min(max(round(k), 0), numel(obj.Defs));
            obj.Selected = k;
            c = obj.Ctl;
            on = matlab.lang.OnOffSwitchState(k > 0);
            set([c.Name c.Line c.Conditions c.Combine c.InDataset c.Duplicate c.Remove], "Enable", on);
            c.Up.Enable = matlab.lang.OnOffSwitchState(k > 1);
            c.Down.Enable = matlab.lang.OnOffSwitchState(k > 0 && k < numel(obj.Defs));
            if k == 0
                c.Name.Value = '';
                c.Conditions.Value = {''};
                c.Result.Text = "Add a derived event.";
                c.Result.FontColor = [0.4 0.4 0.4];
                c.Table.Selection = [];
                return
            end
            d = obj.Defs(k);
            c.Name.Value = char(d.Name);
            items = obj.lineItems(k);
            c.Line.Items = cellstr(items);
            c.Line.Value = char(d.Line);
            if isempty(d.Conditions)
                c.Conditions.Value = {''};
            else
                c.Conditions.Value = cellstr(d.Conditions(:));
            end
            c.Combine.Value = char(d.Combine);
            c.InDataset.Value = d.InDataset;
            c.Table.Selection = k;
            obj.refreshResult();
        end

        function add(obj)
            %add  A new definition after the selected one ("Trial", no condition yet).
            d = EphysPipelineConfig.defaults("DerivedEvent");
            d.Name = obj.freeName("Event");
            obj.insert(d);
        end

        function duplicate(obj)
            %duplicate  A copy of the selected definition, to vary its conditions.
            if obj.Selected == 0; return; end
            d = obj.Defs(obj.Selected);
            d.Name = obj.freeName(regexprep(d.Name, '_?\d+$', ''));
            obj.insert(d);
        end

        function remove(obj)
            %remove  Delete the selected definition.
            k = obj.Selected;
            if k == 0; return; end
            obj.Defs(k) = [];
            obj.changed();
            obj.select(min(k, numel(obj.Defs)));
        end

        function move(obj, step)
            %move  Move the selected definition up (-1) or down (+1); later ones can build on earlier ones.
            k = obj.Selected;
            j = k + step;
            if k == 0 || j < 1 || j > numel(obj.Defs); return; end
            obj.Defs([k j]) = obj.Defs([j k]);
            obj.changed();
            obj.select(j);
        end

        function edit(obj, field, value)
            %edit  Set FIELD (Name, Line, Conditions, Combine, InDataset) of the selected definition.
            k = obj.Selected;
            if k == 0; return; end
            d = obj.Defs(k);
            switch string(field)
                case "Conditions"
                    v = string(value);
                    if isscalar(v); v = splitlines(v); end
                    v = reshape(strtrim(v), 1, []);
                    d.Conditions = v(v ~= "");
                case "InDataset"
                    d.InDataset = logical(value);
                otherwise
                    d.(field) = strtrim(string(value));
            end
            obj.Defs(k) = EphysPipelineConfig.normalizeSection("DerivedEvent", d);
            obj.changed();
            obj.select(k);
        end
    end

    methods (Access = private)
        function build(obj, parent, visible)
            fig = uifigure("Name", "Derived events", "Visible", "off", "Position", [100 100 1000 600]);
            if ~isempty(parent) && isvalid(parent)
                p = parent.Position;
                fig.Position(1:2) = p(1:2) + max(0, (p(3:4) - fig.Position(3:4)) / 2);
            end
            obj.Fig = fig;
            g = uigridlayout(fig, [3 2]);
            g.RowHeight = {'fit', '1x', 30};
            g.ColumnWidth = {'1.25x', '1x'};
            intro = uilabel(g, "WordWrap", "on", "FontColor", [0.3 0.3 0.3], "Text", ...
                "A derived event is a new line: the intervals of a line (Trial, Stim, ...) in the trials that meet " + ...
                "conditions on the trial parameters. The behavior step (or Write behavior .mat) adds it to the " + ...
                "behavior file; the exports and the analysis app then have it wherever lines are used. " + ...
                "Edits go into the config (Behavior.DerivedEvents) at once; the conditions are kept as typed.");
            intro.Layout.Row = 1; intro.Layout.Column = [1 2];

            c = struct();
            c.Table = uitable(g, "RowName", {}, "SelectionType", "row", "Multiselect", "off", ...
                "ColumnName", {'Name', 'From', 'Conditions', 'In dataset', 'Trials', 'Intervals'}, ...
                "ColumnWidth", {100, 70, 'auto', 70, 55, 65}, ...
                "CellSelectionCallback", @(~, evt) obj.onTableSelected(evt));
            c.Table.Layout.Row = 2; c.Table.Layout.Column = 1;
            bg = uigridlayout(g, [1 6]);
            bg.Layout.Row = 3; bg.Layout.Column = 1;
            bg.ColumnWidth = {'fit', 'fit', 'fit', 'fit', 'fit', '1x'};
            bg.RowHeight = {30};
            bg.Padding = [0 0 0 0];
            c.Add = uibutton(bg, "Text", "Add", "ButtonPushedFcn", @(~,~) obj.add(), ...
                "Tooltip", "A new derived event after the selected one.");
            c.Duplicate = uibutton(bg, "Text", "Duplicate", "ButtonPushedFcn", @(~,~) obj.duplicate(), ...
                "Tooltip", "A copy of the selected event, e.g. to make the next depth group.");
            c.Remove = uibutton(bg, "Text", "Remove", "ButtonPushedFcn", @(~,~) obj.remove());
            c.Up = uibutton(bg, "Text", "Up", "ButtonPushedFcn", @(~,~) obj.move(-1), ...
                "Tooltip", "Events are made in order, so one can take its intervals from an earlier one.");
            c.Down = uibutton(bg, "Text", "Down", "ButtonPushedFcn", @(~,~) obj.move(1));
            styleButton([c.Add c.Duplicate c.Remove c.Up c.Down]);
            styleButton(c.Add, "primary");
            styleButton(c.Remove, "danger");

            ep = uipanel(g, "Title", "Selected event");
            ep.Layout.Row = [2 3]; ep.Layout.Column = 2;
            eg = uigridlayout(ep, [9 2]);
            eg.RowHeight = {'fit', 'fit', 'fit', 90, 'fit', 'fit', 'fit', 'fit', '1x'};
            eg.ColumnWidth = {'fit', '1x'};
            lab(eg, "Name:", 1);
            c.Name = uieditfield(eg, "Tooltip", "The new line's name: letters, digits and _, starting with a letter (e.g. Shallow).", ...
                "ValueChangedFcn", @(src, ~) obj.edit("Name", src.Value));
            c.Name.Layout.Row = 1; c.Name.Layout.Column = 2;
            lab(eg, "From line:", 2);
            c.Line = uidropdown(eg, "Items", {'Trial'}, "Editable", "on", ...
                "Tooltip", "The line whose intervals are taken (Trial = the trial line). An interval belongs to the trial holding its onset.", ...
                "ValueChangedFcn", @(src, ~) obj.edit("Line", src.Value));
            c.Line.Layout.Row = 2; c.Line.Layout.Column = 2;
            h = uilabel(eg, "Text", "Conditions, one per line:");
            h.Layout.Row = 3; h.Layout.Column = [1 2];
            c.Conditions = uitextarea(eg, "Tooltip", "Logical expressions over the trial parameters, e.g. Depth >= -6", ...
                "ValueChangedFcn", @(src, ~) obj.edit("Conditions", strjoin(string(src.Value), newline)));
            c.Conditions.Layout.Row = 4; c.Conditions.Layout.Column = [1 2];
            lab(eg, "Combine:", 5);
            c.Combine = uidropdown(eg, "Items", {'all: every condition holds (AND)', 'any: at least one holds (OR)'}, ...
                "ItemsData", {'all', 'any'}, "ValueChangedFcn", @(src, ~) obj.edit("Combine", src.Value));
            c.Combine.Layout.Row = 5; c.Combine.Layout.Column = 2;
            c.InDataset = uicheckbox(eg, "Text", "Include in the original dataset", ...
                "Tooltip", "Also put the line in the extract's events (beside the recorded lines) and a true / false trials column of this name in the behavior file. The exports and the analysis app have the event either way.", ...
                "ValueChangedFcn", @(src, ~) obj.edit("InDataset", src.Value));
            c.InDataset.Layout.Row = 6; c.InDataset.Layout.Column = [1 2];
            c.Result = uilabel(eg, "Text", "", "WordWrap", "on");
            c.Result.Layout.Row = 7; c.Result.Layout.Column = [1 2];
            h = uilabel(eg, "WordWrap", "on", "FontColor", [0.4 0.4 0.4], "Text", ...
                "MATLAB operators on the trial parameters: == ~= < <= > >= & | ~, e.g. Depth >= -6, " + ...
                "Depth < -6 & Depth >= -10, ismember(Level, [40 60]), Hit | FA. The response words (Hit, Miss, " + ...
                "CR, FA, ...) stand for RespCode bits; text compares with == ""text"".");
            h.Layout.Row = 8; h.Layout.Column = [1 2];
            c.Params = uitable(eg, "RowName", {}, "ColumnName", {'Parameter', 'Values'}, ...
                "ColumnWidth", {110, 'auto'}, "Tooltip", "The trial parameters of the loaded dataset and their values.");
            c.Params.Layout.Row = 9; c.Params.Layout.Column = [1 2];
            obj.Ctl = c;
            obj.refreshParams();
            fig.Visible = matlab.lang.OnOffSwitchState(visible);

            function lab(parent, txt, row)
                l = uilabel(parent, "Text", txt);
                l.Layout.Row = row; l.Layout.Column = 1;
            end
        end

        function insert(obj, d)
            k = obj.Selected + 1;
            obj.Defs = [obj.Defs(1:k-1), d, obj.Defs(k:end)];
            obj.changed();
            obj.select(k);
        end

        function changed(obj)
            %changed  Recount, redraw the list and tell the owner.
            obj.recompute();
            if ~isempty(obj.OnChange)
                obj.OnChange(obj.Defs);
            end
        end

        function recompute(obj)
            %recompute  Results per definition: the counts on the preview, or what is wrong.
            n = numel(obj.Defs);
            R = repmat(struct('nTrials', NaN, 'nIntervals', NaN, 'message', ""), 1, n);
            if ~isempty(obj.Events) && n > 0
                [~, D, failed] = deriveEvents(obj.Events, obj.Trials, obj.Defs, ...
                    TrialLine=obj.TrialLine, OnError="skip");
                for d = D
                    R(d.index).nTrials = d.nTrials;
                    R(d.index).nIntervals = d.nIntervals;
                end
                for f = failed
                    R(f.index).message = f.message;
                end
            else
                names = strings(1, 0);
                for k = 1:n   % without a dataset: the name and the syntax only
                    d = obj.Defs(k);
                    try
                        if ~isvarname(d.Name)
                            error('DerivedEventsDialog:Name', '"%s" is not a valid name (letters, digits and _, starting with a letter).', d.Name);
                        elseif ismember(d.Name, [names "Trial"])
                            error('DerivedEventsDialog:Name', 'The name %s is taken.', d.Name);
                        elseif isempty(d.Conditions)
                            error('DerivedEventsDialog:Name', 'It has no condition yet.');
                        end
                        for cnd = d.Conditions
                            tableFilterFcn(cnd);
                        end
                    catch ME
                        R(k).message = string(ME.message);
                    end
                    names(end+1) = d.Name; %#ok<AGROW>
                end
            end
            obj.Results = R;
            obj.refreshTable();
        end

        function refreshTable(obj)
            n = numel(obj.Defs);
            Name = strings(n, 1); From = strings(n, 1); Conditions = strings(n, 1);
            InDataset = false(n, 1); Trials = strings(n, 1); Intervals = strings(n, 1);
            for k = 1:n
                d = obj.Defs(k);
                r = obj.Results(k);
                Name(k) = d.Name;
                From(k) = d.Line;
                j = " & ";
                if d.Combine == "any"; j = " | "; end
                Conditions(k) = strjoin(d.Conditions, j);
                InDataset(k) = d.InDataset;
                if r.message ~= ""
                    Trials(k) = "error"; Intervals(k) = "error";
                elseif ~isnan(r.nTrials)
                    Trials(k) = string(r.nTrials); Intervals(k) = string(r.nIntervals);
                end
            end
            t = obj.Ctl.Table;
            t.Data = table(Name, From, Conditions, InDataset, Trials, Intervals);
            removeStyle(t);
            bad = find([string.empty(1, 0), obj.Results.message] ~= "");
            if ~isempty(bad)
                addStyle(t, uistyle("FontColor", [0.75 0.1 0.1]), "row", bad);
            end
            if obj.Selected >= 1 && obj.Selected <= n; t.Selection = obj.Selected; end
        end

        function refreshResult(obj)
            k = obj.Selected;
            c = obj.Ctl;
            if k == 0; return; end
            r = obj.Results(k);
            if r.message ~= ""
                c.Result.Text = r.message;
                c.Result.FontColor = [0.75 0.1 0.1];
            elseif isnan(r.nTrials)
                c.Result.Text = "Load a dataset on the Trials tab to count this event on it.";
                c.Result.FontColor = [0.4 0.4 0.4];
            else
                nPaired = nnz(isfinite(obj.Trials.TrialOnset));
                c.Result.Text = sprintf("On %s: %d of %d paired trials meet the conditions; %d interval(s).", ...
                    obj.DatasetName, r.nTrials, nPaired, r.nIntervals);
                c.Result.FontColor = [0 0.45 0];
            end
        end

        function refreshParams(obj)
            %refreshParams  The trial parameters of the preview and their values.
            Parameter = strings(0, 1); Values = strings(0, 1);
            T = obj.Trials;
            if istable(T)
                for v = string(T.Properties.VariableNames)
                    if ismember(v, DerivedEventsDialog.PairingColumns) || startsWith(v, "TrialOnsetSample_") ...
                            || startsWith(v, "TrialOffsetSample_")
                        continue
                    end
                    x = T.(v);
                    if iscellstr(x) || ischar(x); x = string(x); end %#ok<ISCLSTR>
                    if ~(isnumeric(x) || islogical(x) || isstring(x)) || size(x, 2) ~= 1
                        continue
                    end
                    if isnumeric(x) || islogical(x)
                        u = unique(double(x(isfinite(double(x)))));
                        txt = compose("%g", u);
                    else
                        u = unique(x(~ismissing(x)));
                        txt = """" + u + """";
                    end
                    if numel(txt) > 16; txt = [txt(1:16); "... (" + numel(u) + " values)"]; end
                    Parameter(end+1, 1) = v; %#ok<AGROW>
                    Values(end+1, 1) = strjoin(txt, "  "); %#ok<AGROW>
                end
            end
            obj.Ctl.Params.Data = table(Parameter, Values);
        end

        function items = lineItems(obj, k)
            %lineItems  The lines definition K can take its intervals from.
            items = "Trial";
            if isstruct(obj.Events)
                items = [items, setdiff(string(fieldnames(obj.Events)).', obj.TrialLine, 'stable')];
            end
            items = [items, string.empty(1, 0), obj.Defs(1:k-1).Name];
            items = unique([items, obj.Defs(k).Line], 'stable');
            items = items(items ~= "");
        end

        function nm = freeName(obj, base)
            if base == "" || ~isvarname(base); base = "Event"; end
            taken = [string.empty(1, 0), obj.Defs.Name];
            if isstruct(obj.Events); taken = [taken, string(fieldnames(obj.Events)).']; end
            j = 1;
            nm = base + j;
            while ismember(nm, taken)
                j = j + 1;
                nm = base + j;
            end
        end

        function onTableSelected(obj, evt)
            if isempty(evt.Indices); return; end
            obj.select(evt.Indices(1, 1));
        end
    end

    methods (Static, Access = private)
        function defs = normalize(defs)
            %normalize  A row of complete DerivedEvent structs (1 x 0 for none).
            S.Behavior = struct('DerivedEvents', {defs});
            if isempty(defs); S.Behavior.DerivedEvents = []; end
            B = EphysPipelineConfig.normalizeSection("Behavior", S.Behavior);
            defs = B.DerivedEvents;
        end
    end
end
