%% DatasetBrowser to neuroGLM
% A post-processing script of the DatasetBrowser (or run by hand with B in the
% workspace): it hands the browser's whole sessions to the neuroGLM toolbox
% (Pillow lab; Park, Meister, Huk & Pillow, Nat. Neurosci. 2014) and fits,
% for every unit with opts.minSpikes spikes in the trials fitted, of each
% dataset with opts.minTrials trials fitted, the paper's trial-based Poisson GLM:
%
%   rate(t) = exp( sum over events of kernel_e * event_e(t) + h * spikes(t) )
%
% with a kernel per digital line edge (onset and offset), one per trial group
% for the browser's event line (the paper's coherence-dependent kernels), a
% spike-history filter, and optionally the LFP as a continuous covariate.
%
% The covariates: opts.events names the events given a kernel (every line edge
% and response_time when empty), opts.history the spike history, opts.coupling
% the other units, opts.withSignal the signal and, for AUX, opts.auxParts its
% columns. Every line stays in g.expt whatever opts.events holds.
%
% The trial's response enters as the paper's choice-dependent saccade kernels:
% opts.responseEvents get one kernel per response word (opts.responses;
% F.kernels.response_time__Hit, ...). One of them is the moment of the response,
% response_time (the first opts.responseLine opts.responseEdge after each opts.responseAfter
% onset, on every trial whatever its word, from the digital lines alone), whose kernels also
% reach opts.acausalMs before it.
% Each trial's word is g.expt.trial(j).response, for sorting the predictions by response.
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
% Each dataset prints where its trials went (the browser's selection, the
% recording's edges, erased periods, the signal) and how many are fitted.
%
% Leaves glm{k} per dataset fitted in the workspace: expt (neuroGLM's experiment),
% info (labels and trial rows), the train/test split (the same trials for
% every unit: the last block of consecutive trials is held out) and fits, one element per unit with spikes: unit (its row of
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
opts.outDir = "";                        % a folder to save <dataset>_neuroglm.mat in (in a subfolder named after the browser's tags); "" keeps them in the workspace only
opts.binMs = 5;                          % neuroGLM's bin (1 ms, as the paper); 5-10 ms fits much faster on long sessions
opts.window = [-0.5 Inf];                % s around TrialOnset; Inf = up to the next trial's start, so the trials tile the session and every event between trials (Trough_on mostly) is in one; a finite end leaves out the events after it
opts.minTrials = 20;                     % a dataset with fewer trials fitted (the training block) is not fitted, with a line printed
opts.minSpikes = 100;                    % a unit with fewer spikes in the trials fitted is not fitted, with a line printed
opts.events = ["Platform_off","Stim_on"];%,"Trough_on"];              % the events given a kernel, named as the kernels are: "<line>_on", "<line>_off", "response_time", e.g. ["Stim_on" "RespWindow_on" "response_time"]; string.empty = every line edge and response_time. One a dataset lacks is left out, with a line printed
opts.kernelMs = 1000;                     % each event kernel's reach after the event
opts.nBases = 8;                         % raised cosines per kernel
opts.acausal = string.empty;             % event variables whose kernel also precedes the event, e.g. "Resp_on" for the animal's response
opts.acausalMs = 500;                   % how far those kernels and response_time's reach before the event; after it, opts.kernelMs
opts.groupKernels = true;                % one kernel per trial group (B's groupBy) for the browser's event line's onset (B.Settings.ref.line)
opts.responses = "Hit";%["Hit" "Miss" "CR" "FA"];    % the response words given their own kernels; string.empty = none (a trial with another word gets none on opts.responseEvents)
opts.responseEvents = "response_time";   % the events split by response word; not one groupKernels also splits (B.Settings.ref.line's onset). One a fixed time from another event (RespWindow_on, RespWindow_off) cannot be told from its kernel, and swapping words to decode then fails
opts.responseTime = true;                % the event response_time: the moment of the response, with kernels before and after it
opts.responseLine = "Platform"; opts.responseEdge = "offset";   % that moment: this line's edge (leaving the platform)...
opts.responseAfter = "RespWindow";       % ...the first one after this line's onset, before the next trial (digital lines only)
opts.history = false; opts.historyMs = 500;    % the spike-history filter
opts.coupling = false;                   % a coupling filter from every other unit of the dataset (slow with many units)
opts.withSignal = "";% "AUX";                    % "LFP" | "MUA" | "AUX" | "": that signal's channels as an instantaneous covariate
opts.auxParts = ["magnitude" "axes" "slow"];   % withSignal "AUX": the columns, each z-scored: "magnitude" (of the axes less their 2 s running mean), "axes" (those, signed), "slow" (the 2 s running means)
opts.fitMethod = "matRegress";           % "matRegress": neuroGLM's route (fminunc, ridge prior; the paper's) | "glmfit": maximum likelihood
opts.ridge = "evidence";                 % matRegress: the ridge prior's precision, or "evidence" to pick it by the marginal likelihood (the paper)
opts.trainFraction = 0.8;                % trials fitted; the last block of consecutive trials (about 1 - this) is held out for the prediction (NeuroGLMExport.split); 1 = test on the fit
opts.workers = 4;                        % process workers fitting units at once (Parallel Computing Toolbox), fewer when memory is short; 0 = one unit after the other here

auxKnown = ["magnitude" "axes" "slow"];
if opts.withSignal == "AUX" && (isempty(opts.auxParts) || ~all(ismember(opts.auxParts, auxKnown)))
    error('opts.auxParts takes one or more of %s (opts.withSignal = "" for no signal).', strjoin(auxKnown, ", "));
end
if opts.outDir ~= "" && ~isempty(B.Filter.Tags)
    opts.outDir = fullfile(opts.outDir, join(B.Filter.Tags, "_"));   % a subfolder per set of tags
end
if opts.outDir ~= "" && ~isfolder(opts.outDir), mkdir(opts.outDir); end

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
nDone = 0;      % units fitted or passed over, for the progress strip
nFit = 0;
B.progressStart("Fitting neuroGLM");
try
    for k = 1:numel(S)
        D = S(k);
        name = D.name;
        B.progress(nDone / nAll, name + ": building the experiment");
        B.checkCancel();
        args = {};
        if opts.withSignal ~= ""
            % the same dataset's signal, whole: loaded with the spikes (opts.withSignal ticked in Data), else through sessionData
            L = loaded([loaded.key] == D.key & [loaded.data] == opts.withSignal);
            if isempty(L), L = sessionData(B.source(D.key), epochMatrixSettings(B.Settings, data=opts.withSignal)); end
            if opts.withSignal == "AUX"
                % each axis less its 2 s running mean (offset and gravity); the parts in opts.auxParts' order
                x = double(L.signal);
                w = 2 * floor(2 * L.signalFs / 2) + 1;
                slow = movmean(x, w, 1);
                hp = x - slow;
                parts = struct('magnitude', sqrt(sum(hp .^ 2, 2)), 'axes', hp, 'slow', slow);
                L.signal = zscore(cell2mat(arrayfun(@(p) parts.(p), reshape(opts.auxParts, 1, []), 'UniformOutput', false)));
            end
            args = {'Signal', L};
        end
        if ~isempty(opts.responses), args = [args, {'Responses', opts.responses}]; end %#ok<AGROW>
        if opts.responseTime
            after = opts.responseAfter;
            if after == "Trial", after = D.trialLine; end
            if isfield(D.eventsContinuous, opts.responseLine) && isfield(D.eventsContinuous, after)
                args = [args, {'ResponseLine', opts.responseLine, 'ResponseEdge', opts.responseEdge, ...
                    'ResponseAfter', opts.responseAfter}]; %#ok<AGROW>
            else
                fprintf('%s: no response-time kernel (no line %s or %s)\n', name, opts.responseLine, opts.responseAfter);
            end
        end
        [expt, info] = sessionDataNeuroGLM(D, 'Window', opts.window, 'BinMs', opts.binMs, args{:});

        % the events given a kernel: opts.events, those of this dataset (all of them in the order registered)
        events = [reshape([info.lines.on, info.lines.off].', 1, []), info.responseTime(info.responseTime ~= "")];
        if ~isempty(opts.events)
            for ev = setdiff(reshape(opts.events, 1, []), events, 'stable')
                fprintf('%s: no kernel on %s (no such event; it has %s)\n', name, ev, strjoin(events, ", "));
            end
            events = intersect(reshape(opts.events, 1, []), events, 'stable');
            if isempty(events)
                error('%s has none of opts.events (%s).', name, strjoin(opts.events, ", "));
            end
        end
        acausal = reshape(opts.acausal, 1, []);
        if info.responseTime ~= "", acausal = [acausal, info.responseTime]; end %#ok<AGROW>
        dsArgs = {'Events', events, 'KernelMs', opts.kernelMs, 'NBases', opts.nBases, 'Acausal', acausal, 'AcausalMs', opts.acausalMs, ...
            'History', opts.history, 'HistoryMs', opts.historyMs, 'Coupling', opts.coupling};
        groupBy = string.empty(1, 0);
        groupEvents = {};
        if opts.groupKernels
            % the paper's coherence-dependent kernels: the event the browser aligns to, split by trial group
            refLine = B.Settings.ref.line;
            if refLine == "Trial", refLine = D.trialLine; end
            refOn = info.lines.on(info.lines.line == refLine);
            if isempty(refOn), refOn = info.lines.on(1); end
            if ismember(refOn, events)
                groupBy(end + 1) = "group"; %#ok<AGROW>
                groupEvents{end + 1} = refOn.';
            else
                fprintf('%s: no kernels per trial group (%s is not in opts.events)\n', name, refOn);
            end
        end
        if ~isempty(opts.responses) && info.response ~= ""
            % the paper's choice-dependent kernels: these events, split by the trial's response word
            have = intersect(reshape(opts.responseEvents, 1, []), events, 'stable');
            for ev = setdiff(reshape(opts.responseEvents, 1, []), have, 'stable')
                fprintf('%s: no response kernels on %s (no such event, or not in opts.events)\n', name, ev);
            end
            if ~isempty(have)
                groupBy(end + 1) = info.response; %#ok<AGROW>
                groupEvents{end + 1} = have; %#ok<AGROW>
            end
        end
        if ~isempty(groupBy)
            dsArgs = [dsArgs, {'GroupBy', groupBy, 'GroupEvents', groupEvents}]; %#ok<AGROW>
        end

        % one split per dataset: every unit is fitted and tested on the same trials. The held-out
        % trials are the last block of the session (NeuroGLMExport.split, splitTrials): trials next
        % to each other share drift and spike history, so scattered held-out trials would be tested
        % on what the fit has seen of their neighbors
        [train, test] = NeuroGLMExport.split(expt, TestFraction=1 - opts.trainFraction);
        nWithSpikes = nnz(~cellfun(@isempty, D.spikes));
        fprintf(['%s: %d trials, %d kept by the browser''s trial selection; left out: %d off the recording, ' ...
            '%d on erased periods, %d off the signal; %d fitted, %d held out\n'], name, height(D.trials), nnz(D.kept), ...
            info.nDroppedEdge, info.nDroppedArtifact, info.nDroppedSignal, numel(train), numel(test));
        if numel(train) < opts.minTrials
            fprintf('%s: not fitted (%d trials fitted, fewer than opts.minTrials = %d)\n', name, numel(train), opts.minTrials);
            nDone = nDone + nWithSpikes;
            continue
        end

        % the units with enough spikes in the trials fitted
        nSpikes = arrayfun(@(v) sum(arrayfun(@(tr) numel(tr.(v)), expt.trial(train))), info.units.variable);
        few = nSpikes < max(1, opts.minSpikes);
        for u = reshape(find(few), 1, [])
            fprintf('%s, unit %s: not fitted (%d spikes in the trials fitted, fewer than opts.minSpikes = %d)\n', ...
                name, info.units.label(u), nSpikes(u), opts.minSpikes);
        end
        units = info.units(~few, :);
        if isempty(units)
            fprintf('%s: not fitted (no unit has opts.minSpikes = %d spikes in the trials fitted)\n', name, opts.minSpikes);
            nDone = nDone + nWithSpikes;
            continue
        end
        fits = NeuroGLMExport.fitUnits(expt, units, Design=dsArgs, Trials=train, Test=test, ...
            Method=opts.fitMethod, Ridge=opts.ridge, Workers=opts.workers, ...
            ProgressFcn=@(f, m) B.progress((nDone + f * height(units)) / nAll, name + ": " + m), ...
            LogFcn=@(m) fprintf('%s, %s\n', name, m), CheckFcn=@() B.checkCancel());
        nFit = nFit + height(units);
        nDone = nDone + nWithSpikes;

        g = struct();
        g.key = D.key; g.name = D.name; g.variables = D.variables;   % the dataset's variables (a struct of values)
        g.expt = expt; g.info = info; g.fits = fits;
        g.trainTrials = train; g.testTrials = test;
        glm{k} = g;
        savedTo = "";
        if opts.outDir ~= ""
            B.progress(nDone / nAll, name + ": saving");
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
glm = glm(~cellfun(@isempty, glm));      % the datasets fitted
B.progressFinish(sprintf("%d units of %d dataset(s) fitted (%d passed over)", nFit, numel(glm), numel(S) - numel(glm)));

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

