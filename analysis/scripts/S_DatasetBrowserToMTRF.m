%% DatasetBrowser to mTRF-Toolbox
% A post-processing script of the DatasetBrowser (or run by hand with B in the
% workspace): it turns the browser's signal (or spike trains) and a stimulus
% into the stimulus / response pairs the mTRF-Toolbox fits (Crosse et al.
% 2016, Front Hum Neurosci 10:604, https://github.com/mickcrosse/mTRF-Toolbox),
% one mTRFExport.package per dataset, in either of two ways:
%
%   1. Epochs: "Keep single trials" ticked, Compute. Each epoch of R.epochs
%      becomes a trial, with an impulse on its event as the stimulus:
%      epochMatrixMTRF. -> mtEpochs. A forward model fit on it is the mean
%      evoked response, lag by lag (the check that both agree).
%   2. Whole sessions: "Load whole sessions". Each dataset's whole signal,
%      resampled to fs, is the response; the stimulus is the pulses of a
%      digital line (the browser's event line by default), a trial parameter
%      on each trial's onset, or an AUX channel's envelope (auxChannel). The
%      artifact-free stretches of the session, split into pieces of at most
%      maxSeconds, are the trials the toolbox cross-validates over:
%      sessionDataMTRF, Mode "segments". -> mtSessions. The kept trials cut in
%      the browser's window are made too (Mode "trials"). -> mtTrials
%
% Either part runs when its data is there. The toolbox itself is needed only
% to fit (mTRFcrossval, mTRFtrain, mTRFpredict) and to plot (mTRFplot): the
% last sections do, when it is on the path. Works the same for LFP, MUA,
% SPIKE, AUX and the spike trains of units / detected (binned as rates).
%
% A forward model (Dir = 1, a TRF) says how the response follows the
% stimulus at each lag; a backward model (Dir = -1, a decoder) reconstructs
% the stimulus from every channel at once. Both are ridge regressions over
% time-lagged copies of the input; lambda, the ridge, is picked by
% leave-one-trial-out cross-validation (the correlation between the
% prediction and the data on the left-out trial).

if ~exist('B', 'var') || ~isa(B, 'DatasetBrowser')
    error('B is not a DatasetBrowser: run this from the browser (Post-processing script), or set B = DatasetBrowser.open(root) first.');
end
mtrfPath = 'c:\src\mTRF-Toolbox\mtrf';   % added (with its subfolders) when the toolbox is not on the path
outDir = "";                % a folder to save <dataset>_mtrf_*.mat in; "" keeps them in the workspace only
fs = 128;                   % Hz, the rate the models are fit at (the toolbox's examples use 64-128)
stimulus = "";              % the stimulus of the whole sessions: "" = the browser's event line (an impulse on each
                            % onset); or line names and numeric trial columns, e.g. ["Stim" "Depth"]; see sessionDataMTRF
kind = "onset";             % each line's feature: "onset" | "offset" | "boxcar"
auxChannel = [];            % a column of the datasets' AUX signal (e.g. the speaker monitor): its envelope is the
                            % stimulus instead of `stimulus`
maxSeconds = 30;            % whole sessions: the longest piece (a trial = a cross-validation fold)
tmin = -100; tmax = 400;    % ms, the lags of the model (negative = the response leads the stimulus)
lambda = 10 .^ (-2:1:6);    % the ridge values cross-validated
holdOut = [];               % the trial kept out of training to test the final model on: [] = the first one
                            % whose stimulus changes, a number = that trial, 0 = none

%% 1. Epochs (R.epochs): a trial per epoch, an impulse on the event
R = B.Result;
mtEpochs = {};
if ~isempty(R) && isfield(R, 'epochs') && ~isempty(R.epochs)
    mtEpochs = epochMatrixMTRF(R, Fs=fs);
    fprintf('mtEpochs: %d datasets, %d epochs at %g Hz, %s\n', numel(mtEpochs), ...
        sum(cellfun(@(m) m.nTrials, mtEpochs)), mtEpochs{1}.fs, R.labels.description);
end

%% 2. Whole sessions (B.Sessions): the stimulus over the whole recording
S = B.Sessions;
mtSessions = {};
mtTrials = {};
if ~isempty(S)
    S = S(arrayfun(@(D) ~isempty(D.signal) || ~isempty(D.spikes), S));   % "Load trials only" brings no data
end
if ~isempty(S)
    stim = stimulus;
    if isempty(auxChannel)
        if isscalar(stim) && stim == ""; stim = B.Settings.ref.line; end
        if isscalar(stim) && stim == "Trial"; stim = S(1).trialLine; end   % the browser's "Trial" = the paired trial line
    else
        % the envelope of one AUX channel, read from each dataset's AUX extract as the stimulus
        stim = @(D) auxEnvelopeStimulus(B, D, auxChannel, fs);
    end
    mtSessions = sessionDataMTRF(S, Stimulus=stim, Kind=kind, Fs=fs, Mode="segments", MaxSeconds=maxSeconds);
    win = B.Settings.window;
    mtTrials = sessionDataMTRF(S, Stimulus=stim, Kind=kind, Fs=fs, Mode="trials", Window=[win.pre win.post]);
    fprintf('mtSessions: %d datasets, %s; %d pieces of <= %g s; mtTrials: %d kept trials\n', ...
        numel(mtSessions), mtSessions{1}.cfg.stimulus, sum(cellfun(@(m) m.nTrials, mtSessions)), ...
        maxSeconds, sum(cellfun(@(m) m.nTrials, mtTrials)));
end

if isempty(mtEpochs) && isempty(mtSessions)
    error(['Nothing to convert: Compute with "Keep single trials" ticked (B.Result.epochs), ' ...
        'or "Load whole sessions" (B.Sessions).']);
end

if outDir ~= ""
    for m = [mtEpochs; mtSessions; mtTrials].'
        M = m{1};
        save(fullfile(outDir, M.cfg.name + "_mtrf_" + packageKind(M) + ".mat"), '-struct', 'M', '-v7.3');
    end
end

%% The toolbox: cross-validate the ridge, train, test on a held-out trial
% Everything below needs the mTRF-Toolbox on the path.
if ~mTRFExport.hasMTRF() && isfolder(mtrfPath); addpath(genpath(mtrfPath)); end
if ~mTRFExport.hasMTRF()
    disp('The mTRF-Toolbox is not on the path: set mtrfPath to its mtrf folder to fit models.');
    return
end

% the data to model: the first dataset's whole session (every piece a fold) when it
% gives at least 3 pieces, else its kept trials, else its epochs
candidates = [mtSessions(1:min(1, end)); mtTrials(1:min(1, end)); mtEpochs(1:min(1, end))];
enough = cellfun(@(m) m.nTrials >= 3, candidates);
if ~any(enough)
    error('%s gives at most %d trial(s): the toolbox cross-validates over at least 2 (lower maxSeconds, or compute more epochs).', ...
        candidates{1}.cfg.name, max(cellfun(@(m) m.nTrials, candidates)));
end
M = candidates{find(enough, 1)};
% pieces whose stimulus never changes (no event in them) cannot be scored: their fold's r is NaN
silent = cellfun(@(x) all(x(:) == x(1)), M.stim);
if any(silent)
    fprintf('%d of %d trials hold no change of the stimulus: they train but cannot be scored (raise maxSeconds).\n', ...
        nnz(silent), M.nTrials);
end
test = false(M.nTrials, 1);
if isempty(holdOut); holdOut = find(~silent, 1); end
if holdOut >= 1; test(min(holdOut, M.nTrials)) = true; end
train = ~test;

% forward (encoding) model: the TRF of every channel
cvF = mTRFcrossval(M.stim(train), M.resp(train), M.fs, 1, tmin, tmax, lambda, 'verbose', 0);
rF = squeeze(mean(cvF.r, 1, 'omitnan'));         % [nLambda x nChannels] mean over the folds scored
if isvector(rF); rF = reshape(rF, numel(lambda), []); end
[~, iF] = max(mean(rF, 2));                      % the ridge best on average over the channels
trf = mTRFtrain(M.stim(train), M.resp(train), M.fs, 1, tmin, tmax, lambda(iF), 'verbose', 0);
trf.label = M.respLabels; trf.pos = M.pos; trf.featureLabels = M.stimLabels;   % names for the plots
fprintf('Forward model (%s -> %s): lambda = %g, CV r = %.3f (mean over %d channels)\n', ...
    strjoin(M.stimLabels, '+'), M.cfg.data, lambda(iF), max(mean(rF, 2)), M.nChannels);

% backward (decoding) model: the stimulus from every channel at once
cvB = mTRFcrossval(M.stim(train), M.resp(train), M.fs, -1, tmin, tmax, lambda, 'verbose', 0);
rB = squeeze(mean(cvB.r, 1, 'omitnan'));
if isvector(rB); rB = reshape(rB, numel(lambda), []); end
[~, iB] = max(mean(rB, 2));
decoder = mTRFtrain(M.stim(train), M.resp(train), M.fs, -1, tmin, tmax, lambda(iB), 'verbose', 0);
fprintf('Backward model (%s -> %s): lambda = %g, CV r = %.3f\n', ...
    M.cfg.data, strjoin(M.stimLabels, '+'), lambda(iB), max(mean(rB, 2)));

% the held-out trial: the prediction of each model against the data
if any(test)
    [predF, statsF] = mTRFpredict(M.stim(test), M.resp(test), trf, 'verbose', 0);
    [predB, statsB] = mTRFpredict(M.stim(test), M.resp(test), decoder, 'verbose', 0);
    if ~iscell(predF); predF = {predF}; end
    if ~iscell(predB); predB = {predB}; end
    fprintf('Held-out trial %d: forward r = %.3f (mean over channels), backward r = %.3f\n', ...
        find(test, 1), mean(statsF.r, 'all', 'omitnan'), mean(statsB.r, 'all', 'omitnan'));
end

%% Plots: the TRFs, the cross-validation, the held-out trial
fig = figure('Name', M.cfg.name + ": mTRF", 'Color', 'w', 'Position', [100 100 1100 700]);
tl = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
unitText = M.respUnits; if unitText == ""; unitText = "a.u."; end

% the TRF of every channel (summed over the features), with the toolbox's plot
ax = nexttile(tl);
mTRFplot(trf, 'trf', 'all', 'all', [tmin tmax]);
title(ax, 'TRF per channel'); xlabel(ax, 'Lag (ms)'); ylabel(ax, "Weight (" + unitText + " per event)");

% the same as an image, channels in probe order (depth) when positions are known
ax = nexttile(tl);
W = squeeze(sum(trf.w, 1));                      % [nLag x nChannels]
if isvector(W); W = reshape(W, numel(trf.t), []); end
ord = 1:M.nChannels;
if all(isfinite(M.pos(:, 2))); [~, ord] = sortrows(M.pos, [-2 1]); end   % top of the probe first
imagesc(ax, trf.t, 1:M.nChannels, W(:, ord).');
cl = max(abs(W), [], 'all'); if cl > 0; clim(ax, [-cl cl]); end
colormap(ax, blueWhiteRed(256));
colorbar(ax);
yticks(ax, 1:M.nChannels); yticklabels(ax, M.respLabels(ord));
xline(ax, 0, 'k');
title(ax, 'TRF by channel'); xlabel(ax, 'Lag (ms)');

% the global field power across channels
ax = nexttile(tl);
mTRFplot(trf, 'gfp', 'all', 'all', [tmin tmax]);
title(ax, 'Global field power'); xlabel(ax, 'Lag (ms)'); ylabel(ax, 'GFP');

% the cross-validation: r against lambda, both directions
ax = nexttile(tl);
hF = semilogx(ax, lambda, mean(rF, 2), '-o');
hold(ax, 'on');
hB = semilogx(ax, lambda, mean(rB, 2), '-s');
xline(ax, lambda(iF), ':', 'HandleVisibility', 'off'); xline(ax, lambda(iB), ':', 'HandleVisibility', 'off');
hold(ax, 'off'); grid(ax, 'on');
legend(ax, [hF hB], {'forward (mean over channels)', 'backward'}, 'Location', 'best');
title(ax, 'Cross-validation'); xlabel(ax, '\lambda'); ylabel(ax, 'r (left-out trial)');

% the held-out trial: the best-predicted channel, and the decoded stimulus
if any(test)
    ax = nexttile(tl);
    y = M.resp{find(test, 1)}; p = predF{1};
    [~, c] = max(statsF.r(1, :));
    tt = (0:size(y, 1) - 1) / M.fs;
    plot(ax, tt, y(:, c), 'DisplayName', 'measured'); hold(ax, 'on');
    plot(ax, tt, p(:, c), 'DisplayName', sprintf('predicted (r = %.2f)', statsF.r(1, c)));
    hold(ax, 'off'); legend(ax, 'Location', 'best');
    title(ax, "Held-out trial, " + M.respLabels(c)); xlabel(ax, 'Time in the trial (s)'); ylabel(ax, M.cfg.data + " (" + unitText + ")");

    ax = nexttile(tl);
    s = M.stim{find(test, 1)}; q = predB{1};
    plot(ax, tt, s(:, 1) / max(abs(s(:, 1)) + eps), 'DisplayName', 'stimulus'); hold(ax, 'on');
    plot(ax, tt, q(:, 1) / max(abs(q(:, 1)) + eps), 'DisplayName', sprintf('decoded (r = %.2f)', statsB.r(1, 1)));
    hold(ax, 'off'); legend(ax, 'Location', 'best');
    title(ax, "Held-out trial, " + M.stimLabels(1) + " decoded"); xlabel(ax, 'Time in the trial (s)'); ylabel(ax, 'normalized');
end
title(tl, sprintf('%s: %s, %d trials at %g Hz, lags %d..%d ms', M.cfg.name, M.cfg.stimulus, M.nTrials, M.fs, tmin, tmax), ...
    'Interpreter', 'none');

%% The check: a TRF of the epochs is the evoked mean
% With an impulse of unit area on every epoch's event and no ridge to speak
% of, the forward model's weight at lag tau plus its bias (b/fs: the toolbox
% predicts (b + sum w x) / fs) is the mean epoch at tau.
if ~isempty(mtEpochs)
    E = mtEpochs{1};
    lagMs = [ceil(E.t(1) * E.fs) floor(E.t(end) * E.fs)] / E.fs * 1e3;
    evoked = mTRFtrain(E.stim, E.resp, E.fs, 1, lagMs(1), lagMs(2), 1e-6, 'verbose', 0);
    meanEpoch = mean(cat(3, E.resp{:}), 3);                      % [nTime x nChannels]
    j0 = round(-E.t(1) * E.fs) + 1;                              % the event's sample
    lagS = round(evoked.t / 1e3 * E.fs);
    inside = j0 + lagS >= 1 & j0 + lagS <= numel(E.t);
    W = squeeze(evoked.w(1, :, :));
    if isvector(W); W = reshape(W, numel(evoked.t), []); end
    bias = reshape(evoked.b, 1, []) / E.fs;
    gap = max(abs(W(inside, :) + bias - meanEpoch(j0 + lagS(inside), :)), [], 'all');
    fprintf('Epochs of %s: TRF vs the evoked mean, largest gap %.3g %s (%d epochs)\n', ...
        E.cfg.name, gap, E.respUnits, E.nTrials);
end

%% Local functions
function s = auxEnvelopeStimulus(B, D, channel, fs)
% One AUX column of dataset D, read from its extract, as a stimulus struct for sessionDataMTRF
src = B.source(D.key);
[x, fsAux, meta] = selectChannels(src, "AUX", Channels=channel);
[y, fsEnv] = mTRFExport.envelope(x, fsAux, fs);
s = struct('x', y, 'fs', fsEnv, 'labels', string(meta.label).' + " envelope");
end

function k = packageKind(M)
if isfield(M.cfg, 'epochs'); k = "epochs"; elseif M.cfg.mode == "trials"; k = "trials"; else; k = "session"; end
end
