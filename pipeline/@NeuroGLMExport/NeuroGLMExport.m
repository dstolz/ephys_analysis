classdef NeuroGLMExport
    % NeuroGLMExport  Hand this pipeline's trials to the neuroGLM toolbox, and fit its Poisson GLM.
    %   neuroGLM (Pillow lab, github.com/pillowlab/neuroGLM) is the reference
    %   implementation of Park, Meister, Huk & Pillow, Nat. Neurosci. 2014:
    %   a trial-based Poisson GLM whose spike rate is exp(sum of kernels
    %   convolved with task events + spike history). It stores the data as
    %   an "experiment" struct (buildGLM.initExperiment) with one element of
    %   expt.trial per trial, builds a design matrix from a "design
    %   specification" (buildGLM.initDesignSpec, addCovariate*) and leaves
    %   the regression to you.
    %
    %   This class packages the pipeline's data into that experiment struct
    %   and runs the common steps around it:
    %     experiment    whole-session spike times, event times, per-trial
    %                   values and continuous signals, cut into trials over
    %                   given spans           -> expt (buildGLM's struct)
    %     designSpec    a default design: a kernel per event (raised
    %                   cosines), spike history, optional coupling, raw
    %                   continuous covariates, kernels split by group
    %                                         -> dspec
    %     fit           the design matrix, the binned response and a Poisson
    %                   GLM (glmfit, or matRegress + fminunc with a ridge
    %                   prior)                -> F (weights, kernels,
    %                   bits per spike, dm, y)
    %     predict       the model's rate on any trials, per trial
    %   sessionDataNeuroGLM (analysis/) feeds experiment from a sessionData
    %   struct (DatasetBrowser's B.Sessions).
    %
    %   neuroGLM is needed for everything here (hasNeuroGLM / requireNeuroGLM
    %   tell you whether it is on the path; it is not bundled). fit has two
    %   routes: glmfit (Statistics and Machine Learning Toolbox; maximum
    %   likelihood) and neuroGLM's own matRegress (glms.neglog.poisson
    %   minimized by fminunc of the Optimization Toolbox) with the paper's
    %   ridge prior and evidence optimization (hasMatRegress /
    %   requireMatRegress).
    %   As the other exporters, this class shares no code with FieldTripExport
    %   or ChronuxDataset.
    %
    %   Conventions
    %   -----------
    %   - Time inside a trial is in ms from the trial's start (neuroGLM's
    %     unitOfTime 'ms'), binned at BinMs (1 ms by default, as the paper).
    %     expt.binfun(t) = (t == 0) + ceil(t / binSize) is bin 1 at t = 0.
    %   - Every input time is a second on one clock, the signals' and
    %     spikes' continuous clock (sample k at (k-1)/Fs); the caller moves
    %     digital-event times there first (sessionData's eventsContinuous /
    %     toContinuous).
    %   - A trial's duration is rounded down to whole bins; the spikes and
    %     events at or after its end are left out; an event exactly at the
    %     start is at 0.
    %   - Continuous signals are resampled to the bin rate (1000 / BinMs Hz,
    %     resample of the Signal Processing Toolbox when the rates differ)
    %     and cut so that row k of a trial is the bin starting at
    %     (k-1) * BinMs; trials running off a signal are dropped.
    %   - Variable labels are MATLAB field names (matlab.lang.makeValidName,
    %     made unique); the callers keep the original names in expt.param.
    %
    %   See also sessionDataNeuroGLM, FieldTripExport, ChronuxDataset.

    methods (Static)
        function [expt, keep] = experiment(spans, opts)
            %experiment  A neuroGLM experiment struct: trials cut over spans from whole-session data.
            %   [expt, keep] = NeuroGLMExport.experiment(spans, Spikes=, Events=, Values=, Continuous=, ...)
            %   spans is [nTrials x 2] [start stop] s on the continuous
            %   clock. Each row becomes one element of expt.trial, with
            %   duration = floor((stop - start) * 1000 / BinMs) * BinMs ms.
            %   Options
            %     BinMs       bin size, ms (1)
            %     Spikes      struct: label -> column of spike times, s; each
            %                 a registered spike train (times in ms from the
            %                 trial's start, inside [0 duration))
            %     Events      struct: label -> column of event times, s; each
            %                 a registered timing variable (0 or more per
            %                 trial)
            %     Values      table with nTrials rows: each column a
            %                 registered value (a string column stays string)
            %     Continuous  struct: label -> struct(data=[N x d], fs=Hz),
            %                 row k at (k-1)/fs; each a registered continuous
            %                 variable of d dimensions, resampled to the bin
            %                 rate and cut per trial ([nBins x d])
            %     Id          expt.id ("" = neuroGLM's time@host)
            %     Param       struct stored in expt.param (anything useful)
            %     Describe    struct: label -> a longer description (else the
            %                 label)
            %   keep marks the rows of spans that became trials (a trial is
            %   dropped only when a continuous signal does not cover it, or
            %   its duration is shorter than one bin). expt.trial(k) also
            %   carries span (its [start stop] s on the continuous clock).
            arguments
                spans (:,2) double
                opts.BinMs (1,1) double {mustBePositive} = 1
                opts.Spikes (1,1) struct = struct()
                opts.Events (1,1) struct = struct()
                opts.Values table = table()
                opts.Continuous (1,1) struct = struct()
                opts.Id (1,1) string = ""
                opts.Param = struct()
                opts.Describe (1,1) struct = struct()
            end
            NeuroGLMExport.requireNeuroGLM();
            n = size(spans, 1);
            if ~isempty(opts.Values) && height(opts.Values) ~= n
                error('NeuroGLMExport:BadValues', 'Values has %d rows but there are %d spans.', height(opts.Values), n);
            end
            binMs = opts.BinMs;
            if opts.Id == ""; id = []; else; id = char(opts.Id); end
            expt = buildGLM.initExperiment('ms', binMs, id, opts.Param);
            desc = @(lab) NeuroGLMExport.describe(opts.Describe, lab);

            spikeLabels = string(fieldnames(opts.Spikes)).';
            eventLabels = string(fieldnames(opts.Events)).';
            valueLabels = string(opts.Values.Properties.VariableNames);
            contLabels  = string(fieldnames(opts.Continuous)).';
            labs = [spikeLabels eventLabels valueLabels contLabels];
            bad = labs(~arrayfun(@isvarname, labs));
            if ~isempty(bad)
                error('NeuroGLMExport:BadLabel', 'Not a valid variable name: %s (use matlab.lang.makeValidName).', strjoin(bad, ', '));
            end
            [~, first] = unique(labs, 'stable');
            if numel(first) ~= numel(labs)
                error('NeuroGLMExport:DuplicateLabel', 'A label is used twice across Spikes, Events, Values and Continuous.');
            end
            for lab = spikeLabels; expt = buildGLM.registerSpikeTrain(expt, char(lab), desc(lab)); end
            for lab = eventLabels; expt = buildGLM.registerTiming(expt, char(lab), desc(lab)); end
            for lab = valueLabels; expt = buildGLM.registerValue(expt, char(lab), desc(lab)); end

            % continuous signals, resampled to the bin rate once
            fsBin = 1000 / binMs;
            cont = struct();
            for lab = contLabels
                c = opts.Continuous.(lab);
                if ~isstruct(c) || ~isfield(c, 'data') || ~isfield(c, 'fs')
                    error('NeuroGLMExport:BadContinuous', 'Continuous.%s must be a struct with fields data and fs.', lab);
                end
                x = double(c.data);
                if isvector(x); x = x(:); end
                fs = double(c.fs);
                if abs(fs - fsBin) > 1e-9 * fsBin
                    [p, q] = rat(fsBin / fs, 1e-9);
                    x = resample(x, p, q);
                end
                cont.(lab) = x;
                expt = buildGLM.registerContinuous(expt, char(lab), desc(lab), size(x, 2));
            end

            % the trials
            keep = true(n, 1);
            trials = cell(n, 1);
            for k = 1:n
                t0 = spans(k, 1); t1 = spans(k, 2);
                nBins = floor((t1 - t0) * 1000 / binMs + 1e-9);
                if nBins < 1; keep(k) = false; continue; end
                dur = nBins * binMs;                      % ms
                tEnd = t0 + dur / 1000;                   % s, exclusive
                tr = buildGLM.newTrial(expt, dur);
                tr = rmfield(tr, 'expt');
                tr.span = [t0 tEnd];
                for lab = spikeLabels
                    st = double(opts.Spikes.(lab)(:));
                    st = st(st >= t0 & st < tEnd);
                    tr.(lab) = sort((st - t0) * 1000);
                end
                for lab = eventLabels
                    et = double(opts.Events.(lab)(:));
                    et = et(et >= t0 & et < tEnd);
                    tr.(lab) = sort((et - t0) * 1000);
                end
                for lab = valueLabels
                    v = opts.Values.(lab)(k, :);
                    if iscell(v) && isscalar(v); v = v{1}; end
                    tr.(lab) = v;
                end
                for lab = contLabels
                    x = cont.(lab);
                    r0 = round(t0 * fsBin) + 1;
                    rows = r0:(r0 + nBins - 1);
                    if r0 < 1 || rows(end) > size(x, 1)
                        keep(k) = false;
                        break
                    end
                    tr.(lab) = x(rows, :);
                end
                if keep(k); trials{k} = tr; end
            end
            trials = trials(keep);
            if isempty(trials)
                error('NeuroGLMExport:NoTrials', 'No span became a trial (all shorter than one bin, or off the continuous signals).');
            end
            % addTrial's checks, then the struct array in one go (addTrial grows it one by one)
            for k = 1:numel(trials)
                NeuroGLMExport.checkTrial(expt, trials{k}, k);
            end
            expt.trial = [trials{:}].';
        end

        function dspec = designSpec(expt, opts)
            %designSpec  A default neuroGLM design specification for one spike train.
            %   dspec = NeuroGLMExport.designSpec(expt, Response=, Events=, ...)
            %   Options
            %     Response     the spike train to model: its label, or its
            %                  index among the registered spike trains (1)
            %     Events       the timing variables given a kernel (all)
            %     KernelMs     the kernel's length after an event, ms (500)
            %     NBases       raised cosines per kernel (8)
            %     Shape        "raised cosine" (default) | "boxcar"
            %     Acausal      timing variables whose kernel also precedes
            %                  the event: it spans [-KernelMs, KernelMs]
            %                  (none); e.g. a response the animal makes
            %     GroupBy      a value variable: the events in GroupEvents
            %                  get one kernel per distinct value, included
            %                  only on the trials with that value (""); e.g.
            %                  "group" for the browser's trial groups, as
            %                  the paper's coherence-dependent kernels. A
            %                  value of "" gets no kernel. Several variables
            %                  split different events
            %     GroupEvents  the events split by GroupBy (Events); with
            %                  several GroupBy, a cell of them, one per
            %                  variable. An event takes one split
            %     History      a spike-history filter on the response (true)
            %     HistoryMs    its reach, ms (200)
            %     HistoryBases raised cosines, log-stretched (10)
            %     Coupling     a coupling filter from every other spike train
            %                  (false), with the history basis
            %     Continuous   the continuous variables as instantaneous
            %                  covariates (all registered)
            %   The design is dspec.covar; dspec.response holds the label
            %   fit regresses on, dspec.groupBy the variables and
            %   dspec.groupLevels their values, a cell with one per variable.
            %   Kernels: covariate label = the event label; grouped kernels
            %   "<event>__<value>"; history "hist"; coupling "coupling_<label>".
            arguments
                expt (1,1) struct
                opts.Response = 1
                opts.Events string = string.empty
                opts.KernelMs (1,1) double {mustBePositive} = 500
                opts.NBases (1,1) double {mustBeInteger, mustBePositive} = 8
                opts.Shape (1,1) string {mustBeMember(opts.Shape, ["raised cosine" "boxcar"])} = "raised cosine"
                opts.Acausal string = string.empty
                opts.GroupBy string = string.empty
                opts.GroupEvents = string.empty
                opts.History (1,1) logical = true
                opts.HistoryMs (1,1) double {mustBePositive} = 200
                opts.HistoryBases (1,1) double {mustBeInteger, mustBePositive} = 10
                opts.Coupling (1,1) logical = false
                opts.Continuous string = string.empty
            end
            NeuroGLMExport.requireNeuroGLM();
            types = expt.type;
            labels = string(fieldnames(types)).';
            kind = @(t) labels(cellfun(@(l) strcmp(types.(l), t), cellstr(labels)));
            spikeLabels = kind('spike train');
            eventLabels = kind('timing');
            contLabels  = kind('continuous');
            if isempty(spikeLabels)
                error('NeuroGLMExport:NoSpikeTrain', 'The experiment has no spike train to model.');
            end
            resp = opts.Response;
            if isnumeric(resp)
                if resp < 1 || resp > numel(spikeLabels)
                    error('NeuroGLMExport:BadResponse', 'Response %d: the experiment has %d spike train(s).', resp, numel(spikeLabels));
                end
                resp = spikeLabels(resp);
            end
            resp = string(resp);
            if ~ismember(resp, spikeLabels)
                error('NeuroGLMExport:BadResponse', '"%s" is not a registered spike train (%s).', resp, strjoin(spikeLabels, ', '));
            end
            events = opts.Events;
            if isempty(events); events = eventLabels; end
            groupBy = reshape(opts.GroupBy(opts.GroupBy ~= ""), 1, []);
            groupEvents = opts.GroupEvents;
            if ~iscell(groupEvents); groupEvents = {groupEvents}; end
            groupEvents = cellfun(@(g) reshape(string(g), 1, []), groupEvents, 'UniformOutput', false);
            missing = setdiff([events opts.Acausal groupEvents{:}], eventLabels);
            if ~isempty(missing)
                error('NeuroGLMExport:BadEvent', 'Not a registered timing variable: %s.', strjoin(missing, ', '));
            end
            conts = opts.Continuous;
            if isempty(conts); conts = contLabels; end
            missing = setdiff(conts, contLabels);
            if ~isempty(missing)
                error('NeuroGLMExport:BadContinuous', 'Not a registered continuous variable: %s.', strjoin(missing, ', '));
            end
            if numel(groupBy) > 1 && numel(groupEvents) ~= numel(groupBy)
                error('NeuroGLMExport:BadGroupEvents', 'Several GroupBy need GroupEvents as a cell, one element per variable.');
            end
            levels = cell(1, numel(groupBy));
            for i = 1:numel(groupBy)
                by = groupBy(i);
                if ~isfield(types, by) || ~strcmp(types.(by), 'value')
                    error('NeuroGLMExport:BadGroupBy', '"%s" is not a registered value variable.', by);
                end
                if isempty(groupEvents{i}); groupEvents{i} = events; end
                vals = arrayfun(@(tr) tr.(by), expt.trial, 'UniformOutput', false);
                if all(cellfun(@(v) isnumeric(v) || islogical(v), vals))
                    levels{i} = unique(cell2mat(vals(:)));
                else
                    levels{i} = setdiff(unique(string(vals)), "");
                end
            end
            if ~isempty(groupBy)
                split = [groupEvents{1:numel(groupBy)}];
                [u, ~, ic] = unique(split);
                twice = u(accumarray(ic(:), 1) > 1);
                if ~isempty(twice)
                    error('NeuroGLMExport:BadGroupEvents', 'An event takes one split, but %s is in two (GroupBy %s).', ...
                        strjoin(twice, ', '), strjoin(groupBy, ', '));
                end
            end

            dspec = buildGLM.initDesignSpec(expt);
            binfun = expt.binfun;
            nK = binfun(opts.KernelMs);
            for lab = events
                if ismember(lab, opts.Acausal)
                    bs = basisFactory.makeSmoothTemporalBasis(char(opts.Shape), 2 * opts.KernelMs, 2 * opts.NBases, binfun);
                    offset = -nK;
                else
                    bs = basisFactory.makeSmoothTemporalBasis(char(opts.Shape), opts.KernelMs, opts.NBases, binfun);
                    offset = 0;
                end
                iBy = find(cellfun(@(g) ismember(lab, g), groupEvents(1:numel(groupBy))), 1);
                if ~isempty(iBy)
                    by = groupBy(iBy);
                    for L = reshape(levels{iBy}, 1, [])
                        if isnumeric(L) || islogical(L)
                            cond = @(tr) isequal(double(tr.(by)), double(L));
                            tag = regexprep(num2str(L), '[^\w]', '_');
                        else
                            cond = @(tr) string(tr.(by)) == L;
                            tag = matlab.lang.makeValidName(char(L));
                        end
                        covLabel = char(lab + "__" + tag);
                        dspec = buildGLM.addCovariateTiming(dspec, covLabel, char(lab), ...
                            sprintf('%s (%s = %s)', expt.desc.(lab), by, string(L)), bs, offset, cond);
                    end
                else
                    dspec = buildGLM.addCovariateTiming(dspec, char(lab), char(lab), expt.desc.(lab), bs, offset);
                end
            end
            if opts.History || opts.Coupling
                hb = basisFactory.makeNonlinearRaisedCos(opts.HistoryBases, expt.binSize, [0 opts.HistoryMs], 1);
            end
            if opts.History
                dspec = buildGLM.addCovariateSpiketrain(dspec, 'hist', char(resp), 'Spike history', hb);
            end
            if opts.Coupling
                for lab = setdiff(spikeLabels, resp, 'stable')
                    dspec = buildGLM.addCovariateSpiketrain(dspec, char("coupling_" + lab), char(lab), ...
                        char("Coupling from " + lab), hb);
                end
            end
            for lab = conts
                dspec = buildGLM.addCovariateRaw(dspec, char(lab), expt.desc.(lab));
            end
            if ~isfield(dspec, 'covar') || isempty(fieldnames(dspec.covar))
                error('NeuroGLMExport:EmptyDesign', 'The design has no covariate: give Events, History, Coupling or Continuous.');
            end
            dspec.response = resp;
            dspec.groupBy = groupBy;
            dspec.groupLevels = levels;
            dspec.options = opts;
        end

        function F = fit(dspec, opts)
            %fit  Compile the design matrix and fit the Poisson GLM.
            %   F = NeuroGLMExport.fit(dspec, Trials=, Response=, Method=, Ridge=)
            %   Trials: the elements of expt.trial to fit on (all). Response:
            %   the spike train (dspec.response). Constant columns are removed
            %   first (buildGLM.removeConstantCols); the constant term is
            %   fitted apart from the design matrix.
            %   Method
            %     "glmfit"      maximum likelihood by glmfit (Statistics and
            %                   Machine Learning Toolbox; the default): no
            %                   prior, standard errors from glmfit's stats
            %     "matRegress"  neuroGLM's own route, the paper's: the Poisson
            %                   negative log-likelihood glms.neglog.poisson
            %                   (matRegress, on the path with
            %                   addpath(<neuroGLM>/matRegress)) with its
            %                   gradient and Hessian, minimized by fminunc
            %                   (Optimization Toolbox, trust-region) under a
            %                   ridge prior on every weight but the bias;
            %                   standard errors from the Hessian at the
            %                   optimum (the Laplace approximation)
            %   Ridge (matRegress only): the prior precision lambda, i.e. the
            %   penalty lambda/2 * ||w||^2 added to the negative
            %   log-likelihood (0 = maximum likelihood; 1 by default), or
            %   "evidence": lambda picked on RidgeGrid (logspace(-2, 4, 13))
            %   by the largest Laplace approximation of the log marginal
            %   likelihood, the paper's evidence optimization. F.ridge is the
            %   value used, F.evidence the grid's log evidence (NaN when
            %   the Hessian was not positive definite).
            %   F fields
            %     expt, dspec, trials, response, binMs, method, ridge, ridgeGrid, evidence
            %     dm, y       the design matrix struct (dm.X sparse, dm.constCols)
            %                 and the binned response (counts per bin, sparse)
            %     bias        the constant term (log spikes per bin at rest)
            %     w, se       the weights on the basis functions and their
            %                 standard errors
            %     kernels     buildGLM.combineWeights: kernels.<covariate>.tr
            %                 (ms from the event) and .data (the log-rate
            %                 change, the gain is exp(data))
            %     kernelSE    the same shape for sqrt of the variance
            %                 combined as the weights are (neuroGLM's
            %                 tutorial: covariances ignored)
            %     rate        the fitted rate per bin, spikes per s
            %     deviance    2 (saturated log-likelihood - logLik)
            %     stats       glmfit's stats, or hessian / covb (the
            %                 weights' covariance, bias first) from matRegress
            %     logLik, logLikNull   Poisson log-likelihood of the fit and
            %                 of a constant rate
            %     bitsPerSpike   (logLik - logLikNull) / nSpikes / log(2),
            %                 the paper's single-trial prediction measure
            %     nSpikes, nBins
            arguments
                dspec (1,1) struct
                opts.Trials double = []
                opts.Response (1,1) string = ""
                opts.Method (1,1) string {mustBeMember(opts.Method, ["glmfit" "matRegress"])} = "glmfit"
                opts.Ridge = 1
                opts.RidgeGrid (1,:) double {mustBePositive} = logspace(-2, 4, 13)
            end
            NeuroGLMExport.requireNeuroGLM();
            expt = dspec.expt;
            trials = opts.Trials;
            if isempty(trials); trials = 1:numel(expt.trial); end
            resp = opts.Response;
            if resp == ""
                if ~isfield(dspec, 'response')
                    error('NeuroGLMExport:NoResponse', 'Give Response= (the design spec has none).');
                end
                resp = dspec.response;
            end
            dm = buildGLM.compileSparseDesignMatrix(dspec, trials);
            y = buildGLM.getBinnedSpikeTrain(expt, char(resp), dm.trialIndices);
            dm = buildGLM.removeConstantCols(dm);
            if ~isfield(dm.dspec.covar, 'basis')       % combineWeights reads covar.basis; a design of raw covariates has none
                [dm.dspec.covar.basis] = deal([]);
            end
            X = full(dm.X);
            yf = full(y);
            F = struct();
            F.expt = expt;
            F.dspec = dspec;
            F.trials = dm.trialIndices;
            F.response = resp;
            F.binMs = expt.binSize;
            F.method = opts.Method;
            F.ridge = 0;
            F.ridgeGrid = [];
            F.evidence = [];
            F.dm = dm;
            F.y = y;
            switch opts.Method
                case "glmfit"
                    ws = warning('off', 'stats:glmfit:IterationLimit');
                    cleanup = onCleanup(@() warning(ws)); %#ok<NASGU>
                    [b, ~, stats] = glmfit(X, yf, 'poisson');
                    clear cleanup
                    F.bias = b(1);
                    F.w = b(2:end);
                    F.se = stats.se(2:end);
                    F.stats = stats;
                case "matRegress"
                    NeuroGLMExport.requireMatRegress();
                    ridge = opts.Ridge;
                    if isstring(ridge) || ischar(ridge)
                        if string(ridge) ~= "evidence"
                            error('NeuroGLMExport:BadRidge', 'Ridge is a number >= 0 or "evidence".');
                        end
                        grid = sort(opts.RidgeGrid);
                    else
                        if ~isscalar(ridge) || ~isnumeric(ridge) || ridge < 0
                            error('NeuroGLMExport:BadRidge', 'Ridge is a number >= 0 or "evidence".');
                        end
                        grid = double(ridge);
                    end
                    [b, se, H, ev] = NeuroGLMExport.fitRidge(X, yf, grid);
                    F.bias = b(1);
                    F.w = b(2:end);
                    F.se = se(2:end);
                    [~, best] = max(ev);
                    if isempty(best) || isnan(ev(best)); best = numel(grid); end
                    F.ridge = grid(best);
                    F.ridgeGrid = grid;
                    F.evidence = ev;
                    F.stats = struct('hessian', H, 'covb', inv(H));
            end
            F.kernels = buildGLM.combineWeights(dm, F.w);
            v = buildGLM.combineWeights(dm, F.se .^ 2);
            for f = string(fieldnames(v)).'
                if isstruct(v.(f)); v.(f).data = sqrt(max(v.(f).data, 0)); end
            end
            F.kernelSE = v;
            eta = F.bias + X * F.w;
            lambda = exp(eta);                                    % spikes per bin
            F.rate = lambda * 1000 / F.binMs;
            F.nBins = numel(yf);
            F.nSpikes = sum(yf);
            F.logLik = sum(yf .* eta - lambda - gammaln(yf + 1));   % y*log(lambda) through eta: no 0*(-Inf)
            mu = mean(yf);
            F.logLikNull = sum(yf .* log(mu) - mu - gammaln(yf + 1));
            pos = yf > 0;
            logLikSat = sum(yf(pos) .* log(yf(pos)) - yf(pos) - gammaln(yf(pos) + 1));
            F.deviance = 2 * (logLikSat - F.logLik);
            F.bitsPerSpike = (F.logLik - F.logLikNull) / max(F.nSpikes, 1) / log(2);
        end

        function P = predict(F, trials)
            %predict  The fitted model's rate on trials, one cell per trial.
            %   P = NeuroGLMExport.predict(F, trials) (default F.trials)
            %     P.trials   the trial indices
            %     P.t{k}     bin starts, ms from the trial's start
            %     P.rate{k}  the model's rate, spikes per s, per bin
            %     P.counts{k}   the response's spike counts per bin
            %     P.logLik, P.bitsPerSpike   as fit, over these trials
            %   Held-out trials (not in F.trials) give the cross-validated
            %   prediction.
            arguments
                F (1,1) struct
                trials double = []
            end
            if isempty(trials); trials = F.trials; end
            expt = F.expt;
            dm = buildGLM.compileSparseDesignMatrix(F.dspec, trials);
            X = full(dm.X(:, ~F.dm.constCols));
            y = full(buildGLM.getBinnedSpikeTrain(expt, char(F.response), dm.trialIndices));
            eta = F.bias + X * F.w;
            lambda = exp(eta);
            n = arrayfun(@(k) expt.binfun(expt.trial(k).duration), dm.trialIndices);
            edges = [0 cumsum(n)];
            P = struct();
            P.trials = dm.trialIndices;
            P.t = cell(1, numel(n)); P.rate = P.t; P.counts = P.t;
            for k = 1:numel(n)
                idx = edges(k) + 1:edges(k + 1);
                P.t{k} = (0:n(k) - 1) * F.binMs;
                P.rate{k} = lambda(idx).' * 1000 / F.binMs;
                P.counts{k} = y(idx).';
            end
            P.logLik = sum(y .* eta - lambda - gammaln(y + 1));
            mu = mean(y);
            P.logLikNull = sum(y .* log(mu) - mu - gammaln(y + 1));
            P.bitsPerSpike = (P.logLik - P.logLikNull) / max(sum(y), 1) / log(2);
        end

        function fits = fitUnits(expt, units, opts)
            %fitUnits  Fit and test one design per unit, on process workers or here; progress and cancel on the way.
            %   fits = NeuroGLMExport.fitUnits(expt, units, Design=, Trials=, Test=, Method=, Ridge=, Workers=, ...)
            %   units: a table with a row per unit to fit, its spike train's
            %   label in the column variable (sessionDataNeuroGLM's
            %   info.units). fits has one element per row, in that order:
            %   unit (the row), dspec, F (fit), P (predict on Test).
            %   Options
            %     Design       designSpec's options, a name-value cell ({})
            %     Trials       the trials fitted (all)
            %     Test         the trials predicted (Trials)
            %     Method, Ridge   as fit
            %     Workers      process workers fitting at once, as fitWorkers
            %                  allows (0: one unit after the other, here)
            %     ProgressFcn  ProgressFcn(fraction, message) at the start
            %                  and after each unit ([] = none)
            %     LogFcn       LogFcn(message), a unit's line as it finishes
            %                  ([] = none)
            %     CheckFcn     called between units and, with workers, four
            %                  times a second; its error stops the workers
            %                  and is raised here ([] = none)
            arguments
                expt (1,1) struct
                units table
                opts.Design cell = {}
                opts.Trials double = []
                opts.Test double = []
                opts.Method (1,1) string = "glmfit"
                opts.Ridge = 1
                opts.Workers (1,1) double {mustBeInteger, mustBeNonnegative} = 0
                opts.ProgressFcn = []
                opts.LogFcn = []
                opts.CheckFcn = []
            end
            trials = opts.Trials;
            if isempty(trials); trials = 1:numel(expt.trial); end
            nU = height(units);
            parts = cell(1, nU);
            nWorkers = 0;
            if nU > 1
                nWorkers = NeuroGLMExport.fitWorkers(NeuroGLMExport.designSpec(expt, 'Response', units.variable(1), opts.Design{:}), ...
                    trials, min(opts.Workers, nU));
            end
            NeuroGLMExport.reportFit(opts, 0, nU, []);
            if nWorkers == 0
                for i = 1:nU
                    if ~isempty(opts.CheckFcn); opts.CheckFcn(); end
                    parts{i} = NeuroGLMExport.fitOne(expt, units(i, :), opts.Design, trials, opts.Test, opts.Method, opts.Ridge);
                    NeuroGLMExport.reportFit(opts, i, nU, parts{i});
                end
            else
                constant = parallel.pool.Constant(expt);   % one copy per worker, not one per unit
                pool = gcp('nocreate');
                F = parallel.FevalFuture.empty(1, 0);      % the units running
                of = zeros(1, 0);
                next = 1;
                nDone = 0;
                try
                    while nDone < nU
                        while next <= nU && numel(F) < nWorkers
                            F(end + 1) = parfeval(pool, @NeuroGLMExport.fitOne, 1, constant, units(next, :), ...
                                opts.Design, trials, opts.Test, opts.Method, opts.Ridge); %#ok<AGROW>
                            of(end + 1) = next; %#ok<AGROW>
                            next = next + 1;
                        end
                        if ~isempty(opts.CheckFcn); opts.CheckFcn(); end
                        [k, part] = fetchNext(F, 0.25);
                        if isempty(k); continue; end
                        parts{of(k)} = part;
                        F(k) = [];
                        of(k) = [];
                        nDone = nDone + 1;
                        NeuroGLMExport.reportFit(opts, nDone, nU, part);
                    end
                catch ME
                    if ~isempty(F); cancel(F); end
                    rethrow(ME);
                end
            end
            fits = struct('unit', {}, 'dspec', {}, 'F', {}, 'P', {});
            fits = [fits, parts{:}];
            for j = 1:numel(fits)      % shared again, as a fit here holds it
                fits(j).dspec.expt = expt;
                fits(j).F.expt = expt;
                fits(j).F.dspec.expt = expt;
                fits(j).F.dm.dspec.expt = expt;
            end
        end

        function n = fitWorkers(dspec, trials, maxWorkers)
            %fitWorkers  How many process workers can fit a design at once (0 = fit here), with the pool open.
            %   n = NeuroGLMExport.fitWorkers(dspec, trials, maxWorkers) for
            %   fitUnits, each worker fitting dspec on trials.
            %   The open process pool is used, else one is started. A worker
            %   holds about 4 full design matrices (bins x columns doubles)
            %   and the experiment, and 10% of the available memory or 2 GB
            %   stays free: n = min(what fits, maxWorkers, the pool's size,
            %   which is at most the Processes profile's NumWorkers).
            %   n is 0 for maxWorkers < 2 and, with the warning
            %   NeuroGLMExport:SerialFit, when fewer than two workers can be
            %   had (memory, no Parallel Computing Toolbox, no process pool).
            arguments
                dspec (1,1) struct
                trials double
                maxWorkers (1,1) double {mustBeInteger, mustBeNonnegative}
            end
            n = 0;
            if maxWorkers < 2; return; end
            expt = dspec.expt;
            nBins = sum(arrayfun(@(k) expt.binfun(expt.trial(k).duration), trials));
            sz = whos('expt');
            perWorker = 4 * 8 * nBins * sum([dspec.covar.edim]) + sz.bytes;
            avail = 8e9;
            if ispc
                m = memory;
                avail = double(m.MemAvailableAllArrays);
            end
            cap = min(maxWorkers, floor((avail - max(2e9, 0.1 * avail)) / perWorker));
            why = "";
            if cap < 2
                why = sprintf("%.1f GB per worker, %.1f GB available", perWorker / 1e9, avail / 1e9);
            elseif isempty(ver('parallel')) || ~license('test', 'Distrib_Computing_Toolbox')
                why = "the Parallel Computing Toolbox is not available";
            else
                try
                    pool = gcp('nocreate');
                    if isempty(pool)
                        cluster = parcluster("Processes");
                        pool = parpool(cluster, max(1, min(cap, cluster.NumWorkers)));
                    end
                    if ~isa(pool, 'parallel.ProcessPool')
                        why = "the open pool is a " + class(pool) + ", not a process pool";
                    elseif pool.NumWorkers < 2
                        why = "the pool has one worker";
                    else
                        n = min(cap, pool.NumWorkers);
                    end
                catch ME
                    why = "no process pool could be started (" + ME.message + ")";
                end
            end
            if why ~= ""
                warning('NeuroGLMExport:SerialFit', 'Fitting one unit after the other: %s.', why);
            end
        end

        function tf = hasMatRegress()
            %hasMatRegress  True when neuroGLM's matRegress (glms, nlfuns packages) is on the path.
            tf = ~isempty(which('glms.neglog.poisson')) && ~isempty(which('nlfuns.exp'));
        end

        function requireMatRegress()
            %requireMatRegress  Error with a hint when matRegress or fminunc is missing.
            if ~NeuroGLMExport.hasMatRegress()
                error('NeuroGLMExport:NoMatRegress', ...
                    ['neuroGLM''s matRegress is not on the MATLAB path: addpath(fullfile(<neuroGLM>, ''matRegress'')). ' ...
                     'Or fit with Method="glmfit".']);
            end
            if exist('fminunc', 'file') ~= 2
                error('NeuroGLMExport:NoOptimizationToolbox', ...
                    'Method "matRegress" needs fminunc (Optimization Toolbox); fit with Method="glmfit" instead.');
            end
        end

        function tf = hasNeuroGLM()
            %hasNeuroGLM  True when neuroGLM's buildGLM and basisFactory packages are on the path.
            tf = ~isempty(which('buildGLM.initExperiment')) && ~isempty(which('basisFactory.makeSmoothTemporalBasis'));
        end

        function requireNeuroGLM()
            %requireNeuroGLM  Error with an install hint when neuroGLM is missing.
            if ~NeuroGLMExport.hasNeuroGLM()
                error('NeuroGLMExport:NoNeuroGLM', ...
                    ['neuroGLM is not on the MATLAB path. Clone github.com/pillowlab/neuroGLM and ' ...
                     'addpath its folder (the one holding +buildGLM and +basisFactory).']);
            end
        end
    end

    methods (Static, Hidden)
        function part = fitOne(expt, unit, design, trials, test, method, ridge)
            %fitOne  One unit of fitUnits, on a worker or here: the experiment (or its Constant) comes off the result, fitUnits puts it back.
            if isa(expt, 'parallel.pool.Constant'); expt = expt.Value; end
            dspec = NeuroGLMExport.designSpec(expt, 'Response', unit.variable, design{:});
            F = NeuroGLMExport.fit(dspec, Trials=trials, Method=method, Ridge=ridge);
            P = NeuroGLMExport.predict(F, test);
            dspec.expt = [];
            F.expt = [];
            F.dspec.expt = [];
            F.dm.dspec.expt = [];
            part = struct('unit', unit, 'dspec', dspec, 'F', F, 'P', P);
        end
    end

    methods (Static, Access = private)
        function reportFit(opts, nDone, nU, part)
            %reportFit  fitUnits' ProgressFcn and, with a finished unit PART, LogFcn.
            if ~isempty(part) && ~isempty(opts.LogFcn)
                opts.LogFcn(sprintf('unit %s: %d trials fitted (%s, ridge %g), %d held out; %.3f bits/spike (fit), %.3f (held out)', ...
                    part.unit.label, numel(part.F.trials), part.F.method, part.F.ridge, numel(part.P.trials), part.F.bitsPerSpike, part.P.bitsPerSpike));
            end
            if ~isempty(opts.ProgressFcn)
                opts.ProgressFcn(nDone / max(nU, 1), sprintf('%d/%d units', nDone, nU));
            end
        end

        function [b, se, H, ev] = fitRidge(X, y, grid)
            %fitRidge  Poisson GLM with a ridge prior by fminunc, over a grid of precisions.
            %   [b, se, H, ev] = fitRidge(X, y, grid): b = [bias; w] at the
            %   grid value with the largest Laplace log evidence ev (one per
            %   grid value, ascending; NaN when the Hessian is not positive
            %   definite), se its standard errors sqrt(diag(inv(H))). The bias
            %   carries no prior. Fits along the grid start from the previous
            %   optimum.
            Xb = [ones(size(X, 1), 1), X];
            p = size(Xb, 2);
            pen = [0; ones(p - 1, 1)];
            w0 = [log(max(mean(y), 1e-6)); zeros(p - 1, 1)];
            fopts = optimoptions(@fminunc, 'Algorithm', 'trust-region', 'SpecifyObjectiveGradient', true, ...
                'HessianFcn', 'objective', 'Display', 'off', 'MaxIterations', 500, ...
                'OptimalityTolerance', 1e-8, 'FunctionTolerance', 1e-10, 'StepTolerance', 1e-10);
            n = numel(grid);
            ev = NaN(1, n);
            W = zeros(p, n);
            Hs = cell(1, n);
            for i = 1:n
                lam = grid(i);
                obj = @(w) NeuroGLMExport.ridgeObjective(w, Xb, y, lam, pen);
                [wi, Li, ~, ~, ~, Hi] = fminunc(obj, w0, fopts);
                W(:, i) = wi;
                Hs{i} = Hi;
                [R, flag] = chol(Hi);
                if flag == 0
                    logdet = 2 * sum(log(diag(R)));
                    if lam > 0
                        ev(i) = -Li + 0.5 * (p - 1) * log(lam) - 0.5 * logdet;   % + constants
                    else
                        ev(i) = -Li - 0.5 * logdet;                              % no prior: not comparable across lambdas
                    end
                end
                w0 = wi;
            end
            [~, best] = max(ev);
            if isempty(best) || isnan(ev(best)); best = n; end
            b = W(:, best);
            H = Hs{best};
            [R, flag] = chol(H);
            if flag == 0
                Rinv = R \ eye(p);
                se = sqrt(sum(Rinv .^ 2, 2));
            else
                se = sqrt(abs(diag(pinv(H))));
            end
        end

        function [L, dL, H] = ridgeObjective(w, Xb, y, lam, pen)
            %ridgeObjective  Negative log posterior: glms.neglog.poisson + lam/2 ||w||^2 (no prior on the bias).
            switch nargout
                case 1
                    L = glms.neglog.poisson(w, Xb, y, @nlfuns.exp);
                case 2
                    [L, dL] = glms.neglog.poisson(w, Xb, y, @nlfuns.exp);
                    dL = dL + lam * (pen .* w);
                otherwise
                    [L, dL, H] = glms.neglog.poisson(w, Xb, y, @nlfuns.exp);
                    dL = dL + lam * (pen .* w);
                    H = H + lam * diag(pen);
            end
            L = L + 0.5 * lam * sum(pen .* w .^ 2);
        end

        function d = describe(D, lab)
            if isfield(D, lab); d = char(string(D.(lab))); else; d = char(lab); end
        end

        function checkTrial(expt, tr, k)
            %checkTrial  buildGLM.addTrial's checks, without growing the struct array.
            for v = string(fieldnames(expt.type)).'
                if ~isfield(tr, v)
                    error('NeuroGLMExport:MissingVariable', 'Trial %d lacks the variable %s.', k, v);
                end
                x = tr.(v);
                switch expt.type.(v)
                    case 'continuous'
                        if size(x, 1) ~= expt.binfun(tr.duration)
                            error('NeuroGLMExport:BadTrial', 'Trial %d: %s has %d rows for %d bins.', k, v, size(x, 1), expt.binfun(tr.duration));
                        end
                    case {'timing', 'spike train'}
                        if ~isempty(x) && (min(x) < 0 || max(x) > tr.duration)
                            error('NeuroGLMExport:BadTrial', 'Trial %d: %s has times outside [0 %g] ms.', k, v, tr.duration);
                        end
                end
            end
        end
    end
end
