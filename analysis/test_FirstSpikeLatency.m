classdef test_FirstSpikeLatency < matlab.unittest.TestCase
    %test_FirstSpikeLatency  firstSpikeLatency and responseOnset on hand-made and synthetic spike trains, figureLatencies, and the box plot statistics (latencyBoxStats).
    %   Spike trains and epochs built here on a 30 kHz sample grid (spikes
    %   at (k-1)/Fs, each epoch's event at its t0Continuous on the same
    %   clock), cut by spikePSTH with Raster=true as a figure's raster and
    %   PSTH panels cut them: known latencies (a spike in the event's own
    %   sample at 0, a spike before the event not counted with MinSec 0),
    %   an epoch with no spike in the window NaN, both bounds included to
    %   the sample, MaxSec Inf and past the window's end clipped to the
    %   raster's span, a negative MinSec, several units and Units=, the
    %   trial groups' counts (n, nEpochs), the stop mask (MaskAfterStop),
    %   the spike's time on the continuous clock, and the errors (no raster
    %   rows, a window that ends before it starts, a unit the raster lacks).
    %   latencyBoxStats against prctile and Tukey's fences by hand (the
    %   whiskers, the outliers, NaN left out, none and one value).
    %   The rules: "surprise" (Legendy & Salcman 1985) and "poisson"
    %   (Chase & Young 2007) by hand on planted trains (a burst trimmed of
    %   the spontaneous spike before it; the count's p reached at the
    %   second spike; the unit's and each trial's baseline rate; no
    %   baseline before the event is an error); then on synthetic Poisson
    %   trains with a known onset (a 20 Hz baseline, 250 Hz for 30 ms
    %   from 50 ms with 2 ms of jitter, 200 epochs, a fixed seed): each
    %   rule finds the onset within its tolerance, and in that noisy case
    %   the first-spike rule takes a spontaneous spike for the latency in
    %   most epochs where the Poisson rules rarely do. responseOnset: the
    %   CUSUM by hand on a planted histogram (its baseline mean and SD, the
    %   curve, the onset at the rise's first bin, a crossing that does not
    %   last passed over), the synthetic onset found within 5 ms (every
    %   epoch and each group) and no onset on a baseline alone.
    %   figureLatencies: one latency and one onset per unit for a raster
    %   and a PSTH on the same rows, handed to both, kept in the cache
    %   (an edit of the method takes the latencies again, not the onset).
    %   No fixture; the Poisson rules need the Statistics and Machine
    %   Learning Toolbox (poisscdf).
    %
    %   Usage:  runtests("test_FirstSpikeLatency")

    properties (Constant)
        Fs = 30000
    end

    methods (TestClassSetup)
        function paths(tc) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            addpath(here);
            addpath(fullfile(fileparts(here), 'pipeline'));
        end
    end

    methods (Test)
        function knownLatencies(tc)
            [st, E] = tc.fixture();
            R = spikePSTH(st, E, Window=[-0.1 0.3], BinSec=0.01, Raster=true);
            tc.verifyTrue(all(isnan(firstSpikeLatency(R).spikeTime), 'all'), 'without R.epochs no spike time');
            R.epochs = E;   % as a figure's layer has it (figurePointLayer)
            L = firstSpikeLatency(R);
            want = [10; 0; NaN; 250; 1; NaN] / 1000;   % ms, as planted (fixture)
            tc.verifySize(L.lat, [6 2]);
            tc.verifyEqual(L.lat(:, 1), want, 'AbsTol', 1e-12, ...
                'the first spike at or after 0: 10 ms; one in the event''s own sample at 0; none (NaN); 250 ms; 1 ms; none in the window');
            tc.verifyEqual(L.window, [0 0.3], 'AbsTol', 1e-12, 'MaxSec Inf: up to the raster''s end');
            tc.verifyEqual(L.units, [1 2]);
            tc.verifyEqual(L.spikeTime(:, 1), E.t0Continuous + want, 'AbsTol', 1e-12, 'the spike''s time on the continuous clock');
            tc.verifyEqual(L.lat(:, 2), [NaN; 0.05; 0.05; NaN; NaN; NaN], 'AbsTol', 1e-12, 'the second unit''s own first spikes');
            L2 = firstSpikeLatency(R, Units=2);
            tc.verifyEqual(L2.lat, L.lat(:, 2), 'Units= picks the raster''s units');
        end

        function boundsAreIncluded(tc)
            [st, E] = tc.fixture();
            R = spikePSTH(st, E, Window=[-0.1 0.3], BinSec=0.01, Raster=true);
            Lmin = firstSpikeLatency(R, MinSec=0.010, MaxSec=0.2);
            tc.verifyEqual(Lmin.lat(1, 1), 0.010, 'AbsTol', 1e-12, 'a spike exactly at MinSec counts');
            Lmin2 = firstSpikeLatency(R, MinSec=0.010 + 1 / tc.Fs);
            tc.verifyEqual(Lmin2.lat(1, 1), 0.020, 'AbsTol', 1e-12, 'one sample after it, the next spike');
            Lmax = firstSpikeLatency(R, MaxSec=0.250);
            tc.verifyEqual(Lmax.lat(4, 1), 0.250, 'AbsTol', 1e-12, 'a spike exactly at MaxSec counts');
            Lmax2 = firstSpikeLatency(R, MaxSec=0.250 - 1 / tc.Fs);
            tc.verifyTrue(isnan(Lmax2.lat(4, 1)), 'one sample before it, none');
            Lneg = firstSpikeLatency(R, MinSec=-0.06);
            tc.verifyEqual(Lneg.lat(1, 1), -0.05, 'AbsTol', 1e-12, 'a negative MinSec finds a spike before the event');
            Lpt = firstSpikeLatency(R, MinSec=0, MaxSec=0);
            tc.verifyEqual(Lpt.lat(:, 1), [NaN; 0; NaN; NaN; NaN; NaN], 'AbsTol', 1e-12, 'a window of one instant: the spike on it');
            Lfar = firstSpikeLatency(R, MaxSec=5);
            tc.verifyEqual(Lfar.window, [0 0.3], 'AbsTol', 1e-12, 'MaxSec past the window: clipped to the raster''s span');
            tc.verifyEqual(Lfar.lat, firstSpikeLatency(R).lat, 'and the same latencies as Inf');
        end

        function groupsCounted(tc)
            [st, E] = tc.fixture();
            R = spikePSTH(st, E, Window=[-0.1 0.3], BinSec=0.01, Raster=true);
            L = firstSpikeLatency(R);
            tc.verifyEqual(L.epochGroup, E.groupIndex);
            tc.verifyEqual(L.nEpochs, [3; 3], 'three epochs per group');
            tc.verifyEqual(L.n, [2 2; 2 0], 'per group and unit, the epochs with a first spike');
            tc.verifyEqual(L.groups.label, ["A"; "B"]);
        end

        function stopMask(tc)
            [st, E] = tc.fixture();
            E.t1 = E.t0 + 0.1;   % every epoch stops 100 ms after its event
            R = spikePSTH(st, E, Window=[-0.1 0.3], BinSec=0.01, Raster=true, MaskAfterStop=true);
            L = firstSpikeLatency(R);
            tc.verifyEqual(L.lat(:, 1), [10; 0; NaN; NaN; 1; NaN] / 1000, 'AbsTol', 1e-12, ...
                'masked after the stop event: the 250 ms spike is gone, as from the raster');
        end

        function errors(tc)
            [st, E] = tc.fixture();
            R0 = spikePSTH(st, E, Window=[-0.1 0.3], BinSec=0.01, Raster=false);
            tc.verifyError(@() firstSpikeLatency(R0), 'firstSpikeLatency:NoRaster');
            tc.verifyError(@() firstSpikeLatency(rmfield(R0, 'raster')), 'firstSpikeLatency:NoRaster');
            R = spikePSTH(st, E, Window=[-0.1 0.3], BinSec=0.01, Raster=true);
            tc.verifyError(@() firstSpikeLatency(R, MinSec=0.1, MaxSec=0.05), 'firstSpikeLatency:BadWindow');
            tc.verifyError(@() firstSpikeLatency(R, MinSec=NaN), 'firstSpikeLatency:BadWindow');
            tc.verifyError(@() firstSpikeLatency(R, Units=3), 'firstSpikeLatency:BadUnit');
        end

        function surpriseByHand(tc)
            % a baseline of 10 Hz (2 spikes in each epoch's 200 ms before the event), then in epoch 1 a lone spike at
            % 10 ms and a burst at 40-43 ms: the seed starts at the lone spike (its interval, 30 ms, is under 50 ms), the
            % burst grows to 43 ms, and shedding the lone spike raises the surprise, so the latency is 40 ms; epoch 2 has
            % only spaced spikes (none under 50 ms apart): no burst
            Fs = tc.Fs;
            [st, E] = tc.planted({[-150 -50 10 40 41 42 43], [-150 -50 20 120 220]}, Fs);
            R = spikePSTH(st, E, Window=[-0.2 0.3], BinSec=0.01, Raster=true);
            L = firstSpikeLatency(R, Method="surprise", Surprise=3, MinSpikes=3);
            tc.verifyEqual(L.rate, [10; 10], 'AbsTol', 1e-9, 'the unit''s baseline rate: 4 spikes in 2 x 200 ms');
            tc.verifyEqual(L.lat, [0.040; NaN], 'AbsTol', 1e-12, 'the burst''s first spike once the lone one is shed; no burst');
            S = @(n, T) -log10(poisscdf(n - 1, 10 * T, 'upper'));
            tc.verifyGreaterThan(S(4, 0.003), S(5, 0.033), 'by hand: the burst alone is the more surprising');
            Lhi = firstSpikeLatency(R, Method="surprise", Surprise=S(4, 0.003) + 0.1);
            tc.verifyTrue(all(isnan(Lhi.lat)), 'a threshold above the burst''s surprise: none');
            L1 = firstSpikeLatency(R);
            tc.verifyEqual(L1.lat, [0.010; 0.020], 'AbsTol', 1e-12, 'the first-spike rule takes the lone spike');
            tc.verifyEqual(L.method, "surprise");
            tc.verifyEqual(L.baseline, [-0.2 0], 'AbsTol', 1e-12, 'the baseline: the window before the event');
        end

        function poissonByHand(tc)
            % a baseline of 10 Hz; spikes at 5, 6, 7 ms: P(N >= 1) at 5 ms = 1 - exp(-0.05) = 0.049 > 0.01, P(N >= 2) at
            % 6 ms = 0.0018 < 0.01: the latency is the second spike, 6 ms
            Fs = tc.Fs;
            [st, E] = tc.planted({[-150 -50 5 6 7], [-150 -50 100 200]}, Fs);
            R = spikePSTH(st, E, Window=[-0.2 0.3], BinSec=0.01, Raster=true);
            L = firstSpikeLatency(R, Method="poisson", Alpha=0.01);
            tc.verifyEqual(L.lat, [0.006; NaN], 'AbsTol', 1e-12, 'the spike at which the count turns improbable; none');
            L05 = firstSpikeLatency(R, Method="poisson", Alpha=0.05);
            tc.verifyEqual(L05.lat(1), 0.005, 'AbsTol', 1e-12, 'alpha 0.05: the first spike already (p 0.049)');
            Lt = firstSpikeLatency(R, Method="poisson", BaselineRate="trial", Baseline=[-0.1 0]);
            tc.verifyEqual(Lt.rate, [10; 10], 'AbsTol', 1e-9, 'each trial''s own rate: one spike in its 100 ms');
            Lw = firstSpikeLatency(R, Method="poisson", Baseline=[-0.04 0]);
            tc.verifyEqual(Lw.rate, [0; 0], 'a baseline window with no spike: rate 0');
            tc.verifyEqual(Lw.lat, [0.005; 0.1], 'AbsTol', 1e-12, 'at rate 0 any spike is improbable: the first one');
            R0 = spikePSTH(st, E, Window=[0 0.3], BinSec=0.01, Raster=true);
            tc.verifyError(@() firstSpikeLatency(R0, Method="poisson"), 'firstSpikeLatency:NoBaseline');
            tc.verifyError(@() firstSpikeLatency(R0, Method="surprise"), 'firstSpikeLatency:NoBaseline');
            tc.verifyEqual(firstSpikeLatency(R0).lat, [0.005; 0.1], 'AbsTol', 1e-12, 'the first-spike rule needs no baseline');
        end

        function noisyOnset(tc)
            % synthetic trains, a known onset: each rule within its tolerance, and the Poisson rules' benefit
            [R, truth, onset] = tc.synthetic(250);
            L1 = firstSpikeLatency(R).lat;
            L2 = firstSpikeLatency(R, Method="surprise").lat;
            L3 = firstSpikeLatency(R, Method="poisson").lat;
            exact = @(x) mean(abs(x - truth) < 5e-4);
            early = @(x) mean(x < truth - 5e-4);
            tc.verifyGreaterThan(early(L1), 0.4, 'noisy: the first-spike rule takes a spontaneous spike in most epochs');
            tc.verifyLessThan(early(L2), 0.3, 'Poisson surprise: few spontaneous spikes taken');
            tc.verifyLessThan(early(L3), 0.1, 'Poisson count: fewer still');
            tc.verifyGreaterThan(exact(L2), exact(L1) + 0.2, 'Poisson surprise finds the first response spike far more often');
            tc.verifyLessThan(abs(median(L2 - truth, 'omitnan')), 1e-3, 'Poisson surprise: its median error under 1 ms');
            tc.verifyLessThan(abs(median(L2, 'omitnan') - onset), 0.006, 'Poisson surprise: the median latency within 6 ms of the onset');
            lag = median(L3 - truth, 'omitnan');
            tc.verifyTrue(lag >= 0 && lag < 0.02, sprintf(['Poisson count: at or after the first response spike, the ' ...
                'count''s detection lag under 20 ms (%.1f ms)'], 1000 * lag));
            tc.verifyLessThan(abs(median(L1, 'omitnan') - onset), 0.04, 'sanity: the first-spike rule''s median is far from it too');
            tc.verifyGreaterThan(abs(median(L1, 'omitnan') - onset), 0.006, 'the first-spike rule''s median misses the onset');
            tc.verifyLessThan(mean(isnan(L2)) + mean(isnan(L3)), 0.3, 'few epochs without a latency');
        end

        function cusumByHand(tc)
            % a planted histogram of 10 ms bins over 10 epochs: before the event 1, 3, 1, 3, ... spikes a bin (10 and 30
            % spikes/s: mean 20, SD 10.54), then 2 a bin for 20 ms and 12 a bin after: the CUSUM (allowance 1 SD) stays
            % 0, rises in the 20-30 ms bin past 5 SD and stays: the onset is 20 ms
            nE = 10;
            counts = [repmat([1 3], 1, 10) 2 2 12 12 12 12 12 12 12 12];   % bins of [-0.2 0.2]
            [R, edges] = tc.histogramRaster(counts, nE, -0.2, 0.01);
            O = responseOnset(R, BinSec=0.01, Threshold=5, Drift=1, SustainSec=0.01, MaxSec=0.2);
            x = counts / (nE * 0.01);
            m = mean(x(1:20));
            s = std(x(1:20));
            z = (x(21:end) - m) / s - 1;
            C = zeros(numel(z), 1);
            c = 0;
            for i = 1:numel(z); c = max(0, c + z(i)); C(i) = c; end
            tc.verifyEqual(O.baselineMean, m, 'AbsTol', 1e-9, 'the baseline mean: 20 spikes/s');
            tc.verifyEqual(O.baselineSD, s, 'AbsTol', 1e-9, 'the baseline SD');
            tc.verifyEqual(O.t, edges(21:end-1).', 'AbsTol', 1e-12, 'the bins searched: from the event');
            tc.verifyEqual(O.cusum, C, 'AbsTol', 1e-9, 'Page''s CUSUM in baseline SDs, less the allowance');
            tc.verifyEqual(O.onset, 0.02, 'AbsTol', 1e-12, 'the onset: the rise''s first bin');
            tc.verifyEqual(O.groupOnset, 0.02, 'AbsTol', 1e-12, 'one group: the same');
            % a crossing that does not last: one bin of 12 at 0-10 ms, then the baseline again, then the response at 100 ms
            counts2 = [repmat([1 3], 1, 10) 12 2 2 2 2 2 2 2 2 2 12 12 12 12 12 12 12 12 12 12];
            R2 = tc.histogramRaster(counts2, nE, -0.2, 0.01);
            O2 = responseOnset(R2, BinSec=0.01, Threshold=5, Drift=1, SustainSec=0.02);
            tc.verifyEqual(O2.onset, 0.1, 'AbsTol', 1e-12, 'a crossing that falls back is passed over');
            O3 = responseOnset(R2, BinSec=0.01, Threshold=5, Drift=1, SustainSec=0);
            tc.verifyEqual(O3.onset, 0, 'AbsTol', 1e-12, 'without a sustain the first crossing counts');
            tc.verifyError(@() responseOnset(R2, Baseline=[0.5 0.6]), 'responseOnset:NoBaseline');
            tc.verifyError(@() responseOnset(R2, MinSec=0.1, MaxSec=0.05), 'responseOnset:BadWindow');
        end

        function syntheticOnset(tc)
            [R, ~, onset] = tc.synthetic(250);
            O = responseOnset(R);
            tc.verifyLessThan(abs(O.onset - onset), 0.005, sprintf('the CUSUM onset within 5 ms of the onset (%.1f ms)', 1000 * O.onset));
            tc.verifyLessThan(max(abs(O.groupOnset - onset)), 0.006, 'each group''s onset within 6 ms of it');
            Ow = responseOnset(tc.synthetic(80));
            tc.verifyLessThan(abs(Ow.onset - onset), 0.006, 'a weaker response (80 Hz) too');
            n = 0;
            for k = 1:10
                O0 = responseOnset(tc.synthetic(0, k));
                n = n + any(isfinite([O0.onset; O0.groupOnset(:)]));
            end
            tc.verifyEqual(n, 0, 'no onset on a baseline alone (10 synthetic runs, every epoch and each group)');
        end

        function figureOncePerUnit(tc)
            % a raster with its marks and a PSTH with its box plot and group onsets on the same rows: one latency and one
            % onset taken, both panels handed them; an edit of the method takes the latencies again, the onset kept
            R = tc.synthetic(250);
            lay = struct('name', "", 'skip', "", 'R', R);
            P = struct('id', {"raster_1" "psth_1"}, 'skip', "", 'layers', {lay lay});
            o1 = struct('firstSpike', struct('enabled', true), 'rasterSort', "", 'onsetLine', "off");
            o2 = struct('latencyBox', struct('enabled', true), 'display', "trace", 'onsetLine', "groups");
            spec = struct('panels', struct('id', {"raster_1" "psth_1"}, 'type', {"raster" "psth"}, 'options', {o1 o2}), ...
                'latency', EphysAnalysisConfig.defaults("Latency"));
            C = struct('on', true, 'pool', [], 'dataset', "d", ...
                'K', struct('kind', {}, 'dataset', {}, 'key', {}, 'value', {}, 'bytes', {}, 'from', {}));
            [P1, S1, C1] = figureLatencies(spec, P, C);
            made = @(K, kind) nnz([K.kind] == kind & [K.from] == 0);
            tc.verifyEqual([made(C1.K, "latency") made(C1.K, "onset")], [1 1], 'one latency and one onset for the unit');
            tc.verifyEqual(P1(1).layers(1).R.latency, P1(2).layers(1).R.latency, 'both panels hold the one latency');
            tc.verifyFalse(isfield(P1(1).layers(1).R, 'onset'), 'the raster draws no onset: none handed to it');
            tc.verifyTrue(isfield(P1(2).layers(1).R, 'onset') && P1(2).layers(1).R.onset.why == "", 'the PSTH''s onset');
            tc.verifyEqual(numel(S1.entries), 1, 'F.latency: one entry, the unit');
            tc.verifyEqual(S1.entries.panels, ["raster_1" "psth_1"], 'read by both panels');
            L = firstSpikeLatency(R);
            tc.verifyEqual(P1(1).layers(1).R.latency.lat, L.lat, 'the block''s rule: the first spike, 0 to the end');
            spec2 = spec;
            spec2.latency.method = "surprise";
            C2 = C;
            C2.pool = C1.K;
            [P2, ~, C2] = figureLatencies(spec2, P, C2);
            tc.verifyEqual([made(C2.K, "latency") made(C2.K, "onset")], [1 0], 'a method edit: the latencies again, the onset kept');
            tc.verifyEqual(P2(2).layers(1).R.latency.lat, firstSpikeLatency(R, Method="surprise").lat);
            spec3 = spec;
            spec3.latency.baseline = "window";
            spec3.latency.baselineWindow = [5 6];   % past the window: no baseline, said in why
            P3 = figureLatencies(spec3, P);
            tc.verifyTrue(P3(1).layers(1).R.latency.why == "" && contains(P3(2).layers(1).R.onset.why, "baseline"), ...
                'the first-spike rule needs no baseline; the onset says why it has none');
        end

        function boxStatistics(tc)
            v = [0.012 0.015 0.011 NaN 0.020 0.013 0.090 0.014 0.016 -0.040 0.018].';
            B = latencyBoxStats(v);
            x = v(isfinite(v));
            q = prctile(x, [25 50 75]);
            iq = q(3) - q(1);
            f = [q(1) - 1.5 * iq, q(3) + 1.5 * iq];
            in = x >= f(1) & x <= f(2);
            tc.verifyEqual(B.n, 10, 'NaN (no first spike) left out');
            tc.verifyEqual(B.q, q(:).', 'AbsTol', 1e-15, 'the quartiles and the median are prctile''s');
            tc.verifyEqual(B.iqr, iq, 'AbsTol', 1e-15);
            tc.verifyEqual(B.fences, f, 'AbsTol', 1e-15, 'Tukey''s fences: 1.5 IQR beyond the box');
            tc.verifyEqual(B.whiskers, [min(x(in)) max(x(in))], 'the whiskers: the most extreme values inside the fences');
            tc.verifyEqual(B.outliers, sort(x(~in)), 'the outliers: the values beyond them, ascending');
            tc.verifyEqual(B.outliers, [-0.040; 0.090]);
            B0 = latencyBoxStats(NaN(3, 1));
            tc.verifyEqual(B0.n, 0);
            tc.verifyTrue(all(isnan([B0.q B0.whiskers])) && isempty(B0.outliers), 'no value: NaN, no outlier');
            B1 = latencyBoxStats(0.02);
            tc.verifyEqual([B1.q B1.whiskers], repmat(0.02, 1, 5), 'one value: box, median and whiskers on it');
            tc.verifyEmpty(B1.outliers);
        end
    end

    methods (Static)
        function [st, E] = planted(perEpoch, Fs)
            %planted  One unit's spikes planted in ms from each epoch's event (cell PERPEOCH), epochs 2 s apart, one group.
            nE = numel(perEpoch);
            row0 = 30001 + (0:nE - 1).' * 60000;
            t0 = (row0 - 1) / Fs;
            s = [];
            for e = 1:nE
                s = [s; (row0(e) - 1 + round(perEpoch{e}(:) * Fs / 1000)) / Fs]; %#ok<AGROW>
            end
            st = {sort(s)};
            E = test_FirstSpikeLatency.epochs(t0, ones(nE, 1));
        end

        function E = epochs(t0, g)
            %epochs  epochTable's columns for events at T0 (s on the spikes' clock), groups G (labels A, B).
            nE = numel(t0);
            labels = ["A"; "B"];
            E = table((1:nE).', (1:nE).', t0, t0, NaN(nE, 1), t0 - 0.5, t0 + 1, repmat(1.5, nE, 1), true(nE, 1), ...
                false(nE, 1), g, labels(g), 'VariableNames', {'epoch', 'trial', 't0', 't0Continuous', 't1', 'tStart', ...
                'tStop', 'duration', 'complete', 'artifact', 'groupIndex', 'group'});
        end

        function [R, truth, onset] = synthetic(respHz, seed)
            %synthetic  200 epochs (groups A, B) of a 20 Hz Poisson unit and, from 50 ms (2 ms jitter), RESPHZ for 30 ms.
            %   TRUTH: each epoch's first response spike (NaN: none); R: spikePSTH over [-0.2 0.3] s with its rows.
            if nargin < 2; seed = 0; end
            rs = RandStream('mt19937ar', 'Seed', 17 + seed);
            Fs = test_FirstSpikeLatency.Fs;
            nE = 200;
            onset = 0.05;
            row0 = 30001 + (0:nE - 1).' * 60000;
            t0 = (row0 - 1) / Fs;
            g = 1 + mod((0:nE - 1).', 2);
            st = [];
            truth = NaN(nE, 1);
            for e = 1:nE
                s = test_FirstSpikeLatency.poissonTrain(rs, 20, -1, 1);
                if respHz > 0
                    on = onset + 0.002 * randn(rs);
                    b = test_FirstSpikeLatency.poissonTrain(rs, respHz, on, on + 0.03);
                    b = round(b * Fs) / Fs;
                    if ~isempty(b); truth(e) = min(b); end
                    s = [s; b]; %#ok<AGROW>
                end
                st = [st; t0(e) + round(s * Fs) / Fs]; %#ok<AGROW>
            end
            R = spikePSTH({sort(st)}, test_FirstSpikeLatency.epochs(t0, g), Window=[-0.2 0.3], BinSec=0.01, Raster=true);
        end

        function t = poissonTrain(rs, hz, a, b)
            %poissonTrain  A Poisson train of rate HZ in [A, B) s (exponential intervals from the stream RS).
            t = zeros(0, 1);
            x = a - log(rand(rs)) / hz;
            while x < b
                t(end+1, 1) = x; %#ok<AGROW>
                x = x - log(rand(rs)) / hz;
            end
        end

        function [R, edges] = histogramRaster(counts, nE, lo, b)
            %histogramRaster  Raster rows over NE epochs whose bins of B s from LO hold COUNTS spikes (spread inside the bin, epoch by epoch).
            Fs = test_FirstSpikeLatency.Fs;
            edges = lo + (0:numel(counts)) * b;
            t = [];
            ep = [];
            for k = 1:numel(counts)
                i = (1:counts(k)).';
                t = [t; edges(k) + b * (i - 0.5) / counts(k)]; %#ok<AGROW>   % spread inside the bin
                ep = [ep; mod(i - 1, nE) + 1]; %#ok<AGROW>
            end
            row0 = 30001 + (0:nE - 1).' * 60000;
            t0 = (row0 - 1) / Fs;
            st = sort(t0(ep) + t);
            R = spikePSTH({st}, test_FirstSpikeLatency.epochs(t0, ones(nE, 1)), Window=[edges(1) edges(end)], BinSec=b, Raster=true);
        end

        function [st, E] = fixture()
            %fixture  Six epochs (groups A, A, A, B, B, B) 2 s apart on a 30 kHz grid, two units with planted spikes.
            %   Unit 1, per epoch, in samples from the event: 1: -1500 (-50 ms),
            %   300 (10 ms), 600 (20 ms); 2: 0 (the event's own sample), 90;
            %   3: none in [0 0.3] s (one at -60 ms, one at 400 ms, outside);
            %   4: 7500 (250 ms); 5: 30 (1 ms), 3000; 6: none. Unit 2: 1500
            %   (50 ms) in epochs 2 and 3 only.
            Fs = test_FirstSpikeLatency.Fs;
            nE = 6;
            row0 = 30001 + (0:nE - 1).' * 60000;   % each event's sample
            t0 = (row0 - 1) / Fs;                  % on the spikes' clock: sample k at (k-1)/Fs
            g = [1; 1; 1; 2; 2; 2];
            planted = {[-1500 300 600], [0 90], [-1800 12000], 7500, [30 3000], []};
            s1 = [];
            for e = 1:nE
                s1 = [s1; (row0(e) - 1 + planted{e}(:)) / Fs]; %#ok<AGROW>
            end
            s2 = (row0([2 3]) - 1 + 1500) / Fs;
            st = {sort(s1); sort(s2)};
            labels = ["A"; "B"];
            E = table((1:nE).', (1:nE).', t0, t0, NaN(nE, 1), t0 - 0.5, t0 + 1, repmat(1.5, nE, 1), true(nE, 1), ...
                false(nE, 1), g, labels(g), 'VariableNames', {'epoch', 'trial', 't0', 't0Continuous', 't1', 'tStart', ...
                'tStop', 'duration', 'complete', 'artifact', 'groupIndex', 'group'});
        end
    end
end
