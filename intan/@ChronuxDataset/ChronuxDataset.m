classdef ChronuxDataset < handle
    % ChronuxDataset  Connector: this pipeline's ephys data -> Chronux inputs.
    %   A ChronuxDataset wraps one recording (an EphysDataset, a .mat written by
    %   EphysDataset.toMat, or a plain matrix) and hands out the exact data
    %   structures the Chronux toolbox expects, together with a validated
    %   `params` struct. It never runs Chronux and never alters sample values:
    %   it selects, epochs and re-packages, and reports precisely what it did.
    %
    %   A copy of Chronux (http://chronux.org) is bundled in toolboxes/chronux;
    %   put it on the MATLAB path to run the analyses. ChronuxDataset works
    %   without it (hasChronux / requireChronux tell you whether it is there).
    %
    %   What each method produces
    %   -------------------------
    %     continuous    [nSamples x nChan] double, microvolts    -> mtspectrumc,
    %                   mtspecgramc, coherencyc, CrossSpecMatc, rmlinesc, ...
    %     trials        [nTime x nTrials (x nChan)] epochs       -> the same
    %                   continuous functions with params.trialave = 1
    %     spikes        1 x nUnits struct array with field times -> mtspectrumpt,
    %                   mtspecgrampt, coherencypt, coherencycpt, psth, ...
    %     spikeTrials   1 x nTrials struct array with field times (one unit),
    %                   the createdatamatpt convention -> the same pt functions
    %     binnedSpikes  [nBins x nUnits|nTrials] counts          -> mtspectrumpb,
    %                   mtspecgrampb, coherencypb, coherencycpb, ...
    %     eventOnsets   digital-input onsets (s) to use as trial triggers
    %
    %   Construction
    %   ------------
    %     cx = ChronuxDataset(ds)                    % an EphysDataset
    %     cx = ChronuxDataset("D:\rec\subj1_day1")   % a recording folder
    %     cx = ChronuxDataset("D:\out\subj1_extract.mat")   % a toMat output
    %     cx = ChronuxDataset(X, Fs=1000)            % [nSamples x nChan] uV
    %                                                % (single/double, not int16)
    %     cx = ChronuxDataset(ds, Signal="MUA", SignalOptions=struct('MUA_Fs',2000))
    %
    %   The continuous signal is read lazily: nothing is read until a method
    %   needs it (or loadSignal is called). Signal picks which signal that is:
    %     "LFP" | "MUA" | "SPIKE"  derived with EphysDataset.deriveSignals
    %                              (SignalOptions is forwarded to it)
    %     "AUX"                    the auxiliary (accelerometer) inputs, in
    %                              VOLTS at their own rate, when recorded
    %     "RAW"                    broadband amplifier data at the recording
    %                              rate, through EphysDataset.readData
    %
    %   Typical workflow
    %   ----------------
    %     cx = ChronuxDataset("D:\rec\subj1_day1", Signal="LFP");
    %     cx.Tapers = ChronuxDataset.tapersFor(2, 1);      % +/-2 Hz over 1 s
    %
    %     [data, params] = cx.continuous(Channels=1:16, TimeRange=[0 60]);
    %     [S, f] = mtspectrumc(data, params);              % Chronux
    %
    %     onsets = cx.eventOnsets("din0");
    %     [D, params, T] = cx.trials(onsets, [-0.2 0.5], Channels=5, TrialAve=1);
    %     [S, f] = mtspectrumc(D, params);
    %
    %     [sp, params, t] = cx.spikes();                   % sorted units
    %     [S, f, R] = mtspectrumpt(sp, params, 0, t);
    %
    %   Units, time base and conventions
    %   --------------------------------
    %   - Continuous data is in microvolts, sample k is at t = (k-1)/Fs seconds,
    %     recording-relative (the first sample of the first file is t = 0). This
    %     is the convention of EphysDataset.readData's t vector.
    %   - Digital-input event times (eventOnsets) keep the convention they are
    %     produced with, t = row/Fs, one sample later than the t above. trials
    %     maps an onset back to sample round(t*Fs), so a trial triggered by a
    %     dig-in onset starts on exactly the sample that produced it.
    %   - Spike times are in seconds on the same recording-relative clock.
    %   - No method resamples, rescales, detrends (unless asked), or fills
    %     values. Trials whose window leaves the recording, or that contain
    %     non-finite samples, are dropped and reported rather than padded --
    %     see the Incomplete / NonFinite options of trials.
    %
    %   params
    %   ------
    %   Every data method also returns a Chronux params struct built from the
    %   properties below (override per call with the Tapers/Pad/Fpass/Err/
    %   TrialAve name-value options):
    %     tapers   [TW K] or [W T p]   (default [3 5]; see tapersFor)
    %     pad      FFT padding factor  (default 0)
    %     Fs       sample rate of the data being handed to Chronux, filled in by
    %              the method: the signal rate for continuous data, SpikeFs for
    %              point-process data, BinFs for binned counts
    %     fpass    [fmin fmax]         (default [0 Fs/2]; Inf means Fs/2)
    %     err      0 | [1 p] | [2 p]   (default 0)
    %     trialave 0 | 1               (default 0; use 1 to average trials)
    %
    %   See also EPHYSDATASET, ChronuxDataset.tapersFor, ChronuxDataset.makeParams,
    %   EXTRACT_TRIALS.

    properties
        % Which continuous signal this connector serves. "LFP"/"MUA"/"SPIKE"
        % are derived with EphysDataset.deriveSignals; "AUX" is the aux
        % (accelerometer) inputs in volts; "RAW" is the broadband amplifier
        % data at the recording rate (EphysDataset.readData).
        Signal (1,1) string {mustBeMember(Signal, ["LFP","MUA","SPIKE","AUX","RAW"])} = "LFP"

        % Options forwarded to EphysDataset.deriveSignals when the signal is
        % loaded (LFP_Fs, LFP_bpLoHi, MUA_bpLoHi, keepAmpChannels, labelField,
        % ...). dataTypeOut must not be set here - use the Signal property.
        % For Signal = "RAW" only keepAmpChannels and labelField apply.
        SignalOptions struct = struct()

        % Sample rate (Hz) of the time grid used for point-process data: it
        % becomes params.Fs for spikes / spikeTrials and the default bin rate
        % for binnedSpikes. It is a property of the analysis (it sets the
        % frequency grid and the prolate grid), not of the spike times.
        SpikeFs (1,1) double {mustBePositive, mustBeFinite} = 1000

        % Chronux params defaults (see makeParams).
        Tapers   (1,:) double = [3 5]
        Pad      (1,1) double {mustBeInteger} = 0
        Fpass    (1,2) double {mustBeNonnegative} = [0 Inf]   % Inf -> Fs/2
        Err      (1,:) double = 0
        TrialAve (1,1) double {mustBeMember(TrialAve, [0 1])} = 0
    end

    properties (SetAccess = protected)
        Dataset                              % EphysDataset, or [] for other sources
        SourceType (1,1) string = "none"     % "dataset" | "mat" | "struct" | "matrix" | "none"
        SourceFile (1,1) string = ""         % .mat path (SourceType "mat")
        SourceStruct struct = struct()       % toMat-shaped struct (SourceType "struct")

        Data          = []                   % [nSamples x nChan], microvolts
        Fs (1,1) double = NaN                % sample rate of Data (Hz)
        ChannelLabels (1,:) string = string.empty(1,0)
        Events        struct = struct()      % dig-in lines -> [k x 2] [t_on t_off]
        Info          struct = struct()      % provenance of the loaded signal
        Loaded (1,1) logical = false         % true once Data is populated
    end

    properties (Dependent)
        NumSamples    % rows of Data (NaN before loading)
        NumChannels   % columns of Data (NaN before loading)
        Duration      % NumSamples/Fs seconds of loaded data
    end

    methods
        % --- methods defined in separate files in this @-folder ---
        loadSignal(obj, opts)
        [data, params, info]    = continuous(obj, opts)
        [data, params, T, info] = trials(obj, onsets, twin, opts)
        [data, params, t, info] = spikes(obj, opts)
        [data, params, t, info] = spikeTrials(obj, onsets, twin, opts)
        [data, params, t, info] = binnedSpikes(obj, opts)
        [onsets, info]          = eventOnsets(obj, name, opts)

        function obj = ChronuxDataset(source, opts)
            %ChronuxDataset  Construct from a dataset, folder, .mat or matrix.
            arguments
                source = []
                opts.Fs (1,1) double = NaN          % required for a matrix source
                opts.Signal (1,1) string = "LFP"
                opts.SignalOptions struct = struct()
                opts.ChannelLabels (1,:) string = string.empty(1,0)
                opts.SpikeFs (1,1) double = 1000
                opts.Tapers (1,:) double = [3 5]
                opts.Pad (1,1) double = 0
                opts.Fpass (1,2) double = [0 Inf]
                opts.Err (1,:) double = 0
                opts.TrialAve (1,1) double = 0
                opts.Load (1,1) logical = false     % read the signal now
            end

            obj.Signal        = opts.Signal;
            obj.SignalOptions = opts.SignalOptions;
            obj.SpikeFs       = opts.SpikeFs;
            obj.Tapers        = opts.Tapers;
            obj.Pad           = opts.Pad;
            obj.Fpass         = opts.Fpass;
            obj.Err           = opts.Err;
            obj.TrialAve      = opts.TrialAve;

            if isempty(source)
                return   % empty object; assign a source later or use statics
            end

            if isa(source, 'EphysDataset')
                obj.Dataset    = source;
                obj.SourceType = "dataset";
            elseif isstruct(source)
                % A toMat-shaped struct (Y, info, optional events) already in
                % memory, e.g. load("<Name>_extract.mat") or a fresh
                % deriveSignals result packed the same way.
                if ~isscalar(source) || ~all(isfield(source, {'Y', 'info'}))
                    error('ChronuxDataset:BadSource', ...
                        'A struct source must have the toMat fields Y and info.');
                end
                obj.SourceStruct = source;
                obj.SourceType   = "struct";
            elseif isnumeric(source)
                if ~ismatrix(source)
                    error('ChronuxDataset:MatrixSource', ...
                        'A numeric source must be a [nSamples x nChan] matrix.');
                end
                if isnan(opts.Fs) || opts.Fs <= 0
                    error('ChronuxDataset:NoFs', ...
                        'Fs is required when constructing from a matrix.');
                end
                if ~isfloat(source)
                    error('ChronuxDataset:MatrixClass', ...
                        ['A numeric source must be single or double microvolts; ' ...
                         'got %s. Raw int16 ADC counts have to be scaled first ' ...
                         '(microvolts = 0.195 * double(X) for Intan).'], class(source));
                end
                obj.Data       = source;
                obj.Fs         = opts.Fs;
                obj.SourceType = "matrix";
                obj.Loaded     = true;
                obj.Info       = struct('source', "matrix", 'fs', opts.Fs, ...
                    'signal', obj.Signal, 'units', "microvolts (assumed)");
            elseif isstring(source) || ischar(source)
                src = string(source);
                if ~isscalar(src)
                    error('ChronuxDataset:BadSource', ...
                        'A text source must be one path, not %d.', numel(src));
                end
                if endsWith(src, ".mat", 'IgnoreCase', true)
                    if ~isfile(src)
                        error('ChronuxDataset:NoFile', 'No such .mat file: %s', src);
                    end
                    obj.SourceFile = src;
                    obj.SourceType = "mat";
                elseif isfolder(src)
                    obj.Dataset    = EphysDataset(src);
                    obj.SourceType = "dataset";
                else
                    error('ChronuxDataset:BadSource', ...
                        ['Source must be an EphysDataset, a recording folder, a ' ...
                         '.mat written by toMat, a toMat-shaped struct, or a numeric ' ...
                         'matrix; got "%s".'], src);
                end
            else
                error('ChronuxDataset:BadSource', ...
                    ['Source must be an EphysDataset, a recording folder, a .mat ' ...
                     'written by toMat, a toMat-shaped struct, or a numeric matrix; ' ...
                     'got %s.'], class(source));
            end

            if ~isempty(opts.ChannelLabels)
                obj.ChannelLabels = opts.ChannelLabels;
            end
            if obj.SourceType == "matrix" && ...
                    numel(obj.ChannelLabels) ~= size(obj.Data, 2)
                if ~isempty(obj.ChannelLabels)
                    warning('ChronuxDataset:LabelCount', ...
                        ['%d channel labels for %d columns; labels are replaced ' ...
                         'by ch1..chN so they cannot be mismatched.'], ...
                        numel(obj.ChannelLabels), size(obj.Data, 2));
                end
                obj.ChannelLabels = "ch" + string(1:size(obj.Data, 2));
            end
            if opts.Load
                obj.loadSignal();
            end
        end

        %% --- dependent getters ------------------------------------------
        function n = get.NumSamples(obj)
            if isempty(obj.Data); n = NaN; else; n = size(obj.Data, 1); end
        end

        function n = get.NumChannels(obj)
            if isempty(obj.Data); n = NaN; else; n = size(obj.Data, 2); end
        end

        function d = get.Duration(obj)
            if isempty(obj.Data) || isnan(obj.Fs)
                d = NaN;
            else
                d = size(obj.Data, 1) / obj.Fs;   % total recorded span
            end
        end

        %% --- params ------------------------------------------------------
        function p = params(obj, opts)
            %params  Chronux params struct from this object's settings.
            %   P = cx.params() uses the loaded signal's sample rate. Any field
            %   can be overridden: cx.params(Fs=1000, TrialAve=1, Fpass=[0 100]).
            %   Called by every data method, so the params a method returns and
            %   the data it returns always agree (in particular params.Fs).
            arguments
                obj (1,1) ChronuxDataset
                opts.Fs (1,1) double = NaN
                opts.Tapers (1,:) double = double.empty(1,0)
                opts.Pad double = []
                opts.Fpass (1,:) double = double.empty(1,0)
                opts.Err (1,:) double = double.empty(1,0)
                opts.TrialAve double = []
            end
            fs = opts.Fs;
            if isnan(fs); fs = obj.Fs; end
            if isnan(fs) || fs <= 0
                error('ChronuxDataset:NoFs', ...
                    ['Sample rate unknown; load the signal first or pass Fs ' ...
                     '(params.Fs must match the data handed to Chronux).']);
            end
            tap = opts.Tapers;   if isempty(tap), tap = obj.Tapers;   end
            pad = opts.Pad;      if isempty(pad), pad = obj.Pad;      end
            fp  = opts.Fpass;    if isempty(fp),  fp  = obj.Fpass;    end
            er  = opts.Err;      if isempty(er),  er  = obj.Err;      end
            ta  = opts.TrialAve; if isempty(ta),  ta  = obj.TrialAve; end
            p = ChronuxDataset.makeParams(fs, Tapers=tap, Pad=pad, Fpass=fp, ...
                Err=er, TrialAve=ta);
        end

        %% --- helpers used by the data methods ----------------------------
        function u = dataUnits(obj)
            %dataUnits  Units of Data: "microvolts" unless the source says otherwise (AUX: "volts").
            u = "microvolts";
            if isfield(obj.Info, 'units') && ~startsWith(string(obj.Info.units), "microvolts")
                u = string(obj.Info.units);
            end
        end

        function [idx, labels] = resolveChannels(obj, sel)
            %resolveChannels  Channel selection -> column indices + labels.
            %   SEL is [] (all channels, in the loaded order), a numeric vector
            %   of 1-based column indices (order preserved, duplicates allowed),
            %   or a string array of channel labels matched exactly against
            %   ChannelLabels.
            obj.loadSignal();
            nCh = size(obj.Data, 2);
            if isempty(sel)
                idx = 1:nCh;
            elseif isnumeric(sel)
                idx = double(sel(:)).';
                if any(idx < 1 | idx > nCh | idx ~= round(idx))
                    error('ChronuxDataset:BadChannel', ...
                        'Channels must be integers in 1..%d.', nCh);
                end
            elseif isstring(sel) || ischar(sel) || iscellstr(sel)
                want = string(sel(:)).';
                idx = zeros(1, numel(want));
                for k = 1:numel(want)
                    hit = find(obj.ChannelLabels == want(k));
                    if isempty(hit)
                        error('ChronuxDataset:UnknownChannel', ...
                            'No channel labelled "%s" in this signal.', want(k));
                    end
                    idx(k) = hit(1);
                end
            else
                error('ChronuxDataset:BadChannel', ...
                    'Channels must be [], numeric indices, or channel labels.');
            end
            if numel(obj.ChannelLabels) == nCh
                labels = obj.ChannelLabels(idx);
            else
                labels = "ch" + string(idx);
            end
        end

        function [i0, i1] = resolveSampleRange(obj, timeRange)
            %resolveSampleRange  [t0 t1] seconds -> inclusive sample rows.
            %   Rows are the samples whose time t = (row-1)/Fs lies in
            %   [t0 t1] (a 1e-9 s tolerance absorbs floating-point edges).
            obj.loadSignal();
            n = size(obj.Data, 1);
            t0 = timeRange(1);
            t1 = timeRange(2);
            if t1 <= t0
                error('ChronuxDataset:BadTimeRange', ...
                    'TimeRange must be [t0 t1] with t0 < t1; got [%g %g].', t0, t1);
            end
            if isinf(t0) && t0 < 0
                i0 = 1;
            else
                i0 = max(1, ceil(t0 * obj.Fs - 1e-9) + 1);
            end
            if isinf(t1)
                i1 = n;
            else
                i1 = min(n, floor(t1 * obj.Fs + 1e-9) + 1);
            end
            if i1 < i0
                error('ChronuxDataset:EmptyTimeRange', ...
                    'TimeRange [%g %g] s selects no samples of this %g s signal.', ...
                    t0, t1, n / obj.Fs);
            end
        end

        function s = summary(obj)
            %summary  Struct describing what this connector currently holds.
            s = struct();
            s.sourceType  = obj.SourceType;
            s.signal      = obj.Signal;
            s.loaded      = obj.Loaded;
            s.fs          = obj.Fs;
            s.nSamples    = obj.NumSamples;
            s.nChannels   = obj.NumChannels;
            s.durationSec = obj.Duration;
            s.spikeFs     = obj.SpikeFs;
            s.eventLines  = string(fieldnames(obj.Events)).';
            if obj.SourceType == "dataset" && ~isempty(obj.Dataset)
                s.name   = obj.Dataset.Name;
                s.folder = obj.Dataset.Folder;
            else
                s.name   = "";
                s.folder = obj.SourceFile;
            end
        end
    end

    methods (Static)
        function p = makeParams(Fs, opts)
            %makeParams  Build and validate a Chronux params struct.
            %   P = ChronuxDataset.makeParams(FS) returns the Chronux defaults
            %   for a signal sampled at FS: tapers [3 5], pad 0, fpass
            %   [0 FS/2], err 0, trialave 0.
            %
            %   P = ChronuxDataset.makeParams(FS, Name=Value) sets Tapers, Pad,
            %   Fpass, Err and TrialAve. The struct uses Chronux's own field
            %   names (tapers, pad, Fs, fpass, err, trialave) and nothing else,
            %   so it can be passed straight to any Chronux routine.
            %
            %   Validation (values are never silently changed):
            %     Tapers    [TW K]: K must be a positive integer; a warning is
            %               issued when K > 2*TW-1 (Chronux's stated limit).
            %               [W T p]: Chronux converts it to TW = W*T,
            %               K = floor(2*TW-p); that K must be >= 1. The
            %               3-element form is passed through unchanged.
            %     Fpass     [fmin fmax] with 0 <= fmin < fmax <= Fs/2. fmax =
            %               Inf is replaced by Fs/2 (Chronux's own default).
            %     Err       0, [0 p], [1 p] (theoretical) or [2 p] (jackknife)
            %               with 0 < p < 1.
            %     TrialAve  0 or 1.
            arguments
                Fs (1,1) double {mustBePositive, mustBeFinite}
                opts.Tapers (1,:) double = [3 5]
                opts.Pad (1,1) double {mustBeInteger} = 0
                opts.Fpass (1,:) double = [0 Inf]
                opts.Err (1,:) double = 0
                opts.TrialAve (1,1) double = 0
            end

            tap = opts.Tapers;
            switch numel(tap)
                case 2
                    TW = tap(1); K = tap(2);
                    if ~isfinite(TW) || TW <= 0
                        error('ChronuxDataset:Tapers', ...
                            'tapers(1) (the time-bandwidth product TW) must be positive.');
                    end
                    if K < 1 || K ~= round(K)
                        error('ChronuxDataset:Tapers', ...
                            'tapers(2) (the number of tapers K) must be a positive integer.');
                    end
                    if K > 2*TW - 1
                        warning('ChronuxDataset:TapersK', ...
                            ['K = %g exceeds 2*TW-1 = %g; Chronux expects K <= 2*TW-1 ' ...
                             '(the extra tapers are poorly concentrated).'], K, 2*TW - 1);
                    end
                case 3
                    W = tap(1); T = tap(2); pp = tap(3);
                    if any(~isfinite(tap)) || W <= 0 || T <= 0
                        error('ChronuxDataset:Tapers', ...
                            'tapers [W T p] needs a positive bandwidth W and duration T.');
                    end
                    K = floor(2*W*T - pp);
                    if K < 1
                        error('ChronuxDataset:Tapers', ...
                            ['tapers [%g %g %g] gives K = floor(2*W*T-p) = %d tapers; ' ...
                             'increase W or T, or lower p.'], W, T, pp, K);
                    end
                otherwise
                    error('ChronuxDataset:Tapers', ...
                        'tapers must be [TW K] or [W T p]; got %d elements.', numel(tap));
            end

            fp = opts.Fpass;
            if numel(fp) ~= 2
                error('ChronuxDataset:Fpass', 'Fpass must be [fmin fmax].');
            end
            if isinf(fp(2)); fp(2) = Fs/2; end
            if fp(1) < 0 || fp(1) >= fp(2)
                error('ChronuxDataset:Fpass', ...
                    'Fpass must be [fmin fmax] with 0 <= fmin < fmax; got [%g %g].', ...
                    fp(1), fp(2));
            end
            if fp(2) > Fs/2 + 1e-9
                error('ChronuxDataset:Fpass', ...
                    'Fpass fmax (%g Hz) is above Nyquist (%g Hz).', fp(2), Fs/2);
            end

            er = opts.Err;
            if isscalar(er)
                if ~ismember(er, [0 1 2])
                    error('ChronuxDataset:Err', 'Scalar err must be 0 (no error bars).');
                end
                if er ~= 0
                    error('ChronuxDataset:Err', ...
                        'err = %g needs a confidence level: [%g p] with 0 < p < 1.', er, er);
                end
            elseif numel(er) == 2
                if ~ismember(er(1), [0 1 2])
                    error('ChronuxDataset:Err', ...
                        'err(1) must be 0 (none), 1 (theoretical) or 2 (jackknife).');
                end
                if er(2) <= 0 || er(2) >= 1
                    error('ChronuxDataset:Err', ...
                        'err(2) must be a confidence level in (0 1); got %g.', er(2));
                end
            else
                error('ChronuxDataset:Err', 'err must be 0 or [type p].');
            end

            if ~ismember(opts.TrialAve, [0 1])
                error('ChronuxDataset:TrialAve', 'trialave must be 0 or 1.');
            end

            p = struct('tapers', tap, 'pad', opts.Pad, 'Fs', Fs, 'fpass', fp, ...
                'err', er, 'trialave', opts.TrialAve);
        end

        function [tapers, info] = tapersFor(halfBandwidthHz, durationSec, opts)
            %tapersFor  [TW K] for a wanted spectral resolution and window.
            %   TAPERS = ChronuxDataset.tapersFor(W, T) returns [TW K] with
            %   TW = W*T and K = floor(2*TW) - P (P = 1 by default), i.e. the
            %   most tapers Chronux allows for a half-bandwidth of W Hz over a
            %   T second window: the spectrum is smoothed over f +/- W Hz.
            %
            %   [TAPERS, INFO] = ... also returns TW, K, the achieved
            %   half-bandwidth TW/T (exact here, since TW is not rounded) and
            %   the inputs. Use it when setting movingwin for mtspecgramc:
            %   T must be the moving window length, not the whole recording.
            %
            %   Example: 1 s windows smoothed over +/-2 Hz
            %     cx.Tapers = ChronuxDataset.tapersFor(2, 1);   % [2 3]
            arguments
                halfBandwidthHz (1,1) double {mustBePositive, mustBeFinite}
                durationSec (1,1) double {mustBePositive, mustBeFinite}
                opts.P (1,1) double {mustBeInteger, mustBeNonnegative} = 1
            end
            TW = halfBandwidthHz * durationSec;
            K  = floor(2*TW) - opts.P;
            if K < 1
                error('ChronuxDataset:TapersFor', ...
                    ['W = %g Hz over T = %g s gives TW = %g and K = %d tapers. ' ...
                     'Use a wider bandwidth or a longer window (2*W*T must exceed %d).'], ...
                    halfBandwidthHz, durationSec, TW, K, opts.P + 1);
            end
            tapers = [TW K];
            info = struct('TW', TW, 'K', K, 'halfBandwidthHz', TW/durationSec, ...
                'durationSec', durationSec, 'p', opts.P);
        end

        function tf = hasChronux()
            %hasChronux  True when the Chronux toolbox is on the MATLAB path.
            tf = ~isempty(which('mtspectrumc')) && ~isempty(which('getparams'));
        end

        function requireChronux()
            %requireChronux  Error with an install hint when Chronux is missing.
            if ~ChronuxDataset.hasChronux()
                error('ChronuxDataset:NoChronux', ...
                    ['The Chronux toolbox is not on the MATLAB path. Add the copy ' ...
                     'in toolboxes/chronux with addpath(genpath(...)). ' ...
                     'ChronuxDataset itself does not need Chronux to prepare data.']);
            end
        end

        function X = castTo(X, want)
            %castTo  Cast data to the class Chronux should see.
            %   "double" (Chronux computes its tapers in double), "single", or
            %   "asis" to leave the stored class alone. Only the class changes;
            %   values are never rescaled.
            arguments
                X
                want (1,1) string {mustBeMember(want, ["double","single","asis"])}
            end
            switch want
                case "double", X = double(X);
                case "single", X = single(X);
            end
        end

        function S = toPointProcess(times)
            %toPointProcess  Spike times -> Chronux point-process struct array.
            %   S = ChronuxDataset.toPointProcess(TIMES) accepts a numeric
            %   vector (one channel/trial), a cell array of numeric vectors, or
            %   a struct array with a times field, and returns a 1 x N struct
            %   array whose only field is times: a sorted column vector of
            %   seconds. That is exactly what mtspectrumpt / coherencypt expect
            %   (they read the first field of the struct).
            if isstruct(times)
                fn = fieldnames(times);
                if isempty(fn)
                    error('ChronuxDataset:PointProcess', ...
                        'A struct array of spike times needs a times field.');
                end
                if ~ismember('times', fn)
                    error('ChronuxDataset:PointProcess', ...
                        'Struct array must have a "times" field; found: %s.', ...
                        strjoin(fn', ', '));
                end
                src = {times.times};
            elseif iscell(times)
                src = times(:).';
            elseif isnumeric(times)
                src = {times};
            else
                error('ChronuxDataset:PointProcess', ...
                    ['Spike times must be a numeric vector, a cell array of ' ...
                     'vectors, or a struct array with a times field; got %s.'], ...
                    class(times));
            end
            n = numel(src);
            S = struct('times', cell(1, n));
            for k = 1:n
                v = src{k};
                if isempty(v)
                    S(k).times = zeros(0, 1);
                    continue
                end
                if ~isnumeric(v) || ~isvector(v)
                    error('ChronuxDataset:PointProcess', ...
                        'Element %d of the spike times is not a numeric vector.', k);
                end
                v = double(v(:));
                if any(~isfinite(v))
                    error('ChronuxDataset:PointProcess', ...
                        'Element %d of the spike times contains non-finite values.', k);
                end
                S(k).times = sort(v);
            end
        end
    end
end
