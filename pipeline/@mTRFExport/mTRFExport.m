classdef mTRFExport
    % mTRFExport  Prepare this pipeline's signals and stimuli for the mTRF-Toolbox.
    %   Pure, static packaging functions: nothing here reads a recording or
    %   calls the toolbox. The mTRF-Toolbox (Crosse et al. 2016, Front Hum
    %   Neurosci 10:604; https://github.com/mickcrosse/mTRF-Toolbox) fits
    %   linear encoding models (a temporal response function, TRF: stimulus
    %   -> response) and decoding models (response -> stimulus) by ridge
    %   regression over time-lagged copies of its input. Its functions
    %   (mTRFtrain, mTRFcrossval, mTRFpredict, ...) take
    %     stim   {nTrials x 1} of [nTime x nFeatures]
    %     resp   {nTrials x 1} of [nTime x nChannels]
    %     fs     one rate for both, Hz (it fits at tens of Hz: 64-128)
    %   with the same nTime in each trial's pair. The functions here make
    %   those from the pipeline's data: a signal at its own rate, the
    %   digital lines' pulses, an AUX channel's envelope, the trials or the
    %   artifact-free stretches of a session. sessionDataMTRF and
    %   epochMatrixMTRF (analysis/) feed them the DatasetBrowser's data.
    %
    %   The toolbox is never required to prepare the data; hasMTRF /
    %   requireMTRF say whether it is on the path. The Signal Processing
    %   Toolbox is (resample, envelope, hilbert).
    %
    %   Conventions
    %   -----------
    %   - Signals are [nSamples x nVar], row k at t = (k-1)/Fs (the
    %     pipeline's continuous clock); the toolbox's rows are observations
    %     too, so nothing is transposed.
    %   - A time t falls on sample round(t*Fs) + 1 (as FieldTripExport.epochs
    %     places an onset); artifact periods [tStart tEnd) cover every sample
    %     whose period [(k-1)/Fs, k/Fs) they overlap.
    %   - resample keeps t = 0 on the first sample; the rate it reaches is
    %     FsIn*p/q for the rational p/q nearest FsOut/FsIn and is returned,
    %     so pass that one to the toolbox.
    %   - A package (package) holds stim, resp, fs and the labels of both
    %     sides, with each trial's place on the session (start, s on the
    %     continuous clock) so a model's predictions can be put back.
    %
    %   See also sessionDataMTRF, epochMatrixMTRF, FieldTripExport, ChronuxDataset.

    methods (Static)
        function [Y, FsOut] = resample(X, FsIn, FsOut)
            %resample  A signal at another rate, t = 0 kept on the first sample.
            %   [Y, FS] = mTRFExport.resample(X, FsIn, FsOut) resamples X
            %   ([nSamples x nVar], row k at (k-1)/FsIn) to FS, the rate
            %   FsIn*p/q for [p, q] = rat(FsOut/FsIn) (exact for the usual
            %   pairs, 2000 -> 128 among them), with the Signal Processing
            %   Toolbox's resample: a Kaiser-windowed anti-aliasing filter
            %   (n = 10, beta = 8: passband ripple under 1e-4, against the
            %   default beta = 5's 1e-3) whose half-length is 10 samples of
            %   the lower rate, so the first and last 10 output samples are
            %   filtered against zeros beyond the signal. Y is double, row j
            %   at (j-1)/FS, ceil(nSamples*p/q) rows. FsOut = FsIn returns X
            %   as double.
            arguments
                X (:,:) {mustBeNumeric}
                FsIn (1,1) double {mustBePositive}
                FsOut (1,1) double {mustBePositive}
            end
            X = double(X);
            if FsOut == FsIn
                Y = X;
                return
            end
            [p, q] = rat(FsOut / FsIn, 1e-9);
            reached = FsIn * p / q;
            if abs(reached - FsOut) > 1e-9 * FsOut; FsOut = reached; end   % else the rate asked for, exactly
            if isempty(X)
                Y = zeros(0, size(X, 2));
                return
            end
            if size(X, 1) == 1
                Y = X;      % resample needs more than one sample
                return
            end
            Y = resample(X, p, q, 10, 8);
        end

        function [y, FsOut] = envelope(x, FsIn, FsOut, opts)
            %envelope  The amplitude envelope of a signal (a sound, an AUX channel) at a low rate.
            %   [Y, FS] = mTRFExport.envelope(X, FsIn, FsOut) returns the
            %   envelope of each column of X ([nSamples x nVar] at FsIn) at
            %   FS (resample's rate for FsOut), the stimulus feature the
            %   toolbox's examples use for speech and sounds:
            %     Method "rms" (default): the RMS over a sliding window of
            %       round(FsIn/FsOut) samples (envelope(x, n, 'rms')), as
            %       mTRFenvelope averages the squares over the output frames
            %     Method "hilbert": |hilbert(x)|, each column
            %   then resampled to FS (the anti-aliasing filter smooths it),
            %   clipped at 0 and raised to Compression (log10(2) by default,
            %   the loudness compression of Stevens 1955 that mTRFenvelope
            %   applies; 1 = none). Each column is centered first
            %   (Center=true): an AUX line's DC offset is not sound.
            arguments
                x (:,:) {mustBeNumeric}
                FsIn (1,1) double {mustBePositive}
                FsOut (1,1) double {mustBePositive}
                opts.Method (1,1) string {mustBeMember(opts.Method, ["rms" "hilbert"])} = "rms"
                opts.Compression (1,1) double {mustBeNonnegative} = log10(2)
                opts.Center (1,1) logical = true
            end
            x = double(x);
            if opts.Center && ~isempty(x)
                x = x - mean(x, 1);
            end
            switch opts.Method
                case "rms"
                    n = max(1, round(FsIn / FsOut));
                    if size(x, 1) > n
                        e = envelope(x, n, 'rms');
                    else
                        e = abs(x);
                    end
                case "hilbert"
                    e = abs(hilbert(x));
            end
            [y, FsOut] = mTRFExport.resample(e, FsIn, FsOut);
            y = max(y, 0);
            if opts.Compression ~= 1
                y = y .^ opts.Compression;
            end
        end

        function x = pulses(intervals, Fs, N, opts)
            %pulses  One stimulus feature from a line's pulses: impulses or a boxcar.
            %   X = mTRFExport.pulses(IV, Fs, N) is an [N x 1] feature at Fs
            %   from the pulses IV ([k x 2] [t_on t_off] s on the continuous
            %   clock, sessionData's eventsContinuous.<line>):
            %     Kind "onset" (default): 1 on the sample of each onset,
            %       round(t_on*Fs) + 1
            %     Kind "offset": 1 on the sample of each end, round(t_off*Fs) + 1
            %     Kind "boxcar": 1 from the onset's sample to the end's
            %   Value= gives each pulse's height instead of 1 (k values: a
            %   trial parameter; NaN counts as 0), Height= a factor on every
            %   pulse: Height=Fs makes each impulse a unit area (the discrete
            %   delta), so a forward model's weights (which the toolbox
            %   scales by Fs) are the response per pulse in the signal's own
            %   units. Pulses off the signal are left out; pulses on one
            %   sample add up.
            arguments
                intervals double
                Fs (1,1) double {mustBePositive}
                N (1,1) double {mustBeNonnegative, mustBeInteger}
                opts.Kind (1,1) string {mustBeMember(opts.Kind, ["onset" "offset" "boxcar"])} = "onset"
                opts.Value double = []
                opts.Height (1,1) double = 1
            end
            x = zeros(N, 1);
            iv = reshape(double(intervals), [], 2);
            k = size(iv, 1);
            v = reshape(double(opts.Value), [], 1);
            if isempty(v); v = ones(k, 1); end
            if numel(v) ~= k
                error('mTRFExport:BadValues', 'Value has %d entries for %d pulses.', numel(v), k);
            end
            v(isnan(v)) = 0;
            v = v * opts.Height;
            s0 = round(iv(:, 1) * Fs) + 1;
            s1 = round(iv(:, 2) * Fs) + 1;
            for j = 1:k
                switch opts.Kind
                    case "onset";  a = s0(j); b = s0(j);
                    case "offset"; a = s1(j); b = s1(j);
                    case "boxcar"; a = s0(j); b = max(s0(j), s1(j));
                end
                if isnan(a) || isnan(b) || b < 1 || a > N; continue; end
                a = max(a, 1); b = min(b, N);
                x(a:b) = x(a:b) + v(j);
            end
        end

        function [X, names] = lines(events, names, Fs, N, opts)
            %lines  Stimulus features from several digital lines, one column each.
            %   [X, NAMES] = mTRFExport.lines(EV, NAMES, Fs, N) with EV a
            %   struct of [k x 2] pulse intervals per line (continuous
            %   clock) returns [N x numel(NAMES)], column i = pulses(EV.(NAMES(i)),
            %   ...) with Kind= (one for all, or one per line). NAMES [] takes
            %   every line of EV, in its order.
            arguments
                events (1,1) struct
                names string
                Fs (1,1) double {mustBePositive}
                N (1,1) double {mustBeNonnegative, mustBeInteger}
                opts.Kind string = "onset"
                opts.Height (1,1) double = 1
            end
            names = reshape(names, 1, []);
            if isempty(names); names = string(fieldnames(events)).'; end
            kind = reshape(opts.Kind, 1, []);
            if isscalar(kind); kind = repmat(kind, 1, numel(names)); end
            if numel(kind) ~= numel(names)
                error('mTRFExport:BadKind', 'Kind has %d entries for %d lines.', numel(kind), numel(names));
            end
            X = zeros(N, numel(names));
            for i = 1:numel(names)
                if ~isfield(events, names(i))
                    error('mTRFExport:NoLine', 'No line "%s" (the lines are %s).', names(i), ...
                        strjoin(string(fieldnames(events)), ', '));
                end
                h = opts.Height;
                if kind(i) == "boxcar"; h = 1; end
                X(:, i) = mTRFExport.pulses(events.(names(i)), Fs, N, Kind=kind(i), Height=h);
            end
        end

        function [C, keep, t, rows] = trials(X, Fs, onsets, window, opts)
            %trials  A signal cut into equal trials around event times.
            %   [C, KEEP, T, ROWS] = mTRFExport.trials(X, Fs, ONSETS, [pre post])
            %   cuts X ([N x nVar] at Fs) around each of ONSETS (s on the
            %   continuous clock) into the window [pre post] s (post >
            %   pre): trial j runs from sample round(onset*Fs) + 1 +
            %   round(pre*Fs) to round(onset*Fs) + 1 + round(post*Fs), the
            %   samples FieldTripExport.epochs gives the same onset. C is a
            %   cell column of [nTime x nVar] double, one per onset kept;
            %   KEEP marks the onsets kept: a NaN onset, a trial running off
            %   the signal, or one touching a period of Artifacts= ([k x 2]
            %   [tStart tEnd) s) is left out. T is the nTime sample times, s
            %   from the onset; ROWS the [first last] samples of each trial
            %   kept.
            arguments
                X (:,:) {mustBeNumeric}
                Fs (1,1) double {mustBePositive}
                onsets (:,1) double
                window (1,2) double
                opts.Artifacts double = zeros(0, 2)
            end
            if window(2) <= window(1)
                error('mTRFExport:BadWindow', 'The window must be [pre post] with post > pre.');
            end
            N = size(X, 1);
            pre = round(window(1) * Fs);
            post = round(window(2) * Fs);
            t = ((pre:post) / Fs).';
            s0 = round(onsets * Fs) + 1;
            a = s0 + pre;
            b = s0 + post;
            keep = ~isnan(onsets) & a >= 1 & b <= N;
            art = reshape(double(opts.Artifacts), [], 2);
            if ~isempty(art)
                tA = (a - 1) / Fs;          % the trial's span, s: [tA, tB + 1/Fs)
                tB = b / Fs;
                touch = any(tA < art(:, 2).' & tB > art(:, 1).', 2);
                keep = keep & ~touch;
            end
            rows = [a(keep) b(keep)];
            C = cell(nnz(keep), 1);
            idx = find(keep);
            for j = 1:numel(idx)
                C{j} = double(X(a(idx(j)):b(idx(j)), :));
            end
        end

        function [C, rows] = segments(X, Fs, opts)
            %segments  A signal cut into its artifact-free stretches, split into equal pieces.
            %   [C, ROWS] = mTRFExport.segments(X, Fs, Artifacts=A) cuts X
            %   ([N x nVar] at Fs) between the periods of A ([k x 2]
            %   [tStart tEnd) s on the continuous clock: every sample a period
            %   touches is left out) into a cell column of [nTime x nVar]
            %   double, the continuous data the toolbox cross-validates over
            %   (each cell a fold). Stretches shorter than MinSeconds (2 s by
            %   default) are dropped; one longer than MaxSeconds (Inf by
            %   default) is split into the fewest equal pieces no longer than
            %   that, so MaxSeconds=60 on a clean 10-minute session gives ten
            %   1-minute folds. No piece is shorter than MinSeconds: when the
            %   equal pieces would be, fewer are cut, longer than MaxSeconds
            %   (a 5.8 s stretch with both at 2 s gives two of 2.9 s). ROWS
            %   holds each piece's [first last] samples.
            arguments
                X (:,:) {mustBeNumeric}
                Fs (1,1) double {mustBePositive}
                opts.Artifacts double = zeros(0, 2)
                opts.MinSeconds (1,1) double {mustBeNonnegative} = 2
                opts.MaxSeconds (1,1) double {mustBePositive} = Inf
            end
            N = size(X, 1);
            art = sortrows(reshape(double(opts.Artifacts), [], 2));
            % the samples the periods touch, merged
            bad = zeros(0, 2);
            for j = 1:size(art, 1)
                a = floor(art(j, 1) * Fs + 1e-6) + 1;
                b = ceil(art(j, 2) * Fs - 1e-6);
                if art(j, 2) <= art(j, 1); b = a; end
                a = max(a, 1); b = min(max(b, a), N);
                if a > N || b < 1; continue; end
                if ~isempty(bad) && a <= bad(end, 2) + 1
                    bad(end, 2) = max(bad(end, 2), b);
                else
                    bad(end+1, :) = [a b]; %#ok<AGROW>
                end
            end
            % the clean stretches between them
            clean = zeros(0, 2);
            s = 1;
            for j = 1:size(bad, 1)
                if bad(j, 1) > s; clean(end+1, :) = [s, bad(j, 1) - 1]; end %#ok<AGROW>
                s = bad(j, 2) + 1;
            end
            if s <= N; clean(end+1, :) = [s N]; end
            % drop the short ones, split the long ones
            minN = ceil(opts.MinSeconds * Fs);
            maxN = floor(opts.MaxSeconds * Fs);
            rows = zeros(0, 2);
            for j = 1:size(clean, 1)
                len = clean(j, 2) - clean(j, 1) + 1;
                if len < max(minN, 1); continue; end
                nPieces = max(1, ceil(len / max(maxN, 1)));
                if nPieces > 1 && floor(len / nPieces) < minN
                    nPieces = max(1, floor(len / max(minN, 1)));   % MinSeconds wins over MaxSeconds
                end
                edges = clean(j, 1) + round((0:nPieces) * len / nPieces);
                for p = 1:nPieces
                    a = edges(p); b = edges(p + 1) - 1;
                    if b - a + 1 < max(minN, 1); continue; end
                    rows(end+1, :) = [a b]; %#ok<AGROW>
                end
            end
            C = cell(size(rows, 1), 1);
            for j = 1:size(rows, 1)
                C{j} = double(X(rows(j, 1):rows(j, 2), :));
            end
        end

        function M = package(stim, resp, Fs, opts)
            %package  The pair of cell arrays the toolbox takes, with their labels, checked.
            %   M = mTRFExport.package(STIM, RESP, Fs) returns a struct:
            %     stim        {nTrials x 1} of [nTime x nFeatures] double
            %     resp        {nTrials x 1} of [nTime x nChannels] double
            %     fs          Hz
            %     nTrials, nFeatures, nChannels
            %     stimLabels  1 x nFeatures string (StimLabels=; "f1".. by default)
            %     respLabels  1 x nChannels string (RespLabels=; "ch1".. by default)
            %     respUnits   RespUnits= ("" by default), stimUnits (StimUnits=)
            %     pos         [nChannels x 2] probe positions, um (Positions=;
            %                 NaN when unknown)
            %     start       [nTrials x 1] s: each trial's first sample on
            %                 the continuous clock of the session (Start=; NaN
            %                 when unknown), for putting predictions back
            %     t           Time=: the sample times of a cut trial, s from
            %                 its event (trials of one length); [] otherwise
            %     trialinfo   TrialInfo=: a table or matrix, one row per trial
            %     cfg         Cfg= (dataset, name, ...) plus exporter
            %   A matrix for STIM or RESP counts as one trial. Trial j's
            %   stim and resp must have the same number of rows and every
            %   trial the same number of columns (mTRFExport:Mismatch).
            %   With the toolbox: mTRFtrain(M.stim, M.resp, M.fs, 1, tmin,
            %   tmax, lambda), mTRFcrossval(...) over the trials as folds.
            arguments
                stim
                resp
                Fs (1,1) double {mustBePositive}
                opts.StimLabels string = string.empty
                opts.RespLabels string = string.empty
                opts.StimUnits (1,1) string = ""
                opts.RespUnits (1,1) string = ""
                opts.Positions double = []
                opts.Start double = []
                opts.Time double = []
                opts.TrialInfo = []
                opts.Cfg (1,1) struct = struct()
            end
            if ~iscell(stim); stim = {stim}; end
            if ~iscell(resp); resp = {resp}; end
            stim = reshape(stim, [], 1);
            resp = reshape(resp, [], 1);
            if numel(stim) ~= numel(resp)
                error('mTRFExport:Mismatch', 'stim has %d trials, resp %d.', numel(stim), numel(resp));
            end
            nF = NaN; nC = NaN;
            for j = 1:numel(stim)
                stim{j} = double(stim{j});
                resp{j} = double(resp{j});
                if size(stim{j}, 1) ~= size(resp{j}, 1)
                    error('mTRFExport:Mismatch', 'Trial %d: stim has %d samples, resp %d.', ...
                        j, size(stim{j}, 1), size(resp{j}, 1));
                end
                if j == 1
                    nF = size(stim{j}, 2); nC = size(resp{j}, 2);
                elseif size(stim{j}, 2) ~= nF || size(resp{j}, 2) ~= nC
                    error('mTRFExport:Mismatch', 'Trial %d has %d features x %d channels; trial 1 %d x %d.', ...
                        j, size(stim{j}, 2), size(resp{j}, 2), nF, nC);
                end
            end
            if isempty(stim); nF = 0; nC = 0; end
            M = struct();
            M.stim = stim;
            M.resp = resp;
            M.fs = Fs;
            M.nTrials = numel(stim);
            M.nFeatures = nF;
            M.nChannels = nC;
            M.stimLabels = mTRFExport.labelsOf(opts.StimLabels, nF, "f");
            M.respLabels = mTRFExport.labelsOf(opts.RespLabels, nC, "ch");
            M.stimUnits = opts.StimUnits;
            M.respUnits = opts.RespUnits;
            pos = double(opts.Positions);
            if isempty(pos); pos = NaN(nC, 2); end
            if size(pos, 1) ~= nC
                error('mTRFExport:Mismatch', 'Positions has %d rows for %d channels.', size(pos, 1), nC);
            end
            M.pos = pos(:, 1:min(2, size(pos, 2)));
            st = reshape(double(opts.Start), [], 1);
            if isempty(st); st = NaN(M.nTrials, 1); end
            if numel(st) ~= M.nTrials
                error('mTRFExport:Mismatch', 'Start has %d entries for %d trials.', numel(st), M.nTrials);
            end
            M.start = st;
            M.t = reshape(double(opts.Time), [], 1);
            M.trialinfo = opts.TrialInfo;
            cfg = opts.Cfg;
            cfg.exporter = "mTRFExport.package";
            M.cfg = cfg;
        end

        function [t, s] = lagSamples(tmin, tmax, Fs)
            %lagSamples  The lags a model fits, as the toolbox computes them.
            %   [T, S] = mTRFExport.lagSamples(tmin, tmax, Fs) returns the lag
            %   times T (ms) and samples S a forward model trained with lags
            %   tmin..tmax ms at Fs holds (model.t): floor(tmin/1e3*Fs) to
            %   ceil(tmax/1e3*Fs) samples, each at s/Fs*1e3 ms.
            arguments
                tmin (1,1) double
                tmax (1,1) double
                Fs (1,1) double {mustBePositive}
            end
            s = floor(tmin / 1e3 * Fs):ceil(tmax / 1e3 * Fs);
            t = s / Fs * 1e3;
        end

        function tf = hasMTRF()
            %hasMTRF  True when the mTRF-Toolbox is on the MATLAB path.
            tf = ~isempty(which('mTRFtrain')) && ~isempty(which('mTRFcrossval'));
        end

        function requireMTRF()
            %requireMTRF  Error with an install hint when the toolbox is missing.
            if ~mTRFExport.hasMTRF()
                error('mTRFExport:NoMTRF', ...
                    ['The mTRF-Toolbox is not on the MATLAB path: addpath(genpath(''<mTRF-Toolbox>/mtrf'')) ' ...
                     '(https://github.com/mickcrosse/mTRF-Toolbox). mTRFExport itself does not need it to prepare data.']);
            end
        end
    end

    methods (Static, Access = private)
        function L = labelsOf(L, n, prefix)
            L = reshape(string(L), 1, []);
            if isempty(L)
                L = prefix + string(1:n);
            elseif numel(L) ~= n
                error('mTRFExport:Mismatch', '%d labels for %d columns.', numel(L), n);
            end
        end
    end
end
