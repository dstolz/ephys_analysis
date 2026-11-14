classdef test_RippleStrf < matlab.unittest.TestCase
    %test_RippleStrf  rippleStrf, rippleStimuli and the STRF panel (TORCs and dynamic moving ripples).
    %   rippleStrf on hand-made records and envelopes (the test's own
    %   Eq. 28 of Klein et al. 2000 for a TORC, Eq. 1 of Escabi & Schreiner
    %   2002 for a DMR, passed as Envelope= and Trajectory=, so no stimgen
    %   is needed): a TORC's STRF is the lag sums over a^2 T, equal to a
    %   direct sum over the period, and to the closed form of a neuron
    %   whose rate follows one pixel of the envelope; its RTF peaks at the
    %   stimulus ripple (Klein's Eq. 14 sign: w > 0, Omega > 0 a
    %   downward-moving ripple); a DMR's STRF is the lag sums over sigma^2 T
    %   with its 3.09-SD threshold, its CRH the spikes counted at Fm and
    %   Omega, its energy and phase-locking index read from the significant
    %   pixels; TORCs of one ripple set averaged, of disjoint sets summed,
    %   of overlapping sets refused; two sets compared (SI, RDI); the
    %   refusals (mixed stimuli, a skip shorter than a DMR's lags, a lag of
    %   a TORC's period). Then, on makeAnalysisFixture's "clean" dataset,
    %   rippleStimuli matching a presentation log to the Stim onsets (the
    %   count and the intervals checked, a bank item kept) and reading the
    %   variant from a trial column with a DMR-export-style file, and an
    %   STRF figure computed and drawn in its three views (stimgen's
    %   stimgen.TORC.envelope_from_record, or a stand-in written here with
    %   the same Eq. 28 when stimgen is not on the path).
    %
    %   Usage:  runtests("test_RippleStrf")

    properties
        Fx      % makeAnalysisFixture's struct (TestClassSetup)
        Src     % its dataset's source
        Root    % the fixture's temporary folder
    end

    methods (TestClassSetup)
        function makeFixture(tc)
            tc.Root = string(tempname);
            mkdir(tc.Root);
            tc.addTeardown(@() rmdir(tc.Root, 's'));
            tc.Fx = makeAnalysisFixture(tc.Root, Scenarios="clean", NumTrials=12);
            tc.Src = loadAnalysisSource(tc.Fx.outputs(1));
        end
    end

    methods (Test)

        function torcStrfIsTheLagSumOverAmplitudeSquared(tc)
            [R, d] = torcCase();
            s = R.sets;
            tc.verifyEqual(s.kind, "TORC");
            tc.verifyEqual(size(s.strf), [20 400]);
            tc.verifyEqual(s.lags, (0:399) / 4000, 'AbsTol', 1e-15);
            tc.verifyEqual(s.nSpikes, sum(d.n));
            tc.verifyEqual(s.duration, 0.25, 'AbsTol', 1e-15);
            % a direct sum over the period: lags before the onset read the period before (the envelope is periodic)
            Cd = zeros(20, 400);
            for j = 0:399
                Cd(:, j + 1) = torcEnv(d.r, mod((d.b.' - j) / 4000, 0.25)) * d.n;
            end
            direct = Cd / (d.r.RippleAmplitude ^ 2 * 0.25);
            tc.verifyEqual(s.strf, direct, 'AbsTol', 1e-9 * max(abs(direct(:))));
            tc.verifyEqual(s.strfRate, s.strf);   % a TORC's STRF is drawn as it is
            % the closed form: the rate follows the envelope at (tau0, x0), so C/a^2 = 2 x 20 x 1000 / T cos(...)
            [tau, xx] = meshgrid(s.lags, s.x);
            cf = 2 * 20 * 1000 / 0.25 * cos(2 * pi * (20 * (tau - 0.02) + 0.4 * (2 - xx)));
            tc.verifyLessThan(max(abs(s.strf(:) - cf(:))), 0.01 * 160000);
            % the null: z SD of a sum of N envelope values (mean square 2a^2 = 50), over a^2 T
            z = sqrt(2) * erfcinv(0.002);
            tc.verifyEqual(s.threshold, z * sqrt(s.nSpikes * 50) / (25 * 0.25), 'RelTol', 1e-9);
            tc.verifyEqual(s.sig, abs(s.strf) > s.threshold);
            tc.verifyTrue(isnan(s.energy) && isnan(s.pli) && isempty(s.crh));   % Escabi & Schreiner's, not a TORC's
            tc.verifyTrue(isnan(s.snrMean) || s.snrMax >= s.snrMean);   % 100 spikes of a 2% modulation: likely none significant
        end

        function torcRtfPeaksAtTheStimulusRipple(tc)
            R = torcCase();
            b = R.sets.best;
            % the RTF's grid: 10 Hz (400 lags of 0.25 ms) by 0.2 c/o (20 carriers over 5 octaves)
            tc.verifyEqual(R.sets.rtfFm(2) - R.sets.rtfFm(1), 10, 'AbsTol', 1e-9);
            tc.verifyEqual(R.sets.rtfOmega(2), 0.2, 'AbsTol', 1e-12);
            tc.verifyEqual(b.fm, 20, 'AbsTol', 1e-9);
            tc.verifyEqual(b.omega, 0.4, 'AbsTol', 1e-12);
            tc.verifyLessThan(b.magNeg, 0.5 * b.magnitude);
            tc.verifyFalse(b.secondary);
        end

        function torcSetsAveragedOrSummed(tc)
            % one ripple set at two phases: their STRFs averaged (Eq. 33-34); two disjoint sets: summed (Eq. 39)
            env = @(r, t) torcEnv(r, t);
            r1 = torcRecord(20, 0.4, 0.3, 5);
            r2 = torcRecord(20, 0.4, 1.7, 4);
            r3 = torcRecord(40, -0.8, 0.9, 5);
            t1 = spikesFor(r1, 7);
            t2 = spikesFor(r2, 8);
            t3 = spikesFor(r3, 9);
            one = @(t, r) rippleStrf({t}, {r}, 1, 1, MaxLag=0.05, Envelope=env).sets.strf;
            A = rippleStrf({t1; t2}, {r1 r2}, [1; 2], [1; 1], MaxLag=0.05, Envelope=env);
            tc.verifyEqual(A.sets.strf, (one(t1, r1) + one(t2, r2)) / 2, 'AbsTol', 1e-9 * max(abs(A.sets.strf(:))));
            tc.verifyEqual(A.sets.rippleSets, 1);
            B = rippleStrf({t1; t3}, {r1 r3}, [1; 2], [1; 1], MaxLag=0.05, Envelope=env);
            tc.verifyEqual(B.sets.strf, one(t1, r1) + one(t3, r3), 'AbsTol', 1e-9 * max(abs(B.sets.strf(:))));
            tc.verifyEqual(B.sets.rippleSets, 2);
            r4 = torcRecord([20 60], [0.4 0.4], [0.3 0.1], 5);   % shares (20 Hz, 0.4 c/o) with r1
            tc.verifyError(@() rippleStrf({t1; t1}, {r1 r4}, [1; 2], [1; 1], MaxLag=0.05, Envelope=env), 'rippleStrf:Overlap');
        end

        function dmrStrfSignificanceCrhAndStatistics(tc)
            [r, env, traj] = dmrRecord();
            rs = RandStream('mt19937ar', 'Seed', 7);
            t = sort(rand(rs, 3000, 1) * 2);
            R = rippleStrf({t}, {r}, 1, 1, Rate=4000, MaxLag=0.05, Envelope=env, Trajectory=traj, CrhBins=[25 0.25]);
            s = R.sets;
            tc.verifyEqual(s.kind, "DMR");
            tc.verifyEqual(s.skip, 0.05);   % automatic: the longest lag
            k = t(t >= 0.05 & t < 2);
            b = round(k * 4000);
            tc.verifyEqual(s.nSpikes, numel(k));
            T = 2 - 0.05;   % (as rippleStrf computes it)
            nq = max(1, min(ceil(T * 4000), 20000));
            tq = 0.05 + (0:nq - 1) * (T / nq);
            Sq = env(r, tq);
            sigma2 = mean(Sq(:) .^ 2);
            tc.verifyEqual(s.sigma2, sigma2, 'RelTol', 1e-12);
            tc.verifyEqual(sigma2, 30 ^ 2 / 8, 'RelTol', 0.05);   % M^2/8 for a DMR
            C = zeros(16, 201);
            for j = 0:200
                C(:, j + 1) = sum(env(r, (b.' - j) * (1 / 4000)), 2);
            end
            strf = C / (sigma2 * T);
            tc.verifyEqual(s.strf, strf, 'AbsTol', 1e-9 * max(abs(strf(:))));
            z = sqrt(2) * erfcinv(0.002);
            tc.verifyEqual(s.threshold, z * sqrt(numel(k) * sigma2) / (sigma2 * T), 'RelTol', 1e-9);   % z sqrt(N) / (sigma T)
            tc.verifyEqual(s.strfRate, sqrt(sigma2) * s.strf, 'RelTol', 1e-12);
            sigS = s.strfRate .* s.sig;
            tc.verifyEqual(s.strfSig, sigS);
            tc.verifyEqual(s.energy, sqrt(sum(sigS(:) .^ 2) / 4000), 'RelTol', 1e-12);
            delta = (max(Sq(:)) - min(Sq(:))) / sqrt(sigma2);
            tc.verifyEqual(s.delta, delta, 'RelTol', 1e-12);
            tc.verifyEqual(s.pli, (max(sigS(:)) - min(sigS(:))) / (numel(k) / T) / delta, 'RelTol', 1e-12);
            tr = traj(r, k.');
            tc.verifyEqual(s.crh, histcounts2(tr.Omega, tr.Fm, 0:0.25:4, -350:25:350));
            tc.verifyEqual(s.crhOmegaEdges, 0:0.25:4, 'AbsTol', 1e-12);
            tc.verifyEqual(s.crhFmEdges, -350:25:350, 'AbsTol', 1e-12);
            tc.verifyEqual(sum(s.crhOccupancy(:)), T, 'RelTol', 1e-9);   % every second of stimulus analyzed, once
        end

        function setsAreCompared(tc)
            [~, d] = torcCase();
            env = @(r, t) torcEnv(r, t);
            R = rippleStrf({d.t; d.t}, {d.r}, [1; 1], [1; 2], SetLabels=["A" "B"], MaxLag=0.09975, Envelope=env);
            C = R.compare;
            tc.verifyEqual(C.a, "A");
            tc.verifyEqual(C.b, "B");
            tc.verifyEqual(C.si, 1, 'AbsTol', 1e-12);
            tc.verifyEqual(C.rdi, 0);
            tc.verifyTrue(isnan(C.mdi));   % no energy for a TORC
            half = d.t(1:2:end);
            R2 = rippleStrf({d.t; half}, {d.r}, [1; 1], [1; 2], MaxLag=0.09975, Envelope=env);
            ra = numel(d.t) / 0.25;
            rb = numel(half) / 0.25;
            tc.verifyEqual(R2.compare.rdi, 100 * (ra / rb - 1), 'RelTol', 1e-12);   % Eq. 12, ra > rb
            R3 = rippleStrf({half; d.t}, {d.r}, [1; 1], [1; 2], MaxLag=0.09975, Envelope=env);
            tc.verifyEqual(R3.compare.rdi, -R2.compare.rdi, 'RelTol', 1e-12);   % antisymmetric
        end

        function refusals(tc)
            env = @(r, t) torcEnv(r, t);
            rt = torcRecord(20, 0.4, 0.3, 5);
            [rd, envD] = dmrRecord();
            both = @(rec, t) mixedEnv(rec, t, env, envD);
            tc.verifyError(@() rippleStrf({0.1; 0.1}, {rt rd}, [1; 2], [1; 1], Envelope=both), 'rippleStrf:MixedStimuli');
            tc.verifyError(@() rippleStrf({0.5}, {rd}, 1, 1, MaxLag=0.05, Skip=0.01, Envelope=envD), 'rippleStrf:Skip');
            tc.verifyError(@() rippleStrf({0.1}, {rt}, 1, 1, MaxLag=0.25, Envelope=env), 'rippleStrf:MaxLag');
            tc.verifyError(@() rippleStrf({0.1}, {rt}, 1, 1, Skip=0.3, MaxLag=0.05, Envelope=env), 'rippleStrf:Skip');
            % mixed kinds in different sets are fine: each set has its own
            R = rippleStrf({0.1; 0.5}, {rt rd}, [1; 2], [1; 2], MaxLag=0.05, Envelope=both, Trajectory=@(r, t) dmrTraj(t));
            tc.verifyEqual([R.sets.kind], ["TORC" "DMR"]);
            tc.verifyTrue(isnan(R.compare.si));   % other grids
        end

        function presentationLogIsMatchedByOnsets(tc)
            src = tc.Src;
            on = double(src.events.Stim(:, 1));
            n = numel(on);
            tc.assumeGreaterThan(n, 3, 'The fixture has too few Stim onsets.');
            recs = cell(1, n);
            for k = 1:n; recs{k} = torcRecord(20 + 4 * mod(k, 3), 0.4, 0.1 * k, 5); end
            jitter = 0.0005 * (-1) .^ (1:n).';
            f = writeLog(tc.Root, "log_ok", recs, on - on(1) + jitter, ones(n, 1), (1:n).');
            ref = eventRef(line="Stim", which="all", scope="recording");
            E = epochTable(src, ref);
            stim = struct('source', "log", 'file', f, 'item', "", 'parameter', "", 'tolerance', 0.05);
            S = rippleStimuli(src, E, ref, stim);
            [~, k] = arrayfun(@(t0) min(abs(on - t0)), double(E.t0));
            tc.verifyEqual(S.presentation, k(:));
            tc.verifyTrue(all(isfinite(S.index)));
            tc.verifyEqual(numel(S.records), numel(unique(S.presentation)));   % every presentation's phases differ: a record each
            tc.verifyEqual(S.check.nPresented, n);
            tc.verifyLessThanOrEqual(S.check.maxIntervalError, 0.001 + 1e-9);
            % a presentation too many, an interval off by 0.2 s
            f2 = writeLog(tc.Root, "log_count", [recs recs(1)], [on - on(1); on(end) - on(1) + 1], ones(n + 1, 1), (1:n + 1).');
            tc.verifyError(@() rippleStimuli(src, E, ref, setfield(stim, 'file', f2)), 'rippleStimuli:Count'); %#ok<SFLD>
            tl = on - on(1);
            tl(3:end) = tl(3:end) + 0.2;
            f3 = writeLog(tc.Root, "log_timing", recs, tl, ones(n, 1), (1:n).');
            tc.verifyError(@() rippleStimuli(src, E, ref, setfield(stim, 'file', f3)), 'rippleStimuli:Timing'); %#ok<SFLD>
            % one bank item of two: the other's presentations are left out
            items = 1 + mod((1:n).', 2);
            f4 = writeLog(tc.Root, "log_items", recs, on - on(1), items, (1:n).');
            S4 = rippleStimuli(src, E, ref, setfield(setfield(stim, 'file', f4), 'item', "torc b")); %#ok<SFLD>
            tc.verifyEqual(isfinite(S4.index), items(S4.presentation) == 2);
            tc.verifyEqual(S4.dropped.otherItem, nnz(items(S4.presentation) == 1));
            tc.verifyEqual(S4.itemNames, ["torc a" "torc b"]);
            % aligned to the line's offsets: refused
            tc.verifyError(@() rippleStimuli(src, E, eventRef(line="Stim", edge="offset", scope="recording"), stim), ...
                'rippleStimuli:Ref');
        end

        function parameterRouteReadsTheVariant(tc)
            src = tc.Src;
            tc.assumeTrue(src.hasTrials, 'The fixture has no paired trials.');
            src.trials.Variant = mod((0:height(src.trials) - 1).', 3) + 1;
            recs = {torcRecord(20, 0.4, 0.3, 5) torcRecord(24, 0.8, 0.5, 5) torcRecord(28, -0.4, 0.7, 5)};
            f = fullfile(tc.Root, "export.mat");
            X = struct('FormatVersion', 1, 'Source', struct(), 'CombinationVariables', ["C0001" "C0002" "C0003"]);
            for k = 1:3; X.(sprintf('C%04d', k)) = struct('Record', recs{k}); end
            save(f, '-struct', 'X');
            ref = eventRef(line="Stim");
            E = epochTable(src, ref);
            stim = struct('source', "parameter", 'file', f, 'item', "", 'parameter', "Variant", 'tolerance', 0.05);
            S = rippleStimuli(src, E, ref, stim);
            tc.verifyEqual(S.variant, src.trials.Variant(E.trial));
            tc.verifyEqual(numel(S.records), 3);
            for e = 1:height(E)
                tc.verifyEqual(S.records{S.index(e)}.RippleRates, recs{S.variant(e)}.RippleRates);
            end
            tc.verifyError(@() rippleStimuli(src, E, ref, setfield(stim, 'parameter', "NoSuchColumn")), 'rippleStimuli:NoParam'); %#ok<SFLD>
        end

        function panelComputesAndDraws(tc)
            if exist('stimgen.TORC', 'class') ~= 8   % stimgen absent: a stand-in with the same Eq. 28
                d = string(tempname);
                mkdir(fullfile(d, '+stimgen'));
                writelines(["classdef TORC" "    methods (Static)" ...
                    "        function [S, x] = envelope_from_record(r, t)" ...
                    "            x = double(r.OctaveAxis);" ...
                    "            t = reshape(double(t), 1, []);" ...
                    "            S = zeros(numel(x), numel(t));" ...
                    "            for i = 1:numel(r.RippleRates)" ...
                    "                S = S + 2 * r.RippleAmplitude .* cos(2*pi*(r.RippleRates(i) .* t + r.RippleDensities(i) .* x(:)) + r.RipplePhases(i));" ...
                    "            end" "        end" "    end" "end"], fullfile(d, '+stimgen', 'TORC.m'));
                tc.applyFixture(matlab.unittest.fixtures.PathFixture(d));
                tc.addTeardown(@() rmdir(d, 's'));
            end
            src = tc.Src;
            on = double(src.events.Stim(:, 1));
            n = numel(on);
            recs = repmat({torcRecord(20, 0.4, 0.3, 5)}, 1, n);
            f = writeLog(tc.Root, "log_panel", recs, on - on(1), ones(n, 1), ones(n, 1));
            cfg = EphysAnalysisConfig();
            cfg.Source.Root = tc.Fx.proj;
            cfg.Defaults.EventRef = eventRef(line="Stim", which="all", scope="recording");
            cfg.Defaults.Window = struct('mode', "fixed", 'pre', -0.1, 'post', 0.3, 'stop', []);
            cfg = cfg.addFigure("strf", Id="strf");
            fg = cfg.Figures(cfg.figureIndex("strf"));
            fg.panels(1).options.stim.file = f;
            fg.panels(1).options.maxLag = 0.05;
            cfg.Figures(cfg.figureIndex("strf")) = fg;
            I = cfg.validate(CheckPaths=false);
            tc.verifyEmpty(I(I.Section == "Figures" & startsWith(I.Field, "strf."), :));
            rn = EphysAnalysisRunner(cfg, LogFcn=[]);
            s1 = rn.source(1);
            spec = cfg.figureFor("strf");
            T = figureObservations(s1, spec);
            tc.assertGreaterThan(height(T), 0);
            F = rn.computeFigure(s1, spec, Observation=T(1, :));
            L = F.panels(1).layers(1);
            tc.assertEqual(L.skip, "", 'The STRF layer was skipped: ' + L.skip);
            R = L.R;
            tc.verifyEqual(R.kind, "rippleStrf");
            tc.verifyEqual(R.stimulus.check.nPresented, n);
            tc.verifyEqual(size(R.sets(1).strf), [20 201]);
            tc.verifyEqual(R.sets(1).nEpochs, height(F.epochs));
            roles = PlotAesthetics.roles().Role;
            fig = figure('Visible', 'off');
            tc.addTeardown(@() close(fig));
            for v = ["strf" "rtf" "crh"]
                sp = spec;
                sp.panels(1).options.view = v;
                h = renderFigure(F, sp, fig, UserAesthetics=false);
                C = PlotAesthetics.components(h.layout);
                tc.verifyTrue(all(C.Role ~= "" & ismember(C.Role, roles)), "view " + v + ": every component has a role");
                if v == "crh"   % a TORC has no CRH: the panel says so
                    tc.verifyTrue(any(C.Role == "layerNote"), "view crh of a TORC: a note");
                else
                    tc.verifyTrue(any(C.Role == "image"), "view " + v + ": an image");
                end
            end
            % a log that does not match: the layer is skipped with the reason
            fg.panels(1).options.stim.file = writeLog(tc.Root, "log_short", recs(1:end - 1), on(1:end - 1) - on(1), ...
                ones(n - 1, 1), ones(n - 1, 1));
            cfg.Figures(cfg.figureIndex("strf")) = fg;
            F2 = rn.computeFigure(s1, cfg.figureFor("strf"), Observation=T(1, :));
            tc.verifyTrue(contains(F2.panels(1).layers(1).skip, "presentations"));
        end

    end
end


% ======================================================================================================

function r = torcRecord(rates, dens, phases, a)
%torcRecord  A complete stimgen.TORC generation record by hand: 250 ms, one period, 5 octaves of 20 carriers from 125 Hz.
x = (0:19) * 0.25;
r = struct('RecordVersion', 1, 'Class', "stimgen.TORC", 'Fs', 48000, 'N', 12000, 'Generated', true, ...
    'RippleRates', rates, 'RippleDensities', dens, 'RipplePhases', phases, 'RippleAmplitude', a, ...
    'RipplePeriod', 0.25, 'NumPeriods', 1, 'Duration', 0.25, 'LowFrequency', 125, 'Bandwidth', 5, ...
    'OctaveAxis', x, 'CarrierFrequencies', 125 * 2 .^ x, 'Seed', 1);
end


function S = torcEnv(r, t)
%torcEnv  Klein et al. Eq. 28 from the record: sum_i 2a cos(2 pi (w_i t + Omega_i x) + psi_i).
x = r.OctaveAxis(:);
t = reshape(t, 1, []);
S = zeros(numel(x), numel(t));
for i = 1:numel(r.RippleRates)
    S = S + 2 * r.RippleAmplitude .* cos(2 * pi * (r.RippleRates(i) .* t + r.RippleDensities(i) .* x) + r.RipplePhases(i));
end
end


function [R, d] = torcCase()
%torcCase  One TORC component (20 Hz, 0.4 c/o) and spike counts per 0.25 ms bin following the envelope at 20 ms, 2 octaves.
r = torcRecord(20, 0.4, 0.3, 5);
b = (0:999).';
S0 = torcEnv(r, mod(b.' / 4000 - 0.02, 0.25));
n = 1000 + round(20 * S0(9, :).');
t = repelem(b / 4000, n);
R = rippleStrf({t}, {r}, 1, 1, Rate=4000, MaxLag=0.09975, Envelope=@(rr, tt) torcEnv(rr, tt));
d = struct('r', r, 'b', b, 'n', n, 't', t);
end


function t = spikesFor(r, k)
%spikesFor  Spike counts per bin following the envelope at carrier K, 5 ms before.
b = (0:999).';
S0 = torcEnv(r, mod(b.' / 4000 - 0.005, 0.25));
t = repelem(b / 4000, 200 + round(10 * S0(k, :).'));
end


function [r, env, traj] = dmrRecord()
%dmrRecord  A stimgen.DMR record by hand (2 s, 16 carriers over 4 octaves) with the test's own trajectories.
x = (0:15) * 0.25;
r = struct('RecordVersion', 1, 'Class', "stimgen.DMR", 'Fs', 48000, 'N', 96000, 'Generated', true, ...
    'EnvelopeMode', "DMR", 'NumEnvelopes', 1, 'ModulationDepth', 30, 'OctaveAxis', x, ...
    'CarrierFrequencies', 500 * 2 .^ x, 'ModulationRateRange', [-350 350], 'RippleDensityRange', [0 4]);
env = @(rec, t) dmrEnv(rec, t);
traj = @(rec, t) dmrTraj(t);
end


function tr = dmrTraj(t)
%dmrTraj  Omega(t) = 2 + sin(2 pi 0.7 t), Fm(t) = 100 sin(2 pi 0.3 t), Phi = 2 pi integral Fm.
t = reshape(t, 1, []);
tr = struct('t', t, 'Omega', 2 + sin(2 * pi * 0.7 * t), 'Fm', 100 * sin(2 * pi * 0.3 * t), ...
    'Phase', 2 * pi * 100 * (1 - cos(2 * pi * 0.3 * t)) / (2 * pi * 0.3));
end


function S = dmrEnv(r, t)
%dmrEnv  Escabi & Schreiner Eq. 1: M/2 sin(2 pi Omega(t) X + Phi(t)).
tr = dmrTraj(t);
S = (r.ModulationDepth / 2) * sin(2 * pi * r.OctaveAxis(:) * tr.Omega + tr.Phase);
end


function S = mixedEnv(rec, t, torc, dmr)
if rec.Class == "stimgen.TORC"; S = torc(rec, t); else; S = dmr(rec, t); end
end


function f = writeLog(root, name, recs, tLog, order, variant)
%writeLog  A stimgen presentation log (FormatVersion 1) of these records, times, bank items and variants.
f = fullfile(root, name + ".mat");
L = struct();
L.FormatVersion = 1;
L.StimRecord = reshape(recs, [], 1);
L.StimOrderTime = tLog(:);
L.StimOrder = order(:);
L.StimVariant = variant(:);
L.StimPolarity = ones(numel(recs), 1);
L.StimLateness = zeros(numel(recs), 1);
L.NPresented = numel(recs);
L.BankNames = ["torc a" "torc b"];
L.Bank = struct('ISI', [1 1], 'SelectionType', "Serial", 'NItems', 2, 'Items', {{struct('Name', "torc a") struct('Name', "torc b")}});
save(f, '-struct', 'L');
f = string(f);
end
