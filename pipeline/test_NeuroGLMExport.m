classdef test_NeuroGLMExport < matlab.unittest.TestCase
    %test_NeuroGLMExport  NeuroGLMExport and sessionDataNeuroGLM against neuroGLM's experiment struct.
    %   Needs neuroGLM on the path (or in NEUROGLM_PATH / C:\src\neuroGLM);
    %   the suite is skipped (Incomplete) without it. Checks: experiment cuts
    %   spans into trials (durations in whole bins, spikes and events in ms
    %   from the start, the end excluded, values copied, continuous signals
    %   resampled and cut, trials off a signal dropped); its errors;
    %   sessionDataNeuroGLM's spans (Inf post = up to the next trial, the
    %   last to the recording's end; edge and artifact drops; "all" trials),
    %   its labels and values, a Signal as a continuous variable; the trial's
    %   response word and response time, kernels split by two variables;
    %   designSpec (grouped, acausal, coupling kernels) and fit on a planted
    %   response (a gain after the event, bits per spike > 0, predict's
    %   shapes); the matRegress route (fminunc) against glmfit, its ridge
    %   and evidence optimization (skipped without matRegress or the
    %   Optimization Toolbox); the spike-history filter's reach at two bin
    %   sizes; the kernels' standard errors against the weights' covariance;
    %   lockedEvents on events a fixed time apart; fitWorkers' zero cases.
    %
    %   Usage:  runtests("test_NeuroGLMExport")

    properties (SetAccess = private)
        D = []          % a sessionData-shaped struct with spike trains
        L = []          % the same dataset's LFP, sessionData-shaped
        StimOn = []     % each trial's Stim onset, s, continuous clock
    end

    methods (TestClassSetup)
        function setPath(tc)
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(here);
            addpath(here);
            addpath(fullfile(repo, 'analysis'));
            if ~NeuroGLMExport.hasNeuroGLM()
                cands = [string(getenv('NEUROGLM_PATH')) "C:\src\neuroGLM"];
                cands = cands(cands ~= "" & arrayfun(@isfolder, cands));
                if ~isempty(cands); addpath(cands(1)); end
            end
            tc.assumeTrue(NeuroGLMExport.hasNeuroGLM(), 'neuroGLM is not on the path (set NEUROGLM_PATH).');
            if ~NeuroGLMExport.hasMatRegress()
                root = fileparts(fileparts(which('buildGLM.initExperiment')));   % <neuroGLM>/+buildGLM/initExperiment.m
                if isfolder(fullfile(root, 'matRegress')); addpath(fullfile(root, 'matRegress')); end
            end
            [tc.D, tc.L, tc.StimOn] = test_NeuroGLMExport.makeSession();
        end
    end

    methods (Static)
        function [D, L, stimOn] = makeSession()
            fs = 30000; dur = 30; n = 12;
            toC = @(t) (round(t * fs) - 1) / fs;
            on = 1 + 2.2 * (0:n - 1).';                  % digital clock, s
            stim = on + 0.3;
            resp = on(1:2:end) + 0.8;                    % odd trials only
            events = struct('Trial', [on on + 1.5], 'Stim', [stim stim + 0.2], 'Resp', [resp resp + 0.05]);
            stimOn = toC(stim);
            rng(7);
            bg = @(rate) sort(rand(poissrnd(rate * dur), 1) * dur);
            planted = reshape(stimOn + [0.010 0.012 0.015 0.020 0.030], [], 1);
            spikes = {sort([bg(2); planted]); bg(3)};
            depth = repmat([0.2; 0.8], n / 2, 1);
            word = repmat(["Hit"; "Miss"; "Hit"], n / 3, 1);
            latency = NaN(n, 1); latency(word == "Hit") = 100;   % ms; a miss has none
            trials = table(on, on + 1.5, depth, word, latency, ...
                'VariableNames', {'TrialOnset', 'TrialOffset', 'Depth', 'RespCode', 'RespLatency'});
            kept = true(n, 1); kept(3) = false;
            group = 1 + (depth == 0.8); group(~kept) = 0;
            groups = table([1; 2], ["Depth = 0.2"; "Depth = 0.8"], [0 0.4 0.8; 0.8 0.3 0.1], ...
                [nnz(group == 1); nnz(group == 2)], 'VariableNames', {'index', 'label', 'color', 'n'});
            units = table(["su001_1"; "su002_2"], [1; 2], ["su"; "su"], [5; 9], ["ch5"; "ch9"], [1; 1], ...
                [0; 0], [100; 200], cellfun(@numel, spikes), ...
                'VariableNames', {'label', 'unitId', 'class', 'channel', 'channelName', 'shank', 'x', 'y', 'nSpikes'});
            D = struct('key', "k1", 'name', "ds1", 'folder', "", 'subject', "s1", 'startTime', NaT, 'tags', strings(0, 1), 'variables', struct('probeDepth', 1200), ...
                'fs', fs, 'durationSec', dur, 'data', "units", 'spikes', {spikes}, 'units', units, ...
                'signal', [], 'signalFs', NaN, 'channels', table(), 'events', events, ...
                'eventsContinuous', structfun(toC, events, 'UniformOutput', false), 'toContinuous', toC, ...
                'lines', table(), 'trials', trials, 'kept', kept, 'group', group, 'groups', groups, ...
                'hasTrials', true, 'trialLine', "Trial", 'respField', "RespCode", 'paramNames', "Depth", ...
                'pairing', [], 'derivedEvents', [], 'invertedLines', strings(0, 1), ...
                'artifacts', [10.0 10.05], 'probe', [], 'labels', strings(0, 1));
            L = D;
            L.data = "LFP"; L.spikes = {}; L.units = table();
            L.signalFs = 1000;
            L.signal = single([(0:dur * 1000 - 1).', 10 * (0:dur * 1000 - 1).']);
            L.channels = table(["ch1"; "ch2"], ["uV"; "uV"], 'VariableNames', {'label', 'units'});
        end
    end

    methods (Test)
        function experimentCutsSpans(tc)
            spans = [0 1.0005; 2 2.5; 3.8 4.5];
            Sp = struct('a', [0.5; 1.2; 2.1; 2.4999; 2.5]);
            Ev = struct('e', [0; 1.0; 2.25]);
            V = table(["x"; "y"; "z"], [1; 2; 3], 'VariableNames', {'v1', 'v2'});
            C = struct('c1', struct('data', (0:3999).', 'fs', 1000), ...
                       'c2', struct('data', ones(8000, 1), 'fs', 2000));
            [expt, keep] = NeuroGLMExport.experiment(spans, Spikes=Sp, Events=Ev, Values=V, Continuous=C, ...
                Id="t", Param=struct('p', 1), Describe=struct('a', "unit a"));
            tc.verifyEqual(keep, [true; true; false], 'The span off the continuous signal is dropped.');
            tc.verifyEqual(expt.unitOfTime, 'ms');
            tc.verifyEqual(expt.binSize, 1);
            tc.verifyEqual(expt.id, 't');
            tc.verifyEqual(expt.param.p, 1);
            tc.verifyEqual(expt.desc.a, 'unit a');
            tc.verifyEqual(expt.type.a, 'spike train');
            tc.verifyEqual(expt.type.e, 'timing');
            tc.verifyEqual(expt.type.v1, 'value');
            tc.verifyEqual(expt.type.c1, 'continuous');
            tc.verifyEqual(expt.dim.c1, 1);
            T = expt.trial;
            tc.verifySize(T, [2 1]);
            tc.verifyEqual([T.duration], [1000 500], 'Whole bins; the end rounded down.');
            tc.verifyEqual(T(1).span, [0 1]);
            % times are nudged by 1 ns into the bin that starts on their edge (ceil binning)
            tc.verifyEqual(T(1).a, 500, 'AbsTol', 1e-5);
            tc.verifyEqual(T(2).a, [100; 499.9], 'AbsTol', 1e-5, 'A spike at the end is excluded.');
            tc.verifyEqual(T(1).e, 0, 'AbsTol', 1e-5, 'An event at the start is at 0; one at the end is excluded.');
            tc.verifyEqual(T(2).e, 250, 'AbsTol', 1e-5);
            tc.verifyEqual(T(1).v1, "x");
            tc.verifyEqual(T(2).v2, 2);
            tc.verifyEqual(T(1).c1, (0:999).', 'Row k is the bin at (k-1) ms.');
            tc.verifyEqual(T(2).c1, (2000:2499).');
            tc.verifySize(T(2).c2, [500 1], 'Resampled to the bin rate.');
            tc.verifyEqual(T(2).c2, ones(500, 1), 'AbsTol', 1e-6);
            tc.verifyEqual(expt.binfun(T(1).duration), 1000);
            % 5 ms bins
            expt5 = NeuroGLMExport.experiment(spans(1:2, :), BinMs=5, Spikes=Sp, Events=Ev);
            tc.verifyEqual([expt5.trial.duration], [1000 500]);
            tc.verifyEqual(expt5.binfun(expt5.trial(1).duration), 200);
            y = buildGLM.getBinnedSpikeTrain(expt5, 'a', 1:2);
            tc.verifyEqual(full(sum(y)), 3, 'Three spikes inside the two trials.');
        end

        function experimentSnapsStartToBinGrid(tc)
            % 5 ms bins and a start 0.2 ms past a bin edge. With a continuous signal (rows are bins on
            % the grid) the trial starts on the edge, so spikes and the signal's rows agree.
            spans = [0.0102 0.5];
            Sp = struct('a', [0.0153; 0.0301]);
            C = struct('c', struct('data', (0:199).', 'fs', 200));
            expt = NeuroGLMExport.experiment(spans, BinMs=5, Spikes=Sp, Continuous=C);
            T = expt.trial;
            tc.verifyEqual(T.span(1), 0.010, 'AbsTol', 1e-12, 'The start is snapped to the bin grid.');
            tc.verifyEqual(T.duration, 485, 'The span''s whole bins, wherever the start is moved.');
            tc.verifyEqual(T.a, [5.3; 20.1], 'AbsTol', 1e-5, 'Spikes are binned from the snapped start.');
            tc.verifyEqual(T.c(1:2), [2; 3], 'Row 1 is the bin starting at 10 ms.');
            % without a continuous signal nothing is moved
            expt2 = NeuroGLMExport.experiment(spans, BinMs=5, Spikes=Sp);
            tc.verifyEqual(expt2.trial.span(1), 0.0102);
            tc.verifyEqual(expt2.trial.duration, 485);
            tc.verifyEqual(expt2.trial.a, [5.1; 19.9], 'AbsTol', 1e-5);
        end

        function experimentFindsTimesBySearch(tc)
            % many overlapping spans, repeated spike times: each trial holds exactly the times in [0, duration)
            rs = RandStream('twister', 'Seed', 3);
            st = sort(round(rand(rs, 4000, 1) * 20, 3));
            st = sort([st; st(1:300); 5; 5; 5]);            % duplicates, and three at one instant
            ev = rand(rs, 250, 1) * 20;
            t0 = sort(rand(rs, 40, 1) * 18);
            spans = [t0, t0 + 0.4 + rand(rs, 40, 1)];
            expt = NeuroGLMExport.experiment(spans, BinMs=2, Spikes=struct('s', st, 'n', zeros(0, 1)), Events=struct('e', ev));
            tc.verifyEqual(numel(expt.trial), 40);
            for k = 1:40
                tr = expt.trial(k);
                for name = ["s" "e"]
                    src = st; if name == "e"; src = ev; end
                    rel = round((src - spans(k, 1)) * 1e9);
                    rel = sort(rel(rel >= 0 & rel < round(tr.duration * 1e6)));
                    tc.verifyEqual(tr.(name), rel / 1e6 + 1e-6, 'AbsTol', 1e-9, sprintf('trial %d, %s', k, name));
                end
                tc.verifySize(tr.n, [0 1]);
            end
        end

        function splitHoldsOutTheLastBlock(tc)
            spans = [(0:19).' * 2, (0:19).' * 2 + 2];       % 20 trials end to end
            e = struct('trial', struct('span', mat2cell(spans, ones(20, 1), 2)));
            [train, test] = NeuroGLMExport.split(e, TestFraction=0.25);
            tc.verifyEqual(test, 16:20, 'The held-out trials are the last block.');
            tc.verifyEqual(train, 1:15);
            [train, test] = NeuroGLMExport.split(e);
            tc.verifyEqual([train test], 1:20);
            tc.verifyEqual(numel(test), 4, 'A fifth by default.');
            [train, test] = NeuroGLMExport.split(e, TestFraction=0);
            tc.verifyEqual(test, train, 'Nothing held out: test on the fit.');
            [train, test] = NeuroGLMExport.split(e, TestFraction=0.25, Blocked=false, Seed=2);
            [~, test2] = NeuroGLMExport.split(e, TestFraction=0.25, Blocked=false, Seed=2);
            tc.verifyEqual(test, test2, 'Repeatable by Seed.');
            tc.verifyEqual(sort([train test]), 1:20);
            tc.verifyFalse(isequal(test, 16:20), 'Blocked=false picks the trials at random.');
        end

        function splitKeepsOverlappingTrialsTogether(tc)
            spans = [(0:19).' * 2, (0:19).' * 2 + 2];
            spans(16, 1) = 29;                              % trial 16 overlaps trial 15 ([28 30])
            e = struct('trial', struct('span', mat2cell(spans, ones(20, 1), 2)));
            [train, test] = NeuroGLMExport.split(e, TestFraction=0.25);
            ov = (spans(train, 1) < spans(test, 2).') & (spans(train, 2) > spans(test, 1).');
            tc.verifyFalse(any(ov, 'all'), 'No trained trial shares time with a held-out one.');
            tc.verifyTrue(all(ismember([15 16], test)) || all(ismember([15 16], train)), 'The overlapping pair is not split.');
            tc.verifyEqual(sort([train test]), 1:20);
            all1 = [0 3; 1 4; 2 5];                         % every trial overlaps the next: nothing to hold out
            e1 = struct('trial', struct('span', mat2cell(all1, ones(3, 1), 2)));
            tc.verifyWarning(@() NeuroGLMExport.split(e1), 'NeuroGLMExport:NoHoldOut');
            ws = warning('off', 'NeuroGLMExport:NoHoldOut');
            restore = onCleanup(@() warning(ws));
            [train, test] = NeuroGLMExport.split(e1);
            tc.verifyEqual(test, train);
            tc.verifyEqual(train, 1:3);
        end

        function experimentErrors(tc)
            spans = [0 1];
            tc.verifyError(@() NeuroGLMExport.experiment(spans, Values=table(1, 'VariableNames', {'1 bad'})), 'NeuroGLMExport:BadLabel');
            tc.verifyError(@() NeuroGLMExport.experiment(spans, Spikes=struct('a', 0.1), Events=struct('a', 0.2)), ...
                'NeuroGLMExport:DuplicateLabel');
            tc.verifyError(@() NeuroGLMExport.experiment([0 0.0005], Spikes=struct('a', 0.1)), 'NeuroGLMExport:NoTrials');
            tc.verifyError(@() NeuroGLMExport.experiment(spans, Values=table([1; 2])), 'NeuroGLMExport:BadValues');
            tc.verifyError(@() NeuroGLMExport.experiment(spans, Continuous=struct('c', 1)), 'NeuroGLMExport:BadContinuous');
        end

        function sessionSpans(tc)
            D = tc.D;
            [expt, info] = sessionDataNeuroGLM(D);
            tc.verifyEqual(info.trialIndex, setdiff((1:12).', [3 5]), 'Kept trials, minus the one on an erased period.');
            tc.verifyEqual(info.nDroppedArtifact, 1);
            tc.verifyEqual(info.nDroppedEdge, 0);
            T = expt.trial;
            tc.verifyEqual([T(1:end-1).duration], repmat(2200, 1, 9), 'Up to the next trial''s start.');
            tc.verifyEqual(T(end).duration, 5300, 'The last trial runs to the end of the recording.');
            tc.verifyEqual(T(1).span(1), D.toContinuous(1) - 0.5, 'AbsTol', 1e-12);
            tc.verifyEqual(expt.param.key, "k1");
            tc.verifyEqual(expt.param.variables.probeDepth, 1200, 'The dataset''s variables are in the param.');
            tc.verifyEqual(expt.param.trialIndex, info.trialIndex);
            tc.verifyEqual(info.units.variable, ["sp_su001_1"; "sp_su002_2"]);
            tc.verifyEqual(info.lines.on, ["Trial_on"; "Stim_on"; "Resp_on"]);
            tc.verifyEqual(info.lines.off, ["Trial_off"; "Stim_off"; "Resp_off"]);
            tc.verifyEqual(info.values.variable, ["trialIndex"; "group"; "RespCode"; "Depth"; "response"]);
            tc.verifyEqual(info.response, "response");
            tc.verifyEqual(info.responseTime, "");
            tc.verifyEqual(T(1).trialIndex, 1);
            tc.verifyEqual(T(2).trialIndex, 2);
            tc.verifyEqual(T(1).Depth, 0.2);
            tc.verifyEqual(T(2).Depth, 0.8);
            tc.verifyEqual(T(1).RespCode, "Hit");
            tc.verifyEqual(T(1).group, 1);
            tc.verifyEqual(T(2).group, 2);
            tc.verifyEqual(T(1).Stim_on, (tc.StimOn(1) - T(1).span(1)) * 1000, 'AbsTol', 1e-6, 'Events in ms from the trial''s start.');
            tc.verifyEqual(T(1).Stim_off - T(1).Stim_on, 200, 'AbsTol', 1e-6);
            tc.verifyEqual(T(1).Trial_on, 500, 'AbsTol', 1e-6);
            tc.verifyNumElements(T(1).Resp_on, 1);
            tc.verifyEmpty(T(2).Resp_on, 'A line with no pulse on this trial.');
            planted = T(1).Stim_on + [10 12 15 20 30];
            tc.verifyTrue(all(min(abs(T(1).sp_su001_1 - planted), [], 1) < 1e-6), 'The planted spikes, in ms.');
            tc.verifyTrue(all(T(1).sp_su001_1 >= 0 & T(1).sp_su001_1 < T(1).duration));
            % a finite window, every trial, artifacts kept
            e2 = sessionDataNeuroGLM(D, Window=[-0.2 1.0], Trials="all", DropArtifacts=false);
            tc.verifyNumElements(e2.trial, 12);
            tc.verifyTrue(all([e2.trial.duration] == 1200));
            tc.verifyEqual([e2.trial.group], [1 2 0 2 1 2 1 2 1 2 1 2], 'Trial 3 is not kept: group 0.');
            % trials off the recording
            [e3, i3] = sessionDataNeuroGLM(D, Window=[-2 1]);
            tc.verifyEqual(i3.nDroppedEdge, 1);
            tc.verifyEqual(e3.trial(1).trialIndex, 2);
            % a subset of lines and units
            [e4, i4] = sessionDataNeuroGLM(D, Lines="Stim", Units=2);
            tc.verifyEqual(string(fieldnames(e4.type)).', ["sp_su002_2" "Stim_on" "Stim_off" "trialIndex" "group" "RespCode" "Depth" "response"], ...
                'Spike trains, timings, values, then continuous variables.');
            tc.verifyEqual(i4.units.label, "su002_2");
            tc.verifyError(@() sessionDataNeuroGLM(D, Lines="Nope"), 'sessionDataNeuroGLM:NoLine');
            tc.verifyError(@() sessionDataNeuroGLM(D, Align="Nope"), 'sessionDataNeuroGLM:NoColumn');
            tc.verifyError(@() sessionDataNeuroGLM(tc.L), 'sessionDataNeuroGLM:NoSpikes');
        end

        function sessionWithSignal(tc)
            [expt, info] = sessionDataNeuroGLM(tc.D, Window=[-0.2 1.0], Signal=tc.L);
            tc.verifyEqual(info.signal, "LFP");
            tc.verifyEqual(expt.type.LFP, 'continuous');
            tc.verifyEqual(expt.dim.LFP, 2);
            tc.verifyEqual(height(expt.param.channels), 2);
            tr = expt.trial(1);
            tc.verifySize(tr.LFP, [1200 2]);
            r0 = round(tr.span(1) * 1000) + 1;
            tc.verifyEqual(tr.LFP, double(tc.L.signal(r0:r0 + 1199, :)), 'The signal rows of the trial''s bins.');
            bad = tc.L; bad.key = "other";
            tc.verifyError(@() sessionDataNeuroGLM(tc.D, Signal=bad), 'sessionDataNeuroGLM:SignalMismatch');
        end

        function sessionResponses(tc)
            D = tc.D;
            word = D.trials.RespCode;
            [expt, info] = sessionDataNeuroGLM(D, Window=[-0.2 1.0], Trials="all", DropArtifacts=false, ...
                ResponseLine="Resp", ResponseAfter="Stim");
            tc.verifyEqual(string({expt.trial.response}).', word, 'The words, as text.');
            tc.verifyEqual(info.responseTime, "response_time");
            tc.verifyEqual(expt.type.response_time, 'timing');
            tc.verifyEqual(expt.desc.response_time, 'Response (Stim onset then Resp onset)');
            resp = mod((1:height(D.trials)).', 2) == 1;   % the trials with a Resp pulse
            T = expt.trial;
            tc.verifyEqual([T(resp).response_time], [T(resp).Resp_on], 'AbsTol', 1e-6, ...
                'The first Resp onset after the Stim onset.');
            tc.verifyTrue(all(arrayfun(@(t) isempty(t.response_time), T(~resp))), ...
                'No Resp pulse before the next trial''s onset: no response time.');
            eOff = sessionDataNeuroGLM(D, Window=[-0.2 1.0], Trials="all", DropArtifacts=false, ...
                ResponseLine="Resp", ResponseEdge="offset", ResponseAfter="Stim");
            tc.verifyEqual([eOff.trial(resp).response_time], [eOff.trial(resp).Resp_off], 'AbsTol', 1e-6, 'ResponseEdge "offset".');
            % from the digital lines alone: the trial's words and columns play no part
            D3 = D; D3.trials.RespCode(:) = "Miss"; D3.trials.RespLatency(:) = NaN;
            e3 = sessionDataNeuroGLM(D3, Window=[-0.2 1.0], Trials="all", DropArtifacts=false, ...
                ResponseLine="Resp", ResponseAfter="Stim");
            tc.verifyEqual({e3.trial.response_time}, {T.response_time}, 'The same response times, whatever the trial table holds.');
            % the default ResponseAfter, the trial's onset; a line edge on every trial
            exptLong = sessionDataNeuroGLM(D, Window=[-0.2 2.0], Trials="all", DropArtifacts=false, ...
                ResponseLine="Stim", ResponseEdge="offset");
            TL = exptLong.trial;
            tc.verifyEqual([TL.response_time], [TL.Stim_off], 'AbsTol', 1e-6, 'The first Stim offset after each trial onset.');
            % the bit mask: the first listed word that matches, "" with none
            D2 = D;
            D2.trials.RespCode = repmat([1 + 32 + 256 + 1024; 2 + 128 + 1024; 8 + 64 + 256 + 2048; 4 + 128 + 2048], 3, 1);
            expt2 = sessionDataNeuroGLM(D2, Window=[-0.2 2.0], Trials="all", DropArtifacts=false, Responses=["Hit" "Miss" "FA"]);
            tc.verifyEqual(string({expt2.trial(1:4).response}), ["Hit" "Miss" "FA" ""]);
            D4 = D; D4.respField = "";
            [~, i4] = sessionDataNeuroGLM(D4, Window=[-0.2 1.0]);
            tc.verifyEqual(i4.response, "");
            tc.verifyFalse(ismember("response", i4.values.variable));
            tc.verifyError(@() sessionDataNeuroGLM(D, Responses="Nope"), 'sessionDataNeuroGLM:BadResponse');
            tc.verifyError(@() sessionDataNeuroGLM(D, ResponseLine="Nope"), 'sessionDataNeuroGLM:NoLine');
            tc.verifyError(@() sessionDataNeuroGLM(D, ResponseLine="Resp", ResponseAfter="Nope"), 'sessionDataNeuroGLM:NoLine');
            % two splits on different events, the response time acausal
            expt = sessionDataNeuroGLM(D, Window=[-0.2 1.0], Trials="all", DropArtifacts=false, ResponseLine="Resp", ResponseAfter="Stim");
            dspec = NeuroGLMExport.designSpec(expt, Response=1, Events=["Stim_on" "Resp_on" "response_time"], ...
                GroupBy=["group" "response"], GroupEvents={"Stim_on", "Resp_on"}, Acausal="response_time", ...
                KernelMs=100, NBases=4, History=false);
            tc.verifyEqual(string({dspec.covar.label}), ["Stim_on__0" "Stim_on__1" "Stim_on__2" "Resp_on__Hit" "Resp_on__Miss" "response_time"]);
            tc.verifyEqual(dspec.groupBy, ["group" "response"]);
            tc.verifyEqual(dspec.groupLevels, {[0; 1; 2], ["Hit"; "Miss"]});
            F = NeuroGLMExport.fit(dspec);
            tc.verifyEqual(F.kernels.response_time.tr(1), -100);
            % a kernel per word on the response time, its reach before the event apart from its reach after
            dReach = NeuroGLMExport.designSpec(exptLong, Response=1, Events="response_time", GroupBy="response", ...
                GroupEvents="response_time", Acausal="response_time", AcausalMs=300, KernelMs=100, NBases=4, History=false);
            tc.verifyEqual(string({dReach.covar.label}), ["response_time__Hit" "response_time__Miss"]);
            FReach = NeuroGLMExport.fit(dReach);
            tc.verifyEqual(FReach.kernels.response_time__Hit.tr(1), -300);
            tc.verifyEqual(FReach.kernels.response_time__Miss.tr(1), -300);
            tc.verifyLessThan(abs(FReach.kernels.response_time__Hit.tr(end) - 100), 50, 'And still reaches KernelMs after it.');
            % a blank word gets no kernel
            D5 = D2; D5.trials.RespCode(:) = 4 + 128 + 2048; D5.trials.RespCode(1) = 1;
            e5 = sessionDataNeuroGLM(D5, Window=[-0.2 1.0], Trials="all", DropArtifacts=false, Responses="Hit");
            d5 = NeuroGLMExport.designSpec(e5, Events="Stim_on", GroupBy="response", History=false, KernelMs=100, NBases=4);
            tc.verifyEqual(string({d5.covar.label}), "Stim_on__Hit");
            tc.verifyError(@() NeuroGLMExport.designSpec(expt, GroupBy=["group" "response"], GroupEvents={"Stim_on", "Stim_on"}), ...
                'NeuroGLMExport:BadGroupEvents');
            tc.verifyError(@() NeuroGLMExport.designSpec(expt, GroupBy=["group" "response"], GroupEvents="Stim_on"), ...
                'NeuroGLMExport:BadGroupEvents');
        end

        function matRegressFit(tc)
            tc.assumeTrue(NeuroGLMExport.hasMatRegress(), 'matRegress is not on the path.');
            tc.assumeTrue(exist('fminunc', 'file') == 2, 'No Optimization Toolbox.');
            expt = sessionDataNeuroGLM(tc.D, Window=[-0.2 1.2], BinMs=2);
            dspec = NeuroGLMExport.designSpec(expt, Response="sp_su001_1", Events="Stim_on", KernelMs=100, NBases=5, History=false);
            F0 = NeuroGLMExport.fit(dspec);                                   % glmfit, maximum likelihood
            F1 = NeuroGLMExport.fit(dspec, Method="matRegress", Ridge=0);     % the same optimum by fminunc
            tc.verifyEqual(F1.method, "matRegress");
            tc.verifyEqual(F1.ridge, 0);
            tc.verifyEqual(F1.bias, F0.bias, 'AbsTol', 1e-3);
            % a basis function with no spike under it has no maximum (its weight runs to -Inf, se to Inf) and the
            % two optimizers stop at different places: compare the identified weights only
            ok = F0.se < 10;
            tc.verifyGreaterThanOrEqual(nnz(ok), 3, 'Most weights are identified.');
            tc.verifyEqual(F1.w(ok), F0.w(ok), 'AbsTol', 1e-2 * max(1, max(abs(F0.w(ok)))));
            tc.verifyEqual(F1.se(ok), F0.se(ok), 'RelTol', 0.05, 'AbsTol', 1e-3, 'Laplace standard errors match glmfit''s.');
            tc.verifyEqual(F1.logLik, F0.logLik, 'AbsTol', 1e-3);
            tc.verifyEqual(size(F1.stats.covb), [numel(F1.w) + 1, numel(F1.w) + 1]);
            F2 = NeuroGLMExport.fit(dspec, Method="matRegress", Ridge=10);
            tc.verifyEqual(F2.ridge, 10);
            tc.verifyLessThan(norm(F2.w), norm(F1.w), 'The ridge shrinks the weights.');
            tc.verifyLessThan(F2.logLik, F1.logLik + 1e-9);
            tc.verifyGreaterThan(F2.bitsPerSpike, 0);
            grid = [0.1 1 10 100];
            F3 = NeuroGLMExport.fit(dspec, Method="matRegress", Ridge="evidence", RidgeGrid=grid);
            tc.verifyEqual(F3.ridgeGrid, grid);
            tc.verifySize(F3.evidence, [1 4]);
            tc.verifyTrue(all(isfinite(F3.evidence)));
            [~, best] = max(F3.evidence);
            tc.verifyEqual(F3.ridge, grid(best));
            tc.verifyTrue(F2.converged, 'fminunc reached the optimum under the ridge.');
            tc.verifyTrue(islogical(F3.converged) && isscalar(F3.converged));
            P = NeuroGLMExport.predict(F3, 1:2);
            tc.verifyNumElements(P.rate{1}, 700);
            tc.verifyError(@() NeuroGLMExport.fit(dspec, Method="matRegress", Ridge=-1), 'NeuroGLMExport:BadRidge');
            tc.verifyError(@() NeuroGLMExport.fit(dspec, Method="matRegress", Ridge="nope"), 'NeuroGLMExport:BadRidge');
        end

        function designAndFit(tc)
            expt = sessionDataNeuroGLM(tc.D, Window=[-0.2 1.2]);
            dspec = NeuroGLMExport.designSpec(expt, Response="sp_su001_1", Events=["Stim_on" "Resp_on"], ...
                KernelMs=100, NBases=5, HistoryMs=50, HistoryBases=5);
            tc.verifyEqual(dspec.response, "sp_su001_1");
            tc.verifyEqual(string({dspec.covar.label}), ["Stim_on" "Resp_on" "hist"]);
            F = NeuroGLMExport.fit(dspec);
            tc.verifyEqual(F.trials, 1:numel(expt.trial));
            tc.verifyEqual(F.nBins, 1400 * numel(expt.trial));
            tc.verifyEqual(full(F.nSpikes), sum(arrayfun(@(t) numel(t.sp_su001_1), expt.trial)));
            tc.verifyNumElements(F.w, numel(F.se));
            k = F.kernels.Stim_on;
            tc.verifyEqual(k.tr(1), 0);
            tc.verifyEqual(numel(k.tr), 100);
            early = k.tr >= 5 & k.tr <= 35; late = k.tr >= 80;
            tc.verifyGreaterThan(max(k.data(early)), max(k.data(late)) + 0.5, 'A gain where the spikes were planted.');
            tc.verifyGreaterThan(F.bitsPerSpike, 0);
            tc.verifyGreaterThan(F.logLik, F.logLikNull);
            tc.verifyEqual(size(F.kernelSE.Stim_on.data), size(k.data));
            tc.verifyTrue(all(F.kernelSE.Stim_on.data >= 0));
            tc.verifySize(F.rate, [F.nBins 1]);
            P = NeuroGLMExport.predict(F, 1:3);
            tc.verifyEqual(P.trials, 1:3);
            tc.verifyNumElements(P.rate, 3);
            tc.verifyNumElements(P.rate{1}, 1400);
            tc.verifyEqual(P.t{1}(2), 1);
            tc.verifyEqual(sum(P.counts{1}), numel(expt.trial(1).sp_su001_1));
            tc.verifyEqual(P.rate{1}, F.rate(1:1400).', 'AbsTol', 1e-9, 'The same prediction as the fit on its trials.');
            % grouped, acausal and coupling kernels; the continuous covariate
            d2 = NeuroGLMExport.designSpec(expt, Response=1, Events=["Stim_on" "Resp_on"], GroupBy="group", GroupEvents="Stim_on", ...
                Acausal="Resp_on", KernelMs=100, NBases=4, Coupling=true, History=false);
            labels = string({d2.covar.label});
            tc.verifyEqual(labels, ["Stim_on__1" "Stim_on__2" "Resp_on" "coupling_sp_su002_2"]);
            tc.verifyEqual(d2.groupLevels, {[1; 2]});
            tc.verifyEqual(d2.covariates.label.', labels, 'A row of covariates per kernel.');
            tc.verifyEqual(d2.covariates.source.', ["Stim_on" "Stim_on" "Resp_on" "sp_su002_2"]);
            tc.verifyEqual(d2.covariates.kind.', ["event" "event" "event" "coupling"]);
            tc.verifyEqual(d2.covariates.by.', ["group" "group" "" ""]);
            tc.verifyEqual(d2.covariates.level.', ["1" "2" "" ""]);
            F2 = NeuroGLMExport.fit(d2, Trials=1:6);
            tc.verifyEqual(F2.kernels.Resp_on.tr(1), -100, 'An acausal kernel starts KernelMs before the event.');
            tc.verifyEqual(numel(F2.kernels.Resp_on.tr), 200);
            tc.verifyEqual(F2.trials, 1:6);
            P2 = NeuroGLMExport.predict(F2, 7:9);
            tc.verifyEqual(P2.trials, 7:9);
            eL = sessionDataNeuroGLM(tc.D, Window=[-0.2 1.0], Signal=tc.L);
            d3 = NeuroGLMExport.designSpec(eL, Events="Stim_on", History=false);
            tc.verifyEqual(string({d3.covar.label}), ["Stim_on" "LFP"]);
            tc.verifyEqual(d3.covar(2).edim, 2, 'The signal''s two channels.');
            tc.verifyError(@() NeuroGLMExport.designSpec(expt, Response="nope"), 'NeuroGLMExport:BadResponse');
            tc.verifyError(@() NeuroGLMExport.designSpec(expt, Response=3), 'NeuroGLMExport:BadResponse');
            tc.verifyError(@() NeuroGLMExport.designSpec(expt, Events="nope"), 'NeuroGLMExport:BadEvent');
            tc.verifyError(@() NeuroGLMExport.designSpec(expt, GroupBy="nope"), 'NeuroGLMExport:BadGroupBy');
            bare = NeuroGLMExport.experiment([0 1; 1 2], Spikes=struct('a', [0.5; 1.5]));
            tc.verifyError(@() NeuroGLMExport.designSpec(bare, History=false), 'NeuroGLMExport:EmptyDesign');
        end

        function historyFilterEndsAtItsReach(tc)
            % the spike-history filter covers the lags from one bin to HistoryMs after a spike, at any bin size
            for binMs = [1 5]
                expt = sessionDataNeuroGLM(tc.D, Window=[-0.2 1.2], BinMs=binMs);
                d = NeuroGLMExport.designSpec(expt, Response=1, Events="Stim_on", KernelMs=100, NBases=4, HistoryMs=200);
                tc.verifyEqual(d.covariates.kind.', ["event" "history"]);
                hist = d.covar(string({d.covar.label}) == "hist");
                msg = sprintf('%g ms bins', binMs);
                tc.verifySize(hist.basis.B, [200 / binMs, 10], msg);
                tc.verifyEqual(hist.offset, 1, 'A spike acts from the next bin on.');
                tc.verifyEqual((hist.basis.tr([1 end]).' + hist.offset) * binMs, [binMs 200], msg);
                tc.verifyEqual(rank(hist.basis.B), 10, msg);
                [~, peak] = max(hist.basis.B(:, 1));
                tc.verifyEqual(peak, 1, 'The first raised cosine peaks one bin after the spike.');
                tc.verifyLessThan(hist.basis.B(end, end), 0.01, 'The last one is back at zero at HistoryMs.');
            end
            F = NeuroGLMExport.fit(d);
            tc.verifyEqual(F.kernels.hist.tr([1 end]).', [5 200], 'The history kernel''s lags, ms.');
            % too few lags for that many raised cosines: fewer are used, and said
            expt10 = sessionDataNeuroGLM(tc.D, Window=[-0.2 1.2], BinMs=10);
            few = @() NeuroGLMExport.designSpec(expt10, Response=1, Events="Stim_on", HistoryMs=200);
            d10 = tc.verifyWarning(few, 'NeuroGLMExport:HistoryBases');
            B10 = d10.covar(string({d10.covar.label}) == "hist").basis.B;
            tc.verifySize(B10, [20, size(B10, 2)]);
            tc.verifyLessThan(size(B10, 2), 10);
            tc.verifyEqual(rank(B10), size(B10, 2), 'The raised cosines kept are independent.');
            tc.verifyError(@() NeuroGLMExport.designSpec(expt, Events="Stim_on", HistoryMs=5), 'NeuroGLMExport:BadHistory');
            tc.verifyError(@() NeuroGLMExport.designSpec(expt, Events="Stim_on", HistoryBases=1), 'NeuroGLMExport:BadHistory');
        end

        function kernelStandardErrors(tc)
            % a kernel is B * w, so its variance is diag(B * C * B'), C the covariance of its weights
            expt = sessionDataNeuroGLM(tc.D, Window=[-0.2 1.2], BinMs=5, Trials="all", DropArtifacts=false);
            d1 = NeuroGLMExport.designSpec(expt, Response="sp_su002_2", Events="Stim_on", KernelMs=600, NBases=3, History=false);
            F = NeuroGLMExport.fit(d1);
            tc.assertFalse(any(F.dm.constCols), 'Every column is fitted.');
            tc.verifyTrue(F.converged);
            C = F.stats.covb(2:end, 2:end);
            B = d1.covar(1).basis.B;
            tc.verifySize(B, [120 3]);
            tc.verifyEqual(F.kernelSE.Stim_on.data, sqrt(diag(B * C * B.')), 'RelTol', 1e-8, 'AbsTol', 1e-12);
            tc.verifyEqual(F.kernelSE.Stim_on.tr, F.kernels.Stim_on.tr);
            tc.verifyTrue(all(isfinite(F.kernelSE.Stim_on.data)));
            % an event that never comes up in the trials fitted: its kernel is 0 and its error unknown, not 0
            d2 = NeuroGLMExport.designSpec(expt, Response="sp_su002_2", Events=["Stim_on" "Resp_on"], ...
                KernelMs=600, NBases=3, History=false);
            noResp = find(arrayfun(@(t) isempty(t.Resp_on), expt.trial)).';
            tc.assertNumElements(noResp, 6, 'Resp is on the odd trials only.');
            F2 = NeuroGLMExport.fit(d2, Trials=noResp);
            tc.verifyEqual(nnz(F2.dm.constCols), 3, 'The Resp_on columns are constant.');
            tc.verifyEqual(F2.kernels.Resp_on.data, zeros(120, 1));
            tc.verifyTrue(all(isnan(F2.kernelSE.Resp_on.data)));
            tc.verifySize(F2.kernelSE.Resp_on.data, [120 1]);
            tc.verifyFalse(any(isnan(F2.kernelSE.Stim_on.data)));
        end

        function lockedEventsFindsFixedLags(tc)
            % every trial has Stim 300 ms after Trial and 200 ms long; Resp, 50 ms long, is on the odd trials only
            expt = sessionDataNeuroGLM(tc.D, Window=[-0.2 1.2], Trials="all", DropArtifacts=false);
            T = NeuroGLMExport.lockedEvents(expt);
            tc.verifyEqual(T.first, ["Trial_on"; "Trial_on"; "Stim_on"; "Resp_on"]);
            tc.verifyEqual(T.second, ["Stim_on"; "Stim_off"; "Stim_off"; "Resp_off"]);
            tc.verifyEqual(T.lagMs, [300; 500; 200; 50], 'AbsTol', 0.1);
            tc.verifyEqual(T.fractionFirst, ones(4, 1));
            tc.verifyEqual(T.fractionSecond, ones(4, 1));
            tc.verifyEqual(T.nFirst, [12; 12; 12; 6]);
            tc.verifyEqual(T.nSecond, [12; 12; 12; 6]);
            % Resp follows Stim at one lag, but on half of the Stim pulses: the other half tell the kernels apart
            tc.verifyFalse(any(T.first == "Stim_on" & T.second == "Resp_on"));
            T2 = NeuroGLMExport.lockedEvents(expt, WithinMs=250, Trials=1:6);
            tc.verifyEqual(T2.second, ["Stim_off"; "Resp_off"], 'Only the lags the kernels reach across.');
            tc.verifyEqual(T2.nFirst, [6; 3]);
            T3 = NeuroGLMExport.lockedEvents(expt, Events=["Stim_on" "Resp_on"]);
            tc.verifyEqual(height(T3), 0);
            tc.verifyEqual(string(T3.Properties.VariableNames), ...
                ["first" "second" "lagMs" "fractionFirst" "fractionSecond" "nFirst" "nSecond"]);
            tc.verifyError(@() NeuroGLMExport.lockedEvents(expt, Events="Nope"), 'NeuroGLMExport:BadEvent');
        end

        function fitWorkersCap(tc)
            expt = sessionDataNeuroGLM(tc.D, Window=[-0.2 1.0]);
            dspec = NeuroGLMExport.designSpec(expt, Events="Stim_on", History=false);
            tc.verifyEqual(NeuroGLMExport.fitWorkers(dspec, 1:3, 0), 0, 'Asked for no workers.');
            tc.verifyEqual(NeuroGLMExport.fitWorkers(dspec, 1:3, 1), 0, 'One worker is no gain.');
            dspec.expt.trial(1).duration = 1e15;   % a design no memory holds: no pool is started
            n = tc.verifyWarning(@() NeuroGLMExport.fitWorkers(dspec, 1:3, 4), 'NeuroGLMExport:SerialFit');
            tc.verifyEqual(n, 0);
        end
    end
end
