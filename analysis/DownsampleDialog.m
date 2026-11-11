classdef DownsampleDialog < handle
    %DownsampleDialog  The rate each signal (LFP, MUA, SPIKE, AUX) is downsampled to before it is computed or loaded.
    %   A small modal window with a row per signal: its rate on file (from
    %   one dataset), a field for the rate to bring it to (blank = the rate
    %   on file), and the band that comes through unchanged. Each signal
    %   has its own rate. The signal is low-pass filtered before it is
    %   downsampled (resampleSignal: a linear-phase FIR, so nothing shifts
    %   in time), so no frequency above the new Nyquist folds back into
    %   it: content up to 0.38 x the new rate passes within 0.1%, and what
    %   could fold into that band is at least 60 dB down. The window only
    %   holds the pending edit; nothing changes until OK. The dataset
    %   browser opens it from the Downsample... button beside the Data
    %   boxes (DatasetBrowser.editDownsample) and puts the rates in its
    %   settings' signal.downsample (epochMatrixSettings); the analysis app
    %   from the Data tab's Downsample... button (EphysFigGenApp.onDownsample),
    %   into its config's Source.Downsample (every figure's signals).
    %
    %     dlg = DownsampleDialog(B.Settings.signal.downsample, FileRates=src.signalFs, ...
    %         Dataset=src.name, Ticked=B.Settings.data, Parent=B.Fig, OnDone=@(r) apply(r));
    %
    %   RATES is signal.downsample: a struct with a field per signal
    %   (DatasetOutputs.SignalTypes), each [] (the rate on file) or a rate
    %   in Hz; fields left out are []. Options:
    %     FileRates  struct, a field per signal: its rate on file, Hz (NaN
    %                or no field = not known; loadAnalysisSource's
    %                src.signalFs)
    %     Dataset    the name of the dataset FileRates come from ("" = none)
    %     Ticked     the kinds of Data ticked: their signals are named in
    %                bold, the others are marked "(not ticked)"
    %     UnusedNote what marks a signal not in Ticked ("not ticked"; the
    %                analysis app: "no figure reads it")
    %     UsedBy     who reads the rates, in the window's words ("Compute
    %                and Raw Data"; the analysis app: "the figures")
    %     ScriptName the rates' name in a script, in each field's tooltip
    %                ("signal.downsample"; the app: "Source.Downsample")
    %     OnDone     called once as OnDone(R) when the window closes
    %     Parent     the uifigure to center on ([] = none)
    %     Visible    false builds the window hidden (tests)
    %
    %   The window is modal but does not block (no uiwait): the caller
    %   applies the result in OnDone. R is [] when the window is canceled,
    %   closed, or OK changes no rate; otherwise the new signal.downsample
    %   struct (every signal's field, [] or a rate in Hz).
    %
    %   Properties (read-only): Fig, Ctl (the controls; Ctl.Rate(k) is the
    %   field of signal k), Signals, Rates (the pending rates, as R),
    %   ErrorText. Methods, the same paths as the controls: setRate(SIGNAL,
    %   V) (V a number, [] or text; "" = the rate on file), clearRates (the
    %   Rates on file button), ok, cancel, isOpen.
    %   DownsampleDialog.describe(RATES) words the rates for a status line
    %   or a tooltip ("LFP 250 Hz, AUX 100 Hz"; "" when none is set).
    %
    %   See also DatasetBrowser, epochMatrixSettings, resampleSignal, sessionData.

    properties (SetAccess = private)
        Fig = []                     % the uifigure
        Ctl = struct()               % the controls
        Signals (1,:) string = DatasetOutputs.SignalTypes   % the rows, in order
        Rates = struct()             % the pending rates: a field per signal, [] or Hz
    end

    properties
        OnDone = []                  % called once as OnDone(result) when the window closes
    end

    properties (Dependent)
        ErrorText                    % the inline message ("" when none)
    end

    properties (Constant)
        PassFraction = 0.38          % content up to this fraction of the new rate passes within 0.1% (resampleSignal)
    end

    properties (Access = private)
        Original = struct()          % the rates the window was opened with
        FileRates = struct()         % each signal's rate on file (NaN = not known)
        Dataset (1,1) string = ""
        Ticked (1,:) string = strings(1, 0)
        UnusedNote (1,1) string = "not ticked"
        UsedBy (1,1) string = "Compute and Raw Data"
        ScriptName (1,1) string = "signal.downsample"
        Done (1,1) logical = false
    end

    methods
        function obj = DownsampleDialog(rates, opts)
            arguments
                rates = []
                opts.FileRates = struct()
                opts.Dataset (1,1) string = ""
                opts.Ticked string = strings(1, 0)
                opts.UnusedNote (1,1) string = "not ticked"
                opts.UsedBy (1,1) string = "Compute and Raw Data"
                opts.ScriptName (1,1) string = "signal.downsample"
                opts.OnDone = []
                opts.Parent = []
                opts.Visible (1,1) logical = true
            end
            obj.Rates = DownsampleDialog.normalize(rates);
            obj.Original = obj.Rates;
            obj.FileRates = struct();
            for s = obj.Signals
                v = NaN;
                if isstruct(opts.FileRates) && isfield(opts.FileRates, s) && isnumeric(opts.FileRates.(s)) ...
                        && isscalar(opts.FileRates.(s)) && opts.FileRates.(s) > 0
                    v = double(opts.FileRates.(s));
                end
                obj.FileRates.(s) = v;
            end
            obj.Dataset = opts.Dataset;
            obj.Ticked = reshape(opts.Ticked, 1, []);
            obj.UnusedNote = opts.UnusedNote;
            obj.UsedBy = opts.UsedBy;
            obj.ScriptName = opts.ScriptName;
            obj.OnDone = opts.OnDone;
            obj.build(opts.Parent, opts.Visible);
            obj.refresh();
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

        function setRate(obj, signal, v)
            %setRate  Signal SIGNAL's rate: a number (Hz), [] or text ("" = the rate on file); a bad value stays in the field, marked.
            signal = upper(string(signal));
            k = find(obj.Signals == signal, 1);
            if isempty(k)
                error('DownsampleDialog:BadSignal', 'No signal "%s" (the signals are %s).', signal, strjoin(obj.Signals, ", "));
            end
            if isnumeric(v)
                if isempty(v); txt = ""; else; txt = string(v); end
            else
                txt = strtrim(string(v));
            end
            obj.Ctl.Rate(k).Value = char(txt);
            obj.readField(k);
        end

        function clearRates(obj)
            %clearRates  Every signal back to its rate on file (the fields blank).
            for k = 1:numel(obj.Signals)
                obj.Ctl.Rate(k).Value = '';
                obj.Rates.(obj.Signals(k)) = [];
            end
            obj.refresh();
        end

        function ok(obj)
            %ok  Read every field; a bad one keeps the window open with the reason; else hand the rates to OnDone and close.
            if obj.Done; return; end
            bad = strings(1, 0);
            for k = 1:numel(obj.Signals)
                why = obj.readField(k);
                if why ~= ""; bad(end+1) = why; end %#ok<AGROW>
            end
            if ~isempty(bad)
                obj.Ctl.Error.Text = strjoin(bad, newline);
                return
            end
            r = obj.Rates;
            if isequaln(r, obj.Original); r = []; end
            obj.finish(r);
        end

        function cancel(obj)
            obj.finish([]);
        end
    end

    methods (Static)
        function d = normalize(rates)
            %normalize  A field per signal (DatasetOutputs.SignalTypes), each [] or a positive rate; anything else [].
            d = struct();
            for s = DatasetOutputs.SignalTypes
                v = [];
                if isstruct(rates) && isscalar(rates) && isfield(rates, s)
                    x = rates.(s);
                    if isnumeric(x) && isscalar(x) && isfinite(x) && x > 0; v = double(x); end
                end
                d.(s) = v;
            end
        end

        function text = describe(rates)
            %describe  "LFP 250 Hz, AUX 100 Hz": the signals given a rate, in order; "" when none is.
            d = DownsampleDialog.normalize(rates);
            parts = strings(1, 0);
            for s = DatasetOutputs.SignalTypes
                if ~isempty(d.(s)); parts(end+1) = s + " " + hzText(d.(s)) + " Hz"; end %#ok<AGROW>
            end
            text = strjoin(parts, ", ");
        end
    end

    methods (Access = private)
        function why = readField(obj, k)
            %readField  Field K's text into Rates (blank = []); WHY says what is wrong ("" when fine); the row's note follows.
            s = obj.Signals(k);
            txt = strtrim(string(obj.Ctl.Rate(k).Value));
            why = "";
            if txt == ""
                obj.Rates.(s) = [];
            else
                v = str2double(regexprep(txt, "\s*(hz|Hz|HZ)$", ""));
                if isfinite(v) && v > 0
                    obj.Rates.(s) = v;
                else
                    why = s + ": """ + txt + """ is not a rate. Type a number of Hz above 0, or leave it blank for the rate on file.";
                end
            end
            obj.refresh(k, why);
        end

        function build(obj, parent, visible)
            n = numel(obj.Signals);
            fig = uifigure("Name", "Downsample signals", "Visible", "off", "Position", [100 100 640 360], ...
                "WindowStyle", "modal", "Tag", "DownsampleDialog");
            if ~isempty(parent) && isvalid(parent)
                p = parent.Position;
                fig.Position(1:2) = p(1:2) + max(0, (p(3:4) - fig.Position(3:4)) / 2);
            end
            fig.CloseRequestFcn = @(~, ~) obj.cancel();
            obj.Fig = fig;
            gray = [0.38 0.38 0.38];

            g = uigridlayout(fig, [5 1], "RowHeight", {'fit', 'fit', 'fit', 'fit', 34}, "RowSpacing", 8);
            c = struct();
            c.Intro = uilabel(g, "WordWrap", "on", "Text", ...
                "Bring a signal to a lower rate before " + obj.UsedBy + " read it: less memory, faster work. " + ...
                "Each signal has its own rate; leave a field blank to keep the rate on file. " + ...
                "The signal is low-pass filtered first (anti-aliasing, zero phase), so nothing above the new " + ...
                "Nyquist frequency folds back into it: content up to " + DownsampleDialog.PassFraction + ...
                " × the new rate passes unchanged. Pick a rate at least 2.6 × the highest frequency you study.");

            t = uigridlayout(g, [n + 1, 4], "ColumnWidth", {110, 90, 130, '1x'}, ...
                "RowHeight", repmat({28}, 1, n + 1), "Padding", [0 0 0 0], "RowSpacing", 4, "ColumnSpacing", 10);
            heads = ["Signal" "On file" "Downsample to (Hz)" "Passes unchanged"];
            for j = 1:4
                h = uilabel(t, "Text", heads(j), "FontWeight", "bold");
                h.Layout.Row = 1; h.Layout.Column = j;
            end
            c.Name = gobjects(1, n);
            c.FileRate = gobjects(1, n);
            c.Rate = gobjects(1, n);
            c.Note = gobjects(1, n);
            for k = 1:n
                s = obj.Signals(k);
                c.Name(k) = place(uilabel(t, "Text", s), k + 1, 1);
                c.FileRate(k) = place(uilabel(t, "Text", "", "FontColor", gray), k + 1, 2);
                v = obj.Rates.(s);
                txt = "";
                if ~isempty(v); txt = hzText(v); end
                c.Rate(k) = place(uieditfield(t, "text", "Value", char(txt), "Placeholder", "rate on file", ...
                    "ValueChangedFcn", @(~, ~) obj.readField(k), ...
                    "Tooltip", "The rate, Hz, to bring " + s + " to before " + obj.UsedBy + " read it; " + ...
                    "blank = the rate on file. Script name: " + obj.ScriptName + "." + s), k + 1, 3);
                c.Note(k) = place(uilabel(t, "Text", "", "FontColor", gray), k + 1, 4);
            end
            src = "Rates on file: not known (scan the root and click a dataset).";
            if obj.Dataset ~= ""; src = "Rates on file are those of " + obj.Dataset + "."; end
            c.Source = uilabel(g, "Text", src, "FontColor", gray, "WordWrap", "on");
            c.Error = uilabel(g, "Text", "", "FontColor", [0.75 0.1 0.1], "WordWrap", "on");

            bg = uigridlayout(g, [1 4], "ColumnWidth", {'fit', '1x', 90, 90}, "RowHeight", {30}, "Padding", [0 0 0 0]);
            c.Clear = uibutton(bg, "Text", "Rates on file", "ButtonPushedFcn", @(~, ~) obj.clearRates(), ...
                "Tooltip", "Every signal back to its rate on file (no downsampling).");
            c.Cancel = uibutton(bg, "Text", "Cancel", "ButtonPushedFcn", @(~, ~) obj.cancel());
            c.Cancel.Layout.Column = 3;
            c.OK = uibutton(bg, "Text", "OK", "Tooltip", "Use these rates for " + obj.UsedBy + ".", ...
                "ButtonPushedFcn", @(~, ~) obj.ok());
            c.OK.Layout.Column = 4;
            styleButton([c.Clear c.Cancel]);
            styleButton(c.OK, "confirm");
            obj.Ctl = c;
            fig.Visible = matlab.lang.OnOffSwitchState(visible);
        end

        function refresh(obj, only, why)
            %refresh  Rows ONLY (default all): the names, rates on file and the notes; WHY marks row ONLY's field as bad.
            if nargin < 2; only = 1:numel(obj.Signals); end
            if nargin < 3; why = ""; end
            c = obj.Ctl;
            gray = [0.38 0.38 0.38];
            for k = reshape(only, 1, [])
                s = obj.Signals(k);
                ticked = ismember(s, obj.Ticked);
                c.Name(k).Text = s + ternary(ticked || isempty(obj.Ticked), "", "  (" + obj.UnusedNote + ")");
                c.Name(k).FontWeight = ternary(ticked, "bold", "normal");
                f = obj.FileRates.(s);
                c.FileRate(k).Text = ternary(isnan(f), "—", hzText(f) + " Hz");
                v = obj.Rates.(s);
                color = gray;
                if why ~= ""
                    note = "not a rate";
                    color = [0.75 0.1 0.1];
                elseif isempty(v)
                    note = "all: not downsampled";
                elseif ~isnan(f) && v >= f
                    note = "at or above the rate on file: unchanged";
                else
                    reached = reachedRate(f, v);
                    note = "0–" + hzText(DownsampleDialog.PassFraction * reached) + " Hz";
                    if ~isnan(f) && abs(reached - v) > 1e-9 * v
                        note = note + " (" + hzText(reached) + " Hz reached)";
                    end
                    color = [0.10 0.10 0.10];
                end
                c.Note(k).Text = note;
                c.Note(k).FontColor = color;
                c.Rate(k).BackgroundColor = ternary(why == "", [1 1 1], [1 0.9 0.9]);
            end
            if why == "" && isvalid(c.Error)
                c.Error.Text = "";
            elseif isvalid(c.Error)
                c.Error.Text = why;
            end
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


function h = place(h, row, col)
h.Layout.Row = row;
h.Layout.Column = col;
end


function reached = reachedRate(fs, target)
%reachedRate  The rate resampleSignal reaches for TARGET from FS (FS NaN: TARGET).
reached = target;
if isnan(fs); return; end
[p, q] = rat(target / fs, 1e-9);
reached = fs * p / q;
if abs(reached - target) <= 1e-9 * target; reached = target; end
end


function t = hzText(v)
%hzText  A rate as short text: 250, 1017.25, 95 (4 significant digits past whole numbers).
if v >= 100
    t = string(round(v, 2));
else
    t = string(round(v, 3, 'significant'));
end
end


function v = ternary(tf, a, b)
if tf; v = a; else; v = b; end
end


function closeFig(fig)
if ~isempty(fig) && isvalid(fig); delete(fig); end
end
