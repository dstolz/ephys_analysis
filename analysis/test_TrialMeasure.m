classdef test_TrialMeasure < matlab.unittest.TestCase
    %test_TrialMeasure  trialMeasure (delay, duration, count, param), trialGrouping, trialStats and the trial panels' compute on a hand-built dataset.
    %   No fixture: a dataset struct built here (fs 1000 Hz; six 2-s trials
    %   at 1, 5, 9, ... s on the InTrial line; Stim 0.5 s into each;
    %   Platform intervals that end in, between and after the trials;
    %   Trough pokes in the trials, one on the first low row after a
    %   trial's end, one between trials; an empty Commutator line; the
    %   trial columns PairingFlag, Depth, TrialType, RespLatency (NaN on two
    %   trials) and a text TrialName), shaped as loadAnalysisSource's.
    %   trialMeasure: a delay "after" with which "first" equals stopTimes
    %   (and so eventLatency) in trial and recording scope, also with
    %   "nth", "last", an offsetParam shift and a sequence; the hand
    %   values; "before" negative with the A events lacking a B counted;
    %   maxGapSec drops counted; which "all" and "nth"; durations (Stim,
    %   "Trial", every Platform interval); counts with the trial-end cut
    %   (closed at TrialOffset + 1/fs, half-open at the gap) in both scopes
    %   and on a line with no event; param (NaN counted, the mask, a text
    %   column BadParam, a missing one NoParam); ms against s; the labels;
    %   NoValues. trialGrouping: the figure's groups, a parameter's values,
    %   n bins, edges, a text parameter, layers and sessions. trialStats
    %   against ranksum, kruskalwallis, ttest2, anova1 and pAdjust called
    %   directly, the stars, "first" pairs, mean and median with
    %   errorBounds, n < 2 and test "none" NaN; the fits (polyfit on
    %   y = 2x + 1: r2 = 1, Pearson r = 1; movmean; Spearman on a monotone
    %   curve = 1; a log scale in log10 units). computeTrialPanel on a
    %   hand-made panel: the R contract, the statistics shared by the
    %   layers, a missing line and a bad selection skipped, a scatter's
    %   pairing. The tests and fits need the Statistics and Machine
    %   Learning Toolbox.
    %
    %   Usage:  runtests("test_TrialMeasure")

    properties (Constant)
        Fs = 1000
    end

    properties
        hand   % the hand-built dataset (dataset())
    end

    methods (TestClassSetup)
        function paths(tc)
            here = fileparts(mfilename('fullpath'));
            addpath(here);
            addpath(fullfile(fileparts(here), 'pipeline'));
            tc.hand = test_TrialMeasure.dataset();
        end
    end

    methods (Static)
        function src = dataset()
            % six trials [1 3], [5 7], ... on InTrial; times on the 1 kHz grid
            fs = test_TrialMeasure.Fs;
            on = (1:4:21).';
            off = on + 2;
            ev = struct();
            ev.InTrial = [on off];
            ev.Stim = [on + 0.5, on + 0.7];
            ev.Platform = [0 1.9; 2.2 6.1; 6.5 9.8; 10.2 13.2; 13.3 14.6; 14.9 20.0; 20.5 30];
            ev.Trough = [1.8 1.9; 2.1 2.2; 2.5 2.6; 5.9 6.0; 13.6 13.7; 14.0 14.1; 15 + 1 / fs, 15.05; 15.4 15.45; ...
                16 16.1; 17.6 17.7; 22 22.1; 23.5 23.6];
            ev.Commutator = zeros(0, 2);
            lines = string(fieldnames(ev)).';
            n = numel(on);
            TE = repmat(cell2struct(cell(numel(lines), 1), cellstr(lines), 1), n, 1);
            for k = 1:n
                for ln = lines
                    iv = ev.(ln);
                    TE(k).(ln) = iv(iv(:, 1) <= off(k) + 1 / fs & iv(:, 2) >= on(k), :);
                end
            end
            T = table(on, off, TE, repmat("ok", n, 1), [0.25 0.5 1 0.25 0.5 1].', [0 0 1 0 1 0].', ...
                [250 NaN 400 300 NaN 500].', ["a" "b" "a" "c" "b" "a"].', ...
                'VariableNames', {'TrialOnset', 'TrialOffset', 'TrialEvents', 'PairingFlag', 'Depth', 'TrialType', 'RespLatency', 'TrialName'});
            src = struct('name', "hand", 'key', "hand", 'fs', fs, 'durationSec', 40, 'events', ev, ...
                'invertedLines', string.empty(1, 0), 'hasBehavior', true, 'hasTrials', true, 'nTrials', n, 'trials', T, ...
                'paramNames', ["Depth" "RespLatency" "TrialName" "TrialType"], 'respField', "", 'trialLine', "InTrial", ...
                'signals', struct(), 'probe', []);
        end

        function m = measure(opts)
            % a complete TrialMeasure (as EphysAnalysisConfig.defaults("TrialMeasure") has it)
            arguments
                opts.kind (1,1) string = "delay"
                opts.from = eventRef(line="Stim")
                opts.to = eventRef(line="Platform", edge="offset")
                opts.direction (1,1) string = "after"
                opts.maxGapSec (1,1) double = Inf
                opts.param (1,1) string = ""
                opts.unit (1,1) string = "ms"
                opts.label (1,1) string = ""
            end
            m = struct('kind', opts.kind, 'from', eventRef(opts.from), 'to', eventRef(opts.to), 'direction', opts.direction, ...
                'maxGapSec', opts.maxGapSec, 'param', opts.param, 'unit', opts.unit, 'label', opts.label);
        end

        function p = panel(type, layers, opts)
            % a trial panel as figureFor gives it, with the options trialPanelStats reads
            o = struct('categories', "groups", 'categoryParam', "", 'categoryBins', [], 'series', "layer", ...
                'seriesParam', "", 'seriesBins', [], 'display', "swarm", 'summary', "mean", 'errorType', "sem", ...
                'errorResamples', 1000, 'test', "auto", 'testPairs', "all", 'adjust', "holm", 'testAlpha', 0.05, 'alpha', 0.5, ...
                'fit', "none", 'fitWindow', 10, 'corr', "pearson", 'xScale', "linear", 'yScale', "linear");
            for f = string(fieldnames(opts)).'
                o.(f) = opts.(f);
            end
            p = struct('id', "p1", 'type', type, 'options', o, 'layers', layers);
        end

        function L = layer(m, xm, name)
            if nargin < 2 || isempty(xm); xm = test_TrialMeasure.measure(kind="delay", from=eventRef(line="Trial"), to=eventRef(line="Stim")); end
            if nargin < 3; name = ""; end
            L = struct('name', name, 'source', "trials", 'binding', "fixed", 'enabled', true, 'measure', m, 'xMeasure', xm);
        end

        function ctx = context(sel)
            if nargin < 1; sel = trialSelection(); end
            ctx = struct('check', [], 'checkpoint', @() [], 'selection', sel, 'skips', string.empty(1, 0));
        end
    end

    methods (Test)
        % ---------------------------------------------------------------- delay
        function delayAfterFirstIsStopTimes(tc)
            src = tc.hand;
            [T, info] = trialMeasure(src, tc.measure());
            tc.verifyEqual(string(T.Properties.VariableNames), ["trial" "value" "tA" "tB" "k"]);
            tc.verifyEqual(T.trial, (1:6).');
            tc.verifyEqual(T.value, [400 600 300 1100 2500 8500].', 'AbsTol', 1e-9, 'the first Platform offset after each Stim onset, in its trial');
            tc.verifyEqual(T.tB, stopTimes(src, eventRef(line="Platform", edge="offset"), T.tA, T.trial), 'AbsTol', 1e-12);
            tc.verifyEqual([info.nA info.nNoB info.nNoValue], [6 0 0]);
            tc.verifyEqual(info.kind, "delay");
            tc.verifyEqual(info.unit, "ms");
            % the invariant on other references: which, scope, a shift, a sequence
            refs = {eventRef(line="Platform", edge="offset", which="last"), ...
                eventRef(line="Platform", edge="offset", which="nth", n=2), ...
                eventRef(line="Platform", edge="offset", scope="recording"), ...
                eventRef(line="Platform", edge="offset", scope="recording", which="nth", n=3), ...
                eventRef(line="Trough", offsetParam="RespLatency"), ...
                eventRef(line="Trough", scope="recording", offsetSec=0.01), ...
                eventRef(line="Platform", edge="offset", sequence=struct('line', "Trough", 'maxGapSec', 1), alignStep=0), ...
                eventRef(line="Platform", edge="offset", scope="recording", sequence=struct('line', "Trough", 'maxGapSec', 1))};
            for i = 1:numel(refs)
                to = refs{i};
                tA = src.trials.TrialOnset + 0.5;
                want = stopTimes(src, to, tA, (1:6).');
                try
                    Ti = trialMeasure(src, tc.measure(to=to));
                catch ME
                    tc.verifyEqual(ME.identifier, 'trialMeasure:NoValues');
                    tc.verifyTrue(all(isnan(want)), sprintf('reference %d: no value only where stopTimes has none', i));
                    continue
                end
                got = NaN(6, 1);
                got(Ti.trial) = Ti.tB;
                tc.verifyEqual(got, want, 'AbsTol', 1e-12, sprintf('reference %d (%s, which %s): tB == stopTimes', i, eventRefLabel(to), to.which));
            end
        end

        function delayBefore(tc)
            [T, info] = trialMeasure(tc.hand, tc.measure(direction="before"));
            tc.verifyTrue(all(T.value < 0), 'before: negative values');
            tc.verifyEqual(T.trial, 4);
            tc.verifyEqual(T.value, -300, 'AbsTol', 1e-9, 'trial 4: the Platform offset at 13.2 s, 0.3 s before the Stim onset');
            tc.verifyEqual(info.nNoB, 5, 'the A events without a Platform offset before them in their trial');
            Tr = trialMeasure(tc.hand, tc.measure(direction="before", to=eventRef(line="Platform", edge="offset", scope="recording")));
            tc.verifyEqual(Tr.trial, (2:6).');
            tc.verifyEqual(Tr.value, ([1.9 6.1 13.2 14.6 20.0].' - [5.5 9.5 13.5 17.5 21.5].') * 1000, 'AbsTol', 1e-9, ...
                'recording scope: the nearest offset before, over the recording');
            Tl = trialMeasure(tc.hand, tc.measure(direction="before", to=eventRef(line="Platform", edge="offset", scope="recording", which="last")));
            tc.verifyEqual(Tl.value, (1.9 - [5.5 9.5 13.5 17.5 21.5].') * 1000, 'AbsTol', 1e-9, 'before + last: the farthest one');
        end

        function maxGapDrops(tc)
            [T, info] = trialMeasure(tc.hand, tc.measure(maxGapSec=1));
            tc.verifyEqual(T.trial, (1:3).');
            tc.verifyEqual(info.nNoB, 3, 'the delays of 1.1, 2.5 and 8.5 s are dropped and counted');
            tc.verifyError(@() trialMeasure(tc.hand, tc.measure(maxGapSec=0.1)), 'trialMeasure:NoValues');
        end

        function whichAllAndNth(tc)
            T = trialMeasure(tc.hand, tc.measure(to=eventRef(line="Platform", edge="offset", which="all")));
            tc.verifyEqual(T.trial, [1 1 2 2 3 3 4 4 5 6].');
            tc.verifyEqual(T.value, [400 4600 600 4300 300 3700 1100 6500 2500 8500].', 'AbsTol', 1e-9, 'which all: every offset after A in its trial, nearest first');
            [Tn, info] = trialMeasure(tc.hand, tc.measure(to=eventRef(line="Platform", edge="offset", which="nth", n=2)));
            tc.verifyEqual(Tn.trial, (1:4).');
            tc.verifyEqual(Tn.value, [4600 4300 3700 6500].', 'AbsTol', 1e-9);
            tc.verifyEqual(info.nNoB, 2, 'trials 5 and 6 have one offset after A');
            Tl = trialMeasure(tc.hand, tc.measure(to=eventRef(line="Platform", edge="offset", which="last")));
            tc.verifyEqual(Tl.value, [4600 4300 3700 6500 2500 8500].', 'AbsTol', 1e-9);
        end

        function eventsNearOrder(tc)
            src = tc.hand;
            ref = eventRef(line="Trough", which="all");
            C = eventsNear(src, ref, 13.5, 4, "after");
            tc.verifyEqual(C{1}, [13.6; 14.0; 15 + 1 / tc.Fs], 'AbsTol', 1e-12, 'trial scope: the trial''s own pokes, ascending (the one between trials is not in it)');
            C = eventsNear(src, eventRef(line="Trough", scope="recording"), 13.5, 4, "before");
            tc.verifyEqual(C{1}, [5.9; 2.5; 2.1; 1.8], 'AbsTol', 1e-12, 'recording scope, before: descending');
            C = eventsNear(src, eventRef(line="Trough", scope="recording"), [13.5; 2], [4; 1], "after", Count=2);
            tc.verifyEqual(C, {[13.6; 14.0]; [2.1; 2.5]}, 'AbsTol', 1e-12, 'Count keeps the nearest');
        end

        % ---------------------------------------------------------------- duration, count, param
        function durations(tc)
            [T, info] = trialMeasure(tc.hand, tc.measure(kind="duration"));
            tc.verifyEqual(T.value, repmat(200, 6, 1), 'AbsTol', 1e-9, 'Stim lasts 0.2 s');
            tc.verifyTrue(all(isnan(T.tB)));
            tc.verifyEqual(info.unit, "ms");
            T = trialMeasure(tc.hand, tc.measure(kind="duration", from=eventRef(line="Trial"), unit="s"));
            tc.verifyEqual(T.value, repmat(2, 6, 1), 'AbsTol', 1e-9, '"Trial": the trial itself');
            T = trialMeasure(tc.hand, tc.measure(kind="duration", from=eventRef(line="Platform", which="all")));
            tc.verifyEqual(T.trial, [1 2 3 4 4].');
            tc.verifyEqual(T.value, [3900 3300 3000 1300 5100].', 'AbsTol', 1e-9, 'every Platform interval whose onset a trial holds');
        end

        function counts(tc)
            to = eventRef(line="Trough");
            [T, info] = trialMeasure(tc.hand, tc.measure(kind="count", to=to));
            tc.verifyEqual(T.value, [3 1 0 3 1 1].', 'trial scope: the pokes after Stim onset up to the trial''s end (TrialOffset + 1/fs included)');
            tc.verifyEqual(info.unit, "");
            tc.verifyEqual(T.tB(1), 1.8, 'AbsTol', 1e-12, 'tB: the first B counted');
            tc.verifyTrue(isnan(T.tB(3)));
            Tr = trialMeasure(tc.hand, tc.measure(kind="count", to=eventRef(line="Trough", scope="recording")));
            tc.verifyEqual(Tr.value, [3 1 0 3 1 1].', 'recording scope: the pokes between trials are cut at the trial''s end');
            Tg = trialMeasure(tc.hand, tc.measure(kind="count", to=to, maxGapSec=0.5));
            tc.verifyEqual(Tg.value, [1 1 0 1 1 0].', 'the window [tA, tA + maxGapSec) is half-open');
            Tz = trialMeasure(tc.hand, tc.measure(kind="count", to=eventRef(line="Commutator")));
            tc.verifyEqual(Tz.value, zeros(6, 1), 'a line with no event counts 0');
            T2 = trialMeasure(tc.hand, tc.measure(kind="count", to=to), logical([1 0 0 1 0 0]).');
            tc.verifyEqual([T2.trial T2.value], [1 3; 4 3], 'the mask keeps its trials');
        end

        function params(tc)
            [T, info] = trialMeasure(tc.hand, tc.measure(kind="param", param="RespLatency"));
            tc.verifyEqual(T.trial, [1 3 4 6].');
            tc.verifyEqual(T.value, [250 400 300 500].');
            tc.verifyEqual(T.tA, tc.hand.trials.TrialOnset([1 3 4 6]));
            tc.verifyEqual([info.nA info.nNoValue], [6 2], 'the NaN values are left out and counted');
            tc.verifyEqual(info.unit, "");
            T = trialMeasure(tc.hand, tc.measure(kind="param", param="Depth"), logical([0 1 1 0 0 0]).');
            tc.verifyEqual(T.value, [0.5; 1]);
            tc.verifyError(@() trialMeasure(tc.hand, tc.measure(kind="param", param="TrialName")), 'trialMeasure:BadParam');
            tc.verifyError(@() trialMeasure(tc.hand, tc.measure(kind="param", param="Nope")), 'trialMeasure:NoParam');
            tc.verifyError(@() trialMeasure(tc.hand, tc.measure(kind="param")), 'trialMeasure:NoParam');
            s2 = tc.hand; s2.hasTrials = false;
            tc.verifyError(@() trialMeasure(s2, tc.measure(kind="param", param="Depth")), 'trialMeasure:NoParam');
            tc.verifyError(@() trialMeasure(tc.hand, tc.measure(from=eventRef(line="Nope"))), 'resolveEvents:NoLine');
        end

        function units(tc)
            Tms = trialMeasure(tc.hand, tc.measure());
            [Ts, info] = trialMeasure(tc.hand, tc.measure(unit="s"));
            tc.verifyEqual(Ts.value * 1000, Tms.value, 'AbsTol', 1e-9);
            tc.verifyEqual(Ts.tA, Tms.tA, 'tA and tB stay in s');
            tc.verifyEqual(info.unit, "s");
        end

        function labels(tc)
            arrow = char(8594);
            [~, a] = trialMeasure(tc.hand, tc.measure());
            tc.verifyEqual(a.label, "Stim onset " + arrow + " Platform offset (ms)");
            [~, b] = trialMeasure(tc.hand, tc.measure(direction="before", to=eventRef(line="Platform", edge="offset", scope="recording")));
            tc.verifyEqual(b.label, "Platform offset before Stim onset (ms)");
            [~, c] = trialMeasure(tc.hand, tc.measure(kind="duration", from=eventRef(line="Platform", which="all")));
            tc.verifyEqual(c.label, "Platform duration (ms)");
            [~, d] = trialMeasure(tc.hand, tc.measure(kind="count", to=eventRef(line="Trough")));
            tc.verifyEqual(d.label, "Trough onsets after Stim onset");
            [~, e] = trialMeasure(tc.hand, tc.measure(kind="param", param="RespLatency"));
            tc.verifyEqual(e.label, "RespLatency");
            [~, f] = trialMeasure(tc.hand, tc.measure(label="Time to leave"));
            tc.verifyEqual(f.label, "Time to leave", 'a label set is used as given');
            [~, g] = trialMeasure(tc.hand, tc.measure(to=eventRef(line="Platform", edge="offset", which="last")));
            tc.verifyEqual(g.label, "Stim onset " + arrow + " last Platform offset (ms)");
        end

        % ---------------------------------------------------------------- grouping
        function grouping(tc)
            src = tc.hand;
            [mask, G, gi] = selectTrials(src, trialSelection(groupBy="TrialType"));
            T = trialMeasure(src, tc.measure(), mask);
            V = [T table(gi(T.trial), ones(height(T), 1), repmat(1, height(T), 1), src.trials.Depth(T.trial), src.trials.TrialName(T.trial), ...
                'VariableNames', {'group', 'session', 'layer', 'Depth', 'TrialName'})]; %#ok<REPMAT>
            [idx, Gg] = trialGrouping("groups", src, V, G);
            tc.verifyEqual(idx, gi(T.trial));
            tc.verifyEqual(Gg.label, G.label);
            tc.verifyEqual(Gg.n, [4; 2], 'n: the values in each group');
            [idx, Gp] = trialGrouping("param", src, V, G, Param="Depth");
            tc.verifyEqual(Gp.label, ["Depth = 0.25"; "Depth = 0.5"; "Depth = 1"]);
            tc.verifyEqual(Gp.value, [0.25; 0.5; 1]);
            tc.verifyEqual(idx, [1 2 3 1 2 3].');
            tc.verifyTrue(isOrdinalGroups(Gp), 'three values of a number: ordered colors');
            [idx2, Gq] = trialGrouping("param", src, removevars(V, 'Depth'), G, Param="Depth");
            tc.verifyEqual(idx2, idx, 'a column the values lack is read from the trials');
            tc.verifyEqual(Gq.label, Gp.label);
            [idx, Gb] = trialGrouping("param", src, V, G, Param="Depth", Bins=3);
            tc.verifyEqual(height(Gb), 3);
            tc.verifyEqual(idx, discretize(V.Depth, linspace(0.25, 1, 4)), 'n bins: equal width over the range, the maximum in the last');
            tc.verifyEqual(Gb.n, [2; 2; 2]);
            tc.verifyEqual(Gb.label(1), "Depth 0.25" + char(8211) + "0.5");
            [idx, Ge] = trialGrouping("param", src, V, G, Param="Depth", Bins=[0 0.3 0.6]);
            tc.verifyEqual(idx, [1 2 0 1 2 0].', 'edges: the values outside are left out');
            tc.verifyEqual(height(Ge), 2);
            [idx, Gt] = trialGrouping("param", src, V, G, Param="TrialName");
            tc.verifyEqual(Gt.label, ["TrialName = a"; "TrialName = b"; "TrialName = c"]);
            tc.verifyEqual(idx, [1 2 1 3 2 1].');
            tc.verifyError(@() trialGrouping("param", src, V, G, Param="TrialName", Bins=2), 'trialMeasure:BadParam');
            tc.verifyError(@() trialGrouping("param", src, V, G, Param="Nope"), 'trialMeasure:NoParam');
            V.layer = [1 1 3 3 1 3].';
            [idx, Gl] = trialGrouping("layer", src, V, G, Layers=["first" "" "third"]);
            tc.verifyEqual(Gl.label, ["first"; "third"]);
            tc.verifyEqual(idx, [1 1 2 2 1 2].');
            V.session = [1 2 1 2 1 2].';
            V.sessionKey = repmat("s1", 6, 1); V.sessionKey(V.session == 2) = "s2";
            [idx, Gs] = trialGrouping("session", src, V, G);
            tc.verifyEqual(Gs.label, ["s1"; "s2"]);
            tc.verifyEqual(idx, V.session);
            [~, Gn] = trialGrouping("none", src, V, G);
            tc.verifyEqual(Gn.label, "all");
            tc.verifyEqual(Gn.n, 6);
        end

        % ---------------------------------------------------------------- statistics
        function testsAgainstToolbox(tc)
            tc.assumeTrue(license('test', 'Statistics_Toolbox') == 1, 'needs the Statistics and Machine Learning Toolbox');
            rng(3);
            y = [randn(10, 1); randn(12, 1) + 1; randn(8, 1) + 0.5];
            cat = [ones(10, 1); 2 * ones(12, 1); 3 * ones(8, 1)];
            V = table(y, 'VariableNames', {'value'});
            S = trialStats(V, cat, ones(30, 1));
            tc.verifyEqual(S.test.name, "kruskalwallis");
            tc.verifyEqual(S.test.label, "Kruskal-Wallis");
            tc.verifyEqual(S.test.p, kruskalwallis(y, cat, 'off'), 'AbsTol', 1e-12);
            tc.verifyEqual(S.test.across, "categories");
            tc.verifyEqual(height(S.pairs), 3);
            p = [ranksum(y(cat == 1), y(cat == 2)); ranksum(y(cat == 1), y(cat == 3)); ranksum(y(cat == 2), y(cat == 3))];
            tc.verifyEqual([S.pairs.a S.pairs.b], [1 2; 1 3; 2 3]);
            tc.verifyEqual(S.pairs.p, p, 'AbsTol', 1e-12);
            tc.verifyEqual(S.pairs.pAdj, pAdjust(p, "holm"), 'AbsTol', 1e-12, 'Holm over the series'' pairs');
            stars = repmat("n.s.", 3, 1);
            q = S.pairs.pAdj;
            stars(q < 0.05) = "*"; stars(q < 0.01) = "**"; stars(q < 0.001) = "***";
            tc.verifyEqual(S.pairs.stars, stars);
            tc.verifyEqual(S.pairs.sig, q < 0.05);
            % two categories: auto = ranksum, and the pair is the same test
            S2 = trialStats(V(cat < 3, :), cat(cat < 3), ones(22, 1));
            tc.verifyEqual(S2.test.name, "ranksum");
            tc.verifyEqual(S2.test.p, p(1), 'AbsTol', 1e-12);
            % parametric choices
            St = trialStats(V(cat < 3, :), cat(cat < 3), ones(22, 1), Test="ttest2");
            [~, pt] = ttest2(y(cat == 1), y(cat == 2));
            tc.verifyEqual(St.test.p, pt, 'AbsTol', 1e-12);
            tc.verifyEqual(St.pairs.test, "ttest2");
            Sa = trialStats(V, cat, ones(30, 1), Test="anova1");
            tc.verifyEqual(Sa.test.p, anova1(y, cat, 'off'), 'AbsTol', 1e-12);
            tc.verifyEqual(numel(Sa.test.df), 2);
            % first: each vs level 1; bonferroni
            Sf = trialStats(V, cat, ones(30, 1), TestPairs="first", Adjust="bonferroni");
            tc.verifyEqual([Sf.pairs.a Sf.pairs.b], [1 2; 1 3]);
            tc.verifyEqual(Sf.pairs.pAdj, min(1, 2 * p(1:2)), 'AbsTol', 1e-12);
            % two series, two categories: a test per series; one category: across series
            ser = repmat([1; 2], 15, 1);
            Ss = trialStats(V, cat, ser);
            tc.verifyEqual([Ss.test.per], [1 2]);
            tc.verifyEqual(Ss.test(2).p, kruskalwallis(y(ser == 2), cat(ser == 2), 'off'), 'AbsTol', 1e-12);
            tc.verifyEqual(unique(Ss.pairs.per).', [1 2]);
            r1 = Ss.pairs.per == 1;
            tc.verifyEqual(Ss.pairs.pAdj(r1), pAdjust(Ss.pairs.p(r1), "holm"), 'AbsTol', 1e-12, 'adjusted per series');
            S1 = trialStats(V, ones(30, 1), cat);
            tc.verifyEqual(S1.test.across, "series");
            tc.verifyEqual(S1.test.p, kruskalwallis(y, cat, 'off'), 'AbsTol', 1e-12);
        end

        function summaries(tc)
            tc.assumeTrue(license('test', 'Statistics_Toolbox') == 1, 'needs the Statistics and Machine Learning Toolbox');
            rng(4);
            y = [randn(10, 1); randn(6, 1) + 2; 5];
            cat = [ones(10, 1); 2 * ones(6, 1); 3];
            V = table(y, 'VariableNames', {'value'});
            S = trialStats(V, cat, ones(17, 1), ErrorType="sem");
            tc.verifyEqual(S.table.n, [10; 6; 1]);
            tc.verifyEqual(S.table.center(1), mean(y(1:10)), 'AbsTol', 1e-12);
            [lo, hi] = errorBounds(y(1:10), 1, "sem", 1000, "mean");
            tc.verifyEqual([S.table.lo(1) S.table.hi(1)], [lo hi], 'AbsTol', 1e-12);
            tc.verifyTrue(isnan(S.table.lo(3)) && S.table.center(3) == 5, 'one value: a center, no band');
            Sm = trialStats(V, cat, ones(17, 1), Summary="median", ErrorType="ci95", ErrorResamples=200);
            [lo, hi] = errorBounds(y(11:16), 1, "ci95", 200, "median");
            tc.verifyEqual(Sm.table.center(2), median(y(11:16)), 'AbsTol', 1e-12);
            tc.verifyEqual([Sm.table.lo(2) Sm.table.hi(2)], [lo hi], 'AbsTol', 1e-12);
            q = prctile(y(1:10), [25 75]);
            tc.verifyEqual([S.table.q1(1) S.table.q3(1)], q(:).', 'AbsTol', 1e-12);
            tc.verifyEqual(S.test.levels, [1 2], 'a level with one value takes no part');
            tc.verifyTrue(all(isnan(S.pairs.p(S.pairs.b == 3))), 'pairs with a level of one value: NaN');
            tc.verifyTrue(all(S.pairs.stars(S.pairs.b == 3) == ""));
            Sn = trialStats(V, cat, ones(17, 1), Test="none");
            tc.verifyTrue(isnan(Sn.test.p) && all(isnan(Sn.pairs.p)), 'test none: NaN');
            So = trialStats(V(1:3, :), [1; 2; 2], ones(3, 1));
            tc.verifyTrue(isnan(So.test.p), 'fewer than two levels with two values: NaN, no error');
            Se = trialStats(V(1:0, :), zeros(0, 1), zeros(0, 1), NCategories=2, NSeries=1);
            tc.verifyEqual(Se.table.n, [0; 0]);
            Soff = trialStats(V, cat, ones(17, 1), ErrorType="off");
            tc.verifyTrue(all(isnan(Soff.table.lo)), 'errorType off: no band');
        end

        function fits(tc)
            tc.assumeTrue(license('test', 'Statistics_Toolbox') == 1, 'needs the Statistics and Machine Learning Toolbox');
            x = (1:20).';
            V = table(2 * x + 1, x, 'VariableNames', {'value', 'x'});
            one = ones(20, 1);
            S = trialStats(V, one, one, Fit="linear", Corr="pearson");
            tc.verifyEqual(S.fit.coef, [2 1], 'AbsTol', 1e-9);
            tc.verifyEqual(S.fit.r2, 1, 'AbsTol', 1e-12);
            tc.verifyEqual(numel(S.fit.xg), 100);
            tc.verifyEqual(S.fit.yg, 2 * S.fit.xg + 1, 'AbsTol', 1e-9);
            tc.verifyEqual(S.fit.lo, S.fit.yg, 'AbsTol', 1e-6, 'a perfect fit: no band');
            tc.verifyEqual(S.corr.r, 1, 'AbsTol', 1e-12);
            tc.verifyEqual(S.corr.n, 20);
            rng(5);
            yn = 2 * x + 1 + randn(20, 1);
            Vn = table(yn, x, 'VariableNames', {'value', 'x'});
            Sn = trialStats(Vn, one, one, Fit="poly2");
            mdl = fitlm(x, yn, 'poly2');
            [~, ci] = predict(mdl, Sn.fit.xg);
            tc.verifyEqual(Sn.fit.coef, polyfit(x, yn, 2), 'AbsTol', 1e-9);
            tc.verifyEqual([Sn.fit.lo Sn.fit.hi], ci, 'AbsTol', 1e-9, 'fitlm + predict: the 95% band of the curve');
            tc.verifyEqual(Sn.fit.r2, mdl.Rsquared.Ordinary, 'AbsTol', 1e-12);
            xs = x(randperm(20));
            Vm = table(xs .^ 2, xs, 'VariableNames', {'value', 'x'});
            Sm = trialStats(Vm, one, one, Fit="movmean", FitWindow=4, Corr="spearman");
            tc.verifyEqual(Sm.fit.xg, x);
            tc.verifyEqual(Sm.fit.yg, movmean(x .^ 2, 4), 'AbsTol', 1e-9, 'movmean over the x-sorted points');
            tc.verifyEqual(Sm.corr.r, 1, 'AbsTol', 1e-12, 'Spearman on a monotone curve');
            tc.verifyEqual(Sm.corr.type, "spearman");
            Sd = trialStats(Vm, one, one, Fit="movmedian", FitWindow=3);
            tc.verifyEqual(Sd.fit.yg, movmedian(x .^ 2, 3), 'AbsTol', 1e-9);
            % log scales: y = 10 x^2 is a line in log10 units; a value <= 0 is left out
            Vl = table([10 * x .^ 2; 5], [x; 0], 'VariableNames', {'value', 'x'});
            Sl = trialStats(Vl, ones(21, 1), ones(21, 1), Fit="linear", XScale="log", YScale="log", Corr="pearson");
            tc.verifyEqual(Sl.fit.coef, [2 1], 'AbsTol', 1e-9, 'fitted in log10 units');
            tc.verifyEqual(Sl.fit.r2, 1, 'AbsTol', 1e-9);
            tc.verifyEqual(Sl.fit.nLeftOut, 1);
            tc.verifyEqual(Sl.fit.yg, 10 * Sl.fit.xg .^ 2, 'RelTol', 1e-9, 'the curve in data units');
            tc.verifyEqual(Sl.corr.r, 1, 'AbsTol', 1e-12);
            % two series: one fit each; too few points: NaN, no error
            Vs = [V; table([1; 2], [1; 1], 'VariableNames', {'value', 'x'})];
            S2 = trialStats(Vs, ones(22, 1), [one; 2; 2], Fit="linear", Corr="pearson");
            tc.verifyEqual(numel(S2.fit), 2);
            tc.verifyTrue(isempty(S2.fit(2).coef) && isnan(S2.fit(2).r2) && isnan(S2.corr(2).r));
        end

        % ---------------------------------------------------------------- the panels' compute
        function computeDist(tc)
            tc.assumeTrue(license('test', 'Statistics_Toolbox') == 1, 'needs the Statistics and Machine Learning Toolbox');
            src = tc.hand;
            L = [tc.layer(tc.measure()), tc.layer(tc.measure(kind="param", param="RespLatency"), [], "latency"), ...
                tc.layer(tc.measure(to=eventRef(line="Nope")))];
            p = tc.panel("trialDist", L, struct('categories', "groups", 'series', "layer"));
            P = computeTrialDistPanel(src, p, [], [], tc.context(trialSelection(groupBy="TrialType")));
            tc.verifyEqual([P.layers.skip], ["" "" P.layers(3).skip]);
            tc.verifyTrue(contains(P.layers(3).skip, "Nope"), 'a line the dataset lacks: that layer is skipped');
            R = P.layers(1).R;
            fields = ["kind" "measure" "label" "unit" "xMeasure" "xLabel" "xUnit" "values" "groups" "groupIndex" "n" ...
                "drops" "options" "dataset" "params" "created" "categories" "series" "stats"];
            tc.verifyEqual(sort(string(fieldnames(R))), sort(fields(:)));
            tc.verifyEqual(R.kind, "trialDist");
            tc.verifyEqual(P.layers(1).name, R.label, 'the layer''s name defaults to the label');
            tc.verifyEqual(P.layers(2).name, "latency");
            cols = ["trial" "value" "x" "tA" "tB" "k" "group" "session" "sessionKey" "layer" "TrialType" "category" "series"];
            tc.verifyEqual(string(R.values.Properties.VariableNames), cols);
            [~, ~, gi] = selectTrials(src, trialSelection(groupBy="TrialType"));
            tc.verifyEqual(R.values.group, gi(R.values.trial));
            tc.verifyEqual(R.groupIndex, R.values.group);
            tc.verifyEqual(R.groups.n, [4; 2]);
            tc.verifyEqual(R.n, 6);
            tc.verifyEqual(R.drops, struct('nTrials', 6, 'nKept', 6, 'nA', 6, 'nNoB', 0, 'nNoValue', 0, 'xA', 0, 'xNoB', 0, ...
                'xNoValue', 0, 'nUnpaired', 0));
            tc.verifyEqual(P.layers(2).R.drops.nNoValue, 2);
            tc.verifyEqual(R.values.layer, ones(6, 1));
            tc.verifyEqual(P.layers(2).R.values.layer, 2 * ones(4, 1));
            tc.verifyEqual(R.categories.label, ["TrialType = 0"; "TrialType = 1"]);
            tc.verifyEqual(R.series.label, [P.layers(1).name; "latency"]);
            tc.verifyEqual(P.layers(2).R.stats, R.stats, 'the same statistics in every computed layer');
            v = R.values.value;
            tc.verifyEqual(R.stats.test(1).p, ranksum(v(R.values.TrialType == 0), v(R.values.TrialType == 1)), 'AbsTol', 1e-12, ...
                'categories = the trial groups: the test of the first series is ranksum across them');
            tc.verifyEqual(R.stats.table.n, [4; 2; 3; 1]);
        end

        function computeScatterAndSkips(tc)
            src = tc.hand;
            m = tc.measure(kind="param", param="RespLatency");
            xm = tc.measure();
            p = tc.panel("trialScatter", tc.layer(m, xm), struct('series', "groups", 'fit', "linear", 'corr', "pearson"));
            P = computeTrialScatterPanel(src, p, [], [], tc.context(trialSelection(groupBy="TrialType")));
            R = P.layers(1).R;
            tc.verifyEqual(R.values.trial, [1 3 4 6].');
            tc.verifyEqual(R.values.x, [400 300 1100 8500].', 'AbsTol', 1e-9, 'x: the delay of the same trial');
            tc.verifyEqual(R.values.value, [250 400 300 500].');
            tc.verifyEqual(R.drops.nUnpaired, 2, 'the two delays without a latency');
            tc.verifyEqual(R.xLabel, "Stim onset " + char(8594) + " Platform offset (ms)");
            tc.verifyEqual(P.layers(1).name, "RespLatency vs " + R.xLabel);
            tc.verifyEqual(R.series.label, ["TrialType = 0"; "TrialType = 1"]);
            tc.verifyEqual(numel(R.stats.fit), 2);
            tc.verifyEqual(height(R.categories), 1);
            % a selection that cannot be applied: every layer skipped with its message
            P = computeTrialDistPanel(src, tc.panel("trialDist", tc.layer(m), struct()), [], [], tc.context(trialSelection(groupBy="Nope")));
            tc.verifyTrue(contains(P.layers(1).skip, "Nope") && isempty(P.layers(1).R));
            % a disabled layer stays disabled; a hist has no categories
            L = [tc.layer(m) tc.layer(xm)];
            L(2).enabled = false;
            P = computeTrialHistPanel(src, tc.panel("trialHist", L, struct('series', "layer")), [], [], tc.context());
            tc.verifyEqual([P.layers.skip], ["" "disabled"]);
            tc.verifyEqual(P.layers(1).R.categories.label, "all");
            tc.verifyEmpty(P.layers(1).R.stats.fit);
            % no value at all: the layer is skipped with trialMeasure:NoValues' message
            P = computeTrialHistPanel(src, tc.panel("trialHist", tc.layer(tc.measure(maxGapSec=0.01)), struct()), [], [], tc.context());
            tc.verifyTrue(contains(P.layers(1).skip, "gives no value"));
        end
    end
end
