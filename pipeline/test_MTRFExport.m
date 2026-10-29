function test_MTRFExport()
%test_MTRFExport  Verification suite for the mTRF-Toolbox packaging.
%   Checks mTRFExport's builders on known signals: resample (the rate
%   reached, t = 0 kept), envelope (an AM tone's modulator), pulses and
%   lines (impulses on the onset's sample, boxcars, values, heights, pulses
%   off the signal), trials (the same samples FieldTripExport.epochs gives
%   an onset; NaN, off-signal and artifact-touching trials dropped),
%   segments (artifact-free stretches, merged periods, the short dropped,
%   the long split), package (shapes, labels, the mismatches refused) and
%   lagSamples. No mTRF-Toolbox is needed; when it is on the path (or at
%   c:\src\mTRF-Toolbox\mtrf), mTRFtrain recovers a known kernel from a
%   package of impulses, and mTRFcrossval / mTRFpredict run on its trials.
%
%   Usage:  test_MTRFExport

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

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
    function id = errorId(fn)
        id = '';
        try
            fn();
        catch ME
            id = ME.identifier;
        end
    end

fprintf('\n== 1. resample ==\n');
Fs = 2000; N = 4000;
t = (0:N-1).' / Fs;
X = single([3 + 0 * t, sin(2 * pi * 5 * t)]);
[Y, fsOut] = mTRFExport.resample(X, Fs, 128);
check(fsOut == 128 && isa(Y, 'double') && size(Y, 1) == ceil(N * 8 / 125) && size(Y, 2) == 2, ...
    '2000 -> 128 Hz reaches 128 exactly; ceil(N*p/q) rows, double');
mid = 20:size(Y, 1) - 20;               % the filter's half-length is 10 output samples
tY = (mid - 1).' / fsOut;
check(max(abs(Y(mid, 1) - 3)) < 1e-6 && max(abs(Y(mid, 2) - sin(2 * pi * 5 * tY))) < 1e-4, ...
    'a constant stays, and a 5 Hz sine lands on its own times: t = 0 is the first sample');
[Y1, f1] = mTRFExport.resample(X, Fs, Fs);
check(f1 == Fs && isa(Y1, 'double') && isequal(Y1, double(X)), 'the same rate returns the data as double');
[Y0, f0] = mTRFExport.resample(zeros(0, 3), Fs, 128);
check(f0 == 128 && isequal(size(Y0), [0 3]), 'an empty signal stays empty');
[~, f3] = mTRFExport.resample(X, 30000, 1000);
check(f3 == 1000, '30000 -> 1000 is exact too');

fprintf('\n== 2. envelope ==\n');
Fs = 20000; T = 4;
t = (0:Fs * T - 1).' / Fs;
mod = 1 + 0.5 * sin(2 * pi * 2 * t);
x = mod .* sin(2 * pi * 1000 * t);
[env, fe] = mTRFExport.envelope(x, Fs, 128, Compression=1);
te = (0:numel(env) - 1).' / fe;
expected = (1 + 0.5 * sin(2 * pi * 2 * te)) / sqrt(2);    % the RMS of a sine is its amplitude / sqrt(2)
mid = 30:numel(env) - 30;
check(fe == 128 && max(abs(env(mid) - expected(mid))) < 0.03 * max(expected), ...
    'RMS envelope of an AM tone at 128 Hz follows the modulator (within 3%)');
envH = mTRFExport.envelope(x, Fs, 128, Method="hilbert", Compression=1);
expectedH = 1 + 0.5 * sin(2 * pi * 2 * te);
check(max(abs(envH(mid) - expectedH(mid))) < 0.03 * max(expectedH), 'Hilbert envelope gives the amplitude itself');
envC = mTRFExport.envelope(x, Fs, 128);
check(max(abs(envC(mid) - env(mid) .^ log10(2))) < 1e-9, 'the default compression raises the RMS to log10(2)');
env2 = mTRFExport.envelope([x, x + 5], Fs, 128, Compression=1);
check(size(env2, 2) == 2 && max(abs(env2(mid, 1) - env2(mid, 2))) < 1e-6, ...
    'each column on its own; a DC offset is removed first');

fprintf('\n== 3. pulses and lines ==\n');
Fs = 1000; N = 1000;
x = mTRFExport.pulses([0.1 0.2; 0.5 0.55], Fs, N);
check(nnz(x) == 2 && x(101) == 1 && x(501) == 1, 'onset: 1 on round(t_on*Fs) + 1');
x = mTRFExport.pulses([0.1 0.2; 0.5 0.55], Fs, N, Kind="offset");
check(nnz(x) == 2 && x(201) == 1 && x(551) == 1, 'offset: 1 on round(t_off*Fs) + 1');
x = mTRFExport.pulses([0.1 0.2; 0.5 0.55], Fs, N, Kind="boxcar");
check(nnz(x) == 101 + 51 && all(x(101:201) == 1) && all(x(501:551) == 1) && x(100) == 0 && x(202) == 0, ...
    'boxcar: 1 from the onset''s sample to the end''s');
x = mTRFExport.pulses([0.1 0.2; 0.5 0.55; 0.7 0.8], Fs, N, Value=[2 NaN 0.5], Height=Fs);
check(x(101) == 2 * Fs && x(501) == 0 && x(701) == 0.5 * Fs, 'Value scales each pulse, NaN is 0, Height scales all');
x = mTRFExport.pulses([-0.5 -0.4; 0.9995 1.2; 1.5 1.6], Fs, N, Kind="boxcar");
check(nnz(x) == 0 || (x(1000) == 1 && nnz(x) == 1), 'pulses off the signal are left out, one reaching in is clipped');
x = mTRFExport.pulses([0.1 0.2; 0.1 0.3], Fs, N);
check(x(101) == 2, 'two pulses on one sample add up');
x = mTRFExport.pulses(zeros(0, 2), Fs, N);
check(isequal(size(x), [N 1]) && nnz(x) == 0, 'no pulses: zeros');
check(strcmp(errorId(@() mTRFExport.pulses([0.1 0.2], Fs, N, Value=[1 2])), 'mTRFExport:BadValues'), ...
    'Value with the wrong count is refused');
ev = struct('Stim', [0.1 0.2; 0.5 0.55], 'Trial', [0.05 0.3], 'Empty', zeros(0, 2));
[L, names] = mTRFExport.lines(ev, ["Stim" "Trial"], Fs, N, Kind=["onset" "boxcar"], Height=Fs);
check(isequal(size(L), [N 2]) && isequal(names, ["Stim" "Trial"]) && L(101, 1) == Fs && L(501, 1) == Fs ...
    && all(L(51:301, 2) == 1) && nnz(L(:, 2)) == 251, 'lines: a column per line, Kind per line, Height on impulses only');
[L, names] = mTRFExport.lines(ev, [], Fs, N);
check(isequal(names, ["Stim" "Trial" "Empty"]) && size(L, 2) == 3 && nnz(L(:, 3)) == 0, ...
    'lines: [] takes every line of the struct');
check(strcmp(errorId(@() mTRFExport.lines(ev, "Nope", Fs, N)), 'mTRFExport:NoLine'), 'a line that is not there');

fprintf('\n== 4. trials ==\n');
X = reshape(1:N * 3, N, 3);
[C, keep, tt, rows] = mTRFExport.trials(X, Fs, [0.1; NaN; 0.0005; 0.998], [-0.002 0.005]);
check(isequal(keep, [true; false; false; false]) && isequal(rows, [99 106]) && numel(C) == 1 ...
    && isequal(C{1}, double(X(99:106, :))) && isequal(tt, (-2:5).' / Fs), ...
    'trials: the samples FieldTripExport.epochs gives an onset at 0.1 s; NaN and off-signal trials dropped');
[C, keep] = mTRFExport.trials(X, Fs, [0.1; 0.3; 0.5], [-0.01 0.02], Artifacts=[0.31 0.32; 0.48 0.49]);
check(isequal(keep, [true; false; true]) && numel(C) == 2, ...
    'a trial touching an artifact period is dropped; one ending just before it is kept');
[C, keep, tt] = mTRFExport.trials(X, Fs, 0.5, [0.1 0.2]);
check(keep && isequal(tt, (100:200).' / Fs) && isequal(C{1}, double(X(601:701, :))), ...
    'a window after the onset (pre > 0) is allowed');
check(strcmp(errorId(@() mTRFExport.trials(X, Fs, 0.5, [0.2 0.1])), 'mTRFExport:BadWindow'), 'post <= pre is refused');

fprintf('\n== 5. segments ==\n');
N = 10000;
X = reshape(1:N * 2, N, 2);
[C, rows] = mTRFExport.segments(X, Fs);
check(isequal(rows, [1 N]) && numel(C) == 1 && isequal(C{1}, double(X)), 'no artifacts: the whole signal, one piece');
art = [2 3; 3 3.5; 7.9995 8.0005];
[C, rows] = mTRFExport.segments(X, Fs, Artifacts=art, MinSeconds=2);
check(isequal(rows, [1 2000; 3501 7999]), ...
    'touching periods merge; every sample a period touches is out; the stretch shorter than MinSeconds is dropped');
check(isequal(C{2}, double(X(3501:7999, :))), 'each piece is the signal''s rows');
[~, rows] = mTRFExport.segments(X, Fs, Artifacts=art, MinSeconds=2, MaxSeconds=2.5);
check(isequal(rows, [1 2000; 3501 5750; 5751 7999]), 'a stretch longer than MaxSeconds is split into equal pieces');
[~, rows] = mTRFExport.segments(X, Fs, Artifacts=art, MinSeconds=1, MaxSeconds=Inf);
check(isequal(rows, [1 2000; 3501 7999; 8002 10000]), 'MinSeconds=1 keeps the stretch after the last period');
[C, rows] = mTRFExport.segments(X, Fs, Artifacts=[0 20]);
check(isempty(C) && isempty(rows), 'a period over everything leaves nothing');
[~, rows] = mTRFExport.segments(X, Fs, MaxSeconds=3);
check(isequal(rows, [1 2500; 2501 5000; 5001 7500; 7501 10000]), 'a clean signal split into the fewest pieces of at most MaxSeconds');
[~, rows] = mTRFExport.segments(X(1:5800, :), Fs, MinSeconds=2, MaxSeconds=2);
check(isequal(rows, [1 2900; 2901 5800]), 'pieces never shorter than MinSeconds: fewer, longer pieces when both cannot hold');
[~, rows] = mTRFExport.segments(X(1:3000, :), Fs, MinSeconds=2, MaxSeconds=2);
check(isequal(rows, [1 3000]), 'a stretch that cannot be split keeps one piece');

fprintf('\n== 6. package ==\n');
stim = {ones(50, 1); 2 * ones(40, 1)};
resp = {rand(50, 3); rand(40, 3)};
M = mTRFExport.package(stim, resp, 128, RespLabels=["a" "b" "c"], Positions=[0 0; 0 20; 0 40], Start=[0; 1], ...
    TrialInfo=table([1; 2]), Cfg=struct('name', "x"));
check(M.nTrials == 2 && M.nFeatures == 1 && M.nChannels == 3 && M.fs == 128 && isequal(M.stimLabels, "f1") ...
    && isequal(M.respLabels, ["a" "b" "c"]) && isequal(M.pos, [0 0; 0 20; 0 40]) && isequal(M.start, [0; 1]) ...
    && M.cfg.name == "x" && M.cfg.exporter == "mTRFExport.package" && istable(M.trialinfo), ...
    'package: counts, default feature labels, labels, positions, starts, cfg');
M1 = mTRFExport.package(single(ones(10, 2)), ones(10, 1), 100);
check(M1.nTrials == 1 && isa(M1.stim{1}, 'double') && isequal(M1.stimLabels, ["f1" "f2"]) && isequal(M1.respLabels, "ch1") ...
    && all(isnan(M1.pos(:))) && isnan(M1.start), 'a matrix is one trial, cast to double; unknown positions are NaN');
check(strcmp(errorId(@() mTRFExport.package({ones(5, 1)}, {ones(6, 1)}, 100)), 'mTRFExport:Mismatch'), ...
    'a trial whose stim and resp differ in length is refused');
check(strcmp(errorId(@() mTRFExport.package({ones(5, 1); ones(5, 2)}, {ones(5, 1); ones(5, 1)}, 100)), 'mTRFExport:Mismatch'), ...
    'trials differing in features are refused');
check(strcmp(errorId(@() mTRFExport.package({ones(5, 1)}, {ones(5, 1); ones(5, 1)}, 100)), 'mTRFExport:Mismatch'), ...
    'different trial counts are refused');
check(strcmp(errorId(@() mTRFExport.package(ones(5, 1), ones(5, 2), 100, RespLabels="a")), 'mTRFExport:Mismatch'), ...
    'the wrong number of labels is refused');

fprintf('\n== 7. lagSamples ==\n');
[tl, sl] = mTRFExport.lagSamples(-100, 400, 128);
check(isequal(sl, -13:52) && abs(tl(1) + 13 / 128 * 1e3) < 1e-9, 'floor(tmin) .. ceil(tmax) samples, in ms');

fprintf('\n== 8. the toolbox ==\n');
restore = '';
if ~mTRFExport.hasMTRF()
    mtrf = 'c:\src\mTRF-Toolbox\mtrf';
    if isfolder(mtrf)
        restore = path;
        addpath(genpath(mtrf));
    end
end
if ~isempty(restore); cleaner = onCleanup(@() path(restore)); end %#ok<NASGU>
if mTRFExport.hasMTRF()
    % a known kernel: the response to impulses of unit area is the kernel itself
    fs = 128;
    lagsMs = [0 200];
    [~, lagS] = mTRFExport.lagSamples(lagsMs(1), lagsMs(2), fs);
    h = exp(-((lagS / fs - 0.05) / 0.015) .^ 2) - 0.5 * exp(-((lagS / fs - 0.11) / 0.02) .^ 2);   % uV per event
    rng(7);
    stim = cell(6, 1); resp = cell(6, 1);
    for k = 1:6
        n = 20 * fs;
        on = sort(randperm(n - 40, 25)).' - 1;          % 25 events in 20 s
        x = mTRFExport.pulses([on on] / fs, fs, n, Height=fs);
        y = conv(x, h) / fs;                               % unit-area impulses: a kernel per event
        y = y(1:n);
        stim{k} = x;
        resp{k} = [y, 0.5 * y] + 0.01 * randn(n, 2);
    end
    M = mTRFExport.package(stim, resp, fs, StimLabels="event", RespLabels=["near" "far"]);
    model = mTRFtrain(M.stim, M.resp, M.fs, 1, lagsMs(1), lagsMs(2), 1e-3, 'verbose', 0);
    w = squeeze(model.w);                                   % [nLag x 2]
    check(isequal(size(w), [numel(lagS) 2]) && max(abs(w(:, 1) - h.')) < 0.02 && max(abs(w(:, 2) - 0.5 * h.')) < 0.02, ...
        'mTRFtrain on unit-area impulses returns the kernel in the response''s units');
    cv = mTRFcrossval(M.stim, M.resp, M.fs, 1, lagsMs(1), lagsMs(2), [1e-3 1e3], 'verbose', 0);
    check(isequal(size(cv.r), [6 2 2]) && mean(cv.r(:, 1, 1)) > 0.9, ...
        'mTRFcrossval folds over the package''s trials; the small ridge predicts the left-out trial');
    [pred, stats] = mTRFpredict(M.stim(6), M.resp(6), model, 'verbose', 0);
    if iscell(pred); pred = pred{1}; end
    check(isequal(size(pred), size(M.resp{6})) && all(stats.r(:) > 0.9), 'mTRFpredict on one trial');
    % a trial window of the same data gives a model too
    [C, keep, tC] = mTRFExport.trials(resp{1}, fs, on(6:10) / fs, [-0.05 0.3]);
    S = mTRFExport.trials(stim{1}, fs, on(6:10) / fs, [-0.05 0.3]);
    Mt = mTRFExport.package(S, C, fs, Time=tC);
    check(nnz(keep) >= 1 && Mt.nTrials == nnz(keep) && numel(Mt.t) == size(Mt.resp{1}, 1), 'trials cut from the same rows pair up');
else
    fprintf('  (mTRF-Toolbox not on the path; model checks skipped)\n');
end

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_MTRFExport:Failures', '%d checks failed.', nFail);
end
end
