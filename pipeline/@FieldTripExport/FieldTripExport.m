classdef FieldTripExport
    % FieldTripExport  Build FieldTrip data structures from this pipeline's data.
    %   Pure, static packaging functions: nothing here reads a recording or
    %   calls FieldTrip. They take signals as matrices, spike times, events
    %   and erased periods - from this pipeline or not - and return structs
    %   in the shapes FieldTrip documents (ft_datatype_raw,
    %   ft_datatype_spike, ft_read_event). The DatasetBrowser feeds them its
    %   results (epochMatrixFieldTrip, sessionDataFieldTrip; the browser
    %   script S_DatasetBrowserToFieldTrip).
    %
    %   FieldTrip is never required. When it is on the path, validate() runs
    %   ft_datatype_raw / ft_datatype_spike on the structs as a check.
    %
    %   Conventions
    %   -----------
    %   - continuous: one trial spanning the whole signal; trial{1} is
    %     [nChan x N] (the transpose of this pipeline's [N x nChan]);
    %     time{1} = (k-1)/Fs; sampleinfo = [1 N]; hdr.TimeStampPerSample =
    %     OrigFs/Fs so raw and spike timestamps share the recording's sample
    %     clock.
    %   - epochs: a trial per epoch, time{k} = the epoch's times from its
    %     event; sampleinfo, when the onsets are given, places each epoch on
    %     the continuous signal it was cut from (onset t at sample
    %     round(t*Fs) + 1).
    %   - spikeTimes: timestamp{u} are 0-based samples at hdr.Fs (spike
    %     times in s, t = timestamp/Fs), FirstTimeStamp = 0,
    %     TimeStampPerSample = 1. No trial fields: cut trials in FieldTrip
    %     with ft_spike_maketrials. spikeTrials builds one from spikes
    %     already cut into trials (time, trial, trialtime, as
    %     ft_spike_maketrials leaves them).
    %   - event: one element per digital-input pulse, value = 1. Pulse times
    %     are t = row/origFs on the recording's clock, so row r is at
    %     continuous time (r-1)/origFs, and at a signal's rate Fs sample =
    %     round((t_on - 1/origFs)*Fs) + 1 (1-based): the sample that produced
    %     the onset at the recording rate, the nearest sample of a derived
    %     signal. duration = pulse length in samples at Fs (inclusive).
    %   - artifact: the periods erased before the signals were derived, as
    %     [begsample endsample] rows on a raw structure's sampleinfo (every
    %     sample a period touches), for cfg.artfctdef.<type>.artifact.
    %
    %   See also epochMatrixFieldTrip, sessionDataFieldTrip, ChronuxDataset.

    methods (Static)
        function data = continuous(X, Fs, opts)
            %continuous  FieldTrip raw structure of a continuous signal, one trial.
            %   data = FieldTripExport.continuous(X, Fs) with X [nSamples x
            %   nChan], row k at t = (k-1)/Fs (this pipeline's convention):
            %   trial{1} = X.', time{1} = (0:N-1)/Fs, sampleinfo = [1 N].
            %   Options:
            %     Label      nChan names (default ch1..chN)
            %     ChanType   hdr.chantype, "lfp" by default
            %     ChanUnit   hdr.chanunit, "uV" by default
            %     Positions  [nChan x 2|3] site positions, um: data.elec when all finite
            %     OrigFs     the recording rate, for hdr.TimeStampPerSample = OrigFs/Fs (default Fs)
            %     Class      "double" (default) or "single"
            %     Cfg        fields added to data.cfg
            arguments
                X (:,:) {mustBeNumeric}
                Fs (1,1) double {mustBePositive}
                opts.Label string = string.empty
                opts.ChanType (1,1) string = "lfp"
                opts.ChanUnit (1,1) string = "uV"
                opts.Positions double = []
                opts.OrigFs (1,1) double {mustBePositive} = Fs
                opts.Class (1,1) string {mustBeMember(opts.Class, ["double","single"])} = "double"
                opts.Cfg (1,1) struct = struct()
            end
            [N, nCh] = size(X);
            data = struct();
            data.label      = FieldTripExport.channelLabels(opts.Label, nCh);
            data.time       = {(0:N-1) / Fs};
            data.trial      = {cast(X, opts.Class).'};
            data.fsample    = Fs;
            data.sampleinfo = [1 N];
            data.hdr = FieldTripExport.header(data.label, Fs, N, 0, 1, opts.ChanType, opts.ChanUnit);
            data.hdr.FirstTimeStamp = 0;
            data.hdr.TimeStampPerSample = opts.OrigFs / Fs;
            data = FieldTripExport.withElec(data, opts.Positions);
            data.cfg = FieldTripExport.cfgWith(struct('previous', [], 'exporter', "FieldTripExport.continuous", ...
                'timeConvention', "t = (sample-1)/Fs"), opts.Cfg);
        end

        function data = epochs(X, t, opts)
            %epochs  FieldTrip raw structure of epochs, a trial per epoch.
            %   data = FieldTripExport.epochs(X, t) with X [nChan x nTime x
            %   nEpochs] and t the nTime sample times, s from each epoch's
            %   event (evenly spaced): trial{k} = X(:,:,k), time{k} = t.
            %   Options, besides Label, ChanType, ChanUnit, Positions, Class
            %   and Cfg as in continuous:
            %     Onsets     nEpochs event times, s on the continuous clock of
            %                the signal (sample k at (k-1)/Fs): gives
            %                sampleinfo, epoch k's first sample at
            %                round(Onsets(k)*Fs) + 1 + round(t(1)*Fs). Without
            %                it there is no sampleinfo (FieldTrip makes one up)
            %     TrialInfo  nEpochs rows: data.trialinfo (a matrix or a table)
            %     Fs         the rate, when t alone does not give it exactly
            arguments
                X (:,:,:) {mustBeNumeric}
                t (:,1) double
                opts.Onsets (:,1) double = []
                opts.TrialInfo = []
                opts.Fs (1,1) double = NaN
                opts.Label string = string.empty
                opts.ChanType (1,1) string = "lfp"
                opts.ChanUnit (1,1) string = "uV"
                opts.Positions double = []
                opts.Class (1,1) string {mustBeMember(opts.Class, ["double","single"])} = "double"
                opts.Cfg (1,1) struct = struct()
            end
            [nCh, nT, nE] = size(X);
            if numel(t) ~= nT
                error('FieldTripExport:BadEpochs', 'X has %d time points but t has %d.', nT, numel(t));
            end
            Fs = opts.Fs;
            if ~isfinite(Fs)
                if nT < 2
                    error('FieldTripExport:BadEpochs', 'One time point gives no rate: pass Fs.');
                end
                Fs = (nT - 1) / (t(end) - t(1));
            end
            pre = round(t(1) * Fs);   % samples from the event to an epoch's first (negative before it)
            data = struct();
            data.label   = FieldTripExport.channelLabels(opts.Label, nCh);
            data.fsample = Fs;
            data.trial   = cell(1, nE);
            for k = 1:nE
                data.trial{k} = cast(X(:, :, k), opts.Class);
            end
            data.time = repmat({t.'}, 1, nE);
            if ~isempty(opts.Onsets)
                if numel(opts.Onsets) ~= nE
                    error('FieldTripExport:BadEpochs', '%d epochs but %d onsets.', nE, numel(opts.Onsets));
                end
                beg = round(opts.Onsets * Fs) + 1 + pre;
                data.sampleinfo = [beg, beg + nT - 1];
            end
            if ~isempty(opts.TrialInfo)
                if size(opts.TrialInfo, 1) ~= nE
                    error('FieldTripExport:BadEpochs', '%d epochs but %d TrialInfo rows.', nE, size(opts.TrialInfo, 1));
                end
                data.trialinfo = opts.TrialInfo;
            end
            data.hdr = FieldTripExport.header(data.label, Fs, nT, max(0, -pre), nE, opts.ChanType, opts.ChanUnit);
            data = FieldTripExport.withElec(data, opts.Positions);
            data.cfg = FieldTripExport.cfgWith(struct('previous', [], 'exporter', "FieldTripExport.epochs", ...
                'timeConvention', "time{k} = s from epoch k's event"), opts.Cfg);
        end

        function [T, keep] = trl(onsets, window, Fs, opts)
            %trl  A FieldTrip trial definition around event times.
            %   [trl, keep] = FieldTripExport.trl(onsets, [pre post], Fs)
            %   gives [begsample endsample offset] rows for ft_redefinetrial
            %   on a continuous raw structure: the event at onsets(k) s on the
            %   signal's clock (sample round(t*Fs) + 1), the window [pre post]
            %   s from it (pre < 0 before the event). Info= adds columns (one
            %   row per onset, FieldTrip's trialinfo); NSamples= drops the
            %   trials that run off a signal of that many samples. keep marks
            %   the onsets kept (not NaN, inside the signal).
            arguments
                onsets (:,1) double
                window (1,2) double
                Fs (1,1) double {mustBePositive}
                opts.Info double = zeros(numel(onsets), 0)
                opts.NSamples (1,1) double = Inf
            end
            if window(1) > window(2)
                error('FieldTripExport:BadWindow', 'The window needs pre <= post (got [%g %g]).', window(1), window(2));
            end
            if size(opts.Info, 1) ~= numel(onsets)
                error('FieldTripExport:BadWindow', '%d onsets but %d Info rows.', numel(onsets), size(opts.Info, 1));
            end
            offset = round(window(1) * Fs);
            beg = round(onsets * Fs) + 1 + offset;
            fin = beg + round((window(2) - window(1)) * Fs);
            keep = isfinite(onsets) & beg >= 1 & fin <= opts.NSamples;
            T = [beg(keep), fin(keep), repmat(offset, nnz(keep), 1), opts.Info(keep, :)];
        end

        function spike = spikeTimes(times, Fs, opts)
            %spikeTimes  FieldTrip spike structure of spike trains given as times.
            %   spike = FieldTripExport.spikeTimes(TIMES, Fs) with TIMES a
            %   cell of spike times, s on the continuous clock (sample k at
            %   (k-1)/Fs), one per unit: timestamp{u} = round(t*Fs), 0-based
            %   samples at Fs. Cut trials with
            %   ft_spike_maketrials (cfg.trl in these timestamps,
            %   cfg.timestampspersecond = Fs).
            %   Options:
            %     Label       one name per unit (default unit1..unitN)
            %     DurationSec the recording's length: hdr.nSamples
            %     Cfg         fields added to spike.cfg
            arguments
                times cell
                Fs (1,1) double {mustBePositive}
                opts.Label string = string.empty
                opts.DurationSec (1,1) double = NaN
                opts.Cfg (1,1) struct = struct()
            end
            nU = numel(times);
            labels = FieldTripExport.unitLabels(opts.Label, nU);
            ts = cell(1, nU);
            for u = 1:nU
                ts{u} = round(double(times{u}(:)).' * Fs);
            end
            spike = struct();
            spike.label     = labels;
            spike.timestamp = ts;
            spike.timestampdimord = '{chan}_spike';
            spike.hdr = FieldTripExport.spikeHeader(labels, Fs, round(opts.DurationSec * Fs) + 1);
            spike.cfg = FieldTripExport.cfgWith(struct('previous', [], 'exporter', "FieldTripExport.spikeTimes", ...
                'timestampConvention', "0-based sample at hdr.Fs: t = timestamp/Fs"), opts.Cfg);
        end

        function spike = spikeTrials(times, trial, window, opts)
            %spikeTrials  FieldTrip spike structure of spikes already cut into trials.
            %   spike = FieldTripExport.spikeTrials(TIMES, TRIAL, [pre post])
            %   with TIMES{u} each unit's spike times, s from its trial's
            %   event, and TRIAL{u} each spike's trial (1..nTrials): the
            %   shape ft_spike_maketrials gives, time{u}, trial{u} and
            %   trialtime = [pre post] for every trial.
            %   Options:
            %     NTrials    the number of trials (default: Onsets', else the
            %                largest trial a spike is in)
            %     Onsets     nTrials event times, s on the continuous clock:
            %                with Fs, timestamp{u} = round((onset + t)*Fs),
            %                the spikes' 0-based samples at Fs, as spike()
            %     Fs         the recording rate, for the timestamps and hdr
            %     TrialInfo  nTrials rows: spike.trialinfo
            %     Label, Cfg as in spikeTimes
            %   FieldTrip requires timestamp: without Onsets and Fs it is
            %   round(t*1e6), microseconds from each trial's event (hdr.Fs =
            %   1e6), which places no spike on the recording.
            arguments
                times cell
                trial cell
                window (1,2) double
                opts.NTrials double = []
                opts.Onsets (:,1) double = []
                opts.Fs (1,1) double = NaN
                opts.TrialInfo = []
                opts.Label string = string.empty
                opts.Cfg (1,1) struct = struct()
            end
            nU = numel(times);
            if numel(trial) ~= nU
                error('FieldTripExport:BadSpikeTrials', '%d units of times but %d of trial.', nU, numel(trial));
            end
            if window(1) > window(2)
                error('FieldTripExport:BadWindow', 'The window needs pre <= post (got [%g %g]).', window(1), window(2));
            end
            nT = opts.NTrials;
            if isempty(nT); nT = numel(opts.Onsets); end
            if nT == 0; nT = max([0, cellfun(@(x) max([0; x(:)]), trial)]); end
            if ~isempty(opts.Onsets) && numel(opts.Onsets) ~= nT
                error('FieldTripExport:BadSpikeTrials', '%d trials but %d onsets.', nT, numel(opts.Onsets));
            end
            stamped = ~isempty(opts.Onsets) && isfinite(opts.Fs);
            Fs = 1e6; if stamped; Fs = opts.Fs; end
            labels = FieldTripExport.unitLabels(opts.Label, nU);
            spike = struct();
            spike.label = labels;
            spike.time = cell(1, nU);
            spike.trial = cell(1, nU);
            spike.timestamp = cell(1, nU);
            for u = 1:nU
                t = double(times{u}(:)).';
                k = double(trial{u}(:)).';
                if numel(k) ~= numel(t)
                    error('FieldTripExport:BadSpikeTrials', 'Unit %d: %d times but %d trials.', u, numel(t), numel(k));
                end
                if any(k < 1 | k > nT | k ~= round(k))
                    error('FieldTripExport:BadSpikeTrials', 'Unit %d has spikes outside trials 1..%d.', u, nT);
                end
                spike.time{u} = t;
                spike.trial{u} = k;
                if stamped
                    spike.timestamp{u} = round((opts.Onsets(k).' + t) * Fs);
                else
                    spike.timestamp{u} = round(t * Fs);
                end
            end
            spike.timestampdimord = '{chan}_spike';
            spike.trialtime = repmat(window, nT, 1);
            if ~isempty(opts.TrialInfo)
                if size(opts.TrialInfo, 1) ~= nT
                    error('FieldTripExport:BadSpikeTrials', '%d trials but %d TrialInfo rows.', nT, size(opts.TrialInfo, 1));
                end
                spike.trialinfo = opts.TrialInfo;
            end
            spike.hdr = FieldTripExport.spikeHeader(labels, Fs, NaN);
            convention = "0-based sample at hdr.Fs: t = timestamp/Fs";
            if ~stamped; convention = "microseconds from each trial's event"; end
            spike.cfg = FieldTripExport.cfgWith(struct('previous', [], 'exporter', "FieldTripExport.spikeTrials", ...
                'timeConvention', "time{u} = s from the trial's event", 'timestampConvention', convention), opts.Cfg);
        end

        function ev = event(events, Fs, opts)
            %event  FieldTrip event struct array from dig-in [t_on t_off] intervals.
            %   ev = FieldTripExport.event(events, Fs, EventFs=origFs): one
            %   element per pulse at a signal's rate Fs, type = line name,
            %   value = 1, offset = 0, sample = round((t_on - 1/EventFs)*Fs) + 1
            %   (1-based), duration = round((t_off - t_on)*Fs) + 1 (samples,
            %   inclusive). The times count rows of the EventFs clock (t =
            %   row/EventFs, the recording rate), so sample is the row that
            %   produced the onset when Fs = EventFs (the default) and the
            %   nearest sample of a signal derived at another rate.
            arguments
                events struct
                Fs (1,1) double {mustBePositive}
                opts.EventFs (1,1) double {mustBePositive} = Fs
            end
            ev = struct('type', {}, 'sample', {}, 'value', {}, 'offset', {}, 'duration', {});
            if isempty(events); return; end
            fn = fieldnames(events);
            for k = 1:numel(fn)
                iv = events.(fn{k});
                if isempty(iv); continue; end
                iv = double(iv);
                if isvector(iv) && numel(iv) == 2; iv = iv(:).'; end
                for r = 1:size(iv, 1)
                    s = round((iv(r, 1) - 1 / opts.EventFs) * Fs) + 1;
                    d = round((iv(r, 2) - iv(r, 1)) * Fs) + 1;
                    ev(end+1) = struct('type', fn{k}, 'sample', s, 'value', 1, ...
                        'offset', 0, 'duration', d); %#ok<AGROW>
                end
            end
            if ~isempty(ev)
                [~, ix] = sort([ev.sample]);
                ev = ev(ix);
            end
        end

        function art = artifact(intervals, data)
            %artifact  FieldTrip artifact matrix of [k x 2] second periods.
            %   art = FieldTripExport.artifact(IV, DATA) gives the periods IV
            %   ([tStart tEnd) seconds on the continuous clock, as the
            %   extract's info.artifacts.intervals) as [begsample endsample]
            %   rows of the raw structure DATA, on its sampleinfo: every
            %   sample of the signal a period touches (EphysDataset.intervalRows),
            %   so a period shorter than one sample of a derived signal still
            %   marks one. It is the matrix ft_rejectartifact reads from
            %   cfg.artfctdef.<type>.artifact; [] with no periods.
            arguments
                intervals (:,2) double
                data (1,1) struct
            end
            rows = EphysDataset.intervalRows(intervals, data.fsample, size(data.trial{1}, 2));
            art = rows + data.sampleinfo(1) - 1;
            if isempty(art); art = []; end
        end

        function tf = hasFieldTrip()
            %hasFieldTrip  True when FieldTrip's datatype checkers are on the path.
            tf = exist('ft_datatype_raw', 'file') == 2 && exist('ft_datatype_spike', 'file') == 2;
        end

        function [ok, msg] = validate(s, kind)
            %validate  Run FieldTrip's own datatype check when FieldTrip is present.
            %   [ok, msg] = FieldTripExport.validate(data, "raw" | "spike").
            %   Without FieldTrip on the path ok is true and msg says so.
            arguments
                s (1,1) struct
                kind (1,1) string {mustBeMember(kind, ["raw","spike"])}
            end
            ok = true; msg = "";
            if ~FieldTripExport.hasFieldTrip()
                msg = "FieldTrip is not on the path; structure not validated.";
                return
            end
            try
                if kind == "raw"
                    ft_datatype_raw(s);
                else
                    ft_datatype_spike(s);
                end
            catch ME
                ok = false;
                msg = string(ME.message);
            end
        end
    end

    methods (Static, Access = private)
        function label = channelLabels(label, nCh)
            %channelLabels  nChan x 1 cellstr of the names given, else ch1..chN.
            if isempty(label)
                label = "ch" + string(1:nCh);
            elseif numel(label) ~= nCh
                error('FieldTripExport:BadLabels', '%d labels for %d channels.', numel(label), nCh);
            end
            label = cellstr(label(:));
        end

        function label = unitLabels(label, nU)
            %unitLabels  1 x nU cellstr of the names given, else unit1..unitN (spike.label).
            if isempty(label)
                label = "unit" + string(1:nU);
            elseif numel(label) ~= nU
                error('FieldTripExport:BadLabels', '%d labels for %d units.', numel(label), nU);
            end
            label = cellstr(label(:).');
        end

        function hdr = spikeHeader(label, Fs, nSamples)
            %spikeHeader  The hdr of a spike structure: timestamps are 0-based samples at Fs.
            nU = numel(label);
            hdr = struct('Fs', Fs, 'FirstTimeStamp', 0, 'TimeStampPerSample', 1, ...
                'nSamples', nSamples, 'nSamplesPre', 0, 'nTrials', 1, ...
                'label', {label(:)}, 'chantype', {repmat({'spike'}, nU, 1)}, ...
                'chanunit', {repmat({'unknown'}, nU, 1)});
        end

        function hdr = header(label, Fs, nSamples, nSamplesPre, nTrials, chanType, chanUnit)
            %header  The hdr fields FieldTrip reads, every channel of one type and unit.
            nCh = numel(label);
            hdr = struct('Fs', Fs, 'nChans', nCh, 'nSamples', nSamples, 'nSamplesPre', nSamplesPre, ...
                'nTrials', nTrials, 'label', {label}, ...
                'chantype', {repmat({char(chanType)}, nCh, 1)}, ...
                'chanunit', {repmat({char(chanUnit)}, nCh, 1)});
        end

        function data = withElec(data, pos)
            %withElec  data.elec from [nChan x 2|3] um positions, when all are finite.
            %   2-D positions (the probe's plane) are centered on the probe
            %   (x and y minus their midrange) and get z = rho/tan(rho/R),
            %   rho = hypot(x, y), R = 100*max(rho): the points FieldTrip's
            %   default polar projection (ft_prepare_layout, so ft_multiplotER
            %   without cfg.layout) puts at exactly (x, y)/R, around the
            %   center it scales the layout about. At z = 0 every site
            %   projected onto one circle. z stays within max(rho)/300 of R,
            %   so distances between sites barely change.
            if isempty(pos) || ~all(isfinite(pos), 'all'); return; end
            if size(pos, 1) ~= numel(data.label) || ~ismember(size(pos, 2), [2 3])
                error('FieldTripExport:BadPositions', 'Positions must be [%d x 2] or [%d x 3].', ...
                    numel(data.label), numel(data.label));
            end
            if size(pos, 2) == 2
                pos = pos - (min(pos, [], 1) + max(pos, [], 1)) / 2;
                rho = hypot(pos(:, 1), pos(:, 2));
                R = 100 * max([rho; 1]);
                z = rho ./ tan(rho / R);
                z(rho == 0) = R;
                pos(:, 3) = z;
            end
            data.elec = struct('label', {data.label}, 'elecpos', pos, 'chanpos', pos, 'unit', 'um');
        end

        function cfg = cfgWith(cfg, extra)
            %cfgWith  cfg with the fields of extra set over it.
            for f = string(fieldnames(extra)).'
                cfg.(f) = extra.(f);
            end
        end
    end
end
