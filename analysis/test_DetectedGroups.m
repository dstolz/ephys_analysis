classdef test_DetectedGroups < matlab.unittest.TestCase
    %test_DetectedGroups  Joining the detection channels that hold one neuron (groupDetected, selectUnits merge).
    %   The Spikes step keeps a spike once across neighboring sites but not
    %   one neuron on one channel: the deepest site changes from spike to
    %   spike. groupDetected joins the channels of neighboring sites whose
    %   events leave a refractory gap between them. Covered: one neuron cut
    %   between two sites is joined (its largest-waveform channel named, its
    %   spikes once, in order), an independent neuron on a third neighboring
    %   site and a site far away are not, a pair too sparse to test is left
    %   alone, the copies of Coincidence "tag" are left out, a file without
    %   Coincidence is refused, and selectUnits' merge option (units, labels,
    %   nSites / sites, the filters on the unit's own channel).
    %
    %   The fixture is 600 s at 25 kHz on four sites at y = 0, 20, 40 and 500 um
    %   (x = 0): neuron X (about 11 Hz, 3 ms refractory) lands on site 1 (60%,
    %   about 200 uV) or site 2 (40%, about 150 uV); Y (15 Hz) is on site 3 alone,
    %   Z (15 Hz) on site 4, with the events of Y within the Coincidence jitter
    %   of X's dropped, as the step would.
    %
    %   The tests need the Statistics and Machine Learning Toolbox (poisscdf) and
    %   are skipped without it.
    %
    %   Usage:  runtests("test_DetectedGroups")

    properties (SetAccess = private)
        Spikes = []                    % the detected struct (Coincidence "remove")
        Fs = 25000
        Jitter = 13                    % samples
        Pos = [0 0; 0 20; 0 40; 0 500]
    end

    methods (TestClassSetup)
        function makeFixture(tc)
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(here);
            addpath(here, fullfile(repo, 'pipeline'), repo);
            tc.assumeTrue(license('test', 'Statistics_Toolbox') && exist('poisscdf', 'file') > 0, ...
                "needs the Statistics and Machine Learning Toolbox");
            rng(7);
            n = tc.Fs * 600;
            x = trainOf(11, 0.003, n);
            onFirst = rand(numel(x), 1) < 0.6;
            idx = {x(onFirst), x(~onFirst), trainOf(15, 0.003, n), trainOf(15, 0.003, n)};
            % Y is dropped within the jitter of X's events, as the step removes the smaller copy
            k = discretize(idx{3}, [-Inf; x; Inf]);
            before = x(max(k - 1, 1));
            after = x(min(k, numel(x)));
            near = min(abs(idx{3} - before), abs(idx{3} - after)) <= tc.Jitter;
            idx{3} = idx{3}(~near);
            amp = {-200 + 10 * randn(numel(idx{1}), 1), -150 + 10 * randn(numel(idx{2}), 1), ...
                   -100 + 10 * randn(numel(idx{3}), 1), -120 + 10 * randn(numel(idx{4}), 1)};
            tc.Spikes = detectedOf(idx, amp, tc.Fs, tc.Pos, "remove", tc.Jitter);
        end
    end

    methods (Test)
        function oneNeuronCutBetweenTwoSitesJoins(tc)
            G = groupDetected(tc.Spikes);
            tc.verifyEqual(G.group(1), G.group(2), "sites 1 and 2 hold one neuron");
            tc.verifyNotEqual(G.group(3), G.group(1), "the neuron on site 3 is another");
            tc.verifyNotEqual(G.group(4), G.group(1));
            tc.verifyNotEqual(G.group(4), G.group(3));
            tc.verifyEqual(numel(G.members), 3);
            g = G.group(1);
            tc.verifyEqual(sort(G.members{g}), [1 2]);
            tc.verifyEqual(G.best(g), 1, "the channel with the largest mean waveform");
            tc.verifyEqual(numel(G.times{g}), numel(tc.Spikes.ts{1}) + numel(tc.Spikes.ts{2}), "every spike of the group, once");
            tc.verifyTrue(issorted(G.times{g}) && numel(unique(G.times{g})) == numel(G.times{g}));
            tc.verifyEqual(G.jitterMs, 1000 * tc.Jitter / tc.Fs);
        end

        function pairStatistics(tc)
            G = groupDetected(tc.Spikes);
            P = G.pairs;
            p12 = P(P.A == 1 & P.B == 2, :);
            tc.verifyTrue(p12.joined && p12.ratio <= 0.05 && p12.expected > 20, ...
                "the split neuron leaves almost nothing in the gap, where chance would put some");
            for b = [1 2]
                r = P(P.A == b & P.B == 3, :);
                tc.verifyTrue(~r.joined && r.ratio > 0.6 && r.ratio < 1.6, ...
                    sprintf("site %d and the independent neuron fire close together at the chance rate", b));
            end
            tc.verifyEqual(height(P), 3, "pairs of sites within 50 um: 1-2, 1-3 (40 um), 2-3; the far site has none");
        end

        function aSparsePairIsNotTested(tc)
            D = tc.Spikes;
            for c = 1:2
                D.ts{c} = D.ts{c}(1:150);
                D.info.amplitude{c} = D.info.amplitude{c}(1:150);
                D.info.index{c} = D.info.index{c}(1:150);
            end
            G = groupDetected(D);
            tc.verifyFalse(G.pairs.joined(G.pairs.A == 1 & G.pairs.B == 2), "too few events expected in the gap to tell");
            tc.verifyNotEqual(G.group(1), G.group(2));
        end

        function optionsMoveTheEdges(tc)
            G = groupDetected(tc.Spikes, RadiusUm=10);
            tc.verifyEqual(height(G.pairs), 0, "no sites within 10 um: no pair");
            tc.verifyEqual(numel(G.members), 4);
            G = groupDetected(tc.Spikes, MinExpected=1e4);
            tc.verifyFalse(any(G.pairs.joined), "no pair has that many events expected in the gap");
            G = groupDetected(tc.Spikes, Positions=[zeros(4, 1), [0; 20; 400; 500]]);
            tc.verifyEqual(height(G.pairs), 1, "positions can be passed in (site 3 moved away)");
        end

        function tagsLeaveTheCopiesOut(tc)
            D = tc.Spikes;
            idx = D.info.index;
            amp = D.info.amplitude;
            nPrim = cellfun(@numel, idx);
            primary = arrayfun(@(k) true(k, 1), nPrim, 'UniformOutput', false);
            % a weaker copy of every 10th event of site 1 on site 2, 3 samples later
            pick = (1:10:numel(idx{1})).';
            cp = idx{1}(pick) + 3;
            [idx{2}, o] = sort([idx{2}; cp]);
            amp2 = [amp{2}; 0.5 * amp{1}(pick)];
            amp{2} = amp2(o);
            pr = [true(nPrim(2), 1); false(numel(pick), 1)];
            primary{2} = pr(o);
            Dt = detectedOf(idx, amp, tc.Fs, tc.Pos, "tag", tc.Jitter);
            Dt.info.primary = primary;
            G = groupDetected(Dt);
            g = G.group(1);
            tc.verifyEqual(G.group(1), G.group(2));
            tc.verifyEqual(numel(G.times{g}), nPrim(1) + nPrim(2), "the copies are not spikes of the unit");
            tc.verifyEqual(nnz(G.keep{2}), nPrim(2));
            tc.verifyEqual(G.best(g), 1);
        end

        function aFileWithoutCoincidenceIsRefused(tc)
            D = tc.Spikes;
            D.info.coincidence.mode = "none";
            tc.verifyError(@() groupDetected(D), 'groupDetected:NoCoincidence');
            D.info = rmfield(D.info, 'coincidence');
            tc.verifyError(@() groupDetected(D), 'groupDetected:NoCoincidence');
            D = tc.Spikes;
            D.info.coincidence = rmfield(D.info.coincidence, 'positions');
            tc.verifyError(@() groupDetected(D), 'groupDetected:NoPositions');
        end

        function selectUnitsMerge(tc)
            folder = tc.spikesFolder();
            src = loadAnalysisSource(folder);
            tc.assertTrue(src.hasDetected);
            [st0, m0] = selectUnits(src, struct('source', "detected"));
            tc.verifyEqual(height(m0), 4, "unmerged: a unit per channel");
            tc.verifyFalse(ismember("nSites", string(m0.Properties.VariableNames)));

            usel = struct('source', "detected", 'merge', struct('enabled', true));
            [st, m] = selectUnits(src, usel);
            tc.verifyEqual(height(m), 3);
            tc.verifyEqual(m.channel, [1; 3; 4], "named for the largest waveform's channel, in channel order");
            tc.verifyEqual(m.unitId, m.channel);
            tc.verifyEqual(m.nSites, [2; 1; 1]);
            tc.verifyEqual(m.sites, ["1,2"; "3"; "4"]);
            tc.verifyEqual(m.label, ["A-000+1"; "A-002"; "A-003"]);
            tc.verifyEqual(m.nSpikes, [numel(st0{1}) + numel(st0{2}); numel(st0{3}); numel(st0{4})]);
            tc.verifyEqual(m.nSpikes, cellfun(@numel, st));
            tc.verifyEqual(st{1}, sort([st0{1}; st0{2}]));
            tc.verifyEqual(st{2}, st0{3});

            % the filters see the unit's own channel
            [~, m1] = selectUnits(src, setfield(usel, 'channels', 1));
            tc.verifyEqual(m1.channel, 1);
            tc.verifyError(@() selectUnits(src, setfield(usel, 'channels', 2)), 'selectUnits:NoneLeft', ...
                "channel 2 is part of the unit named for channel 1, not a unit of its own");
        end
    end

    methods (Access = private)
        function folder = spikesFolder(tc)
            root = string(tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
            folder = fullfile(root, "C1_260101_120000");
            mkdir(folder);
            detected = tc.Spikes;
            conversion = struct('note', "test");
            save(fullfile(folder, "C1_260101_120000_spikes.mat"), 'detected', 'conversion');
        end
    end
end


function idx = trainOf(rate, refractory, nSamples)
%trainOf  Event samples of a spike train: a Poisson process of RATE Hz after a REFRACTORY s dead time.
fs = 25000;
mean_ = 1 / rate - refractory;
isi = refractory * fs + (-log(rand(ceil(2 * rate * nSamples / fs), 1)) * mean_ * fs);
idx = cumsum(round(isi));
idx = idx(idx < nSamples - 100 & idx > 100);
end


function D = detectedOf(idx, amp, fs, pos, mode, jit)
%detectedOf  A detected struct (the Spikes step's) from event samples and amplitudes per channel.
n = numel(idx);
D = struct();
D.ts = cellfun(@(i) double(i(:) - 1) / fs, idx, 'UniformOutput', false);
D.channels = 1:n;
D.channelNames = "A-" + compose("%03d", (0:n-1));
D.info = struct('fs', fs, 'index', {cellfun(@(i) double(i(:)), idx, 'UniformOutput', false)}, ...
    'amplitude', {amp}, 'count', cellfun(@numel, idx));
D.info.coincidence = struct('mode', mode, 'radiusUm', 50, 'jitterMs', 1000 * jit / fs, 'jitterSamples', jit, ...
    'positions', pos);
end
