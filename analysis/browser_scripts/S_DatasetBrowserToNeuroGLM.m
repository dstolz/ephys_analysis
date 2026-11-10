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
% spike-history filter, and optionally a signal as a continuous covariate.
%
% The covariates: opts.events names the events given a kernel (every line edge
% and response_time when empty), opts.history the spike history, opts.coupling
% the other units, opts.withSignal the signal and, for AUX, opts.auxParts its
% columns. Every line stays in g.expt whatever opts.events holds.
%
% Kernels are told apart by the trials on which the time between their events
% differs (the paper; neuroGLM's documentation: of two perfectly correlated
% timings, include one). Each dataset prints the events that sit a fixed time
% apart within the kernels' reach, such as the two edges of a pulse of one
% length (NeuroGLMExport.lockedEvents; g.lockedEvents): where their kernels
% overlap, only the sum of the two is determined. Name one of each such pair in
% opts.events, or read their kernels together.
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
% recording's edges, erased periods, the signal) and how many are fitted. A
% unit's line says so when its fit did not converge, or when the ridge the
% evidence picked is at an end of its grid.
%
% Leaves glm{k} per dataset fitted in the workspace: expt (neuroGLM's experiment),
% info (labels and trial rows), the train/test split (the same trials for
% every unit: the last block of consecutive trials is held out), lockedEvents
% and fits, one element per unit fitted: unit (its row of
% D.units), dspec (the design), F (the fit: F.kernels.<covariate>.tr ms /
% .data log gain, F.kernelSE, F.bitsPerSpike, F.converged), P (the prediction
% on the held-out trials).
%
% Against the paper: 5 ms bins here (opts.binMs), 1 ms there; one kernel length
% for every event (opts.kernelMs), an event's own there (0.5 to 5.3 s); every
% line an impulse at each edge, where the paper's motion stimulus is a boxcar
% of its duration; the spike-history filter is opts.historyBases log-stretched
% raised cosines over opts.historyMs, the paper's ten 1 ms steps and ten such
% cosines over 265 ms; one split with the last block held out, the paper's
% five random folds. neuroGLM builds the design a trial at a time: a kernel
% stops at its trial's end and the spike history starts empty in each trial.
% The paper's decoding is not here.
%
% Plots (last section, opts.plots): of one unit, the kernels as gains with
% their standard error, four held-out trials with the spikes, a smoothed rate
% and the model's rate (the paper's Fig. 4), and the held-out PSTH per trial
% group, data against model (Fig. 2c).

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
opts.kernelMs = 500;                     % each event kernel's reach after the event
opts.nBases = 8;                         % raised cosines per kernel
opts.acausal = string.empty;             % event variables whose kernel also precedes the event, e.g. "Resp_on" for the animal's response
opts.acausalMs = 500;                   % how far those kernels and response_time's reach before the event; after it, opts.kernelMs
opts.groupKernels = true;                % one kernel per trial group (B's groupBy) for the browser's event line's onset (B.Settings.ref.line)
opts.responses = "Hit";%["Hit" "Miss" "CR" "FA"];    % the response words given their own kernels; string.empty = none (a trial with another word gets none on opts.responseEvents)
opts.responseEvents = "response_time";   % the events split by response word; not one groupKernels also splits (B.Settings.ref.line's onset). One a fixed time from another event (RespWindow_on, RespWindow_off) cannot be told from its kernel, and swapping words to decode then fails
opts.responseTime = true;                % the event response_time: the moment of the response, with kernels before and after it
opts.responseLine = "Platform"; opts.responseEdge = "offset";   % that moment: this line's edge (leaving the platform)...
opts.responseAfter = "RespWindow";       % ...the first one after this line's onset, before the next trial (digital lines only)
opts.history = true; opts.historyMs = 500;    % the spike-history filter and its reach: the lags from one bin to this long after a spike (the paper's spans 265 ms)
opts.historyBases = 10;                  % its log-stretched raised cosines
opts.coupling = false;                   % a coupling filter from every other unit of the dataset (slow with many units)
opts.withSignal = "AUX";                    % "LFP" | "MUA" | "AUX" | "": that signal's channels as an instantaneous covariate
opts.auxParts = ["magnitude" "axes" "slow"];   % withSignal "AUX": the columns, each z-scored: "magnitude" (of the axes less their 2 s running mean), "axes" (those, signed), "slow" (the 2 s running means); named in g.expt.param.channels. LFP and MUA go in as they are, in uV
opts.fitMethod = "matRegress";           % "matRegress": neuroGLM's route (fminunc, ridge prior; the paper's) | "glmfit": maximum likelihood
opts.ridge = "evidence";                 % matRegress: the ridge prior's precision, or "evidence" to pick it by the marginal likelihood (the paper)
opts.trainFraction = 0.8;                % trials fitted; the last block of consecutive trials (about 1 - this) is held out for the prediction (NeuroGLMExport.split); 1 = test on the fit
opts.workers = 4;                        % process workers fitting units at once (Parallel Computing Toolbox), fewer when memory is short; 0 = one unit after the other here
opts.plots = true;                       % the three figures of the last section

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
                % each axis less its 2 s running mean (offset and gravity); the parts in opts.auxParts' order,
                % a row of L.channels per column made (expt.param.channels, and the covariate's weights in that order)
                x = double(L.signal);
                w = 2 * floor(2 * L.signalFs / 2) + 1;
                slow = movmean(x, w, 1);
                hp = x - slow;
                auxName = reshape(string(L.channels.label), [], 1);
                unnamed = ismissing(auxName) | auxName == "";
                auxName(unnamed) = "axis " + find(unnamed);
                parts = struct('magnitude', sqrt(sum(hp .^ 2, 2)), 'axes', hp, 'slow', slow);
                partLabels = struct('magnitude', "magnitude", 'axes', auxName + " less its 2 s mean", 'slow', auxName + " 2 s mean");
                auxParts = reshape(opts.auxParts, 1, []);
                L.signal = zscore(cell2mat(arrayfun(@(p) parts.(p), auxParts, 'UniformOutput', false)));
                auxLabel = arrayfun(@(p) reshape(partLabels.(p), [], 1), auxParts, 'UniformOutput', false);
                auxLabel = vertcat(auxLabel{:});
                L.channels = table(auxLabel, repmat("z-score", numel(auxLabel), 1), 'VariableNames', {'label', 'units'});
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
            'History', opts.history, 'HistoryMs', opts.historyMs, 'HistoryBases', opts.historyBases, 'Coupling', opts.coupling};
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

        % events a fixed time apart on the trials fitted, closer than their kernels reach: there only the sum of
        % the two kernels is determined (the paper: the variable timing of events is what tells them apart)
        locked = NeuroGLMExport.lockedEvents(expt, Events=events, Trials=train, WithinMs=opts.kernelMs + opts.acausalMs);
        locked = locked(locked.lagMs < opts.kernelMs + opts.acausalMs * ismember(locked.second, acausal), :);
        for r = 1:height(locked)
            fprintf(['%s: %s is %g ms after %s (%.0f%% of its %d events, %.0f%% of the other''s %d): where the two kernels ' ...
                'overlap, only their sum is determined\n'], name, locked.second(r), locked.lagMs(r), locked.first(r), ...
                100 * locked.fractionSecond(r), locked.nSecond(r), 100 * locked.fractionFirst(r), locked.nFirst(r));
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
        g.lockedEvents = locked;
        glm{k} = g;
        savedTo = "";
        if opts.outDir ~= ""
            B.progress(nDone / nAll, name + ": saving");
            savedTo = fullfile(opts.outDir, g.name + "_neuroglm.mat");
            save(savedTo, '-struct', 'g', '-v7.3');
        end
        B.noteInManifest(D.key, "neuroglm", opts, file=savedTo, nUnitsFitted=height(units), ...
            nUnitsNotConverged=nnz(~arrayfun(@(f) f.F.converged, fits)), nLockedEventPairs=height(locked));
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
%   f.dspec.covariates                                        % the design: each kernel, its event, its trial group or response word
%   f.F.kernels.Stim_on.tr, exp(f.F.kernels.Stim_on.data)     % a kernel as gain over ms after the event
%   exp(f.F.kernels.Stim_on.data + [-1 1] .* f.F.kernelSE.Stim_on.data)   % the gain a standard error either side
%   plot(f.F.kernels.RespWindow_on__Hit.tr, exp([f.F.kernels.RespWindow_on__Hit.data, f.F.kernels.RespWindow_on__Miss.data]))   % Hit against Miss
%   plot(f.F.kernels.response_time.tr, exp(f.F.kernels.response_time.data))   % the gain around the response (0 = the response)
%   hits = string({g.expt.trial(f.P.trials).response}) == "Hit";   % held-out trials by response word
%   g.lockedEvents                                            % the events a fixed time apart, whose kernels overlap
%   dspec2 = NeuroGLMExport.designSpec(g.expt, Response=f.dspec.response, History=false);   % another design
%   F2 = NeuroGLMExport.fit(dspec2, Trials=g.trainTrials, Method="matRegress", Ridge=10); NeuroGLMExport.predict(F2, g.testTrials).bitsPerSpike
%   semilogx(f.F.ridgeGrid, f.F.evidence)                     % the evidence over the ridge grid
%   buildGLM.addCovariate / addCovariateBoxcar on f.dspec for your own covariates (neuroGLM's tutorial.m)

%% Plots: one unit's kernels, four held-out trials, the held-out PSTH per trial group
% The first dataset fitted and its unit with the most spikes in the trials fitted (not the one predicted best).
% For another, set kPlot and jPlot and run this section again (glm and opts stay in the workspace).
if ~opts.plots || isempty(glm), return, end
kPlot = 1;          % the dataset: its place in glm
jPlot = [];         % the unit: its place in glm{kPlot}.fits; [] = the one with the most spikes in the trials fitted
if isempty(jPlot), [~, jPlot] = max(arrayfun(@(f) full(f.F.nSpikes), glm{kPlot}.fits)); end
plotMs = 4000;      % the stretch of each trial drawn, from its start (the trials and the PSTHs)
smoothMs = 100;     % the boxcar run over the spikes and over the model's rate (the paper's Fig. 4 smooths the spikes so)
maxGain = 20;       % the gain axes stay within [1/maxGain maxGain]: a kernel beyond that runs off its tile
plotKernels(glm{kPlot}, glm{kPlot}.fits(jPlot), maxGain);
plotTrials(glm{kPlot}, glm{kPlot}.fits(jPlot), plotMs, smoothMs);
plotGroupPSTH(glm{kPlot}, glm{kPlot}.fits(jPlot), plotMs, smoothMs);

%% Local functions
function plotKernels(g, f, maxGain)
% Every kernel of one fitted unit as a gain, exp(log gain), over the time from its event, with the gain a standard
% error either side as thin lines (F.kernelSE; no thin line where it is NaN, where the data say nothing). The
% kernels of an event split by trial group or response word share a tile, the groups in the browser's colors. A
% continuous covariate has no time course: its weights, the log gain per unit of each column, with their errors.
C = f.dspec.covariates;                 % label, source, kind, by, level
K = f.F.kernels;
SE = f.F.kernelSE;
groups = g.expt.param.groups;
maxGain = max(maxGain, 2);
fig = figure('Name', g.name + ", unit " + string(f.unit.label) + ": neuroGLM kernels", 'Color', 'w', 'Position', [100 100 1100 700]);
tl = tiledlayout(fig, 'flow', 'TileSpacing', 'compact', 'Padding', 'compact');
for src = reshape(unique(C.source(C.kind == "event"), 'stable'), 1, [])
    r = find(C.kind == "event" & C.source == src);
    ax = nexttile(tl);
    hold(ax, 'on');
    colors = lines(numel(r));
    names = C.level(r);
    h = gobjects(1, numel(r));
    for i = 1:numel(r)
        gi = [];
        if C.by(r(i)) == "group"; gi = find(groups.index == str2double(C.level(r(i))), 1); end
        if ~isempty(gi)
            colors(i, :) = groups.color(gi, :);
            names(i) = string(groups.label(gi));
        end
        h(i) = drawGain(ax, K.(C.label(r(i))), SE.(C.label(r(i))), colors(i, :));
    end
    finishGainAxes(ax, h, maxGain);
    title(ax, g.expt.desc.(src), 'Interpreter', 'none');
    xlabel(ax, 'Time from the event (ms)');
    if numel(r) > 1; legend(ax, h, names, 'Location', 'best', 'Interpreter', 'none'); end
end
for kind = ["history" "coupling"]
    r = find(C.kind == kind);
    if isempty(r), continue, end
    ax = nexttile(tl);
    hold(ax, 'on');
    colors = lines(numel(r));
    if kind == "history"; colors = zeros(numel(r), 3); end
    h = gobjects(1, numel(r));
    for i = 1:numel(r)
        h(i) = drawGain(ax, K.(C.label(r(i))), SE.(C.label(r(i))), colors(i, :));
    end
    finishGainAxes(ax, h, maxGain);
    xlabel(ax, 'Time from the spike (ms)');
    if kind == "history"
        title(ax, 'Spike history (this unit''s own spikes)');
    else
        title(ax, 'Coupling (the other units'' spikes)');
        if numel(r) <= 12; legend(ax, h, C.source(r), 'Location', 'best', 'Interpreter', 'none'); end
    end
end
for r = reshape(find(C.kind == "continuous"), 1, [])
    w = K.(C.label(r)).data(:);
    ax = nexttile(tl);
    errorbar(ax, (1:numel(w)).', w, SE.(C.label(r)).data(:), 'o', 'Color', [0 0 0], 'MarkerFaceColor', [0 0 0]);
    yline(ax, 0, ':');
    xlim(ax, [0.5, numel(w) + 0.5]);
    if isfield(g.expt.param, 'channels') && height(g.expt.param.channels) == numel(w) && numel(w) <= 16
        set(ax, 'XTick', 1:numel(w), 'XTickLabel', g.expt.param.channels.label, 'TickLabelInterpreter', 'none');
    else
        xlabel(ax, 'Column of the signal');
    end
    title(ax, C.label(r), 'Interpreter', 'none');
    ylabel(ax, 'Log gain per unit of the signal');
    grid(ax, 'on');
end
title(tl, sprintf('%s, unit %s: the kernels as gains (%s, ridge %g); %.3f bits/spike on the %d trials fitted, %.3f on the %d %s', ...
    g.name, f.unit.label, f.F.method, f.F.ridge, f.F.bitsPerSpike, numel(f.F.trials), f.P.bitsPerSpike, numel(f.P.trials), heldWord(g)), ...
    'Interpreter', 'none');
end

function h = drawGain(ax, k, se, color)
% One kernel as a gain: exp(log gain) thick, exp(log gain -/+ its standard error) thin
t = k.tr(:, 1);
h = plot(ax, t, exp(k.data(:, 1)), '-', 'Color', color, 'LineWidth', 1.5);
plot(ax, t, exp(k.data(:, 1) + [-1 1] .* se.data(:, 1)), '-', 'Color', color, 'LineWidth', 0.5, 'HandleVisibility', 'off');
end

function finishGainAxes(ax, h, maxGain)
% A logarithmic gain axis around 1 that holds the kernels H, within [1/maxGain maxGain] whatever their error lines do
y = [h.YData];
y = y(isfinite(y) & y > 0);
lim = [max(min([y / 1.5, 0.8]), 1 / maxGain), min(max([y * 1.5, 1.25]), maxGain)];
set(ax, 'YScale', 'log', 'YLim', lim);
yline(ax, 1, ':', 'HandleVisibility', 'off');
xline(ax, 0, ':', 'HandleVisibility', 'off');
ylabel(ax, 'Gain');
grid(ax, 'on');
end

function plotTrials(g, f, plotMs, smoothMs)
% Four of the trials predicted, evenly spaced through them (not picked by how well they are predicted): the spikes,
% their rate under a boxcar, the model's rate under the same boxcar, and each digital line's onsets (the paper's
% Fig. 4). With a spike-history or coupling filter the model's rate in a bin is given the spikes observed before it.
P = f.P;
binMs = f.F.binMs;
nSmooth = max(1, round(smoothMs / binMs));
t0 = g.expt.param.window(1);            % s: where a trial starts, from the event it is aligned to
onsets = g.info.lines;                  % line, on, off (the variables)
lineColor = lines(height(onsets));
pick = unique(round(linspace(1, numel(P.trials), min(4, numel(P.trials)))));
fig = figure('Name', g.name + ", unit " + string(f.unit.label) + ": neuroGLM, single trials", 'Color', 'w', 'Position', [130 80 1100 750]);
tl = tiledlayout(fig, numel(pick), 1, 'TileSpacing', 'compact', 'Padding', 'compact');
for i = pick
    tr = g.expt.trial(P.trials(i));
    n = min(round(plotMs / binMs), numel(P.t{i}));
    t = (P.t{i}(1:n) + binMs / 2) / 1000 + t0;      % bin centers, s
    spikeRate = movmean(P.counts{i}, nSmooth) * 1000 / binMs;
    modelRate = movmean(P.rate{i}, nSmooth);
    top = max([spikeRate(1:n), modelRate(1:n), 1]);
    ax = nexttile(tl);
    hold(ax, 'on');
    hLine = gobjects(1, height(onsets));
    for j = 1:height(onsets)
        hLine(j) = plot(ax, NaN, NaN, '-', 'Color', lineColor(j, :));   % the legend's entry
        tOn = tr.(onsets.on(j));
        tOn = tOn(tOn < n * binMs) / 1000 + t0;
        if ~isempty(tOn); xline(ax, tOn, '-', 'Color', lineColor(j, :), 'HandleVisibility', 'off'); end
    end
    hData = plot(ax, t, spikeRate(1:n), '-', 'Color', [0.55 0.55 0.55], 'LineWidth', 1);
    hModel = plot(ax, t, modelRate(1:n), '-', 'Color', [0 0 0], 'LineWidth', 1.5);
    sp = tr.(f.unit.variable);
    sp = reshape(sp(sp < n * binMs), 1, []) / 1000 + t0;
    if ~isempty(sp); plot(ax, [sp; sp], top * [1.05; 1.15] .* ones(1, numel(sp)), 'k-', 'HandleVisibility', 'off'); end
    xlim(ax, [t0, t0 + n * binMs / 1000]);
    ylim(ax, [0, top * 1.2]);
    title(ax, trialTitle(g, tr), 'Interpreter', 'none');
    if i == pick(1)
        lg = legend(ax, [hData, hModel, hLine], [sprintf("spikes, %g ms boxcar", smoothMs), "model, same boxcar", ...
            reshape(onsets.line, 1, []) + " onset"], 'Interpreter', 'none');
        lg.Layout.Tile = 'east';
    end
end
xlabel(tl, "Time from " + g.expt.param.align + " (s)", 'Interpreter', 'none');
ylabel(tl, 'Rate (spikes/s)');
title(tl, sprintf('%s, unit %s: %d of the %d %s trials, %.3f bits/spike over all of them', g.name, f.unit.label, ...
    numel(pick), numel(P.trials), heldWord(g), P.bitsPerSpike), 'Interpreter', 'none');
end

function plotGroupPSTH(g, f, plotMs, smoothMs)
% The PSTH of the trials predicted, a tile per trial group: the spikes against the model's rate, each averaged over
% the group's trials from the trials' start and run through one boxcar (the paper's Fig. 2c). A trial shorter than
% the stretch drawn counts up to its end. The held-out trials are the test: on trials the model was fitted on, part
% of the agreement is the fit's own doing.
P = f.P;
binMs = f.F.binMs;
nSmooth = max(1, round(smoothMs / binMs));
nShow = round(plotMs / binMs);
t0 = g.expt.param.window(1);
t = ((0:nShow - 1) + 0.5) * binMs / 1000 + t0;      % bin centers, s
vars = g.info.values;
groupVar = vars.variable(vars.column == "group");
grp = arrayfun(@(k) g.expt.trial(k).(groupVar), P.trials);
groups = g.expt.param.groups;
fig = figure('Name', g.name + ", unit " + string(f.unit.label) + ": neuroGLM, PSTH per trial group", 'Color', 'w', 'Position', [160 60 1100 650]);
tl = tiledlayout(fig, 'flow', 'TileSpacing', 'compact', 'Padding', 'compact');
axs = gobjects(1, 0);
for level = reshape(unique(grp), 1, [])
    idx = find(grp == level);
    spikes = NaN(numel(idx), nShow);
    model = spikes;
    for i = 1:numel(idx)
        n = min(nShow, numel(P.counts{idx(i)}));
        spikes(i, 1:n) = P.counts{idx(i)}(1:n) * 1000 / binMs;
        model(i, 1:n) = P.rate{idx(i)}(1:n);
    end
    color = [0 0.45 0.74];
    label = "group " + level;
    gi = find(groups.index == level, 1);
    if ~isempty(gi)
        color = groups.color(gi, :);
        label = string(groups.label(gi));
    end
    ax = nexttile(tl);
    hold(ax, 'on');
    hData = plot(ax, t, movmean(mean(spikes, 1, 'omitnan'), nSmooth, 'omitnan'), '-', 'Color', color, 'LineWidth', 1.5);
    hModel = plot(ax, t, movmean(mean(model, 1, 'omitnan'), nSmooth, 'omitnan'), '--', 'Color', [0 0 0], 'LineWidth', 1.2);
    xline(ax, 0, ':', 'HandleVisibility', 'off');
    xlim(ax, [t(1), t(end)]);
    title(ax, sprintf('%s (%d trials)', label, numel(idx)), 'Interpreter', 'none');
    if isempty(axs); legend(ax, [hData, hModel], ["spikes" "model"], 'Location', 'best'); end
    axs(end + 1) = ax; %#ok<AGROW>
end
if numel(axs) > 1; linkaxes(axs, 'xy'); end
xlabel(tl, "Time from " + g.expt.param.align + " (s)", 'Interpreter', 'none');
ylabel(tl, 'Rate (spikes/s)');
title(tl, sprintf('%s, unit %s: PSTH of the %d %s trials per trial group, spikes against model (%g ms boxcar)', g.name, f.unit.label, ...
    numel(P.trials), heldWord(g), smoothMs), 'Interpreter', 'none');
end

function s = trialTitle(g, tr)
% "trial 12, Depth = 0.2, Hit": the trial's row of the dataset's trial table, its trial group, its response word
vars = g.info.values;
s = "trial " + tr.(vars.variable(vars.column == "trialIndex"));
groups = g.expt.param.groups;
gi = find(groups.index == tr.(vars.variable(vars.column == "group")), 1);
if ~isempty(gi); s = s + ", " + string(groups.label(gi)); end
if g.info.response ~= "" && string(tr.(g.info.response)) ~= ""; s = s + ", " + string(tr.(g.info.response)); end
end

function w = heldWord(g)
% "held-out" when the trials predicted are apart from the trials fitted; "fitted" when they are the same (opts.trainFraction = 1)
w = "held-out";
if ~isempty(intersect(g.trainTrials, g.testTrials)); w = "fitted"; end
end
