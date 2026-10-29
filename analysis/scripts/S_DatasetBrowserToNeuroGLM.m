%% DatasetBrowser to neuroGLM
% A post-processing script of the DatasetBrowser (or run by hand with B in the
% workspace): it hands the browser's whole sessions to the neuroGLM toolbox
% (Pillow lab; Park, Meister, Huk & Pillow, Nat. Neurosci. 2014) and fits,
% for one unit per dataset, the paper's trial-based Poisson GLM:
%
%   rate(t) = exp( sum over events of kernel_e * event_e(t) + h * spikes(t) )
%
% with a kernel per digital line edge (onset and offset), one per trial group
% for the browser's event line (the paper's coherence-dependent kernels), a
% spike-history filter, and optionally the LFP as a continuous covariate.
%
% Data: "Load whole sessions" with Data = units or detected (B.Sessions holds
% the spike trains, every trial and digital line). Each kept trial becomes a
% neuroGLM trial from TrialOnset + window(1) to the next trial's start
% (window(2) = Inf) or TrialOnset + window(2). sessionDataNeuroGLM builds the
% experiment struct, NeuroGLMExport.designSpec the design, NeuroGLMExport.fit
% the fit: neuroGLM's own route (matRegress's Poisson log-likelihood
% minimized by fminunc under a ridge prior whose weight the marginal
% likelihood picks, as the paper) or plain maximum likelihood by glmfit.
%
% Leaves glm{k} per dataset in the workspace: expt (neuroGLM's experiment),
% dspec (the design), F (the fit: F.kernels.<covariate>.tr ms / .data log
% gain, F.bitsPerSpike), P (the prediction on the held-out trials), info
% (labels and trial rows), unit (the row of D.units modeled).
%
% Plots (last section): the kernels as gains, four held-out trials with the
% spikes, a smoothed rate and the model's rate (the paper's Fig. 4), and the
% PSTH per trial group, data against model (Fig. 2c).

if ~exist('B', 'var') || ~isa(B, 'DatasetBrowser')
    error('B is not a DatasetBrowser: run this from the browser (Post-processing script), or set B = DatasetBrowser.open(root) first.');
end
neuroGLMPath = 'c:\src\neuroGLM';   % added when neuroGLM is not on the path (the folder holding +buildGLM)
outDir = "";                        % a folder to save <dataset>_neuroglm.mat in; "" keeps them in the workspace only
binMs = 1;                          % neuroGLM's bin (1 ms, as the paper); 5-10 ms fits much faster on long sessions
window = [-0.5 Inf];                % s around TrialOnset; Inf = up to the next trial's start
kernelMs = 500;                     % each event kernel's reach after the event
nBases = 8;                         % raised cosines per kernel
acausal = string.empty;             % event variables whose kernel also precedes the event, e.g. "Resp_on" for the animal's response
groupKernels = true;                % one kernel per trial group (B's groupBy) for the browser's event line's onset (B.Settings.ref.line)
history = true; historyMs = 200;    % the spike-history filter
coupling = false;                   % a coupling filter from every other unit of the dataset (slow with many units)
withSignal = "";                    % "LFP" | "MUA" | "AUX" | "": that signal's channels as an instantaneous covariate
unitPick = "busiest";               % "busiest" | an index into D.units | a unit label
fitMethod = "matRegress";           % "matRegress": neuroGLM's route (fminunc, ridge prior; the paper's) | "glmfit": maximum likelihood
ridge = "evidence";                 % matRegress: the ridge prior's precision, or "evidence" to pick it by the marginal likelihood (the paper)
trainFraction = 0.8;                % trials fitted; the rest are held out for the prediction
rng(1);                             % the train/test split

%% The sessions
if ~NeuroGLMExport.hasNeuroGLM()
    addpath(neuroGLMPath);
    NeuroGLMExport.requireNeuroGLM();
end
if fitMethod == "matRegress" && ~NeuroGLMExport.hasMatRegress()
    addpath(fullfile(fileparts(fileparts(which('buildGLM.initExperiment'))), 'matRegress'));
    NeuroGLMExport.requireMatRegress();
end
S = B.Sessions;
if isempty(S)
    error('Nothing to fit: tick datasets and "Load whole sessions" with Data = units or detected.');
end
S = S(arrayfun(@(D) ~isempty(D.spikes), S));
if isempty(S)
    error('B.Sessions holds no spike trains (Data = %s): set Data to units or detected and "Load whole sessions".', B.Settings.data);
end

%% Fit one unit per dataset
glm = cell(numel(S), 1);
for k = 1:numel(S)
    D = S(k);
    args = {};
    if withSignal ~= ""
        % the same dataset's signal, whole, through sessionData (B.Sessions is spikes)
        L = sessionData(B.source(D.key), epochMatrixSettings(B.Settings, data=withSignal));
        args = {'Signal', L};
    end
    [expt, info] = sessionDataNeuroGLM(D, 'Window', window, 'BinMs', binMs, args{:});

    if isstring(unitPick) && unitPick == "busiest"
        [~, u] = max(cellfun(@numel, D.spikes));
    elseif isnumeric(unitPick)
        u = unitPick;
    else
        u = find(string(D.units.label) == string(unitPick), 1);
        if isempty(u), error('%s has no unit labeled %s.', D.name, unitPick); end
    end
    resp = info.units.variable(u);

    dsArgs = {'Response', resp, 'KernelMs', kernelMs, 'NBases', nBases, 'Acausal', acausal, ...
        'History', history, 'HistoryMs', historyMs, 'Coupling', coupling};
    if groupKernels
        % the paper's coherence-dependent kernels: the event the browser aligns to, split by trial group
        refLine = B.Settings.ref.line;
        if refLine == "Trial", refLine = D.trialLine; end
        refOn = info.lines.on(info.lines.line == refLine);
        if isempty(refOn), refOn = info.lines.on(1); end
        dsArgs = [dsArgs, {'GroupBy', "group", 'GroupEvents', refOn.'}]; %#ok<AGROW>
    end
    dspec = NeuroGLMExport.designSpec(expt, dsArgs{:});

    nT = numel(expt.trial);
    perm = randperm(nT);
    nTrain = max(1, round(trainFraction * nT));
    train = sort(perm(1:nTrain));
    test = sort(perm(nTrain + 1:end));
    if isempty(test), test = train; end

    F = NeuroGLMExport.fit(dspec, Trials=train, Method=fitMethod, Ridge=ridge);
    P = NeuroGLMExport.predict(F, test);
    fprintf('%s, unit %s: %d trials fitted (%s, ridge %g), %d held out; %.3f bits/spike (fit), %.3f (held out)\n', ...
        D.name, D.units.label(u), numel(train), fitMethod, F.ridge, numel(test), F.bitsPerSpike, P.bitsPerSpike);

    g = struct();
    g.key = D.key; g.name = D.name;
    g.unit = D.units(u, :);
    g.expt = expt; g.info = info; g.dspec = dspec; g.F = F; g.P = P;
    g.trainTrials = train; g.testTrials = test;
    glm{k} = g;
end

if outDir ~= ""
    for k = 1:numel(glm)
        g = glm{k};
        save(fullfile(outDir, g.name + "_neuroglm.mat"), '-struct', 'g', '-v7.3');
    end
end

% By hand, from here:
%   g = glm{1};
%   g.F.kernels.Stim_on.tr, exp(g.F.kernels.Stim_on.data)   % a kernel as gain over ms after the event
%   dspec2 = NeuroGLMExport.designSpec(g.expt, Response=g.dspec.response, History=false);   % another design
%   F2 = NeuroGLMExport.fit(dspec2, Trials=g.trainTrials, Method="matRegress", Ridge=10); NeuroGLMExport.predict(F2, g.testTrials).bitsPerSpike
%   semilogx(g.F.ridgeGrid, g.F.evidence)                     % the evidence over the ridge grid
%   buildGLM.addCovariate / addCovariateBoxcar on g.dspec for your own covariates (neuroGLM's tutorial.m)

%% Plot 1: the kernels as gains (exp of the log-rate change), a tile per event
g = glm{1};
F = g.F; D = S(1);
K = F.kernels; KS = F.kernelSE;
covs = string(fieldnames(K)); covs(covs == "bias") = [];
base = regexprep(covs, "__.*$", "");          % grouped kernels share their event's tile
tiles = unique(base, 'stable');
fig = figure('Name', sprintf('%s %s: neuroGLM kernels', g.name, g.unit.label), 'Color', 'w');
tl = tiledlayout(fig, 'flow', 'TileSpacing', 'compact', 'Padding', 'compact');
groups = D.groups;
usedGroups = false(height(groups), 1);
for ti = 1:numel(tiles)
    ax = nexttile(tl); hold(ax, 'on');
    members = covs(base == tiles(ti));
    wAll = [];
    for c = members.'
        tr = K.(c).tr(:, 1); w = K.(c).data(:, 1); se = KS.(c).data(:, 1);
        color = [0.15 0.15 0.15];
        lev = regexp(c, "__(\w+)$", 'tokens', 'once');
        if ~isempty(lev)
            gi = str2double(lev{1});
            if isfinite(gi) && gi >= 1 && gi <= height(groups)
                color = groups.color(gi, :); usedGroups(gi) = true;
            end
        end
        fill(ax, [tr; flipud(tr)], exp([w + se; flipud(w - se)]), color, 'FaceAlpha', 0.15, 'EdgeColor', 'none');
        plot(ax, tr, exp(w), 'Color', color, 'LineWidth', 1.5);
        wAll = [wAll; w(isfinite(w))]; %#ok<AGROW>
    end
    yline(ax, 1, ':');
    if any(K.(members(1)).tr(:, 1) < 0), xline(ax, 0, 'k'); end
    title(ax, tiles(ti), 'Interpreter', 'none');
    set(ax, 'YScale', 'log');
    % the limits follow the kernels, not their (sometimes huge) error bands; a poorly constrained kernel is clamped
    lim = [min(wAll) - 0.5, max(wAll) + 0.5];
    lim = [max(lim(1), log(1e-3)), min(lim(2), log(1e3))];
    if ~all(isfinite(lim)) || diff(lim) <= 0, lim = log([0.5 2]); end
    ylim(ax, exp(lim));
end
xlabel(tl, 'Time from the event (ms)'); ylabel(tl, 'Gain (log scale; limits follow the kernels, bands may run off)');
if any(usedGroups)
    % one legend for the groups' colors, beside the tiles
    h = gobjects(0);
    for gi = find(usedGroups).'
        h(end+1) = plot(ax, NaN, NaN, '-', 'Color', groups.color(gi, :), 'LineWidth', 1.5, 'DisplayName', groups.label(gi)); %#ok<SAGROW>
    end
    lgd = legend(h, 'Interpreter', 'none');
    lgd.Layout.Tile = 'east';
end
title(tl, sprintf('%s, unit %s: bias %.1f spikes/s, %.2f bits/spike held out', g.name, g.unit.label, ...
    exp(F.bias) * 1000 / F.binMs, g.P.bitsPerSpike), 'Interpreter', 'none');

%% Plot 2: held-out trials, spikes + smoothed rate + the model's rate (the paper's Fig. 4)
P = g.P;
nShow = min(4, numel(P.trials));
smoothMs = 100;                                  % the paper's boxcar
fig = figure('Name', sprintf('%s %s: single trials', g.name, g.unit.label), 'Color', 'w');
tl = tiledlayout(fig, nShow, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
lineVars = g.info.lines.on;                      % event marks: every line's onsets
colors = lines(numel(lineVars));
for j = 1:nShow
    ax = nexttile(tl); hold(ax, 'on');
    t = P.t{j} / 1000; counts = P.counts{j}; rate = P.rate{j};
    nb = max(1, round(smoothMs / F.binMs));
    smoothed = movmean(counts, nb) * 1000 / F.binMs;
    tr = g.expt.trial(P.trials(j));
    for e = 1:numel(lineVars)
        for et = reshape(tr.(lineVars(e)), 1, []) / 1000
            xline(ax, et, '-', 'Color', colors(e, :), 'Alpha', 0.6, 'HandleVisibility', 'off');
        end
    end
    stairs(ax, t, smoothed, 'k', 'DisplayName', sprintf('spikes, %d ms boxcar', smoothMs));
    plot(ax, t, rate, 'Color', [0.9 0.5 0.1], 'LineWidth', 1.5, 'DisplayName', 'model');
    spikeT = t(counts > 0);
    plot(ax, spikeT, -0.05 * max([rate(:); smoothed(:); 1]) * ones(size(spikeT)), '|k', 'HandleVisibility', 'off');
    title(ax, sprintf('trial %d (row %d of the trials, %s)', P.trials(j), tr.trialIndex, groups.label(tr.group)), 'Interpreter', 'none');
    if j == 1, legend(ax, 'Location', 'northeast'); end
end
xlabel(tl, 'Time from the trial''s start (s)'); ylabel(tl, 'Rate (spikes/s)');
h = gobjects(1, numel(lineVars));
for e = 1:numel(lineVars), h(e) = plot(ax, NaN, NaN, '-', 'Color', colors(e, :)); end
legend(h, lineVars, 'Interpreter', 'none', 'Location', 'southeast');

%% Plot 3: PSTH per trial group around the browser's event, data against model (Fig. 2c)
% Every trial's first onset of the browser's event line is time 0; bins outside
% a trial are left out of the average. 75 ms smoothing, as the paper's PSTHs.
psthWin = [-0.5 1.0];                            % s around the event
psthSmoothMs = 75;
refLine = B.Settings.ref.line;
if refLine == "Trial", refLine = D.trialLine; end
refVar = g.info.lines.on(g.info.lines.line == refLine);
if isempty(refVar), refVar = g.info.lines.on(1); end
Pall = NeuroGLMExport.predict(F, 1:numel(g.expt.trial));
nW = round(diff(psthWin) * 1000 / F.binMs);
tW = psthWin(1) + (0:nW - 1) * F.binMs / 1000;
Mdata = NaN(numel(Pall.trials), nW); Mmodel = Mdata;
grp = zeros(numel(Pall.trials), 1);
for j = 1:numel(Pall.trials)
    tr = g.expt.trial(Pall.trials(j));
    ev = tr.(refVar);
    if isempty(ev), continue, end
    grp(j) = tr.group;
    b0 = round((ev(1) + psthWin(1) * 1000) / F.binMs);           % the window's first bin (0-based) in the trial
    src = b0 + (1:nW);
    ok = src >= 1 & src <= numel(Pall.counts{j});
    Mdata(j, ok) = Pall.counts{j}(src(ok)) * 1000 / F.binMs;
    Mmodel(j, ok) = Pall.rate{j}(src(ok));
end
nb = max(1, round(psthSmoothMs / F.binMs));
fig = figure('Name', sprintf('%s %s: PSTH data vs model', g.name, g.unit.label), 'Color', 'w');
ax = axes(fig); hold(ax, 'on');
for gi = reshape(unique(grp(grp > 0)), 1, [])
    sel = grp == gi;
    color = groups.color(gi, :);
    dataRate = movmean(mean(Mdata(sel, :), 1, 'omitnan'), nb, 'omitnan');
    modelRate = movmean(mean(Mmodel(sel, :), 1, 'omitnan'), nb, 'omitnan');
    plot(ax, tW, dataRate, '-', 'Color', color, 'LineWidth', 1, 'DisplayName', sprintf('%s data (%d trials)', groups.label(gi), nnz(sel)));
    plot(ax, tW, modelRate, '--', 'Color', color, 'LineWidth', 1.5, 'DisplayName', groups.label(gi) + " model");
end
xline(ax, 0, 'k', 'HandleVisibility', 'off');
xlabel(ax, sprintf('Time from %s (s)', refVar), 'Interpreter', 'none');
ylabel(ax, sprintf('Rate (spikes/s, %d ms smoothing)', psthSmoothMs));
title(ax, sprintf('%s, unit %s: PSTH per group, data (solid) and model (dashed)', g.name, g.unit.label), 'Interpreter', 'none');
legend(ax, 'Location', 'best', 'Interpreter', 'none');
