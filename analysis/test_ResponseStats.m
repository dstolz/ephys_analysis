classdef test_ResponseStats < matlab.unittest.TestCase
    %test_ResponseStats  responseStats and pAdjust.
    %   pAdjust against statsmodels' multipletests (pipeline/testdata/
    %   padjust_golden.json, from tools/golden/padjust_golden.py), NaN
    %   included. responseStats on hand-made epochs and spike trains whose
    %   every count is known: the counts and rates; p against signrank and
    %   kruskalwallis called directly on those counts; the direction; the
    %   correction; the epochs left out; rates instead of counts when the
    %   windows differ in length; the errors. The tests that call the
    %   toolbox need the Statistics and Machine Learning Toolbox and are
    %   skipped without it (then the one that expects
    %   responseStats:NoToolbox runs).
    %
    %   Usage:  runtests("test_ResponseStats")

    properties (SetAccess = private)
        Golden = []
    end

    methods (TestClassSetup)
        function loadGolden(tc)
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(here);
            addpath(fullfile(repo, 'pipeline'));
            tc.Golden = readJsonFile(fullfile(repo, 'pipeline', 'testdata', 'padjust_golden.json'));
        end
    end

    methods (Test)
        function pAdjustMatchesStatsmodels(tc)
            cases = tc.Golden.cases;
            if iscell(cases); cases = [cases{:}]; end
            for c = 1:numel(cases)
                C = cases(c);
                p = double(C.p(:));
                for m = ["bh" "holm" "bonferroni"]
                    want = double(C.(m)(:));
                    got = pAdjust(p, m);
                    tc.verifyEqual(isnan(got), isnan(want), sprintf("%s %s: NaN where the input is NaN", C.name, m));
                    k = ~isnan(want);
                    tc.verifyEqual(got(k), want(k), 'RelTol', 1e-12, sprintf("%s %s as statsmodels", C.name, m));
                end
                tc.verifyEqual(pAdjust(p, "none"), p, sprintf("%s none", C.name));
            end
        end

        function pAdjustKeepsShape(tc)
            p = [0.01 0.04 NaN 0.03];
            q = pAdjust(p, "bh");
            tc.verifySize(q, [1 4]);
            tc.verifyEqual(q, [0.03 0.04 NaN 0.04], 'AbsTol', 1e-15, 'BH over the three finite values');
            tc.verifyEqual(pAdjust(NaN(2, 3)), NaN(2, 3), 'nothing to adjust');
            tc.verifyEqual(pAdjust([0.2 0.5], "bonferroni"), [0.4 1], 'capped at 1');
        end

        function countsRatesAndTests(tc)
            tc.assumeTrue(hasStats(), "needs the Statistics and Machine Learning Toolbox");
            [st, E, cR, cB] = fixture();
            [T, info] = responseStats(st, E, Baseline=[-0.2 0], Window=[0 0.2], Correction="holm");
            tc.verifyTrue(info.counts, 'equal windows: the tests run on the counts');
            tc.verifyEqual(info.nEpochs, height(E));
            tc.verifyEqual(T.nEpochs, repmat(height(E), 4, 1));
            tc.verifyEqual(T.responseRate, mean(cR, 1).' / 0.2, 'RelTol', 1e-12, 'response rates: the counts / 0.2 s');
            tc.verifyEqual(T.baselineRate, mean(cB, 1).' / 0.2, 'RelTol', 1e-12, 'baseline rates');
            for u = 1:4
                tc.verifyEqual(T.pEvoked(u), signrank(cR(:, u), cB(:, u)), sprintf('unit %d: p is signrank''s', u));
            end
            tc.verifyEqual(T.direction(1:3), ["excited"; "suppressed"; "none"]);
            tc.verifyEqual(T.qEvoked, pAdjust(T.pEvoked, "holm"), 'Holm over the units');
            tc.verifyEqual(T.responsive, T.qEvoked <= 0.05);
            tc.verifyTrue(T.responsive(1) && T.responsive(2) && ~T.responsive(3), ...
                'every epoch up (unit 1) or down (unit 2) is responsive; no change (unit 3) is not');
            tc.verifyEqual(T.label, "unit " + (1:4).');
        end

        function tuning(tc)
            tc.assumeTrue(hasStats(), "needs the Statistics and Machine Learning Toolbox");
            [st, E, cR] = fixture();
            meta = table(["a"; "b"; "c"; "d"], 'VariableNames', {'label'});
            T = responseStats(st, E, Param="Level", Meta=meta);
            for u = 1:4
                tc.verifyEqual(T.pTuning(u), kruskalwallis(cR(:, u), E.Level, 'off'), ...
                    sprintf('unit %d: p is kruskalwallis''s across the levels', u));
            end
            tc.verifyEqual(T.nLevels, repmat(4, 4, 1));
            tc.verifyEqual(T.bestLevel(4), 40, 'unit 4 fires most at level 40');
            tc.verifyEqual(T.bestRate(4), mean(cR(E.Level == 40, 4)) / 0.2, 'RelTol', 1e-12);
            tc.verifyTrue(T.tuned(4), 'unit 4 is tuned');
            tc.verifyEqual(T.qTuning, pAdjust(T.pTuning, "bh"), 'BH by default');
            tc.verifyEqual(T.label, ["a"; "b"; "c"; "d"], 'labels from Meta');
            E.Level(1:5) = NaN;    % epochs without a level are left out of the tuning test only
            T2 = responseStats(st, E, Param="Level");
            keep = ~isnan(E.Level);
            tc.verifyEqual(T2.pTuning(4), kruskalwallis(cR(keep, 4), E.Level(keep), 'off'));
            tc.verifyEqual(T2.pEvoked, T.pEvoked, 'the evoked test still uses every epoch');
        end

        function epochsLeftOut(tc)
            tc.assumeTrue(hasStats(), "needs the Statistics and Machine Learning Toolbox");
            [st, E, cR, cB] = fixture();
            E.complete(2) = false;
            E.artifact(5) = true;
            E.tStop(9) = E.t0(9) + 0.1;            % too short for the response window
            T = tc.verifyWarning(@() responseStats(st, E), 'responseStats:EpochsLeftOut');
            used = true(height(E), 1);
            used([2 5 9]) = false;
            tc.verifyEqual(T.nEpochs(1), nnz(used));
            tc.verifyEqual(T.pEvoked(1), signrank(cR(used, 1), cB(used, 1)));
        end

        function unequalWindowsUseRates(tc)
            tc.assumeTrue(hasStats(), "needs the Statistics and Machine Learning Toolbox");
            [st, E, cR, cB] = fixture(Pre=-0.4);   % every baseline spike lies in [-0.2 0), so also in [-0.4 0)
            [T, info] = responseStats(st, E, Baseline=[-0.4 0], Window=[0 0.2]);
            tc.verifyFalse(info.counts);
            for u = 1:4
                tc.verifyEqual(T.pEvoked(u), signrank(cR(:, u) / 0.2, cB(:, u) / 0.4), ...
                    sprintf('unit %d: the tests run on the rates when the windows differ', u));
            end
            tc.verifyEqual(T.baselineRate, mean(cB, 1).' / 0.4, 'RelTol', 1e-12);
        end

        function withoutTests(tc)
            [st, E, cR, cB] = fixture();
            [T, info] = responseStats(st, E, Param="Level", Tests=false);   % no toolbox needed
            tc.verifyFalse(info.tests);
            tc.verifyTrue(all(isnan([T.pEvoked; T.qEvoked; T.pTuning; T.qTuning])), 'no p without the tests');
            tc.verifyEqual(T.direction, strings(4, 1), 'no direction without the tests');
            tc.verifyFalse(any(T.responsive) || any(T.tuned));
            tc.verifyEqual(T.responseRate, mean(cR, 1).' / 0.2, 'RelTol', 1e-12);
            tc.verifyEqual(T.baselineRate, mean(cB, 1).' / 0.2, 'RelTol', 1e-12);
            tc.verifyEqual(info.levels, [10; 20; 30; 40]);
            want = NaN(4, 4);
            for k = 1:4
                want(k, :) = mean(cR(E.Level == 10 * k, :), 1) / 0.2;
            end
            tc.verifyEqual(info.levelRate, want, 'RelTol', 1e-12, 'the mean response rate per level');
            tc.verifyEqual(info.levelN, repmat(5, 4, 4), 'five epochs per level');
            tc.verifyEqual(T.bestLevel(4), 40);
            tc.verifyEqual(T.nLevels, repmat(4, 4, 1));
        end

        function errors(tc)
            [st, E] = fixture();
            tc.verifyError(@() responseStats(st, E, Baseline=[0 -0.2]), 'responseStats:BadWindow');
            tc.verifyError(@() responseStats(st, E, Correction="fdr"), 'responseStats:BadOption');
            tc.verifyError(@() responseStats(st, E, Alpha=0), 'responseStats:BadOption');
            if hasStats()
                tc.verifyError(@() responseStats(st, E, Param="Nope"), 'responseStats:NoColumn');
                E.artifact(:) = true;
                tc.verifyError(@() responseStats(st, E), 'responseStats:NoEpochs');
            else
                tc.verifyError(@() responseStats(st, E), 'responseStats:NoToolbox');
            end
        end
    end
end


function tf = hasStats()
tf = license('test', 'Statistics_Toolbox') && exist('signrank', 'file') > 0 && exist('kruskalwallis', 'file') > 0;
end


function [st, E, cR, cB] = fixture(opts)
%fixture  20 epochs 1 s apart; 4 units with known counts in [-0.2 0) and [0 0.2).
%   Unit 1: more spikes after the event in every epoch; unit 2: fewer;
%   unit 3: as many; unit 4: its epoch's level / 10 - 1, plus 1 in every
%   other round of levels (tuned, most at 40), 1 before. Level: 10 20 30
%   40 in turn, 5 rounds.
arguments
    opts.Pre (1,1) double = -0.2
end
n = 20;
t0 = (1:n).';
level = repmat([10; 20; 30; 40], n / 4, 1);
cR = zeros(n, 4); cB = zeros(n, 4);
for e = 1:n
    cB(e, :) = [mod(e, 2), 3, 1 + mod(e, 3), 1];
    cR(e, :) = [2 + mod(e, 3), mod(e, 2), 1 + mod(e, 3), level(e) / 10 - 1 + mod(floor((e - 1) / 4), 2)];
end
st = cell(4, 1);
for u = 1:4
    s = zeros(0, 1);
    for e = 1:n
        s = [s; t0(e) - 0.15 + 0.03 * (0:cB(e, u) - 1).'; t0(e) + 0.02 + 0.03 * (0:cR(e, u) - 1).']; %#ok<AGROW>
    end
    st{u} = s;
end
E = table((1:n).', (1:n).', t0, t0, NaN(n, 1), t0 + opts.Pre, t0 + 0.2, (0.2 - opts.Pre) * ones(n, 1), ...
    true(n, 1), false(n, 1), ones(n, 1), repmat("all", n, 1), level, ...
    'VariableNames', {'epoch', 'trial', 't0', 't0Continuous', 't1', 'tStart', 'tStop', 'duration', ...
    'complete', 'artifact', 'groupIndex', 'group', 'Level'});
end
