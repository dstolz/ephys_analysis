classdef FilterDialog < handle
    %FilterDialog  A modal window to pick or design a signal filter (SignalFilter), with its response drawn.
    %   On the left the filters to start from: No filter, Custom (your own
    %   settings), the EEG bands and line-noise notches (SignalFilter.presets)
    %   and your saved filters (SignalFilter.saved), with Save (under the name
    %   typed) and Delete. On the right the settings: what it passes (band-
    %   pass, band-stop, low-pass, high-pass) and its cutoffs; its design
    %   (Butterworth, Chebyshev I or II, elliptic, FIR) and order, ripple and
    %   attenuation where the design takes them; its phase (zero-phase,
    %   acausal, or causal) and the rate to draw it at. Under them its
    %   response as applied (gain in dB over a log frequency axis, the
    %   cutoffs marked: a zero-phase IIR filter runs forward and back, so
    %   its gain is squared) and its impulse response (a causal filter's is
    %   0 before the impulse, a zero-phase one's symmetric about it), and
    %   the filter in words, with a causal filter's delay. Each change
    %   redraws them. The window only holds the pending edit; nothing
    %   changes until OK.
    %
    %   One filter (a panel's options.filter: EphysFigGenApp.editPanelFilter)
    %     dlg = FilterDialog(f, Rate=1000, RateNote="LFP of rec1, as the figures read it", ...
    %         Parent=app.Fig, OnDone=@(r) apply(r));
    %   A filter per signal (the config's Source.SignalFilter: EphysFigGenApp.onSignalFilter)
    %     dlg = FilterDialog(S, Signals=["LFP" "MUA" "SPIKE" "AUX"], Rates=struct('LFP', 1000, ...), ...);
    %   S has a field per signal, each a filter; the Signal drop-down picks
    %   the one shown, each signal keeping its own pending filter.
    %
    %   Options:
    %     Signals    the signals of a per-signal window (empty: one filter)
    %     Signal     the signal shown first (default the first)
    %     Rate       one filter: the rate (Hz) the signal is read at (NaN:
    %                not known; the response is drawn at 1000 Hz, and a
    %                cutoff above its Nyquist frequency is not refused)
    %     Rates      per signal: a struct, a field per signal (NaN or no
    %                field: not known)
    %     RateNote   one filter: where Rate comes from, in words;
    %                RateNotes, per signal: a struct of them
    %     Used       per signal: the signals the figures read (bold; the
    %                others are marked with UnusedNote, "no figure reads it")
    %     Intro      the sentence on top (default: what filtering does)
    %     ScriptName the filter's name in a script, in the tooltips
    %                ("options.filter"; per signal "Source.SignalFilter")
    %     Title      the window's title ("Filter")
    %     OnDone     called once as OnDone(R) when the window closes
    %     Parent     the uifigure to center on ([] = none)
    %     Visible    false builds the window hidden (tests)
    %
    %   The window is modal but does not block (no uiwait): the caller
    %   applies the result in OnDone. R is [] when the window is canceled,
    %   closed, or OK changes nothing; otherwise the new filter (one
    %   filter: enabled false = No filter) or the new struct of filters
    %   (per signal). OK refuses (the reason in red, the window open) a
    %   filter whose settings SignalFilter.problems refuses, or one that
    %   cannot run at a known rate (a cutoff at or above its Nyquist
    %   frequency).
    %
    %   Properties (read-only): Fig, Ctl (the controls), Signals, Signal
    %   (the one shown), Filter (its pending filter), Filters (every
    %   pending filter, as R), Picked (the list's key: "none", "custom",
    %   "preset:<Name>", "saved:<name>"), PreviewRate, ErrorText. Methods,
    %   the same paths as the controls: pick(KEY) (a key or a label:
    %   "theta", "Theta", "none", "custom", "saved:My gamma"),
    %   setSignal(S), setType(T), setCutoff(LOW, HIGH) (a low-pass takes
    %   HIGH, a high-pass LOW; [] keeps one), setDesign(D), setOrder(N),
    %   setRipple(DB), setAttenuation(DB), setPhase(P), setPreviewRate(FS),
    %   saveAs(NAME), deleteSaved, ok, cancel, isOpen.
    %   FilterDialog.describeSignals(S) words a per-signal struct for a
    %   status line or tooltip ("LFP Theta 4-8 Hz, AUX low-pass 20 Hz";
    %   "" when none is on).
    %
    %   See also SignalFilter, DownsampleDialog, EphysFigGenApp.

    properties (SetAccess = private)
        Fig = []                         % the uifigure
        Ctl = struct()                   % the controls
        Signals (1,:) string = strings(1, 0)   % a per-signal window's signals (empty: one filter)
        Signal (1,1) string = ""         % the signal shown ("" with one filter)
        Picked (1,1) string = "none"     % the list's key for the filter shown
    end

    properties
        OnDone = []                      % called once as OnDone(result) when the window closes
    end

    properties (Dependent)
        Filter                           % the pending filter shown
        Filters                          % every pending filter: one filter, or a struct with a field per signal
        PreviewRate                      % the rate (Hz) the response is drawn at
        ErrorText                        % the inline message ("" when none)
    end

    properties (Constant)
        DefaultRate = 1000               % Hz: the rate the response is drawn at when the signal's is not known
    end

    properties (Access = private)
        Pending = struct()               % a field per item (the signals, or "Filter"): its pending filter
        Original = struct()              % ... as the window was opened
        PickedKey = struct()             % ... the list key of each
        PickedFilter = struct()          % ... the filter as picked from the list (its name kept while its band is)
        Rates = struct()                 % ... the rate it is read at (NaN: not known)
        Notes = struct()                 % ... where that rate comes from
        Preview = struct()               % ... the rate its response is drawn at
        Used (1,:) string = strings(1, 0)
        UnusedNote (1,1) string = "no figure reads it"
        ScriptName (1,1) string = "options.filter"
        Done (1,1) logical = false
        SavedList = []                   % your saved filters (SignalFilter.saved), read on opening and after Save / Delete
    end

    methods
        function obj = FilterDialog(filters, opts)
            arguments
                filters = []
                opts.Signals string = strings(1, 0)
                opts.Signal (1,1) string = ""
                opts.Rate (1,1) double = NaN
                opts.Rates = struct()
                opts.RateNote (1,1) string = ""
                opts.RateNotes = struct()
                opts.Used string = strings(1, 0)
                opts.UnusedNote (1,1) string = "no figure reads it"
                opts.Intro (1,1) string = ""
                opts.ScriptName (1,1) string = ""
                opts.Title (1,1) string = "Filter"
                opts.OnDone = []
                opts.Parent = []
                opts.Visible (1,1) logical = true
            end
            obj.Signals = reshape(opts.Signals, 1, []);
            if isempty(obj.Signals)
                items = "Filter";
                obj.Pending.Filter = SignalFilter.normalize(filters);
                obj.Rates.Filter = positiveOr(opts.Rate);
                obj.Notes.Filter = opts.RateNote;
                obj.ScriptName = "options.filter";
            else
                items = obj.Signals;
                for s = items
                    f = [];
                    if isstruct(filters) && isscalar(filters) && isfield(filters, s); f = filters.(s); end
                    obj.Pending.(s) = SignalFilter.normalize(f);
                    r = NaN;
                    if isstruct(opts.Rates) && isfield(opts.Rates, s); r = opts.Rates.(s); end
                    obj.Rates.(s) = positiveOr(r);
                    n = "";
                    if isstruct(opts.RateNotes) && isfield(opts.RateNotes, s); n = string(opts.RateNotes.(s)); end
                    obj.Notes.(s) = n;
                end
                obj.Signal = items(1);
                if ismember(opts.Signal, items); obj.Signal = opts.Signal; end
                obj.ScriptName = "Source.SignalFilter";
            end
            if opts.ScriptName ~= ""; obj.ScriptName = opts.ScriptName; end
            obj.Original = obj.Pending;
            obj.SavedList = SignalFilter.saved();
            for s = items
                r = obj.Rates.(s);
                if isnan(r); r = FilterDialog.DefaultRate; end
                obj.Preview.(s) = r;
                obj.PickedKey.(s) = FilterDialog.keyOf(obj.Pending.(s), obj.SavedList);
                obj.PickedFilter.(s) = obj.Pending.(s);
            end
            obj.Used = reshape(opts.Used, 1, []);
            obj.UnusedNote = opts.UnusedNote;
            obj.OnDone = opts.OnDone;
            obj.build(opts.Parent, opts.Visible, opts.Intro, opts.Title);
            obj.show();
        end

        function delete(obj)
            if ~isempty(obj.Fig) && isvalid(obj.Fig); delete(obj.Fig); end
        end

        function f = get.Filter(obj)
            f = obj.Pending.(obj.item());
        end

        function F = get.Filters(obj)
            if isempty(obj.Signals)
                F = obj.Pending.Filter;
            else
                F = obj.Pending;
            end
        end

        function r = get.PreviewRate(obj)
            r = obj.Preview.(obj.item());
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

        %% --- the controls' paths ------------------------------------------------------------
        function pick(obj, key)
            %pick  Show the filter KEY names: "none", "custom", a preset ("theta", "Theta", "preset:theta") or one of yours ("saved:<name>", or its name).
            key = obj.resolveKey(key);
            s = obj.item();
            switch extractBefore(key + ":", ":")
                case "none"
                    obj.Pending.(s).enabled = false;
                    obj.PickedKey.(s) = "none";
                case "custom"
                    f = obj.Pending.(s);
                    f.enabled = true;
                    f.name = "";
                    obj.Pending.(s) = f;
                    obj.PickedKey.(s) = "custom";
                    obj.PickedFilter.(s) = f;
                case "preset"
                    f = SignalFilter.preset(extractAfter(key, "preset:"));
                    obj.Pending.(s) = f;
                    obj.PickedKey.(s) = key;
                    obj.PickedFilter.(s) = f;
                case "saved"
                    S = obj.SavedList;
                    k = find(lower(savedNames(S)) == lower(extractAfter(key, "saved:")), 1);
                    if isempty(k); return; end
                    f = S(k).filter;
                    obj.Pending.(s) = f;
                    obj.PickedKey.(s) = key;
                    obj.PickedFilter.(s) = f;
            end
            obj.show();
        end

        function setSignal(obj, s)
            %setSignal  Show signal S's filter (a per-signal window).
            s = upper(string(s));
            if ~ismember(s, obj.Signals)
                error('FilterDialog:BadSignal', 'No signal "%s" here (the signals are %s).', s, strjoin(obj.Signals, ", "));
            end
            obj.Signal = s;
            obj.show();
        end

        function setType(obj, t)
            %setType  What the filter passes: "bandpass" | "bandstop" | "lowpass" | "highpass".
            obj.Ctl.Type.Value = char(lower(string(t)));
            obj.readControls("type");
        end

        function setCutoff(obj, low, high)
            %setCutoff  The cutoffs, Hz ([] keeps one): a low-pass takes HIGH, a high-pass LOW.
            if nargin < 3; high = []; end
            if ~isempty(low); obj.Ctl.Low.Value = double(low); end
            if ~isempty(high); obj.Ctl.High.Value = double(high); end
            obj.readControls("cutoff");
        end

        function setDesign(obj, d)
            %setDesign  "butter" | "cheby1" | "cheby2" | "ellip" | "fir".
            obj.Ctl.Design.Value = char(lower(string(d)));
            obj.readControls("design");
        end

        function setOrder(obj, n)
            obj.Ctl.Order.Value = double(n);
            obj.readControls("order");
        end

        function setRipple(obj, v)
            obj.Ctl.Ripple.Value = double(v);
            obj.readControls("ripple");
        end

        function setAttenuation(obj, v)
            obj.Ctl.Attenuation.Value = double(v);
            obj.readControls("attenuation");
        end

        function setPhase(obj, p)
            %setPhase  "zero" (zero-phase: acausal) | "causal".
            obj.Ctl.Phase.Value = char(lower(string(p)));
            obj.readControls("phase");
        end

        function setPreviewRate(obj, fs)
            %setPreviewRate  The rate (Hz) the response is drawn at.
            obj.Ctl.Rate.Value = double(fs);
            obj.Preview.(obj.item()) = obj.Ctl.Rate.Value;
            obj.show();
        end

        function saveAs(obj, name)
            %saveAs  Keep the filter shown among your saved filters as NAME (default: the name typed); it is then picked.
            if nargin >= 2; obj.Ctl.SaveName.Value = char(string(name)); end
            name = strtrim(string(obj.Ctl.SaveName.Value));
            f = obj.Filter;
            if name == ""
                obj.Ctl.Error.Text = "Type a name for the filter, then Save.";
                return
            end
            try
                SignalFilter.save(name, f);
            catch ME
                obj.Ctl.Error.Text = string(ME.message);
                return
            end
            obj.SavedList = SignalFilter.saved();
            obj.Ctl.SaveName.Value = '';
            obj.pick("saved:" + name);
        end

        function deleteSaved(obj)
            %deleteSaved  Forget the saved filter picked; the settings stay, as your own (Custom).
            key = obj.PickedKey.(obj.item());
            if ~startsWith(key, "saved:"); return; end
            SignalFilter.remove(extractAfter(key, "saved:"));
            obj.SavedList = SignalFilter.saved();
            obj.pick("custom");
        end

        function ok(obj)
            %ok  Check every pending filter; a bad one keeps the window open with the reason; else hand them to OnDone and close.
            if obj.Done; return; end
            bad = strings(1, 0);
            for s = obj.items()
                f = obj.Pending.(s);
                if ~f.enabled; continue; end
                why = "";
                I = SignalFilter.problems(f);
                if ~isempty(I)
                    why = I(1).message;
                elseif ~isnan(obj.Rates.(s))
                    why = SignalFilter.problemAt(f, obj.Rates.(s));
                end
                if why ~= ""
                    if ~isempty(obj.Signals); why = s + ": " + why; end
                    bad(end+1) = why; %#ok<AGROW>
                end
            end
            if ~isempty(bad)
                obj.Ctl.Error.Text = strjoin(bad, newline);
                return
            end
            r = obj.Filters;
            if isequaln(obj.Pending, obj.Original); r = []; end
            obj.finish(r);
        end

        function cancel(obj)
            obj.finish([]);
        end
    end

    methods (Static)
        function text = describeSignals(S)
            %describeSignals  "LFP Theta 4-8 Hz, AUX low-pass 20 Hz": the signals whose filter is on, in order; "" when none is.
            text = "";
            if ~isstruct(S) || ~isscalar(S); return; end
            parts = strings(1, 0);
            for s = DatasetOutputs.SignalTypes
                if ~isfield(S, s); continue; end
                d = SignalFilter.describe(S.(s), Short=true);
                if d ~= ""; parts(end+1) = s + " " + d; end %#ok<AGROW>
            end
            text = strjoin(parts, ", ");
        end
    end

    methods (Static, Access = private)
        function key = keyOf(f, S)
            %keyOf  The list key of filter F: "none" when off; a saved filter's (S: SignalFilter.saved) or a preset's when F
            %   is one (its name and settings); else "custom".
            if ~f.enabled
                key = "none";
                return
            end
            key = "custom";
            for k = 1:numel(S)
                if lower(S(k).name) == lower(f.name) && SignalFilter.key(S(k).filter) == SignalFilter.key(f)
                    key = "saved:" + S(k).name;
                    return
                end
            end
            T = SignalFilter.presets();
            for k = 1:height(T)
                p = SignalFilter.preset(T.Name(k));
                if lower(p.name) == lower(f.name) && SignalFilter.key(p) == SignalFilter.key(f)
                    key = "preset:" + T.Name(k);
                    return
                end
            end
        end
    end

    methods (Access = private)
        function s = item(obj)
            %item  The field of the filter shown: its signal, or "Filter".
            s = obj.Signal;
            if isempty(obj.Signals); s = "Filter"; end
        end

        function s = items(obj)
            s = obj.Signals;
            if isempty(s); s = "Filter"; end
        end

        function key = resolveKey(obj, key)
            %resolveKey  A list key from a key, a preset's name or label, or a saved filter's name.
            key = strtrim(string(key));
            low = lower(key);
            if ismember(low, ["none" "no filter"]); key = "none"; return; end
            if low == "custom"; key = "custom"; return; end
            if startsWith(low, "preset:") || startsWith(low, "saved:")
                if startsWith(low, "preset:")
                    T = SignalFilter.presets();
                    k = find(lower(T.Name) == extractAfter(low, "preset:") | lower(T.Label) == extractAfter(low, "preset:"), 1);
                    if isempty(k)
                        error('FilterDialog:NoFilter', 'No preset "%s".', extractAfter(key, ":"));
                    end
                    key = "preset:" + T.Name(k);
                end
                return
            end
            S = obj.SavedList;
            k = find(lower(savedNames(S)) == low, 1);
            if ~isempty(k); key = "saved:" + S(k).name; return; end
            T = SignalFilter.presets();
            k = find(lower(T.Name) == low | lower(T.Label) == low, 1);
            if isempty(k)
                error('FilterDialog:NoFilter', 'No filter "%s" (a preset or one of your saved filters).', key);
            end
            key = "preset:" + T.Name(k);
        end

        function readControls(obj, what)
            %readControls  The settings' controls into the pending filter (it is then on); WHAT changed. The list shows
            %   Custom once it differs from the filter picked; the name stays while the band does.
            s = obj.item();
            c = obj.Ctl;
            f = obj.Pending.(s);
            was = f;
            f.enabled = true;
            f.type = string(c.Type.Value);
            f.design = string(c.Design.Value);
            if what == "design"   % an order of the other kind of design: its usual one
                if f.design == "fir" && was.design ~= "fir"
                    c.Order.Value = 0;
                elseif f.design ~= "fir" && was.design == "fir"
                    c.Order.Value = 4;
                end
            end
            f.order = c.Order.Value;
            f.ripple = c.Ripple.Value;
            f.attenuation = c.Attenuation.Value;
            f.phase = string(c.Phase.Value);
            switch f.type
                case "lowpass",  f.cutoff = c.High.Value;
                case "highpass", f.cutoff = c.Low.Value;
                otherwise,       f.cutoff = [c.Low.Value c.High.Value];
            end
            p = obj.PickedFilter.(s);
            if isempty(p) || ~isstruct(p) || f.type ~= p.type || ~isequal(f.cutoff, p.cutoff)
                f.name = "";
            else
                f.name = p.name;
            end
            obj.Pending.(s) = f;
            asPicked = isstruct(p) && ~isempty(p) && p.enabled && SignalFilter.key(f) == SignalFilter.key(p) ...
                && f.name == p.name && obj.PickedKey.(s) ~= "none";
            if ~asPicked; obj.PickedKey.(s) = "custom"; end
            obj.show();
        end

        function build(obj, parent, visible, intro, title)
            fig = uifigure("Name", title, "Visible", "off", "Position", [100 100 960 640], ...
                "WindowStyle", "modal", "Tag", "FilterDialog");
            if ~isempty(parent) && isvalid(parent)
                p = parent.Position;
                fig.Position(1:2) = p(1:2) + max(0, (p(3:4) - fig.Position(3:4)) / 2);
            end
            fig.CloseRequestFcn = @(~, ~) obj.cancel();
            obj.Fig = fig;
            gray = [0.38 0.38 0.38];
            perSignal = ~isempty(obj.Signals);
            if intro == ""
                if perSignal
                    intro = "Filter a signal before any figure reads it. Each channel's whole recording is filtered, " + ...
                        "at the rate the figures read it, before it is cut into epochs, so no epoch has an edge of its own. " + ...
                        "Each signal has its own filter; a panel can add one of its own.";
                else
                    intro = "Filter the panel's signal layers (LFP, MUA, SPIKE, AUX) before anything is computed. Each " + ...
                        "channel's whole recording is filtered first, then cut into epochs, so no epoch has an edge of its own. " + ...
                        "Spike layers are not filtered.";
                end
            end
            g = uigridlayout(fig, [4 1], "RowHeight", {'fit', '1x', 'fit', 34}, "RowSpacing", 8);
            c = struct();
            c.Intro = uilabel(g, "WordWrap", "on", "Text", intro);

            main = uigridlayout(g, [1 2], "ColumnWidth", {260, '1x'}, "Padding", [0 0 0 0], "ColumnSpacing", 12);
            % left: the signal, the filters to start from, Save and Delete
            left = uigridlayout(main, [6 1], "RowHeight", {22, 22, '1x', 22, 26, 26}, "Padding", [0 0 0 0], "RowSpacing", 6);
            sg = uigridlayout(left, [1 2], "ColumnWidth", {50, '1x'}, "Padding", [0 0 0 0]);
            uilabel(sg, "Text", "Signal:");
            c.Signal = uidropdown(sg, "Items", "", "ValueChangedFcn", @(src, ~) obj.setSignal(src.Value), ...
                "Tooltip", "The signal whose filter is shown: each has its own.");
            if ~perSignal
                sg.Visible = "off";
                left.RowHeight{1} = 0;
            end
            uilabel(left, "Text", "Start from", "FontWeight", "bold");
            c.List = uilistbox(left, "Items", "", "ValueChangedFcn", @(src, ~) obj.pick(src.Value), ...
                "Tooltip", "No filter, your own settings (Custom), an EEG band or line-noise notch, or one of your saved " + ...
                "filters. Picking one fills the settings; change them freely.");
            uilabel(left, "Text", "Save the settings as one of yours:", "FontColor", gray);
            svg = uigridlayout(left, [1 2], "ColumnWidth", {'1x', 70}, "Padding", [0 0 0 0]);
            c.SaveName = uieditfield(svg, "text", "Placeholder", "a name, e.g. Theta (rat)", ...
                "Tooltip", "Your saved filters are kept with your preferences: every config and app lists them.");
            c.Save = uibutton(svg, "Text", "Save", "ButtonPushedFcn", @(~, ~) obj.saveAs(), ...
                "Tooltip", "Keep these settings under the name typed (one of the same name is replaced).");
            c.Delete = uibutton(left, "Text", "Delete saved filter", "ButtonPushedFcn", @(~, ~) obj.deleteSaved(), ...
                "Tooltip", "Forget the saved filter picked (the settings stay, as Custom).");

            % right: the settings, the response, the impulse response
            right = uigridlayout(main, [3 1], "RowHeight", {'fit', '1x', '1x'}, "Padding", [0 0 0 0], "RowSpacing", 6);
            st = uigridlayout(right, [5 4], "ColumnWidth", {100, '1x', 120, '1x'}, "RowHeight", {24, 24, 24, 24, 'fit'}, ...
                "Padding", [0 0 0 0], "RowSpacing", 4, "ColumnSpacing", 8);
            changed = @(what) @(~, ~) obj.readControls(what);
            place(uilabel(st, "Text", "Passes:"), 1, 1);
            c.Type = place(uidropdown(st, "Items", ["Band-pass" "Band-stop (notch)" "Low-pass" "High-pass"], ...
                "ItemsData", SignalFilter.Types, "ValueChangedFcn", changed("type"), ...
                "Tooltip", "Band-pass keeps the band between the cutoffs; band-stop takes it out (a notch); low-pass keeps " + ...
                "what is below its cutoff, high-pass what is above."), 1, 2);
            place(uilabel(st, "Text", "Cutoffs (Hz):"), 1, 3);
            cg = place(uigridlayout(st, [1 3], "ColumnWidth", {'1x', 'fit', '1x'}, "Padding", [0 0 0 0]), 1, 4);
            c.Low = uieditfield(cg, "numeric", "Limits", [0 Inf], "LowerLimitInclusive", "off", "Value", 4, ...
                "ValueChangedFcn", changed("cutoff"), "Tooltip", "The low cutoff, Hz (a high-pass's cutoff).");
            uilabel(cg, "Text", "to");
            c.High = uieditfield(cg, "numeric", "Limits", [0 Inf], "LowerLimitInclusive", "off", "Value", 8, ...
                "ValueChangedFcn", changed("cutoff"), "Tooltip", "The high cutoff, Hz (a low-pass's cutoff).");
            place(uilabel(st, "Text", "Design:"), 2, 1);
            c.Design = place(uidropdown(st, "Items", ["Butterworth" "Chebyshev I" "Chebyshev II" "Elliptic" "FIR (Hamming window)"], ...
                "ItemsData", SignalFilter.Designs, "ValueChangedFcn", changed("design"), ...
                "Tooltip", "Butterworth: a flat passband, cutoffs at -3 dB (one pass). Chebyshev I: a steeper edge, ripple in " + ...
                "the passband. Chebyshev II: a flat passband, ripple in the stopband, cutoffs where it is Attenuation down. " + ...
                "Elliptic: the steepest edge, ripple in both. FIR: linear phase, cutoffs at -6 dB, as long as its order."), 2, 2);
            place(uilabel(st, "Text", "Order:"), 2, 3);
            c.Order = place(uieditfield(st, "numeric", "Limits", [0 Inf], "RoundFractionalValues", "on", "Value", 4, ...
                "ValueChangedFcn", changed("order"), "Tooltip", "IIR designs: 1 to " + SignalFilter.MaxOrder + " (a band-pass " + ...
                "or band-stop has twice as many poles). FIR: its taps less one; 0 = automatic, " + SignalFilter.FirCycles + ...
                " cycles at the lowest cutoff, or at the band's width when narrower."), 2, 4);
            place(uilabel(st, "Text", "Ripple (dB):"), 3, 1);
            c.Ripple = place(uieditfield(st, "numeric", "Limits", [0 Inf], "LowerLimitInclusive", "off", "Value", 1, ...
                "ValueChangedFcn", changed("ripple"), "Tooltip", "The passband ripple, dB (Chebyshev I, elliptic)."), 3, 2);
            place(uilabel(st, "Text", "Attenuation (dB):"), 3, 3);
            c.Attenuation = place(uieditfield(st, "numeric", "Limits", [0 Inf], "LowerLimitInclusive", "off", "Value", 40, ...
                "ValueChangedFcn", changed("attenuation"), "Tooltip", "The stopband attenuation, dB (Chebyshev II, elliptic)."), 3, 4);
            place(uilabel(st, "Text", "Phase:"), 4, 1);
            c.Phase = place(uidropdown(st, "Items", ["Zero-phase (acausal: no delay)" "Causal (forward only: delayed)"], ...
                "ItemsData", SignalFilter.Phases, "ValueChangedFcn", changed("phase"), ...
                "Tooltip", "Zero-phase: an IIR filter runs forward then backward (its gain squared), an FIR once with its " + ...
                "delay taken out; nothing shifts in time, but each sample depends on later ones too. Causal: forward only, as " + ...
                "a recording system filters; each sample depends on the past alone, so the signal comes out delayed."), 4, 2);
            place(uilabel(st, "Text", "Draw at (Hz):"), 4, 3);
            c.Rate = place(uieditfield(st, "numeric", "Limits", [0 Inf], "LowerLimitInclusive", "off", ...
                "Value", FilterDialog.DefaultRate, "ValueChangedFcn", @(src, ~) obj.setPreviewRate(src.Value), ...
                "Tooltip", "The sampling rate the response is drawn at: the rate the signal is read at, when known."), 4, 4);
            c.RateNote = place(uilabel(st, "Text", "", "FontColor", gray, "WordWrap", "on"), 5, [1 4]);
            c.Mag = uiaxes(right);
            c.Imp = uiaxes(right);

            % under them: the filter in words, the reason it cannot be used
            ng = uigridlayout(g, [2 1], "RowHeight", {'fit', 'fit'}, "Padding", [0 0 0 0], "RowSpacing", 2);
            c.Describe = uilabel(ng, "Text", "", "WordWrap", "on");
            c.Error = uilabel(ng, "Text", "", "FontColor", [0.75 0.1 0.1], "WordWrap", "on");

            bg = uigridlayout(g, [1 3], "ColumnWidth", {'1x', 90, 90}, "RowHeight", {30}, "Padding", [0 0 0 0]);
            c.Cancel = uibutton(bg, "Text", "Cancel", "ButtonPushedFcn", @(~, ~) obj.cancel());
            c.Cancel.Layout.Column = 2;
            c.OK = uibutton(bg, "Text", "OK", "ButtonPushedFcn", @(~, ~) obj.ok(), ...
                "Tooltip", "Use this filter. Script name: " + obj.ScriptName + ".");
            c.OK.Layout.Column = 3;
            styleButton([c.Save c.Delete c.Cancel]);
            styleButton(c.OK, "confirm");
            obj.Ctl = c;
            fig.Visible = matlab.lang.OnOffSwitchState(visible);
        end

        function show(obj)
            %show  The controls, the list, the plots and the words for the filter shown.
            s = obj.item();
            c = obj.Ctl;
            f = obj.Pending.(s);
            % the signal drop-down: each with its filter in words
            if ~isempty(obj.Signals)
                labels = strings(1, numel(obj.Signals));
                for k = 1:numel(obj.Signals)
                    q = obj.Signals(k);
                    d = SignalFilter.describe(obj.Pending.(q), Short=true);
                    labels(k) = q + ternary(d == "", ": no filter", ": " + d);
                    if ~isempty(obj.Used) && ~ismember(q, obj.Used); labels(k) = labels(k) + "  (" + obj.UnusedNote + ")"; end
                end
                set(c.Signal, "Items", labels, "ItemsData", obj.Signals, "Value", char(s));
            end
            % the list
            T = SignalFilter.presets();
            S = obj.SavedList;
            items = ["No filter" "Custom (your settings)" T.Label.' + "  " + compose("%g-%g Hz", T.Cutoff).'];
            keys = ["none" "custom" "preset:" + T.Name.'];
            if ~isempty(S)
                items = [items, savedNames(S) + "  (saved)"];
                keys = [keys, "saved:" + savedNames(S)];
            end
            key = obj.PickedKey.(s);
            if ~ismember(key, keys); key = "custom"; obj.PickedKey.(s) = key; end
            set(c.List, "Items", items, "ItemsData", keys, "Value", char(key));
            obj.Picked = key;
            c.Delete.Enable = matlab.lang.OnOffSwitchState(startsWith(key, "saved:"));
            % the settings
            c.Type.Value = char(pickOf(f.type, SignalFilter.Types, "bandpass"));
            c.Design.Value = char(pickOf(f.design, SignalFilter.Designs, "butter"));
            c.Phase.Value = char(pickOf(f.phase, SignalFilter.Phases, "zero"));
            if isfinite(f.order) && f.order >= 0; c.Order.Value = f.order; end
            if isfinite(f.ripple) && f.ripple > 0; c.Ripple.Value = f.ripple; end
            if isfinite(f.attenuation) && f.attenuation > 0; c.Attenuation.Value = f.attenuation; end
            cut = f.cutoff(isfinite(f.cutoff) & f.cutoff > 0);
            switch f.type
                case "lowpass",  if isscalar(cut); c.High.Value = cut; end
                case "highpass", if isscalar(cut); c.Low.Value = cut; end
                otherwise
                    if numel(cut) == 2; c.Low.Value = cut(1); c.High.Value = cut(2); end
            end
            c.Low.Enable = matlab.lang.OnOffSwitchState(f.type ~= "lowpass");
            c.High.Enable = matlab.lang.OnOffSwitchState(f.type ~= "highpass");
            c.Ripple.Enable = matlab.lang.OnOffSwitchState(ismember(f.design, ["cheby1" "ellip"]));
            c.Attenuation.Enable = matlab.lang.OnOffSwitchState(ismember(f.design, ["cheby2" "ellip"]));
            c.Save.Enable = matlab.lang.OnOffSwitchState(f.enabled);
            fs = obj.Preview.(s);
            c.Rate.Value = fs;
            note = obj.Notes.(s);
            if ~isnan(obj.Rates.(s))
                if note == ""; note = "The signal is read at " + hzText(obj.Rates.(s)) + " Hz."; end
            else
                note = "The rate the signal is read at is not known here (scan the datasets and pick one): " + ...
                    "drawn at the rate typed.";
            end
            c.RateNote.Text = note;
            % the words and the plots
            [words, why] = obj.words(f, fs);
            c.Describe.Text = words;
            c.Error.Text = why;
            obj.draw(f, fs, why);
        end

        function [words, why] = words(obj, f, fs)
            %words  Filter F in words at FS Hz, its delay if causal; WHY: why it cannot be used ("" = it can).
            why = "";
            if ~f.enabled
                words = "No filter: the signal is read as it is.";
                return
            end
            I = SignalFilter.problems(f);
            if ~isempty(I)
                why = I(1).message;
                words = "";
                return
            end
            why = SignalFilter.problemAt(f, fs);
            if why ~= "" && isnan(obj.Rates.(obj.item()))
                why = why + " (drawn at the rate typed; the signal's own is not known here)";
            end
            words = SignalFilter.describe(f) + ".";
            if why ~= ""; return; end
            D = SignalFilter.design(f, fs);
            if D.kind == "fir"; words = words + " Order " + D.order + " (" + (D.order + 1) + " taps) at " + hzText(fs) + " Hz."; end
            if f.phase == "zero"
                if D.kind == "iir"
                    words = words + " Run forward then backward: no delay, its gain squared (as drawn).";
                else
                    words = words + " Its delay (" + msText(D.order / 2 / fs) + ") taken out: no delay.";
                end
            else
                words = words + " Delayed about " + msText(SignalFilter.delay(f, fs)) + " in its passband.";
            end
        end

        function draw(obj, f, fs, why)
            %draw  The response as applied (gain, dB, log frequency) and the impulse response; a message instead when none.
            ax = obj.Ctl.Mag;
            ai = obj.Ctl.Imp;
            cla(ax);
            cla(ai);
            ax.XScale = 'log';
            xlabel(ax, "Frequency (Hz)");
            ylabel(ax, "Gain (dB)");
            xlabel(ai, "Time from the impulse (ms)");
            ylabel(ai, "Response");
            if ~f.enabled || why ~= ""
                if ~f.enabled
                    title(ax, "No filter");
                else
                    title(ax, "Cannot be drawn at " + hzText(fs) + " Hz");
                end
                title(ai, "");
                return
            end
            nyq = fs / 2;
            lo = max(min(f.cutoff) / 50, nyq * 1e-5);
            freq = logspace(log10(lo), log10(nyq * 0.999), 800);
            [~, He] = SignalFilter.response(f, fs, freq);
            db = 20 * log10(max(abs(He), 1e-10));
            floorDb = max(-120, min(-40, floor(min(db) / 10) * 10));
            hold(ax, 'on');
            band = f.cutoff;
            if isscalar(band)
                if f.type == "lowpass"; band = [lo band]; else; band = [band nyq]; end
            end
            if f.type ~= "bandstop"
                patch(ax, band([1 2 2 1]), [floorDb floorDb 10 10], [0.85 0.92 1], 'EdgeColor', 'none', ...
                    'HandleVisibility', 'off', 'Tag', 'passband');
            else
                patch(ax, band([1 2 2 1]), [floorDb floorDb 10 10], [1 0.9 0.88], 'EdgeColor', 'none', ...
                    'HandleVisibility', 'off', 'Tag', 'stopband');
            end
            plot(ax, freq, db, 'LineWidth', 1.5, 'Color', [0 0.32 0.62], 'Tag', 'gain');
            for x = reshape(f.cutoff, 1, [])
                xline(ax, x, '--', 'Color', [0.4 0.4 0.4], 'HandleVisibility', 'off');
            end
            yline(ax, -3, ':', '-3 dB', 'Color', [0.5 0.5 0.5], 'LabelHorizontalAlignment', 'left', 'HandleVisibility', 'off');
            hold(ax, 'off');
            xlim(ax, [lo nyq]);
            ylim(ax, [floorDb 5]);
            grid(ax, 'on');
            how = "as applied";
            if f.phase == "zero" && f.design ~= "fir"; how = "as applied (forward and back: squared)"; end
            title(ax, "Gain " + how + " at " + hzText(fs) + " Hz");
            [h, t] = SignalFilter.impulse(f, fs);
            e = cumsum(h .^ 2);
            e = e / max(e(end), eps);
            i0 = find(e >= 5e-4, 1);
            i1 = find(e >= 1 - 5e-4, 1);
            span = t([1 end]).';   % the whole response, unless it gathers in less (99.9% of its energy)
            if ~isempty(i0) && ~isempty(i1)
                if f.phase == "zero"
                    m = max(abs(t([i0 i1])));
                    span = [-m m];
                else
                    span = [-0.1 1] * t(i1);
                end
            end
            if ~(span(2) > span(1)); span = t([1 end]).'; end
            plot(ai, 1000 * t, h, 'LineWidth', 1, 'Color', [0.55 0.2 0.1], 'Tag', 'impulse');
            xline(ai, 0, ':', 'Color', [0.4 0.4 0.4], 'HandleVisibility', 'off');
            xlim(ai, 1000 * span);
            grid(ai, 'on');
            if f.phase == "zero"
                title(ai, "Impulse response: symmetric, acausal (zero-phase)");
            else
                title(ai, "Impulse response: nothing before the impulse (causal)");
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


function v = positiveOr(v)
%positiveOr  V when it is a rate (one finite number above 0), else NaN.
if ~(isnumeric(v) && isscalar(v) && isfinite(v) && v > 0); v = NaN; end
v = double(v);
end


function v = pickOf(v, allowed, fallback)
if ~ismember(v, allowed); v = fallback; end
end


function t = hzText(v)
%hzText  A rate as short text: 250, 1017.25, 95.
if v >= 100
    t = string(round(v, 2));
else
    t = string(round(v, 3, 'significant'));
end
end


function t = msText(s)
%msText  Seconds as milliseconds in words: "12.5 ms", "0.21 s".
if s >= 1
    t = string(round(s, 3, 'significant')) + " s";
else
    t = string(round(1000 * s, 3, 'significant')) + " ms";
end
end


function v = ternary(tf, a, b)
if tf; v = a; else; v = b; end
end


function closeFig(fig)
if ~isempty(fig) && isvalid(fig); delete(fig); end
end


function n = savedNames(S)
%savedNames  The names of saved filters S (SignalFilter.saved) as a string row (1x0 for none).
n = strings(1, 0);
if ~isempty(S); n = reshape(string({S.name}), 1, []); end
end
