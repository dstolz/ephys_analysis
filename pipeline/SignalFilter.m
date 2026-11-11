classdef SignalFilter
    %SignalFilter  A filter of a continuous signal (LFP, MUA, SPIKE, AUX): its settings, the EEG band presets, your saved filters, its design and its use.
    %   A filter is a struct (SignalFilter.defaults):
    %     enabled      false = no filter (the settings are kept)
    %     name         the preset or saved filter it was picked from, in
    %                  words ("Theta"; "" = your own settings). Words only:
    %                  nothing is computed from it
    %     type         what it passes: "bandpass" | "bandstop" | "lowpass" |
    %                  "highpass"
    %     cutoff       Hz: [low high] for a band-pass or band-stop, one
    %                  value for a low-pass or high-pass
    %     design       "butter" (Butterworth: flat passband; cutoffs at
    %                  -3 dB) | "cheby1" (Chebyshev I: ripple in the
    %                  passband, a steeper edge; cutoffs at the passband
    %                  edge) | "cheby2" (Chebyshev II: flat passband,
    %                  ripple in the stopband; cutoffs at the stopband
    %                  edge, attenuation down) | "ellip" (elliptic: the
    %                  steepest edge, ripple in both; cutoffs at the
    %                  passband edge) | "fir" (a linear-phase FIR, Hamming
    %                  window: cutoffs at -6 dB)
    %     order        an IIR design's order, 1 to MaxOrder (a band-pass
    %                  or band-stop has twice as many poles: butter's n);
    %                  an FIR's order (its taps less one, made even; 0 =
    %                  automatic: FirCycles (3) cycles at its lowest cutoff,
    %                  or at its band's width when that is narrower, so a
    %                  notch is as sharp as its band)
    %     ripple       dB, the passband ripple (cheby1, ellip)
    %     attenuation  dB, the stopband attenuation (cheby2, ellip)
    %     phase        "zero" (acausal, no delay: an IIR filter runs
    %                  forward then backward, filtfilt, so its magnitude
    %                  response is squared, -6 dB at a Butterworth's
    %                  cutoffs; an FIR runs once and its delay is taken
    %                  out, its response as designed) | "causal" (forward
    %                  only, as a recording system filters: each output
    %                  sample depends on the past alone, so the signal is
    %                  delayed and its phase shifted)
    %   A list of filters (a struct array) is applied in order: a chain.
    %
    %   Settings
    %     f = SignalFilter.defaults()          no filter: Butterworth order 4, zero-phase, 4-8 Hz
    %     f = SignalFilter.normalize(F)        every field, of its class; [] = defaults
    %     F = SignalFilter.chain(F)            the enabled filters of a list, normalized (1xN)
    %     I = SignalFilter.problems(f)         what is wrong with f: a struct array (field, message)
    %     why = SignalFilter.problemAt(f, fs)  why f cannot filter a signal at FS Hz ("" = it can)
    %     t = SignalFilter.describe(F)         "Theta 4-8 Hz band-pass, Butterworth order 4, zero-phase"
    %     t = SignalFilter.describe(F, Short=true)   "Theta 4-8 Hz"
    %     k = SignalFilter.key(F)              the chain as text: two chains that filter alike have one key
    %   Presets and your saved filters
    %     T = SignalFilter.presets()           the EEG bands and line-noise notches (Name, Label, Type, Cutoff, Order, Description)
    %     f = SignalFilter.preset(NAME)        one of them, enabled ("theta", or its label "Theta")
    %     S = SignalFilter.saved()             yours: a struct array (name, filter), in the order saved
    %     SignalFilter.save(NAME, f)           keep f as NAME (one of the same name, any case, is replaced)
    %     SignalFilter.remove(NAME)            forget one
    %     f = SignalFilter.find(NAME)          a saved filter by name (any case), else a preset; [] = none
    %   They are kept in the apps' preferences (AppPrefs group
    %   PrefGroup, "Saved"), so every config and both apps see them.
    %   Using
    %     D = SignalFilter.design(f, fs)       its coefficients at FS Hz: kind "iir" (sos, g) | "fir" (b)
    %     Y = SignalFilter.apply(X, fs, F)     X [nSamples x nChannels] filtered by the chain F, column by column
    %     [H, Heff] = SignalFilter.response(f, fs, FREQ)   the response at FREQ Hz: one pass (H), as applied (Heff)
    %     [h, t] = SignalFilter.impulse(f, fs) the impulse response as applied, t s from the impulse
    %     d = SignalFilter.delay(f, fs)        the delay (s) at the passband's middle: 0 for zero-phase
    %   apply filters each column in double and returns X's class. A NaN or
    %   Inf run is bridged by a line for the filter and put back after. A
    %   filter it cannot apply at FS (a cutoff at or above the Nyquist
    %   frequency, a signal shorter than the filter needs, settings
    %   problems refuses) raises SignalFilter:Unusable with the reason.
    %   IIR designs run as second-order sections (zp2sos), which stay
    %   stable for a low band at a high rate (1-4 Hz at 30 kHz); an FIR runs
    %   by FFT (fftfilt), its edges reflected as filtfilt reflects them.
    %
    %   Requires the Signal Processing Toolbox (butter, cheby1, cheby2,
    %   ellip, fir1, hamming, zp2sos, filtfilt, sosfilt, fftfilt, freqz,
    %   impzlength).
    %
    %   Example
    %     [Y, fs] = selectChannels(src, "LFP", Channels=12);
    %     theta = SignalFilter.preset("theta");               % 4-8 Hz, Butterworth order 4, zero-phase
    %     Yt = SignalFilter.apply(Y, fs, theta);             % the whole recording, before any epoch is cut
    %     % or, as the analysis figures read it (each filtered column kept with CacheData):
    %     [Yt, fs] = selectChannels(src, "LFP", Channels=12, Filter=theta);
    %
    %   See also FilterDialog, selectChannels, DatasetOutputs.prepared, resampleSignal,
    %   EphysDataset.filterContinuous, EphysAnalysisConfig.

    properties (Constant)
        Types = ["bandpass" "bandstop" "lowpass" "highpass"]   % what a filter passes
        Designs = ["butter" "cheby1" "cheby2" "ellip" "fir"]    % how it is designed
        Phases = ["zero" "causal"]                              % zero-phase (acausal) or causal
        MaxOrder = 20                                           % an IIR design's highest order
        PrefGroup = "EphysSignalFilters"                        % AppPrefs group of your saved filters
        FirCycles = 3                                           % an automatic FIR order: this many cycles at the lowest cutoff (or the band's width, if narrower)
        MaxImpulse = 2^16                                       % impulse: at most this many samples on each side
    end

    methods (Static)
        %% --- settings --------------------------------------------------------------------
        function f = defaults()
            %defaults  No filter: its settings a Butterworth band-pass of order 4, 4-8 Hz, zero-phase.
            f = struct( ...
                'enabled',     false, ...
                'name',        "", ...
                'type',        "bandpass", ...
                'cutoff',      [4 8], ...
                'design',      "butter", ...
                'order',       4, ...
                'ripple',      1, ...
                'attenuation', 40, ...
                'phase',       "zero");
        end

        function f = normalize(in)
            %normalize  Every field of defaults, of its class (unknown fields dropped); [] or not a struct = defaults.
            %   A struct array is normalized element by element (a row). The
            %   values are not checked here: problems says what is wrong.
            f = SignalFilter.defaults();
            if isempty(in) || ~isstruct(in)
                if isstruct(in); f = repmat(f, 1, 0); end   % an empty list stays an empty list
                return
            end
            if ~isscalar(in)
                in = reshape(in, 1, []);
                f = repmat(f, 1, numel(in));
                for k = 1:numel(in); f(k) = SignalFilter.normalize(in(k)); end
                return
            end
            for name = ["enabled" "name" "type" "cutoff" "design" "order" "ripple" "attenuation" "phase"]
                if ~isfield(in, name); continue; end
                v = in.(name);
                switch name
                    case "enabled"
                        if isstring(v) || ischar(v)
                            f.enabled = any(lower(strtrim(string(v))) == ["1" "true" "yes" "on"]);
                        elseif ~isempty(v)
                            f.enabled = logical(v(1));
                        end
                    case {"name" "type" "design" "phase"}
                        if isempty(v)
                            v = "";
                        else
                            v = strjoin(reshape(string(v), 1, []), " ");
                        end
                        if name ~= "name"; v = lower(strtrim(v)); end
                        f.(name) = v;
                    case "cutoff"
                        f.cutoff = reshape(double(v), 1, []);
                    otherwise   % order, ripple, attenuation
                        if isempty(v)
                            f.(name) = NaN;
                        else
                            f.(name) = double(v(1));
                        end
                end
            end
        end

        function F = chain(F)
            %chain  The enabled filters of a list (a struct array, a cell of structs, one struct or []), normalized: 1xN.
            if iscell(F)
                F = F(cellfun(@isstruct, F) & ~cellfun(@isempty, F));
                if isempty(F)
                    F = [];
                else
                    G = repmat(SignalFilter.defaults(), 1, 0);
                    for k = 1:numel(F); G = [G, SignalFilter.normalize(F{k})]; end %#ok<AGROW>
                    F = G;
                end
            end
            if isempty(F) || ~isstruct(F)
                F = repmat(SignalFilter.defaults(), 1, 0);
                return
            end
            F = SignalFilter.normalize(F);
            F = reshape(F([F.enabled]), 1, []);
        end

        function I = problems(f)
            %problems  What is wrong with filter F's settings: a struct array (field, message), empty when nothing is.
            %   Checked whether it is enabled or not: type, design and phase
            %   among Types, Designs and Phases; cutoff two values 0 < low <
            %   high (a band-pass or band-stop) or one value above 0 (a low-
            %   or high-pass); order a whole number, 1 to MaxOrder for an
            %   IIR design, 0 (automatic) or more for an FIR; ripple above 0
            %   (cheby1, ellip) and below attenuation (ellip); attenuation
            %   above 0 (cheby2, ellip). The rate is not known here
            %   (problemAt checks the cutoffs against the Nyquist frequency).
            f = SignalFilter.normalize(f);
            I = repmat(struct('field', "", 'message', ""), 1, 0);
            if ~ismember(f.type, SignalFilter.Types)
                I(end+1) = issue("type", "The filter's type must be " + orList(SignalFilter.Types) + ", not """ + f.type + """.");
            end
            if ~ismember(f.design, SignalFilter.Designs)
                I(end+1) = issue("design", "The filter's design must be " + orList(SignalFilter.Designs) + ", not """ + f.design + """.");
            end
            if ~ismember(f.phase, SignalFilter.Phases)
                I(end+1) = issue("phase", "The filter's phase must be ""zero"" (acausal) or ""causal"", not """ + f.phase + """.");
            end
            c = f.cutoff;
            if ismember(f.type, ["bandpass" "bandstop"])
                if numel(c) ~= 2 || any(~isfinite(c)) || c(1) <= 0 || c(2) <= c(1)
                    I(end+1) = issue("cutoff", "A " + typeWords(f.type) + " filter takes two cutoffs, low then high, both above 0 Hz " + ...
                        "(" + cutoffText(c) + " given).");
                end
            elseif ismember(f.type, ["lowpass" "highpass"])
                if ~isscalar(c) || ~isfinite(c) || c <= 0
                    I(end+1) = issue("cutoff", "A " + typeWords(f.type) + " filter takes one cutoff above 0 Hz (" + cutoffText(c) + " given).");
                end
            end
            n = f.order;
            if f.design == "fir"
                if ~(isfinite(n) && n >= 0 && n == round(n))
                    I(end+1) = issue("order", "An FIR filter's order is a whole number: its taps less one (0 = automatic, " + ...
                        SignalFilter.FirCycles + " cycles at its lowest cutoff or band width).");
                end
            elseif ismember(f.design, SignalFilter.Designs)
                if ~(isfinite(n) && n >= 1 && n <= SignalFilter.MaxOrder && n == round(n))
                    I(end+1) = issue("order", "An IIR filter's order is a whole number from 1 to " + SignalFilter.MaxOrder + ...
                        " (a band-pass or band-stop has twice as many poles).");
                end
            end
            if ismember(f.design, ["cheby1" "ellip"]) && ~(isfinite(f.ripple) && f.ripple > 0)
                I(end+1) = issue("ripple", "The passband ripple (dB) of a " + designWords(f.design) + " filter must be above 0.");
            end
            if ismember(f.design, ["cheby2" "ellip"]) && ~(isfinite(f.attenuation) && f.attenuation > 0)
                I(end+1) = issue("attenuation", "The stopband attenuation (dB) of a " + designWords(f.design) + " filter must be above 0.");
            end
            if f.design == "ellip" && isfinite(f.ripple) && isfinite(f.attenuation) && f.ripple > 0 && f.attenuation > 0 ...
                    && f.ripple >= f.attenuation
                I(end+1) = issue("ripple", "An elliptic filter's passband ripple must be below its stopband attenuation.");
            end

            function s = issue(field, message)
                s = struct('field', string(field), 'message', string(message));
            end
        end

        function why = problemAt(f, fs)
            %problemAt  Why filter F cannot filter a signal at FS Hz, in a sentence; "" when it can.
            %   The first of problems, else a cutoff at or above the Nyquist
            %   frequency (FS / 2), else a design that comes out unusable
            %   (not finite).
            f = SignalFilter.normalize(f);
            I = SignalFilter.problems(f);
            why = "";
            if ~isempty(I)
                why = I(1).message;
                return
            end
            if ~(isscalar(fs) && isfinite(fs) && fs > 0)
                why = "The signal's rate is not known.";
                return
            end
            nyq = fs / 2;
            if max(f.cutoff) >= nyq
                why = "The filter's " + ternary(isscalar(f.cutoff), "cutoff", "band") + " (" + cutoffText(f.cutoff) + ...
                    " Hz) reaches the Nyquist frequency (" + hzWords(nyq) + " Hz) of a signal at " + hzWords(fs) + ...
                    " Hz: every cutoff must be below it.";
                return
            end
            try
                D = SignalFilter.design(f, fs);
                ok = (D.kind == "iir" && all(isfinite(D.sos(:))) && isfinite(D.g)) || (D.kind == "fir" && all(isfinite(D.b)));
            catch
                ok = false;
            end
            if ~ok
                why = "This filter cannot be designed at " + hzWords(fs) + " Hz (its coefficients are not finite): " + ...
                    "lower its order or widen its band.";
            end
        end

        function text = describe(F, opts)
            %describe  A filter (or a chain) in words: "Theta 4-8 Hz band-pass, Butterworth order 4, zero-phase"; "" for none.
            %   Short=true: "Theta 4-8 Hz", "4-8 Hz band-pass", "low-pass 100 Hz".
            %   Only the enabled filters are described; a chain's are joined
            %   by ", then ".
            arguments
                F = []
                opts.Short (1,1) logical = false
            end
            F = SignalFilter.chain(F);
            parts = strings(1, numel(F));
            for k = 1:numel(F)
                parts(k) = oneText(F(k), opts.Short);
            end
            if opts.Short
                text = strjoin(parts, " + ");
            else
                text = strjoin(parts, "; then ");
            end
        end

        function k = key(F)
            %key  The chain F (its enabled filters) as text: two chains that filter alike have one key ("" = none).
            %   What a filter does and nothing else (its name is words): a
            %   cache of filtered signals is keyed by it.
            F = SignalFilter.chain(F);
            parts = strings(1, numel(F));
            for j = 1:numel(F)
                f = F(j);
                p = f.type + ":" + strjoin(compose("%.10g", f.cutoff), ",") + ":" + f.design + ":" + compose("%.10g", f.order);
                if ismember(f.design, ["cheby1" "ellip"]); p = p + ":r" + compose("%.10g", f.ripple); end
                if ismember(f.design, ["cheby2" "ellip"]); p = p + ":a" + compose("%.10g", f.attenuation); end
                parts(j) = p + ":" + f.phase;
            end
            k = strjoin(parts, ">");
        end

        %% --- presets and your saved filters ------------------------------------------------
        function T = presets()
            %presets  The built-in filters: the EEG bands, sharp-wave ripples and the line-noise notches.
            %   A table, a row each: Name (a key: "theta"), Label ("Theta"),
            %   Type, Cutoff (Hz), Order (Butterworth, zero-phase) and
            %   Description. The bands' edges differ between fields and
            %   species (rodent hippocampal theta runs about 6-10 Hz, high
            %   gamma 60-150 or 70-200 Hz): pick one and change its cutoffs,
            %   then save it as your own.
            rows = {
                "delta",     "Delta",            "bandpass", [1 4],     4, "Delta, 1-4 Hz: slow waves of sleep and anesthesia"
                "theta",     "Theta",            "bandpass", [4 8],     4, "Theta, 4-8 Hz (rodent hippocampal theta runs about 6-10 Hz)"
                "alpha",     "Alpha",            "bandpass", [8 13],    4, "Alpha, 8-13 Hz"
                "beta",      "Beta",             "bandpass", [13 30],   4, "Beta, 13-30 Hz"
                "lowGamma",  "Low gamma",        "bandpass", [30 60],   4, "Low gamma, 30-60 Hz"
                "highGamma", "High gamma",       "bandpass", [60 150],  4, "High gamma, 60-150 Hz"
                "ripple",    "Ripple",           "bandpass", [150 250], 4, "Sharp-wave ripples, 150-250 Hz (hippocampus)"
                "notch60",   "60 Hz line noise", "bandstop", [58 62],   2, "A notch at 60 Hz, the mains of the Americas (58-62 Hz band-stop)"
                "notch50",   "50 Hz line noise", "bandstop", [48 52],   2, "A notch at 50 Hz, the mains of Europe, Asia and Africa (48-52 Hz band-stop)"
                };
            n = size(rows, 1);
            Name = strings(n, 1); Label = strings(n, 1); Type = strings(n, 1); Description = strings(n, 1);
            Cutoff = zeros(n, 2); Order = zeros(n, 1);
            for k = 1:n
                Name(k) = rows{k, 1};
                Label(k) = rows{k, 2};
                Type(k) = rows{k, 3};
                Cutoff(k, :) = rows{k, 4};
                Order(k) = rows{k, 5};
                Description(k) = rows{k, 6};
            end
            T = table(Name, Label, Type, Cutoff, Order, Description);
        end

        function f = preset(name)
            %preset  A built-in filter, enabled, by its Name ("theta") or Label ("Theta"), any case.
            %   Error: SignalFilter:NoPreset.
            arguments
                name (1,1) string
            end
            T = SignalFilter.presets();
            k = find(lower(T.Name) == lower(strtrim(name)) | lower(T.Label) == lower(strtrim(name)), 1);
            if isempty(k)
                error('SignalFilter:NoPreset', 'No preset filter "%s" (the presets are %s).', name, strjoin(T.Name, ", "));
            end
            f = SignalFilter.defaults();
            f.enabled = true;
            f.name = T.Label(k);
            f.type = T.Type(k);
            f.cutoff = T.Cutoff(k, :);
            f.order = T.Order(k);
        end

        function S = saved()
            %saved  Your saved filters: a 1xN struct array (name, filter), in the order saved.
            %   An unreadable preference gives none and the warning
            %   SignalFilter:BadPreference.
            S = repmat(struct('name', "", 'filter', SignalFilter.defaults()), 1, 0);
            try
                if ~AppPrefs.ispref(SignalFilter.PrefGroup, "Saved"); return; end
                v = AppPrefs.getpref(SignalFilter.PrefGroup, "Saved");
            catch ME
                warning('SignalFilter:BadPreference', 'Your saved filters are not readable: %s', ME.message);
                return
            end
            if ~isstruct(v) || ~all(isfield(v, {'name', 'filter'})); return; end
            for k = 1:numel(v)
                nm = strtrim(string(v(k).name));
                if ~isscalar(nm) || ismissing(nm) || nm == ""; continue; end
                f = SignalFilter.normalize(v(k).filter);
                f.name = nm;
                f.enabled = true;
                S(end+1) = struct('name', nm, 'filter', f); %#ok<AGROW>
            end
        end

        function save(name, f)
            %save  Keep filter F as NAME among your saved filters; one of the same name (any case) is replaced in place.
            %   F is saved enabled and named NAME. Errors: SignalFilter:BadName
            %   (a blank name), SignalFilter:BadFilter (settings problems refuses).
            arguments
                name (1,1) string
                f
            end
            name = strtrim(name);
            if name == ""
                error('SignalFilter:BadName', 'A saved filter needs a name.');
            end
            f = SignalFilter.normalize(f);
            I = SignalFilter.problems(f);
            if ~isempty(I)
                error('SignalFilter:BadFilter', '%s', I(1).message);
            end
            f.enabled = true;
            f.name = name;
            S = SignalFilter.saved();
            k = find(lower(savedNames(S)) == lower(name), 1);
            if isempty(k); k = numel(S) + 1; end
            S(k) = struct('name', name, 'filter', f);
            AppPrefs.setpref(SignalFilter.PrefGroup, "Saved", S);
        end

        function remove(name)
            %remove  Forget your saved filter NAME (any case); nothing happens when there is none.
            arguments
                name (1,1) string
            end
            S = SignalFilter.saved();
            k = lower(savedNames(S)) == lower(strtrim(name));
            if ~any(k); return; end
            S(k) = [];
            if isempty(S)
                AppPrefs.rmpref(SignalFilter.PrefGroup, "Saved");
            else
                AppPrefs.setpref(SignalFilter.PrefGroup, "Saved", S);
            end
        end

        function f = find(name)
            %find  Your saved filter NAME (any case), else the preset of that name or label; [] when neither is.
            arguments
                name (1,1) string
            end
            f = [];
            S = SignalFilter.saved();
            k = find(lower(savedNames(S)) == lower(strtrim(name)), 1);
            if ~isempty(k)
                f = S(k).filter;
                return
            end
            T = SignalFilter.presets();
            if any(lower(T.Name) == lower(strtrim(name)) | lower(T.Label) == lower(strtrim(name)))
                f = SignalFilter.preset(name);
            end
        end

        %% --- using ------------------------------------------------------------------------
        function D = design(f, fs)
            %design  Filter F's coefficients at FS Hz: a struct (kind, sos, g, b, order, fs).
            %   kind "iir": SOS (second-order sections, zp2sos) and gain G;
            %   kind "fir": B, the taps (order = numel(B) - 1, even). F must
            %   pass problemAt (design does not check it).
            f = SignalFilter.normalize(f);
            nyq = fs / 2;
            w = f.cutoff / nyq;
            D = struct('kind', "iir", 'sos', zeros(0, 6), 'g', 1, 'b', zeros(1, 0), 'order', 0, 'fs', fs);
            if f.design == "fir"
                n = f.order;
                if n == 0   % automatic: FirCycles cycles at the lowest cutoff, or at the band's width when narrower (a sharp notch)
                    fRef = min(f.cutoff);
                    if numel(f.cutoff) == 2; fRef = min(fRef, f.cutoff(2) - f.cutoff(1)); end
                    n = ceil(SignalFilter.FirCycles * fs / fRef);
                end
                n = 2 * ceil(n / 2);   % even: a whole-sample delay (and the order a high-pass or band-stop needs)
                D.kind = "fir";
                D.b = fir1(n, w, firType(f.type), hamming(n + 1));
                D.order = n;
                return
            end
            ft = iirType(f.type);
            switch f.design
                case "butter"
                    [z, p, k] = butter(f.order, w, ft);
                case "cheby1"
                    [z, p, k] = cheby1(f.order, f.ripple, w, ft);
                case "cheby2"
                    [z, p, k] = cheby2(f.order, f.attenuation, w, ft);
                case "ellip"
                    [z, p, k] = ellip(f.order, f.ripple, f.attenuation, w, ft);
            end
            [D.sos, D.g] = zp2sos(z, p, k);
            D.order = numel(p);
        end

        function Y = apply(X, fs, F)
            %apply  X [nSamples x nChannels] filtered by the chain F at FS Hz, column by column, in X's class.
            %   F: one filter, a list (applied in order) or []; its disabled
            %   filters are skipped (none enabled: X as it is). Error:
            %   SignalFilter:Unusable (problemAt's reason, or a signal too
            %   short for the filter).
            arguments
                X {mustBeNumeric}
                fs (1,1) double
                F = []
            end
            F = SignalFilter.chain(F);
            Y = X;
            if isempty(F) || isempty(X); return; end
            D = cell(1, numel(F));
            for k = 1:numel(F)
                why = SignalFilter.problemAt(F(k), fs);
                if why ~= ""
                    error('SignalFilter:Unusable', '%s', why);
                end
                D{k} = SignalFilter.design(F(k), fs);
            end
            n = size(X, 1);
            for k = 1:numel(F)
                need = padNeeded(D{k}, F(k).phase);
                if n <= need
                    error('SignalFilter:Unusable', ['The signal (%d samples, %.3g s at %s Hz) is too short for the filter %s: ' ...
                        'it needs more than %d samples.'], n, n / fs, hzWords(fs), SignalFilter.describe(F(k), Short=true), need);
                end
            end
            cls = class(X);
            for c = 1:size(X, 2)
                x = double(X(:, c));
                bad = ~isfinite(x);
                if all(bad); continue; end
                if any(bad)   % bridged by a line for the filter, put back after
                    x(bad) = NaN;
                    x = fillmissing(x, 'linear', 'EndValues', 'nearest');
                end
                for k = 1:numel(F)
                    x = runFilter(D{k}, F(k).phase, x);
                end
                if any(bad); x(bad) = NaN; end
                Y(:, c) = cast(x, cls);
            end
        end

        function [H, Heff] = response(f, fs, freq)
            %response  Filter F's response at FREQ Hz (a vector) at FS Hz: H for one pass, Heff as applied.
            %   Heff is H for a causal filter and for a zero-phase FIR (its
            %   delay taken out: |H|, phase 0), |H|^2 for a zero-phase IIR
            %   filter (run forward and back). Both are columns, complex.
            f = SignalFilter.normalize(f);
            freq = reshape(double(freq), [], 1);
            n = numel(freq);
            if n == 1; freq = [freq; freq]; end   % (freqz reads a scalar as a number of points)
            D = SignalFilter.design(f, fs);
            if D.kind == "fir"
                H = reshape(freqz(D.b, 1, freq, fs), [], 1);
            else
                H = D.g * ones(size(freq));
                for s = 1:size(D.sos, 1)
                    H = H .* reshape(freqz(D.sos(s, 1:3), D.sos(s, 4:6), freq, fs), [], 1);
                end
            end
            H = H(1:n);
            Heff = H;
            if f.phase == "zero"
                if D.kind == "fir"
                    Heff = complex(abs(H));
                else
                    Heff = complex(abs(H) .^ 2);
                end
            end
        end

        function [h, t] = impulse(f, fs)
            %impulse  Filter F's impulse response as applied at FS Hz: H at T s from the impulse (columns).
            %   Long enough to show it decay (impzlength; at most MaxImpulse
            %   samples each side): a causal filter's is 0 before the
            %   impulse, a zero-phase one's symmetric about it.
            f = SignalFilter.normalize(f);
            D = SignalFilter.design(f, fs);
            if D.kind == "fir"
                L = D.order + 1;
            else
                L = impzlength(D.sos);
            end
            if f.phase == "zero" && D.kind == "iir"; L = 2 * L; end
            L = min(max(L, 16), SignalFilter.MaxImpulse);
            pad = padNeeded(D, f.phase);
            m = L + pad + 1;   % the impulse's sample, with room on both sides
            x = zeros(2 * m - 1, 1);
            x(m) = 1;
            y = runFilter(D, f.phase, x);
            keep = (m - L):(m + L);
            h = y(keep);
            t = ((keep - m) / fs).';
        end

        function d = delay(f, fs)
            %delay  The delay (s) filter F adds at its passband's middle at FS Hz: 0 for zero-phase.
            %   A causal FIR delays every frequency by order / 2 samples; a
            %   causal IIR filter by its group delay, taken at the middle of
            %   its band (a band-pass's geometric middle, half a low-pass's
            %   cutoff, a high-pass's cutoff and a band-stop's lower one
            %   times 2, below the Nyquist frequency).
            f = SignalFilter.normalize(f);
            d = 0;
            if f.phase == "zero"; return; end
            D = SignalFilter.design(f, fs);
            if D.kind == "fir"
                d = D.order / 2 / fs;
                return
            end
            c = f.cutoff;
            switch f.type
                case "bandpass", fc = sqrt(c(1) * c(2));
                case "lowpass",  fc = c / 2;
                case "highpass", fc = min(2 * c, 0.45 * fs);
                otherwise,       fc = c(1) / 2;
            end
            df = fc * 1e-4;
            H = SignalFilter.response(f, fs, [fc - df; fc + df]);
            dphi = angle(H(2) / H(1));
            d = -dphi / (2 * pi * 2 * df);
        end
    end
end


function y = runFilter(D, phase, x)
%runFilter  Column X (double) through the design D, zero-phase or causal.
if D.kind == "iir"
    if phase == "zero"
        y = filtfilt(D.sos, D.g, x);
    else
        y = D.g * sosfilt(D.sos, x);
    end
    return
end
b = reshape(D.b, [], 1);
N = D.order;
n = numel(x);
if phase == "causal"
    y = fftfilt(b, x);
    return
end
% zero-phase: once through the linear-phase FIR, its delay (N/2 samples) taken out; the edges reflected about the end
% samples (as filtfilt reflects them), N samples on each side, so the first and last N/2 outputs see a signal
pre = 2 * x(1) - x(N + 1:-1:2);
post = 2 * x(n) - x(n - 1:-1:n - N);
z = fftfilt(b, [pre; x; post]);
y = z(N + N / 2 + (1:n));
end


function n = padNeeded(D, phase)
%padNeeded  The fewest samples a signal must exceed for the design D: filtfilt's edge reflection, an FIR's order.
if D.kind == "fir"
    n = D.order;
    if phase == "causal"; n = 0; end
else
    n = 0;
    if phase == "zero"; n = 3 * (2 * size(D.sos, 1)); end   % filtfilt reflects 3 x the order at each end
end
end


function t = iirType(type)
switch type
    case "bandpass", t = "bandpass";
    case "bandstop", t = "stop";
    case "lowpass",  t = "low";
    otherwise,       t = "high";
end
end


function t = firType(type)
switch type
    case "bandpass", t = "bandpass";
    case "bandstop", t = "stop";
    case "lowpass",  t = "low";
    otherwise,       t = "high";
end
end


function t = oneText(f, short)
%oneText  One enabled filter in words (describe): "Theta 4-8 Hz band-pass, Butterworth order 4, zero-phase", short "Theta 4-8 Hz".
band = cutoffText(f.cutoff) + " Hz";
switch f.type
    case "bandpass", what = band + " band-pass";
    case "bandstop", what = band + " band-stop";
    case "lowpass",  what = "low-pass " + band;
    case "highpass", what = "high-pass " + band;
    otherwise,       what = band + " " + f.type;
end
if f.name == ""
    lead = what;
elseif f.type == "bandpass"
    lead = f.name + " " + what;   % "Theta 4-8 Hz band-pass"
else
    lead = f.name + " (" + what + ")";   % "60 Hz line noise (58-62 Hz band-stop)"
end
if short
    if f.name ~= "" && f.type == "bandpass"; lead = f.name + " " + band; end   % "Theta 4-8 Hz"
    t = lead;
    return
end
how = designWords(f.design);
if f.design == "fir"
    if f.order == 0
        how = how + ", automatic order";
    else
        how = how + " order " + f.order;
    end
else
    how = how + " order " + f.order;
end
t = lead + ", " + how + ", " + ternary(f.phase == "zero", "zero-phase", "causal");
end


function t = designWords(d)
switch d
    case "butter", t = "Butterworth";
    case "cheby1", t = "Chebyshev I";
    case "cheby2", t = "Chebyshev II";
    case "ellip",  t = "elliptic";
    case "fir",    t = "FIR";
    otherwise,     t = string(d);
end
end


function t = typeWords(type)
switch type
    case "bandpass", t = "band-pass";
    case "bandstop", t = "band-stop";
    case "lowpass",  t = "low-pass";
    case "highpass", t = "high-pass";
    otherwise,       t = string(type);
end
end


function t = cutoffText(c)
%cutoffText  "4-8", "100" or "none": cutoffs in Hz as short text.
if isempty(c)
    t = "none";
elseif isscalar(c)
    t = hzWords(c);
else
    t = strjoin(arrayfun(@hzWords, reshape(c, 1, [])), "-");
end
end


function t = hzWords(v)
%hzWords  A frequency or rate as short text: 4, 0.5, 1017.25.
if ~isfinite(v)
    t = string(v);
elseif v >= 100
    t = string(round(v, 2));
else
    t = string(round(v, 3, 'significant'));
end
end


function t = orList(v)
v = """" + v + """";
if isscalar(v)
    t = v;
else
    t = strjoin(v(1:end - 1), ", ") + " or " + v(end);
end
end


function v = ternary(tf, a, b)
if tf; v = a; else; v = b; end
end


function n = savedNames(S)
%savedNames  The names of saved filters S (SignalFilter.saved) as a string row (1x0 for none).
n = strings(1, 0);
if ~isempty(S); n = reshape(string({S.name}), 1, []); end
end
