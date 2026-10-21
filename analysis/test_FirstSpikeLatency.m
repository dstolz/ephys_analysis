classdef test_FirstSpikeLatency < matlab.unittest.TestCase
    %test_FirstSpikeLatency  firstSpikeLatency on hand-made spike trains, and the box plot statistics (latencyBoxStats).
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
    %   whiskers, the outliers, NaN left out, none and one value). No
    %   fixture, no toolbox (prctile is MATLAB's).
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
