classdef test_SignalFilter < matlab.unittest.TestCase
    %test_SignalFilter  A signal filter's settings, presets, saved filters, design and use (SignalFilter).
    %   The settings normalized and checked (problems, problemAt), the EEG
    %   presets, the words (describe) and the cache key; each design and type
    %   applied to sines: what passes and what is taken out, zero-phase with
    %   no lag and causal with its delay, an IIR's squared gain, an FIR's
    %   centered delay, a chain in order, the class kept, NaN runs bridged,
    %   the refusals (past Nyquist, too short); the response and impulse
    %   response as applied; your saved filters in a temporary preference
    %   store (AppPrefs.useTemporary).
    %
    %   Usage:  runtests("test_SignalFilter")

    properties (Constant)
        Fs = 1000
    end

    methods (Test)
        function normalizesAndChains(tc)
            d = SignalFilter.defaults();
            tc.verifyEqual(string(fieldnames(d)).', ["enabled" "name" "type" "cutoff" "design" "order" "ripple" "attenuation" "phase"]);
            tc.verifyFalse(d.enabled, 'Off by default.');
            tc.verifyEqual(SignalFilter.normalize([]), d, '[] is the defaults.');
            f = SignalFilter.normalize(struct('enabled', "true", 'type', 'LowPass ', 'cutoff', [100; 200], 'order', "6", 'extra', 1));
            tc.verifyTrue(f.enabled);
            tc.verifyEqual(f.type, "lowpass", 'Lower case, trimmed.');
            tc.verifyEqual(f.cutoff, [100 200], 'A row.');
            tc.verifyEqual(f.order, 6);
            tc.verifyFalse(isfield(f, 'extra'), 'Unknown fields dropped.');
            on = SignalFilter.preset("theta");
            off = d;
            C = SignalFilter.chain([off on off SignalFilter.preset("beta")]);
            tc.verifyEqual(size(C), [1 2], 'Only the enabled ones.');
            tc.verifyEqual([C.name], ["Theta" "Beta"]);
            tc.verifyEqual(size(SignalFilter.chain([])), [1 0]);
            tc.verifyEqual(size(SignalFilter.chain({on, [], off})), [1 1], 'A cell of filters.');
        end

        function presetsAreTheBands(tc)
            T = SignalFilter.presets();
            tc.verifyEqual(T.Name(1:7).', ["delta" "theta" "alpha" "beta" "lowGamma" "highGamma" "ripple"]);
            tc.verifyEqual(T.Cutoff(T.Name == "alpha", :), [8 13]);
            tc.verifyEqual(T.Type(T.Name == "notch60"), "bandstop");
            f = SignalFilter.preset("High gamma");
            tc.verifyEqual([f.name f.type f.design f.phase], ["High gamma" "bandpass" "butter" "zero"], 'By its label too.');
            tc.verifyTrue(f.enabled);
            tc.verifyError(@() SignalFilter.preset("kappa"), 'SignalFilter:NoPreset');
            for k = 1:height(T)
                tc.verifyEmpty(SignalFilter.problems(SignalFilter.preset(T.Name(k))), T.Name(k) + " is a valid filter.");
                tc.verifyEqual(SignalFilter.problemAt(SignalFilter.preset(T.Name(k)), 1000), "", T.Name(k) + " runs at 1 kHz.");
            end
        end

        function refusesBadSettings(tc)
            f = SignalFilter.preset("theta");
            field = @(g) [SignalFilter.problems(g).field];
            g = f; g.cutoff = [8 4];
            tc.verifyEqual(field(g), "cutoff", 'Low above high.');
            g = f; g.type = "lowpass";
            tc.verifyEqual(field(g), "cutoff", 'A low-pass takes one cutoff.');
            g.cutoff = 30;
            tc.verifyEmpty(field(g));
            g = f; g.type = "comb";
            tc.verifyEqual(field(g), "type");
            g = f; g.design = "bessel";
            tc.verifyEqual(field(g), "design");
            g = f; g.phase = "linear";
            tc.verifyEqual(field(g), "phase");
            g = f; g.order = 0;
            tc.verifyEqual(field(g), "order", 'An IIR order is 1 or more.');
            g.order = 21;
            tc.verifyEqual(field(g), "order", 'At most MaxOrder.');
            g.design = "fir";
            g.order = 0;
            tc.verifyEmpty(field(g), 'An FIR order of 0 is automatic.');
            g.order = 2.5;
            tc.verifyEqual(field(g), "order");
            g = f; g.design = "cheby1"; g.ripple = 0;
            tc.verifyEqual(field(g), "ripple");
            g = f; g.design = "cheby2"; g.attenuation = -3;
            tc.verifyEqual(field(g), "attenuation");
            g = f; g.design = "ellip"; g.ripple = 50; g.attenuation = 40;
            tc.verifyEqual(field(g), "ripple", 'An elliptic ripple below its attenuation.');
            g = f; g.design = "butter"; g.ripple = 0;
            tc.verifyEmpty(field(g), 'A design that does not use the ripple ignores it.');
            why = SignalFilter.problemAt(SignalFilter.preset("highGamma"), 250);
            tc.verifySubstring(why, "Nyquist frequency (125 Hz)");
            tc.verifySubstring(SignalFilter.problemAt(f, NaN), "not known");
        end

        function describesInWords(tc)
            f = SignalFilter.preset("theta");
            tc.verifyEqual(SignalFilter.describe(f), "Theta 4-8 Hz band-pass, Butterworth order 4, zero-phase");
            tc.verifyEqual(SignalFilter.describe(f, Short=true), "Theta 4-8 Hz");
            g = f; g.name = ""; g.type = "lowpass"; g.cutoff = 100; g.design = "fir"; g.order = 0; g.phase = "causal";
            tc.verifyEqual(SignalFilter.describe(g), "low-pass 100 Hz, FIR, automatic order, causal");
            n = SignalFilter.preset("notch60");
            tc.verifyEqual(SignalFilter.describe(n, Short=true), "60 Hz line noise (58-62 Hz band-stop)");
            tc.verifyEqual(SignalFilter.describe([n f], Short=true), "60 Hz line noise (58-62 Hz band-stop) + Theta 4-8 Hz", 'A chain, in order.');
            tc.verifyEqual(SignalFilter.describe(SignalFilter.defaults()), "", 'Off: no words.');
        end

        function keysWhatItDoes(tc)
            f = SignalFilter.preset("theta");
            g = f; g.name = "My theta";
            tc.verifyEqual(SignalFilter.key(g), SignalFilter.key(f), 'The name is words only.');
            g = f; g.phase = "causal";
            tc.verifyNotEqual(SignalFilter.key(g), SignalFilter.key(f));
            g = f; g.ripple = 3;
            tc.verifyEqual(SignalFilter.key(g), SignalFilter.key(f), 'A Butterworth ignores the ripple.');
            tc.verifyNotEqual(SignalFilter.key([f SignalFilter.preset("notch60")]), SignalFilter.key([SignalFilter.preset("notch60") f]), ...
                'A chain in order.');
            tc.verifyEqual(SignalFilter.key(SignalFilter.defaults()), "");
        end

        function designs(tc)
            f = SignalFilter.preset("theta");
            D = SignalFilter.design(f, tc.Fs);
            tc.verifyEqual(D.kind, "iir");
            tc.verifyEqual(D.order, 8, 'A band-pass of order 4 has 8 poles (butter''s n).');
            tc.verifySize(D.sos, [4 6]);
            f.design = "fir";
            f.order = 0;
            D = SignalFilter.design(f, tc.Fs);
            tc.verifyEqual(D.kind, "fir");
            tc.verifyEqual(D.order, 750, 'Automatic: 3 cycles at 4 Hz at 1 kHz.');
            f.cutoff = [58 62];
            D = SignalFilter.design(f, tc.Fs);
            tc.verifyEqual(D.order, 750, 'A narrow band: 3 cycles at its width (4 Hz), not at 58 Hz.');
            f.cutoff = [4 8];
            f.order = 101;
            D = SignalFilter.design(f, tc.Fs);
            tc.verifyEqual(D.order, 102, 'Made even.');
            tc.verifyNumElements(D.b, 103);
        end

        function zeroPhasePassesTheBandWithNoLag(tc)
            [t, x6, x40, x1] = tc.sines();
            X = single([x6 + x40 + x1, 2 * x40]);
            Y = SignalFilter.apply(X, tc.Fs, SignalFilter.preset("theta"));
            tc.verifyClass(Y, 'single', 'The input''s class.');
            mid = t > 5 & t < 15;
            tc.verifyLessThan(max(abs(double(Y(mid, 1)) - x6(mid))), 0.08, ...
                'The 6 Hz sine passes (squared gain near 1), in phase; 1 and 40 Hz are taken out.');
            tc.verifyLessThan(max(abs(Y(mid, 2))), 0.01, 'Each column filtered on its own: 40 Hz alone, gone.');
            xb = tc.bandNoise();
            tc.verifyEqual(lagOf(SignalFilter.apply(xb, tc.Fs, SignalFilter.preset("theta")), xb, tc.Fs), 0, 'Zero-phase: no lag.');
        end

        function causalIsDelayed(tc)
            xb = tc.bandNoise();   % theta-band noise: its cross-correlation has one peak, at the lag
            f = SignalFilter.preset("theta");
            f.phase = "causal";
            d = SignalFilter.delay(f, tc.Fs);
            lag = lagOf(SignalFilter.apply(xb, tc.Fs, f), xb, tc.Fs);
            tc.verifyGreaterThan(lag, 0, 'Causal: the output comes after its input.');
            tc.verifyLessThan(abs(lag - d), 0.05, sprintf('Its lag in the band (%.3f s) is about its delay (%.3f s).', lag, d));
            tc.verifyEqual(SignalFilter.delay(SignalFilter.preset("theta"), tc.Fs), 0, 'Zero-phase: no delay.');
            g = f; g.design = "fir"; g.order = 200;
            tc.verifyEqual(SignalFilter.delay(g, tc.Fs), 0.1, 'A causal FIR: order / 2 samples.');
            tc.verifyEqual(lagOf(SignalFilter.apply(xb, tc.Fs, g), xb, tc.Fs), 0.1, 'AbsTol', 1e-9);
            g.phase = "zero";
            tc.verifyEqual(lagOf(SignalFilter.apply(xb, tc.Fs, g), xb, tc.Fs), 0, 'A zero-phase FIR: its delay taken out.');
        end

        function everyTypeAndDesign(tc)
            [t, x6, x40, x1] = tc.sines();
            x60 = sin(2 * pi * 60 * t);
            mid = t > 5 & t < 15;
            gain = @(y, x) rms(y(mid)) / rms(x(mid));
            keeps = 0.75;   % a passband: a Chebyshev I's or elliptic's 1 dB ripple, twice (zero-phase), is down to 0.79
            for d = SignalFilter.Designs
                f = SignalFilter.defaults();
                f.enabled = true;
                f.design = d;
                f.order = 4;
                if d == "fir"; f.order = 0; end
                f.type = "bandpass"; f.cutoff = [4 8];
                y = SignalFilter.apply(x6 + x40, tc.Fs, f);
                tc.verifyGreaterThan(gain(y, x6), keeps, d + " band-pass keeps 6 Hz");
                tc.verifyLessThan(gain(SignalFilter.apply(x40, tc.Fs, f), x40), 0.05, d + " band-pass takes out 40 Hz");
                f.type = "bandstop"; f.cutoff = [50 70];
                tc.verifyLessThan(gain(SignalFilter.apply(x60, tc.Fs, f), x60), 0.1, d + " band-stop takes out 60 Hz");
                tc.verifyGreaterThan(gain(SignalFilter.apply(x6, tc.Fs, f), x6), keeps, d + " band-stop keeps 6 Hz");
                f.type = "lowpass"; f.cutoff = 20;
                tc.verifyGreaterThan(gain(SignalFilter.apply(x6, tc.Fs, f), x6), keeps, d + " low-pass keeps 6 Hz");
                tc.verifyLessThan(gain(SignalFilter.apply(x60, tc.Fs, f), x60), 0.05, d + " low-pass takes out 60 Hz");
                f.type = "highpass"; f.cutoff = 20;
                tc.verifyLessThan(gain(SignalFilter.apply(x1, tc.Fs, f), x1), 0.05, d + " high-pass takes out 1 Hz");
                tc.verifyGreaterThan(gain(SignalFilter.apply(x60, tc.Fs, f), x60), keeps, d + " high-pass keeps 60 Hz");
            end
        end

        function chainsBridgesAndRefuses(tc)
            [t, x6, x40] = tc.sines();
            x60 = sin(2 * pi * 60 * t);
            band = SignalFilter.preset("theta");
            notch = SignalFilter.preset("notch60");
            Y = SignalFilter.apply(x6 + x60, tc.Fs, [notch band]);
            tc.verifyEqual(Y, SignalFilter.apply(SignalFilter.apply(x6 + x60, tc.Fs, notch), tc.Fs, band), 'AbsTol', 1e-12, ...
                'A chain: each filter in order.');
            off = band; off.enabled = false;
            tc.verifyEqual(SignalFilter.apply(x40, tc.Fs, off), x40, 'Off: the signal as it is.');
            x = x6 + x40;
            x(3000:3100) = NaN;
            y = SignalFilter.apply(x, tc.Fs, band);
            tc.verifyTrue(all(isnan(y(3000:3100))) && all(isfinite(y([1:2999 3101:end]))), ...
                'A NaN run is bridged for the filter and put back: the rest stays finite.');
            tc.verifyError(@() SignalFilter.apply(x6, 250, SignalFilter.preset("highGamma")), 'SignalFilter:Unusable');
            tc.verifyError(@() SignalFilter.apply(x6(1:20), tc.Fs, band), 'SignalFilter:Unusable', 'Too short for filtfilt.');
            fir = band; fir.design = "fir"; fir.order = 500;
            tc.verifyError(@() SignalFilter.apply(x6(1:400), tc.Fs, fir), 'SignalFilter:Unusable', 'Shorter than an FIR''s order.');
        end

        function responseAsApplied(tc)
            f = SignalFilter.preset("theta");
            [H, Heff] = SignalFilter.response(f, tc.Fs, [4 6 8 40]);
            tc.verifyEqual(abs(H(1)), 1 / sqrt(2), 'AbsTol', 1e-6, 'A Butterworth: -3 dB at its cutoff for one pass.');
            tc.verifyEqual(Heff, complex(abs(H) .^ 2), 'AbsTol', 1e-12, 'Zero-phase IIR: the gain squared, no phase.');
            tc.verifyEqual(abs(Heff(2)), 1, 'AbsTol', 0.01);
            tc.verifyLessThan(abs(Heff(4)), 1e-4);
            c = f; c.phase = "causal";
            [H2, Heff2] = SignalFilter.response(c, tc.Fs, [4 6 8 40]);
            tc.verifyEqual(Heff2, H2, 'Causal: as one pass.');
            [~, Hs] = SignalFilter.response(f, tc.Fs, 6);
            tc.verifySize(Hs, [1 1], 'One frequency.');
            [h, t] = SignalFilter.impulse(f, tc.Fs);
            tc.verifyEqual(h, flipud(h), 'AbsTol', 1e-9, 'Zero-phase: symmetric about the impulse.');
            tc.verifyEqual(t(ceil(end / 2)), 0);
            [h, t] = SignalFilter.impulse(c, tc.Fs);
            tc.verifyEqual(max(abs(h(t < 0))), 0, 'Causal: nothing before the impulse.');
        end

        function keepsYourFilters(tc)
            restore = AppPrefs.useTemporary(); %#ok<NASGU>
            tc.verifyEmpty(SignalFilter.saved());
            f = SignalFilter.preset("theta");
            f.cutoff = [6 10];
            SignalFilter.save("Rat theta", f);
            g = SignalFilter.preset("highGamma");
            g.phase = "causal";
            SignalFilter.save("Gamma causal", g);
            S = SignalFilter.saved();
            tc.verifyEqual([S.name], ["Rat theta" "Gamma causal"], 'In the order saved.');
            tc.verifyEqual(S(1).filter.cutoff, [6 10]);
            tc.verifyEqual(S(1).filter.name, "Rat theta", 'Named by its name.');
            tc.verifyTrue(S(1).filter.enabled);
            f.cutoff = [5 9];
            SignalFilter.save("rat THETA", f);
            S = SignalFilter.saved();
            tc.verifyEqual([S.name], ["rat THETA" "Gamma causal"], 'The same name, any case: replaced in place.');
            tc.verifyEqual(SignalFilter.find("Rat Theta").cutoff, [5 9]);
            SignalFilter.save("Theta", g);
            tc.verifyEqual(SignalFilter.find("theta").phase, "causal", 'Yours before a preset of the name.');
            tc.verifyEqual(SignalFilter.find("beta").cutoff, [13 30], 'Else the preset.');
            tc.verifyEmpty(SignalFilter.find("kappa"));
            SignalFilter.remove("THETA");
            SignalFilter.remove("nothing");
            tc.verifyEqual([SignalFilter.saved().name], ["rat THETA" "Gamma causal"]);
            tc.verifyError(@() SignalFilter.save("  ", f), 'SignalFilter:BadName');
            f.cutoff = [9 5];
            tc.verifyError(@() SignalFilter.save("Bad", f), 'SignalFilter:BadFilter');
            SignalFilter.remove("rat theta");
            SignalFilter.remove("Gamma causal");
            tc.verifyEmpty(SignalFilter.saved());
            tc.verifyFalse(AppPrefs.ispref(SignalFilter.PrefGroup, "Saved"), 'None left: the preference goes.');
        end
    end

    methods
        function xb = bandNoise(tc)
            %bandNoise  20 s of theta-band (4-8 Hz) noise at Fs, the same every run.
            s = RandStream('mt19937ar', 'Seed', 7);
            xb = SignalFilter.apply(randn(s, 20 * tc.Fs, 1), tc.Fs, SignalFilter.preset("theta"));
        end

        function [t, x6, x40, x1] = sines(tc)
            %sines  20 s at Fs: unit sines at 6, 40 and 1 Hz (columns).
            t = (0:20 * tc.Fs - 1).' / tc.Fs;
            x6 = sin(2 * pi * 6 * t);
            x40 = sin(2 * pi * 40 * t);
            x1 = sin(2 * pi * 1 * t);
        end
    end
end


function lag = lagOf(y, x, fs)
%lagOf  The lag (s) of Y behind X, by their cross-correlation over the middle of the record (within +-0.5 s).
n = numel(x);
mid = round(n / 4):round(3 * n / 4);
best = -Inf;
lag = NaN;
for k = -round(0.5 * fs):round(0.5 * fs)
    c = sum(y(mid + k) .* x(mid));
    if c > best
        best = c;
        lag = k / fs;
    end
end
end
