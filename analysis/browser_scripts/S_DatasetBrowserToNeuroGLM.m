%% DatasetBrowser to neuroGLM
% A post-processing script of the DatasetBrowser (or run by hand with B in the
% workspace): it hands the browser's whole sessions to the neuroGLM toolbox
% (Pillow lab; Park, Meister, Huk & Pillow, Nat. Neurosci. 2014) and fits,
% for every unit of each dataset, the paper's trial-based Poisson GLM:
%
%   rate(t) = exp( sum over events of kernel_e * event_e(t) + h * spikes(t) )
%
% with a kernel per digital line edge (onset and offset), one per trial group
% for the browser's event line (the paper's coherence-dependent kernels), a
% spike-history filter, and optionally the LFP as a continuous covariate.
%
% Data: "Load whole sessions" with Data = units or detected (B.Sessions holds
% the spike trains, every trial and digital line); with withSignal, tick that
% signal too and it comes from B.Sessions (else it is loaded here). Each kept
% trial becomes a
% neuroGLM trial from TrialOnset + window(1) to the next trial's start
% (window(2) = Inf) or TrialOnset + window(2). sessionDataNeuroGLM builds the
% experiment struct, NeuroGLMExport.designSpec the design, NeuroGLMExport.fit
% the fit: neuroGLM's own route (matRegress's Poisson log-likelihood
% minimized by fminunc under a ridge prior whose weight the marginal
% likelihood picks, as the paper) or plain maximum likelihood by glmfit.
%
% Leaves glm{k} per dataset in the workspace: expt (neuroGLM's experiment),
% info (labels and trial rows), the train/test split (the same trials for
% every unit) and fits, one element per unit with spikes: unit (its row of
% D.units), dspec (the design), F (the fit: F.kernels.<covariate>.tr ms /
% .data log gain, F.bitsPerSpike), P (the prediction on the held-out trials).
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
loaded = S;
S = S(arrayfun(@(D) ~isempty(D.spikes), S));
if isempty(S)
    error('B.Sessions holds no spike trains (Data = %s): tick units or detected and "Load whole sessions".', ...
        strjoin(B.Settings.data, ", "));
end

%% Fit every unit of each dataset
glm = cell(numel(S), 1);
for k = 1:numel(S)
    D = S(k);
    args = {};
    if withSignal ~= ""
        % the same dataset's signal, whole: loaded with the spikes (withSignal ticked in Data), else through sessionData
        L = loaded([loaded.key] == D.key & [loaded.data] == withSignal);
        if isempty(L), L = sessionData(B.source(D.key), epochMatrixSettings(B.Settings, data=withSignal)); end
        args = {'Signal', L};
    end
    [expt, info] = sessionDataNeuroGLM(D, 'Window', window, 'BinMs', binMs, args{:});

    dsArgs = {'KernelMs', kernelMs, 'NBases', nBases, 'Acausal', acausal, ...
        'History', history, 'HistoryMs', historyMs, 'Coupling', coupling};
    if groupKernels
        % the paper's coherence-dependent kernels: the event the browser aligns to, split by trial group
        refLine = B.Settings.ref.line;
        if refLine == "Trial", refLine = D.trialLine; end
        refOn = info.lines.on(info.lines.line == refLine);
        if isempty(refOn), refOn = info.lines.on(1); end
        dsArgs = [dsArgs, {'GroupBy', "group", 'GroupEvents', refOn.'}]; %#ok<AGROW>
    end

    % one split per dataset: every unit is fitted and tested on the same trials
    nT = numel(expt.trial);
    perm = randperm(nT);
    nTrain = max(1, round(trainFraction * nT));
    train = sort(perm(1:nTrain));
    test = sort(perm(nTrain + 1:end));
    if isempty(test), test = train; end

    fits = struct('unit', {}, 'dspec', {}, 'F', {}, 'P', {});
    for u = 1:height(info.units)
        if isempty(D.spikes{u})
            fprintf('%s, unit %s: no spikes, not fitted\n', D.name, info.units.label(u));
            continue
        end
        dspec = NeuroGLMExport.designSpec(expt, 'Response', info.units.variable(u), dsArgs{:});
        F = NeuroGLMExport.fit(dspec, Trials=train, Method=fitMethod, Ridge=ridge);
        P = NeuroGLMExport.predict(F, test);
        fprintf('%s, unit %s: %d trials fitted (%s, ridge %g), %d held out; %.3f bits/spike (fit), %.3f (held out)\n', ...
            D.name, info.units.label(u), numel(train), fitMethod, F.ridge, numel(test), F.bitsPerSpike, P.bitsPerSpike);
        fits(end + 1) = struct('unit', info.units(u, :), 'dspec', dspec, 'F', F, 'P', P); %#ok<SAGROW>
    end

    g = struct();
    g.key = D.key; g.name = D.name;
    g.expt = expt; g.info = info; g.fits = fits;
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
%   g = glm{1}; f = g.fits(1);                                % the first dataset's first fitted unit
%   vertcat(g.fits.unit), arrayfun(@(f) f.P.bitsPerSpike, g.fits)   % every unit and its held-out bits/spike
%   f.F.kernels.Stim_on.tr, exp(f.F.kernels.Stim_on.data)     % a kernel as gain over ms after the event
%   dspec2 = NeuroGLMExport.designSpec(g.expt, Response=f.dspec.response, History=false);   % another design
%   F2 = NeuroGLMExport.fit(dspec2, Trials=g.trainTrials, Method="matRegress", Ridge=10); NeuroGLMExport.predict(F2, g.testTrials).bitsPerSpike
%   semilogx(f.F.ridgeGrid, f.F.evidence)                     % the evidence over the ridge grid
%   buildGLM.addCovariate / addCovariateBoxcar on f.dspec for your own covariates (neuroGLM's tutorial.m)

