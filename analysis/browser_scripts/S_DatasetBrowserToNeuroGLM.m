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
% The trial's response enters twice (the paper's choice-dependent saccade
% kernels): opts.responseEvents get one kernel per response word (opts.responses;
% F.kernels.RespWindow_on__Hit, ...), and the moment of the response (opts.responseLine's
% onset + opts.responseLatency, Hit and FA trials) gets a kernel of its own that also
% reaches before it (F.kernels.response_time). Each trial's word is
% g.expt.trial(j).response, for sorting the predictions by response.
%
% Data: "Load whole sessions" with Data = units or detected (B.Sessions holds
% the spike trains, every trial and digital line); with opts.withSignal, tick that
% signal too and it comes from B.Sessions (else it is loaded here). Each kept
% trial becomes a
% neuroGLM trial from TrialOnset + opts.window(1) to the next trial's start
% (opts.window(2) = Inf) or TrialOnset + opts.window(2). sessionDataNeuroGLM builds the
% experiment struct, NeuroGLMExport.designSpec the design, NeuroGLMExport.fit
% the fit: neuroGLM's own route (matRegress's Poisson log-likelihood
% minimized by fminunc under a ridge prior whose weight the marginal
% likelihood picks, as the paper) or plain maximum likelihood by glmfit. The
% units are fitted on up to opts.workers process workers, so their lines print as
% they finish; the results are in unit order either way. The browser's progress
% strip follows the units, and its Cancel stops the fits.
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
opts = struct();                    % the settings, noted whole in each dataset's manifest
opts.neuroGLMPath = 'c:\src\neuroGLM';   % added when neuroGLM is not on the path (the folder holding +buildGLM)
opts.outDir = "C:\Users\dstolz\My Drive\PROJECTS\OFC_Ephys\Analysis\NeuroGLM\";                        % a folder to save <dataset>_neuroglm.mat in; "" keeps them in the workspace only
opts.binMs = 1;                          % neuroGLM's bin (1 ms, as the paper); 5-10 ms fits much faster on long sessions
opts.window = [-0.5 Inf];                % s around TrialOnset; Inf = up to the next trial's start
opts.kernelMs = 500;                     % each event kernel's reach after the event
opts.nBases = 8;                         % raised cosines per kernel
opts.acausal = string.empty;             % event variables whose kernel also precedes the event, e.g. "Resp_on" for the animal's response
opts.groupKernels = true;                % one kernel per trial group (B's groupBy) for the browser's event line's onset (B.Settings.ref.line)
opts.responses = ["Hit" "Miss" "CR" "FA"];    % the response words given their own kernels; string.empty = none (a trial with another word gets none on opts.responseEvents)
opts.responseEvents = "RespWindow_on";   % the events split by response word; not one groupKernels also splits (B.Settings.ref.line's onset)
opts.responseTime = true;                % a kernel around the moment of the response, before and after it
opts.responseLine = "RespWindow"; opts.responseLatency = "RespLatency";   % that moment: the line's onset + the trial column, ms
opts.history = true; opts.historyMs = 200;    % the spike-history filter
opts.coupling = false;                   % a coupling filter from every other unit of the dataset (slow with many units)
opts.withSignal = "AUX";                    % "LFP" | "MUA" | "AUX" | "": that signal's channels as an instantaneous covariate
opts.fitMethod = "matRegress";           % "matRegress": neuroGLM's route (fminunc, ridge prior; the paper's) | "glmfit": maximum likelihood
opts.ridge = "evidence";                 % matRegress: the ridge prior's precision, or "evidence" to pick it by the marginal likelihood (the paper)
opts.trainFraction = 0.8;                % trials fitted; the rest are held out for the prediction
opts.workers = 4;                        % process workers fitting units at once (Parallel Computing Toolbox), fewer when memory is short; 0 = one unit after the other here
rng(1);                             % the train/test split

%% The sessions
if ~NeuroGLMExport.hasNeuroGLM()
    addpath(opts.neuroGLMPath);
    NeuroGLMExport.requireNeuroGLM();
end
if opts.fitMethod == "matRegress" && ~NeuroGLMExport.hasMatRegress()
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
% on the browser's progress strip: Cancel stops the fits; the datasets finished stay in glm (and in opts.outDir)
glm = cell(numel(S), 1);
nAll = max(1, sum(arrayfun(@(D) nnz(~cellfun(@isempty, D.spikes)), S)));
nFit = 0;
B.progressStart("Fitting neuroGLM");
try
    for k = 1:numel(S)
        D = S(k);
        name = D.name;
        B.progress(nFit / nAll, name + ": building the experiment");
        B.checkCancel();
        args = {};
        if opts.withSignal ~= ""
            % the same dataset's signal, whole: loaded with the spikes (opts.withSignal ticked in Data), else through sessionData
            L = loaded([loaded.key] == D.key & [loaded.data] == opts.withSignal);
            if isempty(L), L = sessionData(B.source(D.key), epochMatrixSettings(B.Settings, data=opts.withSignal)); end
            if opts.withSignal == "AUX"
                % the axes as one: each less its 2 s running mean (offset and gravity), then the vector magnitude
                x = double(L.signal);
                w = 2 * floor(2 * L.signalFs / 2) + 1;
                L.signal = zscore(sqrt(sum((x - movmean(x, w, 1)) .^ 2, 2)));
            end
            args = {'Signal', L};
        end
        if ~isempty(opts.responses), args = [args, {'Responses', opts.responses}]; end %#ok<AGROW>
        if opts.responseTime
            if isfield(D.eventsContinuous, opts.responseLine) && ismember(opts.responseLatency, string(D.trials.Properties.VariableNames))
                args = [args, {'ResponseLine', opts.responseLine, 'ResponseLatency', opts.responseLatency}]; %#ok<AGROW>
            else
                fprintf('%s: no response-time kernel (no line %s or trial column %s)\n', name, opts.responseLine, opts.responseLatency);
            end
        end
        [expt, info] = sessionDataNeuroGLM(D, 'Window', opts.window, 'BinMs', opts.binMs, args{:});

        acausal = reshape(opts.acausal, 1, []);
        if info.responseTime ~= "", acausal = [acausal, info.responseTime]; end %#ok<AGROW>
        dsArgs = {'KernelMs', opts.kernelMs, 'NBases', opts.nBases, 'Acausal', acausal, ...
            'History', opts.history, 'HistoryMs', opts.historyMs, 'Coupling', opts.coupling};
        groupBy = string.empty(1, 0);
        groupEvents = {};
        if opts.groupKernels
            % the paper's coherence-dependent kernels: the event the browser aligns to, split by trial group
            refLine = B.Settings.ref.line;
            if refLine == "Trial", refLine = D.trialLine; end
            refOn = info.lines.on(info.lines.line == refLine);
            if isempty(refOn), refOn = info.lines.on(1); end
            groupBy(end + 1) = "group"; %#ok<AGROW>
            groupEvents{end + 1} = refOn.'; %#ok<AGROW>
        end
        if ~isempty(opts.responses) && info.response ~= ""
            % the paper's choice-dependent kernels: these events, split by the trial's response word
            have = intersect(reshape(opts.responseEvents, 1, []), [info.lines.on.', info.lines.off.', info.responseTime], 'stable');
            for ev = setdiff(reshape(opts.responseEvents, 1, []), have)
                fprintf('%s: no response kernels on %s (no such event)\n', name, ev);
            end
            if ~isempty(have)
                groupBy(end + 1) = info.response; %#ok<AGROW>
                groupEvents{end + 1} = have; %#ok<AGROW>
            end
        end
        if ~isempty(groupBy)
            dsArgs = [dsArgs, {'GroupBy', groupBy, 'GroupEvents', groupEvents}]; %#ok<AGROW>
        end

        % one split per dataset: every unit is fitted and tested on the same trials
        nT = numel(expt.trial);
        perm = randperm(nT);
        nTrain = max(1, round(opts.trainFraction * nT));
        train = sort(perm(1:nTrain));
        test = sort(perm(nTrain + 1:end));
        if isempty(test), test = train; end

        noSpikes = cellfun(@isempty, reshape(D.spikes, [], 1));
        for u = reshape(find(noSpikes), 1, [])
            fprintf('%s, unit %s: no spikes, not fitted\n', name, info.units.label(u));
        end
        units = info.units(~noSpikes, :);
        fits = NeuroGLMExport.fitUnits(expt, units, Design=dsArgs, Trials=train, Test=test, ...
            Method=opts.fitMethod, Ridge=opts.ridge, Workers=opts.workers, ...
            ProgressFcn=@(f, m) B.progress((nFit + f * height(units)) / nAll, name + ": " + m), ...
            LogFcn=@(m) fprintf('%s, %s\n', name, m), CheckFcn=@() B.checkCancel());
        nFit = nFit + height(units);

        g = struct();
        g.key = D.key; g.name = D.name;
        g.expt = expt; g.info = info; g.fits = fits;
        g.trainTrials = train; g.testTrials = test;
        glm{k} = g;
        savedTo = "";
        if opts.outDir ~= ""
            B.progress(nFit / nAll, name + ": saving");
            savedTo = fullfile(opts.outDir, g.name + "_neuroglm.mat");
            save(savedTo, '-struct', 'g', '-v7.3');
        end
        B.noteInManifest(D.key, "neuroglm", opts, file=savedTo, nUnitsFitted=height(units));
    end
catch ME
    % a run this script opened ends here, whatever stopped it (run after Compute or Load, checkCancel leaves it open)
    if B.Busy
        if endsWith(string(ME.identifier), ":Canceled")
            B.progressFinish("Canceled");
        else
            B.progressFinish("Failed: " + string(ME.message));
        end
    end
    rethrow(ME);
end
B.progressFinish(sprintf("%d units of %d dataset(s) fitted", nFit, numel(S)));

% By hand, from here:
%   g = glm{1}; f = g.fits(1);                                % the first dataset's first fitted unit
%   vertcat(g.fits.unit), arrayfun(@(f) f.P.bitsPerSpike, g.fits)   % every unit and its held-out bits/spike
%   f.F.kernels.Stim_on.tr, exp(f.F.kernels.Stim_on.data)     % a kernel as gain over ms after the event
%   plot(f.F.kernels.RespWindow_on__Hit.tr, exp([f.F.kernels.RespWindow_on__Hit.data, f.F.kernels.RespWindow_on__Miss.data]))   % Hit against Miss
%   plot(f.F.kernels.response_time.tr, exp(f.F.kernels.response_time.data))   % the gain around the response (0 = the response)
%   hits = string({g.expt.trial(f.P.trials).response}) == "Hit";   % held-out trials by response word
%   dspec2 = NeuroGLMExport.designSpec(g.expt, Response=f.dspec.response, History=false);   % another design
%   F2 = NeuroGLMExport.fit(dspec2, Trials=g.trainTrials, Method="matRegress", Ridge=10); NeuroGLMExport.predict(F2, g.testTrials).bitsPerSpike
%   semilogx(f.F.ridgeGrid, f.F.evidence)                     % the evidence over the ridge grid
%   buildGLM.addCovariate / addCovariateBoxcar on f.dspec for your own covariates (neuroGLM's tutorial.m)

