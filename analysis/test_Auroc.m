classdef test_Auroc < matlab.unittest.TestCase
    %test_Auroc  aurocCurves, aucOf and spikePSTH's BaselineMode "auroc".
    %   aucOf against counting every pair (ties half, NaN left out). The
    %   "psth" method against a port of the Caras lab's
    %   auROC_response_curve (Caraslab_EPhys_preprocessing_pipeline,
    %   auROC_analysis/calculate_auROC.py: the trial-averaged PSTH's bins,
    %   a criterion swept in 0.1 Hz steps, trapz), which the paper used.
    %   The "epochs" method against counting the pairs of epoch counts by
    %   hand. Tiled and sliding windows; the whole-bin rules and the errors;
    %   the stop mask; each cutoff (the 95% CI formula, fixed, none) and
    %   each test (bootstrap, ranksum, shuffle) on driven, suppressed and
    %   flat units, reproducible by seed; spikePSTH's auROC result, its
    %   modulatedOnly and its caption; renderPSTH and renderHeatmap tag
    %   what they add. Needs the Statistics and Machine Learning Toolbox
    %   (skipped without it, but for the NoToolbox error).
    %
    %   Usage:  runtests("test_Auroc")

    methods (TestClassSetup)
        function paths(tc) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            addpath(here);
            addpath(fullfile(fileparts(here), 'pipeline'));
        end
    end

    methods (Test)
        function noToolbox(tc)
            tc.assumeFalse(hasStats(), "the toolbox is installed");
            [st, E] = fixture();
            tc.verifyError(@() aurocCurves(st, E), 'aurocCurves:NoToolbox');
        end

        function aucCountsPairs(tc)
            tc.assumeTrue(hasStats(), "needs the Statistics and Machine Learning Toolbox");
            rs = RandStream('mt19937ar', 'Seed', 3);
            A = randi(rs, 5, 7, 4) - 1;
            B = randi(rs, 5, 11, 4) - 1;
            want = zeros(1, 4);
            for j = 1:4
                d = A(:, j) - B(:, j).';
                want(j) = mean(d > 0, 'all') + mean(d == 0, 'all') / 2;
            end
            tc.verifyEqual(aucOfShim(A, B), want, 'AbsTol', 1e-12, 'P(a > b) + P(a = b) / 2, column by column');
            tc.verifyEqual(aucOfShim(A, B(:, 1)), arrayfun(@(j) aucOfShim(A(:, j), B(:, 1)), 1:4), 'AbsTol', 1e-12, ...
                'one B column serves every A column');
            An = A; An(2, 3) = NaN;
            x = A([1 3:end], 3);
            d = x - B(:, 3).';
            tc.verifyEqual(aucOfShim(An(:, 3), B(:, 3)), mean(d > 0, 'all') + mean(d == 0, 'all') / 2, 'AbsTol', 1e-12, ...
                'NaN values are left out');
            tc.verifyEqual(aucOfShim([1; 2], [3; 4]), 0);
            tc.verifyEqual(aucOfShim([5; 6], [3; 4]), 1);
            tc.verifyEqual(aucOfShim([0; 0], [0; 0]), 0.5, 'all ties: chance');
            tc.verifyTrue(isnan(aucOfShim(NaN(2, 1), [1; 2])), 'no A value: NaN');
        end

        function psthMethodIsTheLabs(tc)
            tc.assumeTrue(hasStats(), "needs the Statistics and Machine Learning Toolbox");
            [st, E] = fixture(Pre=2);
            A = aurocCurves(st, E(E.groupIndex == 1, :), Window=[-2 5], Baseline=[-2 -1], BinSec=0.01, WindowSec=0.1, ...
                Cutoff="none");
            tc.verifySize(A.auroc, [70 3]);
            tc.verifyEqual(A.starts, (-2:0.1:4.9).', 'AbsTol', 1e-9, 'tiled 100 ms windows from the event');
            for u = 1:3
                ref = labCurve(st{u}, E.t0Continuous(E.groupIndex == 1), 2, 5, 2, 1);
                n = numel(ref) - 1;   % the lab's last window has 9 bins (np.arange leaves the last bin out)
                tc.verifyEqual(A.auroc(1:n, u), ref(1:n), 'AbsTol', 1e-9, sprintf('unit %d: the lab''s auROC curve', u));
            end
            tc.verifyEqual(A.direction, strings(3, 1), 'cutoff none: no call');
        end

        function epochsMethodCountsPairs(tc)
            tc.assumeTrue(hasStats(), "needs the Statistics and Machine Learning Toolbox");
            [st, E] = fixture();
            A = aurocCurves(st, E, Window=[-0.5 1], Baseline=[-0.5 0], Method="epochs", ModulationWindow=[0 0.3], Cutoff="none");
            ta = E.t0Continuous;
            for u = 1:3
                for g = 1:2
                    e = find(E.groupIndex == g);
                    base = zeros(5, numel(e));
                    for k = 1:5
                        base(k, :) = countIn(st{u}, ta(e), -0.5 + 0.1 * (k - 1), -0.4 + 0.1 * (k - 1));
                    end
                    w = 7;   % [0.1 0.2)
                    x = countIn(st{u}, ta(e), A.starts(w), A.stops(w));
                    d = x(:) - base(:).';
                    tc.verifyEqual(A.auroc(w, u, g), mean(d > 0, 'all') + mean(d == 0, 'all') / 2, 'AbsTol', 1e-12, ...
                        sprintf('unit %d group %d: each epoch''s count against every baseline piece', u, g));
                end
            end
            tc.verifyEqual(A.inModulation.', [false(1, 5) true(1, 3) false(1, 7)], 'the windows wholly inside [0 0.3]');
            tc.verifyEqual(A.mean, squeeze(mean(A.auroc(6:8, :, :), 1)), 'AbsTol', 1e-12);
            tc.verifyEqual(A.phasic, squeeze(mean(abs(A.auroc(6:8, :, :) - 0.5), 1)), 'AbsTol', 1e-12);
        end

        function windowsAndErrors(tc)
            tc.assumeTrue(hasStats(), "needs the Statistics and Machine Learning Toolbox");
            [st, E] = fixture();
            S = aurocCurves(st, E, Window=[-0.5 1], Baseline=[-0.5 0], Windows="sliding", StepSec=0.02, Cutoff="none");
            tc.verifyEqual(S.starts, (-0.5:0.02:0.9).', 'AbsTol', 1e-9, 'sliding: a window every step, wholly inside');
            tc.verifyEqual(S.t, S.starts + 0.05, 'AbsTol', 1e-12, 'its time is its centre');
            tc.verifyEqual(S.edges([1 2 end]), [-0.46 -0.44 0.96], 'AbsTol', 1e-9, 'bar edges half a step either side');
            T = aurocCurves(st, E, Window=[-0.55 1], Baseline=[-0.55 0], Cutoff="none");
            tc.verifyEqual(T.starts(1), -0.5, 'AbsTol', 1e-9, 'tiled windows are edged at whole multiples from the event');
            tc.verifyEqual(T.baseline, [-0.55 0], 'AbsTol', 1e-9);
            tc.verifyError(@() aurocCurves(st, E, WindowSec=0.015), 'aurocCurves:BadOption', 'a window of 1.5 bins');
            tc.verifyError(@() aurocCurves(st, E, Windows="sliding", StepSec=0.005), 'aurocCurves:BadOption', 'a step of half a bin');
            tc.verifyError(@() aurocCurves(st, E, Window=[0 0.05]), 'aurocCurves:BadWindow', 'no whole window fits');
            tc.verifyError(@() aurocCurves(st, E, Method="epochs", Baseline=[-0.05 0]), 'aurocCurves:BadBaseline', ...
                'epochs: a baseline shorter than a window');
            tc.verifyError(@() aurocCurves(st, E, ModulationWindow=[0.02 0.08]), 'aurocCurves:BadModulation', ...
                'a modulation window holding no whole window');
            tc.verifyError(@() aurocCurves(st, E, Cutoff="maybe"), 'aurocCurves:BadOption');
            tc.verifyError(@() aurocCurves(st, E, Cutoff="fixed", Threshold=0.5), 'aurocCurves:BadOption');
        end

        function maskAfterStop(tc)
            tc.assumeTrue(hasStats(), "needs the Statistics and Machine Learning Toolbox");
            [st, E] = fixture();
            E.t1 = E.t0 + 0.295;   % inside a bin: bins from 0.3 on start after it (a stop on a bin edge is at the mercy of rounding)
            A = aurocCurves(st, E, Window=[-0.5 1], Baseline=[-0.5 0], MaskAfterStop=true, Cutoff="none");
            tc.verifyTrue(all(isnan(A.auroc(A.starts >= 0.3, :, :)), 'all'), 'every bin after the stop is left out: NaN');
            tc.verifyTrue(all(isfinite(A.auroc(A.starts < 0.3, :, :)), 'all'));
            tc.verifyTrue(all(A.count(A.starts >= 0.3, :, :) == 0, 'all'), 'no spike counted after the stop');
            B = aurocCurves(st, E, Window=[-0.5 1], Baseline=[-0.5 0], MaskAfterStop=true, Method="epochs", Cutoff="none");
            tc.verifyTrue(all(isnan(B.auroc(B.starts >= 0.3, :, :)), 'all'), 'epochs: windows after the stop are NaN');
        end

        function cutoffs(tc)
            tc.assumeTrue(hasStats(), "needs the Statistics and Machine Learning Toolbox");
            [st, E] = fixture(Units=12);
            A = aurocCurves(st, E, Window=[-0.5 1], Baseline=[-0.5 0], ModulationWindow=[0 0.3]);
            v = A.phasic(:);
            c = mean(v) + tinv(0.975, numel(v) - 1) * std(v) / sqrt(numel(v));
            tc.verifyEqual(A.cutoffValue, c, 'AbsTol', 1e-12, 'ci: the upper 95% bound of the mean phasic modulation');
            tc.verifyEqual(A.direction == "increase", A.mean > 0.5 + c);
            tc.verifyEqual(A.direction == "decrease", A.mean < 0.5 - c);
            tc.verifyEqual(A.nIncrease, sum(A.direction == "increase", 1).');
            F = aurocCurves(st, E, Window=[-0.5 1], Baseline=[-0.5 0], ModulationWindow=[0 0.3], Cutoff="fixed", Threshold=0.2);
            tc.verifyEqual(F.modulated, abs(F.mean - 0.5) > 0.2);
            tc.verifyEqual(F.cutoffValue, 0.2);
            truth = repmat(["increase"; "decrease"; "none"], 4, 2);
            tc.verifyEqual(F.direction, truth, 'driven units up, suppressed down, flat ones not');
            tc.verifyWarning(@() aurocCurves(st(1:2), E, Window=[-0.5 1], Baseline=[-0.5 0], ModulationWindow=[0 0.3]), ...
                'aurocCurves:WideCutoff', 'two units: the interval is too wide to call any');
        end

        function tests(tc)
            tc.assumeTrue(hasStats(), "needs the Statistics and Machine Learning Toolbox");
            [st, E] = fixture(Units=6);
            truth = repmat(["increase"; "decrease"; "none"], 2, 2);
            for method = ["psth" "epochs"]
                for test = ["bootstrap" "ranksum" "shuffle"]
                    args = {'Window', [-0.5 1], 'Baseline', [-0.5 0], 'ModulationWindow', [0 0.3], 'Method', method, ...
                        'Cutoff', "test", 'Test', test, 'NResamples', 200};
                    A = aurocCurves(st, E, args{:});
                    what = method + " " + test;
                    tc.verifyEqual(A.direction, truth, what + ": driven up, suppressed down, flat not");
                    tc.verifyEqual(A.q, reshape(pAdjust(A.p(:), "bh"), size(A.p)), what + ": BH over every unit and group");
                    if test ~= "ranksum"
                        B = aurocCurves(st, E, args{:});
                        tc.verifyEqual(B.p, A.p, what + ": the same seed, the same p");
                        tc.verifyGreaterThanOrEqual(min(A.p, [], 'all'), 1 / 201, what + ": p >= 1 / (n + 1)");
                    end
                end
            end
            A = aurocCurves(st, E, Window=[-0.5 1], Baseline=[-0.5 0], ModulationWindow=[0 0.3], Cutoff="test", Test="ranksum");
            Ag = aurocCurves(st, E, Window=[-0.5 1], Baseline=[-0.5 0], ModulationWindow=[0 0.3], Cutoff="none");
            e = E.groupIndex == 1;
            edges = -0.5:0.01:1;
            v = mean(binCountsRef(st{1}, E.t0Continuous(e), edges), 2);
            win = edges(1:end-1) >= -1e-9 & edges(1:end-1) < 0.3 - 1e-9;
            base = edges(1:end-1) < -1e-9;
            tc.verifyEqual(A.p(1, 1), ranksum(v(win), v(base)), 'AbsTol', 1e-12, 'ranksum: the call window''s bins against the baseline''s');
            tc.verifyEqual(A.mean, Ag.mean, 'the test does not change the curve');
        end

        function spikePSTHResult(tc)
            tc.assumeTrue(hasStats(), "needs the Statistics and Machine Learning Toolbox");
            [st, E] = fixture(Units=6);
            a = struct('modulationWindow', [0 0.3], 'cutoff', "fixed", 'threshold', 0.2);
            R = spikePSTH(st, E, Window=[-0.5 1], BinSec=0.01, SmoothSec=0.02, Baseline=[-0.5 0], BaselineMode="auroc", Auroc=a);
            A = aurocCurves(st, E, Window=[-0.5 1], Baseline=[-0.5 0], ModulationWindow=[0 0.3], Cutoff="fixed", Threshold=0.2);
            tc.verifyEqual(R.rate, A.auroc, 'R.rate is the auROC (smoothing not used)');
            tc.verifyEqual(R.t, A.t);
            tc.verifyEqual(R.edges, A.edges);
            tc.verifyTrue(all(isnan(R.sem), 'all'));
            tc.verifyEqual(R.units, "auROC");
            tc.verifyEqual(R.auroc.direction, A.direction);
            tc.verifyEqual(R.auroc.settings.cutoff, "fixed");
            tc.verifyEqual(numel(R.raster), 6);
            a.modulatedOnly = true;
            M = spikePSTH(st, E, Window=[-0.5 1], BinSec=0.01, Baseline=[-0.5 0], BaselineMode="auroc", Auroc=a, ...
                Labels="u" + (1:6));
            keep = any(A.modulated, 2);
            tc.verifyEqual(M.labels, "u" + find(keep), 'modulatedOnly keeps the units modulated in some group');
            tc.verifyEqual(M.rate, A.auroc(:, keep, :));
            tc.verifyEqual(numel(M.raster), nnz(keep));
            tc.verifyEqual(M.auroc.mean, A.mean(keep, :));
            tc.verifyEqual(M.auroc.nUnits, 6, 'the counts stay those of every unit tested');
            tc.verifyError(@() spikePSTH(st([3 6]), E, Window=[-0.5 1], Baseline=[-0.5 0], BaselineMode="auroc", Auroc=a), ...
                'spikePSTH:NoneModulated', 'two flat units: none modulated');
            txt = plotCaption(struct('kind', "psth", 'baseline', struct('Mode', "auroc")), R);
            tc.verifyTrue(contains(txt, "auROC against the baseline [-0.5 0] s, from the PSTH's bins in 100 ms windows, tiled") ...
                && contains(txt, "by a fixed cutoff (+/-0.2): group 1 2 up, 2 down; group 2 2 up, 2 down (of 6 units)") ...
                && ~contains(txt, "smooth"), "the caption says how and counts the calls: " + txt);
        end

        function renderersTagWhatTheyAdd(tc)
            tc.assumeTrue(hasStats(), "needs the Statistics and Machine Learning Toolbox");
            [st, E] = fixture(Units=6);
            a = struct('modulationWindow', [0 0.3], 'cutoff', "fixed", 'threshold', 0.2);
            R = spikePSTH(st, E, Window=[-0.5 1], BinSec=0.01, Baseline=[-0.5 0], BaselineMode="auroc", Auroc=a);
            f = figure('Visible', 'off');
            closer = onCleanup(@() close(f));
            h = renderPSTH(R, f);
            tc.verifyEqual(ylim(h.axes(1)), [0 1], 'a 0-1 axis');
            for role = ["chanceLine" "modWindow" "modMarks"]
                tc.verifyNotEmpty(findall(f, 'Tag', role), "the PSTH draws its " + role);
            end
            marks = findall(f, 'Tag', 'modMarks');
            tc.verifyTrue(any(contains(string(get(marks, 'String')), "\uparrow")) ...
                && any(contains(string(get(marks, 'String')), "\downarrow")) && any(contains(string(get(marks, 'String')), "n.s.")));
            clf(f);
            h = renderHeatmap(R, f, Order="modulation");
            tc.verifyEqual(clim(h.axes(1)), [0 1], 'auROC colours on [0 1]');
            tc.verifyEqual(numel(findall(f, 'Tag', 'modMarks')), 8, 'a triangle by each modulated row of both tiles');
            img = findobj(h.axes(1), 'Type', 'image');
            rowMean = mean(img.CData(:, R.auroc.inModulation), 2);
            tc.verifyTrue(issorted(rowMean, 'descend'), 'rows by the first group''s mean auROC, highest first');
            C = PlotAesthetics.components(f);
            tc.verifyFalse(any(C.Role == ""), 'every component has a role');
        end
    end
end


function tf = hasStats()
tf = license('test', 'Statistics_Toolbox') && exist('tiedrank', 'file') == 2;
end


function a = aucOfShim(A, B)
%aucOfShim  aucOf (private to analysis/, so reachable from this file only).
a = aucOf(A, B);
end


function [st, E] = fixture(opts)
%fixture  Units by thirds: driven (+5 spikes in [0.05 0.35)), suppressed (none in [0 0.4)), flat (8 Hz Poisson); two groups of 30 epochs.
arguments
    opts.Units (1,1) double = 3
    opts.Pre (1,1) double = 0.6
end
rs = RandStream('mt19937ar', 'Seed', 7);
nE = 60;
t0 = (5:8:5 + 8 * (nE - 1)).';
g = 1 + (mod((1:nE).', 2) == 0);
E = table((1:nE).', NaN(nE, 1), t0, t0, NaN(nE, 1), t0 - opts.Pre, t0 + 5, repmat(opts.Pre + 5, nE, 1), true(nE, 1), ...
    false(nE, 1), g, "group " + g, 'VariableNames', {'epoch', 'trial', 't0', 't0Continuous', 't1', 'tStart', 'tStop', ...
    'duration', 'complete', 'artifact', 'groupIndex', 'group'});
T = t0(end) + 10;
st = cell(opts.Units, 1);
for u = 1:opts.Units
    s = sort(rand(rs, round(8 * T), 1) * T);
    for e = 1:nE
        switch mod(u - 1, 3)
            case 0, s = [s; t0(e) + 0.05 + rand(rs, 5, 1) * 0.3]; %#ok<AGROW>
            case 1, s = s(~(s >= t0(e) & s < t0(e) + 0.4));
        end
    end
    st{u} = sort(s);
end
end


function c = countIn(s, t0, a, b)
%countIn  Spikes in [t0 + a, t0 + b) for each event.
c = arrayfun(@(t) nnz(s >= t + a - 1e-12 & s < t + b - 1e-12), t0(:)).';
end


function C = binCountsRef(s, t0, edges)
%binCountsRef  Spike counts per bin [edges(k), edges(k+1)) and event, by brute force: [nBins x nEvents].
C = zeros(numel(edges) - 1, numel(t0));
for e = 1:numel(t0)
    r = s - t0(e);
    for k = 1:numel(edges) - 1
        C(k, e) = nnz(r >= edges(k) - 1e-12 & r < edges(k + 1) - 1e-12);
    end
end
end


function auc = labCurve(s, t0, pre, post, b0, b1)
%labCurve  calculate_auROC.py's auROC_response_curve on its PSTH (10 ms bins, 100 ms windows), ported.
%   bin_cuts = np.arange(-pre, post, 0.01); hist = round(counts / nTrials / 0.01, 4);
%   baseline: bins starting in [-b0, -b1); each window: bins starting in
%   [start, start + 0.1) for start in np.arange(edges[0], edges[-1], 0.1);
%   thresholds = linspace(0, max + 0.1, floor((max + 0.1) / 0.1)), counted >=;
%   auROC = trapz(sorted(TP), sorted(FP)).
edges = round((-pre:0.01:post - 0.01 + 1e-9) * 100) / 100;
rel = [];
for e = 1:numel(t0)
    rel = [rel; s - t0(e)]; %#ok<AGROW>
end
counts = histcounts(rel, edges);
hist = round(counts / numel(t0) / 0.01, 4);
starts = edges(1:end-1);
base = hist(starts >= -b0 - 1e-9 & starts < -b1 - 1e-9);
mx = max(hist) + 0.1;
th = linspace(0, mx, floor(mx / 0.1));
w0 = edges(1):0.1:edges(end) - 1e-9;
auc = zeros(numel(w0), 1);
for k = 1:numel(w0)
    cur = hist(starts >= w0(k) - 1e-9 & starts < w0(k) + 0.1 - 1e-9);
    fp = arrayfun(@(t) mean(base >= t), th);
    tp = arrayfun(@(t) mean(cur >= t), th);
    auc(k) = trapz(sort(fp), sort(tp));
end
end
