function test_ChronuxAnalysis()
%test_ChronuxAnalysis  Verification suite for the Chronux tab's analyses (no recording needed).
%   Hand-built Chronux files (the shape EphysDataset.exportChronux writes,
%   with its export.layout index), saved -v7.3 and -v7, check:
%   chronuxSettings (defaults, overlays, its errors); loadChronuxExport (the
%   index; rows read by parts equal to the whole signal's, channels in the
%   order asked, Span, both file versions, TooLarge, NoLayout, the Check
%   called); chronuxTimeBase (segments clear of the artifact periods' rows,
%   the seconds accounted for, spike-clock segments, epochs from an
%   epochTable with its groups); the alignment (a signal whose value is its
%   row: offset 0 of each trial is the row of its time 0, on a block that
%   starts past row 1); and, with Chronux on the path: chronuxSpectrum (a
%   40 Hz sine peaks within the tapers' bandwidth, the error bars bracket
%   the spectrum, a 10 Hz burst inside an artifact period is not seen over
%   a stretch, groups and trial counts), chronuxSpecgram (a 30 Hz burst
%   after each event, a dB baseline near 0 in its window, a stretch's
%   artifact period left NaN), a Check that throws stops them,
%   chronuxPairs and chronuxCoherence (a delayed copy of a channel is
%   coherent at its frequencies with the delay's phase, noise stays under
%   confC, seed and pair modes, a coherogram NaN over an artifact
%   period), the spike analyses on spike trains written into the file
%   (chronuxSpikeTrains; a train modulated at 20 Hz peaks there and its
%   spectrum's rate is its mean rate, spikes locked to a 40 Hz field are
%   coherent with it at 40 Hz, two identical trains have a coherence of 1),
%   and renderChronux (every kind, layout and scale, the phase tiles, into
%   a classic figure and a uifigure panel, pages, every component's role
%   known to PlotAesthetics).
%
%   Usage:  test_ChronuxAnalysis

here = fileparts(mfilename('fullpath'));
repo = fileparts(here);
addpath(here);
addpath(fullfile(repo, 'pipeline'));
addpath(repo);
added = "";
if ~ChronuxDataset.hasChronux()
    added = string(genpath(fullfile(repo, 'toolboxes', 'chronux')));
    addpath(added);
end
pathBack = onCleanup(@() rmpathQuiet(added));   % Chronux's findpeaks must not stay ahead of MATLAB's for other suites

root = fullfile(tempdir, sprintf('ChronuxAnalysis_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
cleanup = onCleanup(@() rmdirQuiet(root));

nPass = 0; nFail = 0;
    function check(cond, msg)
        if cond
            nPass = nPass + 1;
            fprintf('  PASS: %s\n', msg);
        else
            nFail = nFail + 1;
            fprintf(2, '  FAIL: %s\n', msg);
            LegacySuiteTest.checkFailed(msg);   % one failure per check in run_all_tests' report
        end
    end
    function id = errorId(fcn)
        id = '';
        try
            fcn();
        catch ME
            id = ME.identifier;
        end
    end

rng(11, 'twister');

fprintf('\n== 1. chronuxSettings ==\n');
S0 = chronuxSettings();
check(S0.analysis == "spectrum" && S0.timeBase == "aligned" && isequal(S0.window, [-0.5 1]) && S0.display.scale == "db", ...
    'the defaults: a spectrum over epochs of [-0.5 1] s, drawn in dB');
S1 = chronuxSettings(struct('analysis', "specgram", 'display', struct('layout', "overlay")));
check(S1.analysis == "specgram" && S1.display.layout == "overlay" && S1.display.scale == "db", ...
    'a struct overlays the defaults (display fields one by one)');
check(strcmp(errorId(@() chronuxSettings(struct('nope', 1))), 'chronuxSettings:UnknownField'), 'an unknown setting is refused');
check(strcmp(errorId(@() chronuxSettings(struct('err', "maybe"))), 'chronuxSettings:BadValue'), 'a value not allowed is refused');
check(strcmp(errorId(@() chronuxSettings(struct('analysis', "specgram", 'baseline', "db", 'baselineWindow', [-2 0]))), ...
    'chronuxSettings:Baseline'), 'a baseline outside the window is refused');

fprintf('\n== 2. a Chronux file, and loadChronuxExport ==\n');
fs = 1000;
dur = 120;
n = dur * fs;
t = (0:n-1).' / fs;                         % row k at (k-1)/fs
ev = (2:3:110).';                           % events, s on the continuous clock
lfp = zeros(n, 4);
lfp(:, 1) = 20 * sin(2 * pi * 40 * t) + randn(n, 1);
lfp(:, 2) = (1:n).';                        % the value is the row
lfp(:, 3) = randn(n, 1);
art = [30 32; 70.5 71];                     % artifact periods, [start end) s
burst = t >= 30 & t < 32;
lfp(burst, 3) = lfp(burst, 3) + 50 * sin(2 * pi * 10 * t(burst));   % only inside an artifact period
for e = ev.'
    on = t >= e & t < e + 0.5;
    lfp(on, 1) = lfp(on, 1) + 30 * sin(2 * pi * 30 * t(on));          % a 30 Hz burst after each event
end
lag = 5;                                    % rows: channel 4 is channel 1 5 ms later, plus noise
lfp(:, 4) = [zeros(lag, 1); lfp(1:end-lag, 1)] + randn(n, 1);
f73 = writeChronux(fullfile(root, 'demo_chronux.mat'), lfp, fs, art, '-v7.3');
f7 = writeChronux(fullfile(root, 'demo7_chronux.mat'), lfp, fs, art, '-v7');
X = loadChronuxExport(f73);
L = X.signals.LFP;
check(X.hdf5 && L.windowed && L.fs == fs && L.nSamples == n && L.nChan == 4 && isequal(L.labels, ["A1" "A2" "A3" "A4"]) ...
    && L.units == "microvolts" && isequal(X.artifacts, art) && isfield(X.events, 'Stim'), ...
    'the index: a -v7.3 file read by parts, the signal''s rate, size, labels and units, the artifacts and events');
check(~isfield(X.signals, 'MUA') && isempty(X.sp), 'only the signals and spikes the file holds');
D = loadChronuxExport(f73, Signal="LFP", Rows=[1001 3500], Channels=[3 1], Index=X, BlockRows=700);
check(isequal(size(D.data), [2500 2]) && isequal(D.data, single(lfp(1001:3500, [3 1]))) && D.row0 == 1001 ...
    && abs(D.t0 - 1) < 1e-12 && isequal(D.labels, ["A3" "A1"]), ...
    'rows read a block at a time equal the signal''s, the channels in the order asked');
D7 = loadChronuxExport(f7, Signal="LFP", Rows=[1001 3500], Channels=[3 1]);
check(~loadChronuxExport(f7).signals.LFP.windowed && isequal(D7.data, D.data), 'a -v7 file is read whole and gives the same rows');
Ds = loadChronuxExport(f73, Signal="LFP", Span=[2 3], Index=X);
check(Ds.row0 <= 2001 && Ds.row0 + size(Ds.data, 1) - 1 >= 3001, 'Span reads every row with (k-1)/fs in it');
nChecks = 0;
loadChronuxExport(f73, Signal="LFP", Index=X, Channels=2, BlockRows=50000, Check=@() countCheck());
check(nChecks == 3, 'Check is called after each block of rows');
check(strcmp(errorId(@() loadChronuxExport(f73, Signal="LFP", Index=X, MaxMB=0.5)), 'loadChronuxExport:TooLarge'), ...
    'more than MaxMB is refused');
check(strcmp(errorId(@() loadChronuxExport(f73, Signal="MUA", Index=X)), 'loadChronuxExport:NoSignal'), 'a signal not in the file is refused');
bare = fullfile(root, 'bare_chronux.mat');
Sb = struct('LFP', struct('data', 1), 'export', struct('dataset', "bare"), 'sp', []);
save(bare, '-struct', 'Sb');
check(strcmp(errorId(@() loadChronuxExport(bare)), 'loadChronuxExport:NoLayout'), 'a file without export.layout is refused');

fprintf('\n== 3. chronuxTimeBase ==\n');
TB = chronuxTimeBase("range", Range=[10 90], Artifacts=art, Fs=fs, NRows=n, Segment=2);
bad = EphysDataset.intervalRows(art, fs, n);
rows0 = round(TB.starts * fs) + 1;
rowsEnd = rows0 + round(TB.window(2) * fs);
touch = false;
for i = 1:size(bad, 1); touch = touch || any(rows0 <= bad(i, 2) & rowsEnd >= bad(i, 1)); end
check(~touch && all(rows0 >= 10 * fs + 1) && all(rowsEnd <= 90 * fs) && round(TB.window(2) * fs) + 1 == 2 * fs, ...
    'range: 2 s segments of exactly 2000 rows, inside the range, none touching an artifact period''s rows');
check(abs(TB.secondsUsed + TB.secondsArtifact + TB.secondsShort - 80) < 1e-9 && abs(TB.secondsArtifact - 2.5) < 0.01 ...
    && TB.nTrials == numel(TB.starts) && all(TB.groupIndex == 1) && TB.groups.n == TB.nTrials, ...
    'the seconds used, in artifact periods and too short add up to the range; one group');
TBs = chronuxTimeBase("range", Range=[0 Inf], Artifacts=art, Duration=dur, Segment=5);
check(isequal(TBs.window, [0 5]) && ~any(EphysDataset.overlapsIntervals(TBs.starts, TBs.starts + 5 - 1e-6, art)) ...
    && abs(TBs.span(2) - dur) < 1e-9, 'spike clock: segments of 5 s clear of the periods, up to the recording''s end');
check(strcmp(errorId(@() chronuxTimeBase("range", Range=[30.1 31.9], Artifacts=art, Duration=dur, Segment=1)), ...
    'chronuxTimeBase:NoTrials'), 'a range inside an artifact period has no trial');
E = table((1:numel(ev)).', ev, 1 + mod((0:numel(ev)-1).', 2), 'VariableNames', {'epoch', 't0Continuous', 'groupIndex'});
E.Properties.UserData = struct('nDroppedEdge', 1, 'nDroppedArtifact', 2);
G = table([1; 2], ["odd"; "even"], [1 0 0; 0 0 1], [0; 0], 'VariableNames', {'index', 'label', 'color', 'n'});
TBa = chronuxTimeBase("aligned", E=E, Groups=G, Window=[-0.5 1], Label="Stim onset");
check(TBa.nTrials == numel(ev) && isequal(TBa.groups.n, [ceil(numel(ev) / 2); floor(numel(ev) / 2)]) ...
    && abs(TBa.span(1) - (ev(1) - 0.5)) < 1e-12 && contains(TBa.text, "Stim onset") && contains(TBa.text, "2 touching artifact"), ...
    'aligned: one trial per epoch, the groups counted, the span, what was left out');
TB1 = chronuxTimeBase("aligned", E=E, Groups=G, Window=[-0.5 1], UseGroups=false);
check(height(TB1.groups) == 1 && TB1.groups.n == numel(ev), 'UseGroups=false: every epoch in one group');

fprintf('\n== 4. the alignment ==\n');
Db = loadChronuxExport(f73, Signal="LFP", Rows=[1501 40000], Channels=2, Index=X);
TBr = TBa;
TBr.starts = [2.1; 5.2345; 20];
TBr.groupIndex = [1; 1; 1];
[Xc, kept] = chronuxCut(Db, TBr, 1, "none");
r0 = round(TBr.starts * fs) + 1;
s0 = round(-0.5 * fs);
check(isequal(kept, 1:3) && size(Xc, 1) == 1501 && isequal(Xc(1 - s0, :).', r0) && isequal(Xc(1, :).', r0 + s0), ...
    'offset 0 of each trial is the row nearest its time 0 ((k-1)/fs), on a block that starts at row 1501');
TBr.starts = [1.2; 5];   % the first leaves the block (it starts at 1.5 s)
[~, kept, info] = chronuxCut(Db, TBr, 1, "none");
check(isequal(kept, 2) && info.droppedEdge == 1, 'a trial that leaves the block is left out and counted');

if ~ChronuxDataset.hasChronux()
    fprintf('\n(Chronux is not on the path: the analyses are not checked)\n');
else
    fprintf('\n== 5. chronuxSpectrum ==\n');
    S = chronuxSettings(struct('timeBase', "range", 'segmentSec', 2, 'fpass', [0 100], 'TW', 3, 'K', 5, 'err', "jackknife"));
    TBx = chronuxTimeBase("range", Range=[0 Inf], Artifacts=art, Fs=fs, NRows=n, Segment=2);
    Dx = loadChronuxExport(f73, Signal="LFP", Channels=[1 3], Span=TBx.span, Index=X);
    R = chronuxSpectrum(Dx, TBx, S, Dataset="demo");
    [~, im] = max(R.S(:, 1));
    W = R.tapers.halfBandwidthHz;
    check(R.kind == "chronuxSpectrum" && abs(R.f(im) - 40) <= W && R.nTrials(1) == TBx.nTrials, ...
        sprintf('a 40 Hz sine peaks at %.2f Hz (within the +/-%.2g Hz bandwidth), over every segment', R.f(im), W));
    check(all(R.Slo(:) <= R.S(:) + 1e-9 & R.S(:) <= R.Shi(:) + 1e-9), 'the jackknife error bars bracket the spectrum');
    near10 = abs(R.f - 10) <= W;
    near20 = abs(R.f - 20) <= W;
    check(mean(R.S(near10, 2)) < 3 * mean(R.S(near20, 2)), ...
        'a 10 Hz burst inside an artifact period is not seen over a stretch');
    Snone = S; Snone.err = "none";
    R0 = chronuxSpectrum(Dx, TBx, Snone);
    check(isempty(R0.Slo) && max(abs(R0.S(:) - R.S(:)) ./ R.S(:)) < 1e-9 && R0.params.err == 0, ...
        'without error bars: the same spectrum, none');
    Sa = chronuxSettings(struct('window', [0 0.5], 'fpass', [0 100], 'err', "none"));
    Da = loadChronuxExport(f73, Signal="LFP", Channels=1, Span=TBa.span, Index=X);
    TBw = chronuxTimeBase("aligned", E=E, Groups=G, Window=[0 0.5]);
    Ra = chronuxSpectrum(Da, TBw, Sa);
    [~, ia] = max(Ra.S(:, 1, 1));
    check(isequal(Ra.nTrials, TBw.groups.n.') && abs(Ra.f(ia) - 30) <= Ra.tapers.halfBandwidthHz + 2 && size(Ra.S, 3) == 2, ...
        'epochs: one spectrum per group, the burst after each event at 30 Hz');
    check(strcmp(errorId(@() chronuxSpectrum(Dx, TBx, S, Check=@() error('test:stop', 'stop'))), 'test:stop'), ...
        'a Check that throws stops it');

    fprintf('\n== 6. chronuxSpecgram ==\n');
    Sg = chronuxSettings(struct('analysis', "specgram", 'window', [-1 1.5], 'movingwin', [0.25 0.05], 'fpass', [0 80], ...
        'TW', 2, 'K', 3, 'baseline', "db", 'baselineWindow', [-1 -0.1]));
    TBg = chronuxTimeBase("aligned", E=E, Groups=G, Window=[-1 1.5], UseGroups=false);
    Dg = loadChronuxExport(f73, Signal="LFP", Channels=1, Span=TBg.span, Index=X);
    Rg = chronuxSpecgram(Dg, TBg, Sg);
    f30 = abs(Rg.f - 30) <= 4;
    post = Rg.t > 0.15 & Rg.t < 0.35;
    pre = Rg.t > -0.8 & Rg.t < -0.3;
    inBase = Rg.t >= -1 & Rg.t <= -0.1;
    check(Rg.kind == "chronuxSpecgram" && Rg.aligned && mean(Rg.S(post, f30), 'all') > mean(Rg.S(pre, f30), 'all') + 6, ...
        'the 30 Hz burst after each event stands out over the baseline (dB change)');
    check(abs(mean(Rg.S(inBase, :), 'all')) < 1 && Rg.baseline.units == "dB change", 'a dB baseline is near 0 in its window');
    nW = round(0.25 * fs);
    check(abs(Rg.t(1) - (-1 + (nW - 1) / 2 / fs)) < 1e-12, 'each window''s time is its center, s from the event');
    Sr = chronuxSettings(struct('analysis', "specgram", 'timeBase', "range", 'range', [20 40], 'movingwin', [0.5 0.25], 'fpass', [0 80]));
    TBq = chronuxTimeBase("range", Range=[20 40], Artifacts=art, Fs=fs, NRows=n, Segment=0.5);
    Dq = loadChronuxExport(f73, Signal="LFP", Channels=[1 3], Span=TBq.span, Index=X);
    Rq = chronuxSpecgram(Dq, TBq, Sr);
    inArt = Rq.t > 30.3 & Rq.t < 31.7;
    out = Rq.t > 22 & Rq.t < 28;
    check(~Rq.aligned && all(isnan(Rq.S(inArt, :, :)), 'all') && all(isfinite(Rq.S(out, :, :)), 'all'), ...
        'a stretch: NaN over the artifact period, power elsewhere');
    check(strcmp(errorId(@() chronuxSpecgram(Dq, TBq, Sr, MaxMB=0.001)), 'chronuxSpecgram:TooLarge'), ...
        'a spectrogram over MaxMB is refused');

    fprintf('\n== 8. chronuxPairs, chronuxCoherence ==\n');
    Sc = chronuxSettings(struct('analysis', "coherence", 'timeBase', "range", 'segmentSec', 2, 'fpass', [0 100], ...
        'pairMode', "seed", 'seed', 1, 'channels', [3 4], 'err', "jackknife"));
    Dc = loadChronuxExport(f73, Signal="LFP", Channels=[1 3 4], Span=TBx.span, Index=X);
    Pc = chronuxPairs(Sc, Dc.channels, Dc.labels);
    check(isequal(Pc.a, [1; 1]) && isequal(Pc.b, [3; 4]) && isequal(Pc.label, ["A1-A3"; "A1-A4"]), ...
        'seed mode: the seed against every other channel picked');
    Sp = Sc; Sp.pairMode = "pair"; Sp.partner = 4;
    check(isequal(chronuxPairs(Sp, Dc.channels, Dc.labels).b, 4), 'pair mode: the seed and its partner');
    Sp.partner = 1;
    check(strcmp(errorId(@() chronuxPairs(Sp, Dc.channels, Dc.labels)), 'chronuxPairs:BadPair'), 'a channel with itself is refused');
    Rc = chronuxCoherence(Dc, TBx, Sc, Dataset="demo");
    k40 = abs(Rc.f - 40) == min(abs(Rc.f - 40));
    hiF = Rc.f > 60;
    expect = 2 * pi * 40 * lag / fs;
    check(Rc.kind == "chronuxCoherence" && Rc.C(k40, 2) > 0.95 && abs(abs(Rc.phi(k40, 2)) - expect) < 0.15, ...
        sprintf('a delayed copy is coherent at 40 Hz (C %.3f) with the delay''s phase (%.2f rad; %.2f expected)', ...
        Rc.C(k40, 2), abs(Rc.phi(k40, 2)), expect));
    check(mean(Rc.C(hiF, 1) < Rc.confC(1)) > 0.9 && isfinite(Rc.confC(1)) && all(Rc.Clo(:) <= Rc.C(:) + 1e-9), ...
        'noise stays under confC; the jackknife bars bracket C');
    Sg2 = chronuxSettings(struct('analysis', "coherence", 'overTime', true, 'timeBase', "range", 'range', [20 40], ...
        'movingwin', [0.5 0.25], 'fpass', [0 80], 'pairMode', "pair", 'seed', 1, 'partner', 4));
    Dq4 = loadChronuxExport(f73, Signal="LFP", Channels=[1 4], Span=TBq.span, Index=X);
    Rcg = chronuxCoherence(Dq4, TBq, Sg2);
    check(Rcg.kind == "chronuxCohgram" && all(isnan(Rcg.C(inArt, :)), 'all') && all(isfinite(Rcg.C(out, :)), 'all') ...
        && size(Rcg.C, 3) == 1, 'over time, a stretch: NaN over the artifact period');

    fprintf('\n== 9. the spike analyses ==\n');
    lam = 20 * (1 + 0.9 * sin(2 * pi * 20 * t));          % a train modulated at 20 Hz
    t1 = t(rand(n, 1) < lam / fs);
    pk = (1 / 160 : 1 / 40 : dur - 0.1).';                  % the 40 Hz sine's peaks
    t2 = round(pk(rand(numel(pk), 1) < 0.5) * fs) / fs;   % at half the peaks, on the sample grid
    U = struct('label', ["u1"; "u2"; "u3"], 'class', ["su"; "su"; "mua"]);
    fsp = writeChronux(fullfile(root, 'spikes_chronux.mat'), lfp, fs, art, '-v7.3', ...
        struct('times', {t1, t2, t1}), U);
    Xs = loadChronuxExport(fsp);
    SP = chronuxSpikeTrains(Xs, "units");
    check(numel(SP.times) == 3 && isequal(SP.labels, ["u1" "u2" "u3"]) && isequal(SP.class, ["su" "su" "mua"]) ...
        && isequal(SP.times(2).times, t2), 'chronuxSpikeTrains: the file''s units, labeled');
    check(strcmp(errorId(@() chronuxSpikeTrains(Xs, "detected")), 'chronuxSpikeTrains:None') ...
        && strcmp(errorId(@() chronuxSpikeTrains(Xs, "units", 4)), 'chronuxSpikeTrains:BadIndex'), ...
        'no detections, or a train not in the file, is refused');
    TBp = chronuxTimeBase("range", Range=[0 Inf], Artifacts=art, Duration=dur, Segment=2);
    Ss = chronuxSettings(struct('analysis', "spikeSpectrum", 'timeBase', "range", 'fpass', [0 100], 'spikeFs', 1000, ...
        'err', "jackknife"));
    Rs = chronuxSpikeSpectrum(chronuxSpikeTrains(Xs, "units", 1), TBp, Ss);
    band = Rs.f > 8;
    [~, ip] = max(Rs.S(band, 1));
    fb = Rs.f(band);
    check(Rs.kind == "chronuxSpikeSpectrum" && abs(fb(ip) - 20) <= Rs.tapers.halfBandwidthHz && abs(Rs.rate - 20) < 1.5 ...
        && abs(mean(Rs.S(Rs.f > 60, 1)) / Rs.rate - 1) < 0.2, ...
        sprintf('a train modulated at 20 Hz peaks at %.1f Hz; its rate %.1f spikes/s is where the spectrum tends', fb(ip), Rs.rate));
    Sf = chronuxSettings(struct('analysis', "spikeField", 'timeBase', "range", 'segmentSec', 2, 'fpass', [0 100], ...
        'fieldChannel', 1, 'err', "theoretical"));
    TBf = chronuxTimeBase("range", Range=[0 Inf], Artifacts=art, Fs=fs, NRows=n, Segment=2);
    Df = loadChronuxExport(fsp, Signal="LFP", Channels=1, Span=TBf.span, Index=Xs);
    Rf = chronuxSpikeField(Df, chronuxSpikeTrains(Xs, "units", [1 2]), TBf, Sf);
    k40 = abs(Rf.f - 40) == min(abs(Rf.f - 40));
    check(Rf.kind == "chronuxSpikeField" && Rf.C(k40, 2) > 0.5 && Rf.C(k40, 2) > Rf.confC(2) ...
        && Rf.C(k40, 1) < Rf.C(k40, 2) && isequal(Rf.pairs.label, ["u1-A1"; "u2-A1"]), ...
        sprintf('spikes locked to the 40 Hz field are coherent with it there (C %.2f; the other train %.2f)', Rf.C(k40, 2), Rf.C(k40, 1)));
    Su = chronuxSettings(struct('analysis', "unitCoherence", 'timeBase', "range", 'fpass', [2 100], 'pairMode', "pair", ...
        'unitSeed', 1, 'unitPartner', 3, 'err', "none"));
    Ru = chronuxUnitCoherence(chronuxSpikeTrains(Xs, "units", [1 3]), TBp, Su);
    check(Ru.kind == "chronuxUnitCoherence" && min(Ru.C(:)) > 0.99 && isequal(Ru.pairs.label, "u1-u3"), ...
        'two identical trains have a coherence of 1');
    Su.unitPartner = 2;
    check(strcmp(errorId(@() chronuxUnitCoherence(chronuxSpikeTrains(Xs, "units", [1 3]), TBp, Su)), ...
        'chronuxUnitCoherence:BadPair'), 'a partner not among the trains picked is refused');

    fprintf('\n== 7. renderChronux ==\n');
    fig = figure('Visible', 'off');
    closeFig = onCleanup(@() close(fig));
    roles = PlotAesthetics.roles().Role;
    ok = true; why = strings(0, 1);
    cases = {R, struct('layout', "grid", 'scale', "db"); R, struct('layout', "overlay", 'scale', "log"); ...
        Ra, struct('layout', "grid", 'scale', "linear"); Rg, struct(); Rq, struct('scale', "linear"); ...
        Rc, struct('layout', "grid", 'showPhase', true); Rc, struct('layout', "overlay"); Rcg, struct(); ...
        Rs, struct('scale', "db"); Rf, struct('showPhase', true); Ru, struct('showPhase', false)};
    for i = 1:size(cases, 1)
        Ri = cases{i, 1};
        d = Ri.settings.display;
        for f = string(fieldnames(cases{i, 2})).'; d.(f) = cases{i, 2}.(f); end
        h = renderChronux(Ri, fig, Display=d, Editable=false);
        C = PlotAesthetics.components(h.layout);
        if any(C.Role == "") || ~all(ismember(C.Role, roles))
            ok = false;
            why(end+1) = Ri.kind + " " + i + ": " + strjoin(unique(C.Type(C.Role == "" | ~ismember(C.Role, roles))), ", "); %#ok<AGROW>
        end
    end
    check(ok, "every component of every Chronux plot has a known role" + ifText(~ok, " (" + strjoin(why, "; ") + ")"));
    d = Rc.settings.display; d.showPhase = true;
    h = renderChronux(Rc, fig, Display=d, Editable=false);
    C = PlotAesthetics.components(h.layout);
    check(numel(h.axes) == 2 && any(C.Role == "phase") && any(C.Role == "confLine") ...
        && numel(findobj(fig, 'Type', 'axes')) == 4, 'coherence: a magnitude tile per pair with confC, and a phase tile under each');
    h = renderChronux(Rs, fig, Editable=false);
    check(any(PlotAesthetics.components(h.layout).Role == "rateLine"), 'a spike spectrum marks its mean rate');
    d = R.settings.display; d.maxTiles = 1; d.page = 2;
    h = renderChronux(R, fig, Display=d, Editable=false);
    check(h.pages == 2 && h.page == 2 && numel(h.axes) == 1 && contains(string(h.axes(1).Title.String), "A3"), ...
        'a tile a page: page 2 of 2 shows the second channel');
    uf = uifigure('Visible', 'off');
    closeUf = onCleanup(@() delete(uf));
    p = uipanel(uf);
    h = renderChronux(Rg, p, Editable=false);
    check(~isempty(h.layout) && isa(findobj(h.axes(1), 'Type', 'image'), 'matlab.graphics.primitive.Image'), ...
        'a spectrogram draws into a uifigure''s panel');
end

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_ChronuxAnalysis:Failures', '%d checks failed.', nFail);
end

    function countCheck()
        nChecks = nChecks + 1;
    end
end


function file = writeChronux(file, lfp, fs, art, ver, sp, units)
%writeChronux  A Chronux file of exportChronux's shape: LFP, events, artifacts, export with its layout (SP, UNITS: sorted units).
if nargin < 6; sp = []; units = []; end
n = size(lfp, 1);
labels = "A" + string(1:size(lfp, 2));
S = struct();
S.LFP = struct('data', lfp, 'params', ChronuxDataset.makeParams(fs), 't', (0:n-1) / fs, 'labels', labels, ...
    'info', struct('fs', fs, 'units', "microvolts"));
S.sp = sp;
S.units = units;
S.spDetected = [];
S.detected = [];
S.events = struct('Stim', [(2:3:110).' + 1 / 30000, (2:3:110).' + 0.1]);
S.artifacts = struct('intervals', art, 'fill', "line", 'nSamples', n);
S.export = struct('tool', "test", 'created', "2026-10-12 12:00:00", 'dataset', "demo", 'signals', "LFP", ...
    'layout', struct('LFP', struct('fs', fs, 'nSamples', n, 'nChan', size(lfp, 2), 'labels', labels, ...
        'units', "microvolts", 'sampleRange', [1 n])), 'eventFs', 30000);
save(file, '-struct', 'S', ver);
end


function s = ifText(c, a)
if c; s = a; else; s = ""; end
end


function rmpathQuiet(p)
if p ~= ""
    w = warning('off', 'MATLAB:rmpath:DirNotFound');
    rmpath(p);
    warning(w);
end
end


function rmdirQuiet(p)
if isfolder(p)
    try
        rmdir(p, 's');
    catch
    end
end
end
