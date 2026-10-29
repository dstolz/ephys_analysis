function test_CSDEstimate()
%test_CSDEstimate  Verification suite for the current source density connectors.
%   Checks laminarColumns (a staggered shank merges into one profile, a true
%   two-column shank separates, "2d" positions, several shanks, unplaced
%   channels and small columns dropped, a gap breaks uniformity),
%   epochMatrixCSD on a made-up result (the group means in V, the epochs
%   scaled, median, a group without epochs, the errors) and sessionDataCSD
%   on a made-up session (the signal transposed and scaled, the kept trials
%   cut as mTRFExport.trials cuts them, an artifact drops a trial, the
%   errors); then the estimators on a known potential: icsdEstimate (the
%   standard method recovers the constant CSD of a quadratic potential in
%   uA/mm^3; every method puts the source of a Gaussian bump at its center,
%   is linear over pages, and the errors) when the iCSD toolbox is on the
%   path or at c:\src\iCSD, and kcsdEstimate (the same bump, the fit at the
%   channels, a cross-validation's errors table, a 2-D layout, the errors)
%   when a Python with kcsd is found. Either estimator's section is skipped
%   without its toolbox.
%
%   Usage:  test_CSDEstimate

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fullfile(fileparts(here), 'pipeline'));

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

fprintf('\n== 1. laminarColumns ==\n');
% a staggered 16-site shank (makeSyntheticProbe's layout): x alternates 0 / 8 um, y = 25 um steps
site = (0:15).';
T = table("c" + string(site + 1), site + 1, zeros(16, 1), 8 * mod(site, 2), 25 * site, repmat("uV", 16, 1), ...
    'VariableNames', {'label', 'channel', 'shank', 'x', 'y', 'units'});
C = laminarColumns(T);
check(isscalar(C) && C.dim == 1 && numel(C.rows) == 16, 'auto: a staggered shank is one 16-channel profile');
check(isequal(C.rows, (16:-1:1).') && C.depth_mm(1) == 0 && all(diff(C.depth_mm) > 0), ...
    'the rows run from the top channel (largest y) down; depth 0 at the top, ascending');
check(abs(C.h_mm - 0.025) < 1e-12 && C.uniform && isequal(C.x_um, [0 8]) && isequal(C.pos_mm, C.depth_mm), ...
    'spacing 25 um, uniform, both x noted, pos_mm = depth_mm');
check(isequal(C.label, "c" + string(16:-1:1).') && isequal(C.channel, (16:-1:1).'), 'labels and channels follow the rows');
C2 = laminarColumns(T, Columns="separate");
check(numel(C2) == 2 && all([C2.dim] == 1) && all(arrayfun(@(c) numel(c.rows), C2) == 8) ...
    && abs(C2(1).h_mm - 0.05) < 1e-12 && C2(1).x_um == 0 && C2(2).x_um == 8, 'separate: one 8-channel profile per x, 50 um apart');
C3 = laminarColumns(T, Columns="2d");
check(isscalar(C3) && C3.dim == 2 && isequal(size(C3.pos_mm), [16 2]) && isequal(C3.pos_mm(:, 2), C3.depth_mm) ...
    && isequal(sort(unique(C3.pos_mm(:, 1))), [0; 0.008]), '2d: positions [x depth] in mm, x from the leftmost channel');
% a true two-column shank: the same depths in both columns separate under auto
T2 = T; T2.x = 20 * mod(site, 2); T2.y = 25 * floor(site / 2);
C4 = laminarColumns(T2);
check(numel(C4) == 2 && all(arrayfun(@(c) numel(c.rows), C4) == 8) && abs(C4(1).h_mm - 0.025) < 1e-12, ...
    'auto: two columns sharing depths give one profile per x');
C5 = laminarColumns(T2, Columns="merged");
check(isscalar(C5) && numel(C5.rows) == 16 && abs(C5.h_mm - 0.025) < 1e-12 && nnz(diff(C5.depth_mm) == 0) == 8, ...
    'merged: one profile of 16 with pairs at one depth; h from the steps between depths');
% two shanks, unplaced channels, a small column, Shanks=
T3 = [T; T];
T3.shank(17:32) = 1; T3.x(17:32) = T3.x(17:32) + 200; T3.channel(17:32) = 17:32;
T3.x(20) = NaN;                                   % one channel of shank 1 has no position
T3 = [T3; table("odd", 33, 2, 500, 0, "uV", 'VariableNames', T3.Properties.VariableNames)];
C6 = laminarColumns(T3);
check(numel(C6) == 2 && isequal([C6.shank], [0 1]) && numel(C6(2).rows) == 15 && ~ismember(20, C6(2).rows), ...
    'two shanks in order; the unplaced channel left out; a one-channel shank dropped');
check(~C6(2).uniform && abs(C6(2).h_mm - 0.025) < 1e-12, 'the gap the missing channel leaves breaks uniformity; h is the median step');
C7 = laminarColumns(T3, Shanks=1);
check(isscalar(C7) && C7.shank == 1, 'Shanks= keeps one shank');
check(isempty(laminarColumns(T3, MinChannels=20)), 'MinChannels above every column gives none');
check(strcmp(errorId(@() laminarColumns(T(:, {'label', 'channel'}))), 'laminarColumns:NoPositions'), 'no x, y: laminarColumns:NoPositions');

fprintf('\n== 2. epochMatrixCSD ==\n');
nT = 50; t = ((0:nT - 1).' - 10) / 1000;
E = table((1:6).', [1 1 2 2 1 3].', (1:6).' * 2, 'VariableNames', {'trial', 'resultGroup', 't0Continuous'});
X = single(randn(16, nT, 6));
R = struct('rowKind', "channel", 'valueUnits', "uV", 't', t, 'groupLabels', ["a"; "b"; "c"; "d"], ...
    'keys', "k1", 'settings', struct('data', "LFP", 'signal', struct('statistic', "mean")), ...
    'labels', struct('description', "d", 'event', "Stim", 'window', "w", 'groups', ["a" "b" "c" "d"]), ...
    'rows', T, 'epochs', struct('key', "k1", 'name', "n1", 'rows', (1:16).', 'E', E, 'spikes', [], 'data', X));
P = epochMatrixCSD(R);
check(isscalar(P) && P.key == "k1" && isequal(size(P.pots), [16 nT 4]) && isequal(size(P.epochs), [16 nT 6]), ...
    'one profile; pots [nChan x nTime x nGroups], epochs [nChan x nTime x nEpochs]');
expectA = mean(double(X(16:-1:1, :, [1 2 5])), 3) * 1e-6;
check(max(abs(P.pots(:, :, 1) - expectA), [], 'all') < 1e-12 && isequal(P.rows, (16:-1:1).'), ...
    'group a: the mean of its epochs, channels top down, uV -> V');
check(all(isnan(P.pots(:, :, 4)), 'all') && isequal(P.nEpochs, [3; 2; 1; 0]), 'a group without epochs is NaN; nEpochs counts');
check(max(abs(double(P.epochs(:, :, 3)) - double(X(16:-1:1, :, 3)) * 1e-6), [], 'all') < 1e-12 && isequal(P.group, E.resultGroup), ...
    'every epoch kept, scaled, with its group');
check(P.units == "V" && abs(P.fs - 1000) < 1e-9 && isequal(P.t, t) && P.cfg.scale == 1e-6 && P.cfg.data == "LFP", 'units, fs, t and cfg');
R2 = R; R2.settings.signal.statistic = "median";
P2 = epochMatrixCSD(R2);
check(max(abs(P2.pots(:, :, 1) - median(double(X(16:-1:1, :, [1 2 5])), 3) * 1e-6), [], 'all') < 1e-12, 'statistic median');
P3 = epochMatrixCSD(R, Columns="separate");
check(numel(P3) == 2 && isequal(size(P3(1).pots), [8 nT 4]), 'Columns= goes through: two profiles of 8');
R3 = R; R3.rows.units(:) = "V";
check(abs(epochMatrixCSD(R3).cfg.scale - 1) < eps, 'a result in V is not scaled');
check(strcmp(errorId(@() epochMatrixCSD(rmfield(R, 'epochs'))), 'epochMatrixCSD:NoEpochs'), 'no epochs: epochMatrixCSD:NoEpochs');
R4 = R; R4.rowKind = "unit";
check(strcmp(errorId(@() epochMatrixCSD(R4)), 'epochMatrixCSD:NotSignal'), 'a spike result: epochMatrixCSD:NotSignal');
R5 = R; R5.rows = R5.rows(:, {'label', 'channel', 'shank', 'units'});
check(strcmp(errorId(@() epochMatrixCSD(R5)), 'epochMatrixCSD:NoPositions'), 'no positions: epochMatrixCSD:NoPositions');
check(strcmp(errorId(@() epochMatrixCSD(R, MinChannels=20)), 'epochMatrixCSD:NoColumn'), 'no column big enough: epochMatrixCSD:NoColumn');
R6 = R; R6.rows.units(:) = "spikes/s";
check(strcmp(errorId(@() epochMatrixCSD(R6)), 'epochMatrixCSD:Units'), 'not a voltage: epochMatrixCSD:Units');

fprintf('\n== 3. sessionDataCSD ==\n');
fs = 1000; N = 5000;
sig = single(randn(N, 16));
trials = table([0.5; 1.5; 2.5; 3.5; 4.5], 'VariableNames', {'TrialOnset'});
groups = table((1:2).', ["x"; "y"], 'VariableNames', {'index', 'label'});
D = struct('key', "k1", 'name', "n1", 'data', "LFP", 'signal', sig, 'signalFs', fs, 'channels', T, ...
    'hasTrials', true, 'trials', trials, 'kept', [true; true; false; true; true], 'group', [1; 2; 0; 1; 2], ...
    'groups', groups, 'toContinuous', @(x) x, 'artifacts', [3.4 3.45], 'eventsContinuous', struct('Stim', [0.5 0.6]), ...
    'durationSec', N / fs, 'fs', 30000);
Q = sessionDataCSD(D);
check(isscalar(Q) && isequal(size(Q.signal), [16 N]) && isa(Q.signal, 'single') ...
    && max(abs(double(Q.signal) - double(sig(:, 16:-1:1)).' * 1e-6), [], 'all') < 1e-12, ...
    'the whole signal, [nChan x nSamples] top down, uV -> V, single');
check(~isfield(Q, 'pots') && isequal(Q.artifacts, [3.4 3.45]) && isequal(Q.events, D.eventsContinuous) && Q.cfg.groups.label(2) == "y", ...
    'no window: no epochs; artifacts, events and groups carried');
Q2 = sessionDataCSD(D, Window=[-0.1 0.2]);
[Cc, keep, tt] = mTRFExport.trials(sig, fs, [0.5; 1.5; 3.5; 4.5], [-0.1 0.2], Artifacts=[3.4 3.45]);
check(isequal(Q2.t, tt(:)) && isequal(Q2.trial, [1; 2; 5]) && isequal(Q2.group, [1; 2; 2]), ...
    'kept trials cut in the window; the one touching the artifact dropped (keep = [1 1 0 1])');
check(isequal(keep, [true; true; false; true]) && max(abs(double(Q2.epochs(:, :, 2)) - Cc{2}(:, 16:-1:1).' * 1e-6), [], 'all') < 1e-12, ...
    'each epoch is mTRFExport.trials'' cut, channels top down, in V');
check(isequal(size(Q2.pots), [16 numel(tt) 2]) && max(abs(Q2.pots(:, :, 2) - mean(double(Q2.epochs(:, :, 2:3)), 3)), [], 'all') < 1e-12 ...
    && isequal(Q2.nEpochs, [1; 2]) && isequal(Q2.groupLabels, ["x"; "y"]), 'pots: the group means; nEpochs; the groups'' labels');
D2 = D; D2.signal = []; D2.data = "units";
check(strcmp(errorId(@() sessionDataCSD(D2)), 'sessionDataCSD:NoSignal'), 'spike data: sessionDataCSD:NoSignal');
D3 = D; D3.hasTrials = false;
check(strcmp(errorId(@() sessionDataCSD(D3, Window=[-0.1 0.2])), 'sessionDataCSD:NoTrials'), 'no trials: sessionDataCSD:NoTrials');
check(strcmp(errorId(@() sessionDataCSD(D, Window=[-0.1 0.2], Align="Nope")), 'sessionDataCSD:NoTrials'), 'no Align column: sessionDataCSD:NoTrials');

% the known potentials of sections 4 and 5: 16 channels 0.1 mm apart
depth = (0:15).' * 0.1;                               % mm below the top channel
tt = (0:99) / 1000;
bump = exp(-((depth - 0.75) / 0.2) .^ 2) * 1e-3;      % V, a Gaussian bump centered between channels 8 and 9
pots = bump .* (1 + 0 * tt);                          % constant in time
pots2 = cat(3, pots, 2 * pots);

fprintf('\n== 4. icsdEstimate (iCSD toolbox) ==\n');
if ~exist('iCSD_spline', 'file') && isfolder('c:\src\iCSD'); addpath(genpath('c:\src\iCSD')); end
if ~exist('iCSD_spline', 'file')
    fprintf('  (skipped: the iCSD toolbox is not on the path)\n');
else
    % a quadratic potential: CSD = -cond * d2V/dz2 = -0.3 * 2a, a in V/m^2
    a = 1e3; z = depth * 1e-3;                        % m
    quad = (a * z .^ 2) .* (1 + 0 * tt);
    [csd, zs, info] = icsdEstimate(quad, depth, Method="standard", B1=0, Cond=0.3);
    expected = -0.3 * 2 * a * 1e-3;                   % A/m^3 -> uA/mm^3
    check(isequal(size(csd), [16 100]) && max(abs(zs - depth)) < 1e-12 && max(abs(csd(2:15, :) - expected), [], 'all') < 1e-9, ...
        sprintf('standard, unsmoothed: the quadratic''s constant CSD %.3g uA/mm^3 inside (got %.4g .. %.4g)', ...
        expected, min(csd(2:15, 1)), max(csd(2:15, 1))));
    check(info.method == "standard" && abs(info.h_mm - 0.1) < 1e-12 && info.uniform && info.units.csd == "uA/mm^3", 'info');
    [csdV, zV] = icsdEstimate(quad, depth, Method="standard", B1=0, Vaknin=false);
    check(isequal(size(csdV), [14 100]) && max(abs(zV - depth(2:15))) < 1e-12 && max(abs(csdV - expected), [], 'all') < 1e-9, ...
        'standard without Vaknin electrodes: the inner channels, the same CSD');
    for m = ["spline" "delta" "step" "standard"]
        [csd, zs] = icsdEstimate(pots, depth, Method=m);
        [~, i] = max(csd(:, 1));
        check(all(isfinite(csd), 'all') && size(csd, 2) == 100 && issorted(zs) && abs(zs(i) - 0.75) <= 0.1, ...
            sprintf('%s: finite, z ascending, the source (CSD > 0) of the bump within a spacing of its center (%.3g mm)', m, zs(i)));
        csd2 = icsdEstimate(pots2, depth, Method=m);
        check(isequal(size(csd2), [numel(zs) 100 2]) && max(abs(csd2(:, :, 2) - 2 * csd2(:, :, 1)), [], 'all') < 1e-9 * max(abs(csd2(:))), ...
            sprintf('%s: pages estimated at once, linear', m));
    end
    csdN = icsdEstimate(cat(3, pots, NaN(size(pots))), depth, Method="delta");
    check(all(isnan(csdN(:, :, 2)), 'all') && all(isfinite(csdN(:, :, 1)), 'all'), 'an all-NaN page (a group without epochs) stays NaN, the rest estimated');
    check(strcmp(errorId(@() icsdEstimate(NaN(size(pots)), depth)), 'icsdEstimate:NoData'), 'nothing finite: icsdEstimate:NoData');
    [~, zS] = icsdEstimate(pots, depth, Method="spline", NumOut=120, GaussSigma=0);
    check(numel(zS) == 120 && zS(1) < 0 && zS(end) > 1.5, 'spline: NumOut points, extending half a spacing past the end channels');
    check(strcmp(errorId(@() icsdEstimate(pots(1:15, :), depth)), 'icsdEstimate:Size'), 'rows and depths differ: icsdEstimate:Size');
    check(strcmp(errorId(@() icsdEstimate(pots, flip(depth))), 'icsdEstimate:Depths'), 'depths not ascending: icsdEstimate:Depths');
    gap = [1:7 9:16];
    for m = ["step" "delta"]
        check(strcmp(errorId(@() icsdEstimate(pots(gap, :), depth(gap), Method=m)), 'icsdEstimate:NotUniform'), ...
            sprintf('a gap: %s refuses with icsdEstimate:NotUniform', m));
    end
    csdG = icsdEstimate(pots(gap, :), depth(gap), Method="spline");
    check(all(isfinite(csdG), 'all'), 'spline takes the unequal spacing');
    check(strcmp(errorId(@() icsdEstimate(pots, depth, Method="spline", Surface=0)), 'icsdEstimate:Surface'), ...
        'spline with the top channel at the surface: icsdEstimate:Surface');
end

fprintf('\n== 5. kcsdEstimate (kCSD-python) ==\n');
pyOk = true;
try
    kcsdEstimate(depth(1:3), pots(1:3, 1:2), Lambda=0);
catch ME
    if strcmp(ME.identifier, 'kcsdEstimate:NoPython')
        pyOk = false;
        fprintf('  (skipped: %s)\n', strtok(ME.message, newline));
    else
        rethrow(ME);
    end
end
if pyOk
    [csd, G, info] = kcsdEstimate(depth, pots, RInit=0.2, Lambda=0, Gdx=0.025);
    [~, i] = max(csd(:, 1));
    check(isequal(size(csd), [numel(G.x) 100]) && G.x(1) == 0 && abs(G.x(end) - 1.5) < 1e-9 && numel(G.x) == 61, ...
        'KCSD1D on the channels'' span at Gdx: [nX x nTime]');
    check(all(isfinite(csd), 'all') && abs(G.x(i) - 0.75) <= 0.1, sprintf('the source of the bump within a spacing of its center (%.3g mm)', G.x(i)));
    c = corrcoef(info.potEst(:, 1), pots(:, 1));
    check(isequal(size(info.potEst), [16 100]) && c(1, 2) > 0.99 && info.R == 0.2 && info.lambd == 0 && isempty(info.cv), ...
        'potEst reproduces the potentials (V); R and lambda as given; no cv');
    csd2 = kcsdEstimate(depth, pots2, RInit=0.2, Lambda=0, Gdx=0.025);
    check(isequal(size(csd2), [61 100 2]) && max(abs(csd2(:, :, 2) - 2 * csd2(:, :, 1)), [], 'all') < 1e-6 * max(abs(csd2(:))), ...
        'pages estimated at once, linear');
    [csdN, ~, infoN] = kcsdEstimate(depth, cat(3, pots(:, 1:5), NaN(16, 5)), RInit=0.2, Lambda=0, Gdx=0.05);
    check(all(isnan(csdN(:, :, 2)), 'all') && all(isfinite(csdN(:, :, 1)), 'all') && all(isnan(infoN.potEst(:, :, 2)), 'all'), ...
        'an all-NaN page (a group without epochs) stays NaN in csd and potEst, the rest estimated');
    check(strcmp(errorId(@() kcsdEstimate(depth, NaN(16, 3))), 'kcsdEstimate:NoData'), 'nothing finite: kcsdEstimate:NoData');
    [~, ~, infoCV] = kcsdEstimate(depth, pots(:, 1:5), Lambdas=[0 1e-6 1e-3], Rs=[0.1 0.2], Gdx=0.05);
    check(isequal(size(infoCV.cv.errors), [2 3]) && isequal(infoCV.cv.lambdas, [0; 1e-6; 1e-3]) && isequal(infoCV.cv.Rs, [0.1; 0.2]) ...
        && ismember(infoCV.R, [0.1 0.2]) && ismember(infoCV.lambd, [0 1e-6 1e-3]), ...
        'cross-validation over Lambdas and Rs: errors [nRs x nLambdas], the best pair used');
    pos2 = [repmat([0; 0.05], 8, 1), kron((0:7).' * 0.1, [1; 1])];   % two columns 50 um apart, 8 depths
    bump2 = exp(-((pos2(:, 2) - 0.35) / 0.15) .^ 2) * 1e-3 .* (1 + 0 * tt(1:10));
    [csd3, G3] = kcsdEstimate(pos2, bump2, RInit=0.15, Lambda=0, Gdx=0.025, Gdy=0.05);
    check(isequal(size(csd3), [numel(G3.x) numel(G3.y) 10]) && numel(G3.x) == 3 && numel(G3.y) == 15 && all(isfinite(csd3), 'all'), ...
        'KCSD2D on [x depth] positions: [nX x nY x nTime]');
    check(strcmp(errorId(@() kcsdEstimate(depth(1:15), pots)), 'kcsdEstimate:Size'), 'rows and positions differ: kcsdEstimate:Size');
    check(strcmp(errorId(@() kcsdEstimate(rand(16, 3), pots)), 'kcsdEstimate:Dim'), 'three columns: kcsdEstimate:Dim');
    check(strcmp(errorId(@() kcsdEstimate(depth, pots, Python="no_such_python.exe")), 'kcsdEstimate:NoPython'), ...
        'a Python that does not run: kcsdEstimate:NoPython');
end

fprintf('\n######## %d passed, %d failed ########\n', nPass, nFail);
if nFail > 0
    error('test_CSDEstimate:Failures', '%d check(s) failed.', nFail);
end
end
