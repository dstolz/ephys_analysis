classdef FieldTripExport
    % FieldTripExport  Build FieldTrip data structures from this pipeline's data.
    %   Pure, static packaging functions: nothing here reads a recording or
    %   calls FieldTrip. They take the neutral inputs the pipeline already
    %   produces - the extract struct written by EphysDataset.toMat (Y, events,
    %   info), the units struct from EphysDataset.readSortedUnits, and the
    %   detected struct from EphysDataset.spikesToMat - and return structs in
    %   the shapes FieldTrip documents (ft_datatype_raw, ft_datatype_spike,
    %   ft_read_event). EphysDataset.exportFieldTrip writes them to a .mat.
    %
    %   FieldTrip is never required. When it is on the path, validate() runs
    %   ft_datatype_raw / ft_datatype_spike on the structs as a check.
    %
    %   Conventions
    %   -----------
    %   - raw: one trial spanning the whole signal; trial{1} is [nChan x N]
    %     (the transpose of this pipeline's [N x nChan]); time{1} = (k-1)/Fs;
    %     sampleinfo = [1 N]; hdr.TimeStampPerSample = origFs/Fs so raw and
    %     spike timestamps share the recording's sample clock.
    %   - spike: timestamp{u} are 0-based recording samples (Kilosort's
    %     spike_times), hdr.Fs the sorter's rate, FirstTimeStamp = 0,
    %     TimeStampPerSample = 1. No trial fields: cut trials in FieldTrip
    %     with ft_spike_maketrials.
    %   - event: one element per digital-input pulse, sample = round(t_on*Fs)
    %     (1-based, the sample that produced the onset with t = row/Fs),
    %     duration = pulse length in samples (inclusive), value = 1.
    %
    %   See also EphysDataset.exportFieldTrip, EphysDataset.exportChronux.

    methods (Static)
        function data = raw(S, sig, opts)
            %raw  FieldTrip raw structure for one signal of a toMat extract.
            %   data = FieldTripExport.raw(S, "LFP") with S = load("x_extract.mat").
            arguments
                S (1,1) struct
                sig (1,1) string {mustBeMember(sig, ["LFP","MUA","SPIKE","AUX"])}
                opts.Class (1,1) string {mustBeMember(opts.Class, ["double","single"])} = "double"
            end
            if ~isfield(S, 'Y') || ~isfield(S.Y, sig) || isempty(S.Y.(sig))
                error('FieldTripExport:SignalMissing', 'The extract holds no %s signal.', sig);
            end
            if ~isfield(S, 'info') || ~isfield(S.info, sig) || ~isfield(S.info.(sig), 'Fs')
                error('FieldTripExport:SignalMissing', 'No info.%s.Fs in the extract.', sig);
            end
            X  = S.Y.(sig);
            Fs = double(S.info.(sig).Fs);
            [N, nCh] = size(X);
            labels = FieldTripExport.labelsFor(S, nCh, sig);
            [unit, unitName] = FieldTripExport.unitsFor(S, sig);
            origFs = Fs;
            if isfield(S.info, 'origFs') && isfinite(double(S.info.origFs)); origFs = double(S.info.origFs); end

            data = struct();
            data.label      = cellstr(labels(:));
            data.time       = {(0:N-1) / Fs};
            data.trial      = {cast(X, opts.Class).'};
            data.fsample    = Fs;
            data.sampleinfo = [1 N];
            data.hdr = struct('Fs', Fs, 'nChans', nCh, 'nSamples', N, 'nSamplesPre', 0, ...
                'nTrials', 1, 'label', {cellstr(labels(:))}, ...
                'chantype', {repmat({char(lower(sig))}, nCh, 1)}, ...
                'chanunit', {repmat({unit}, nCh, 1)}, ...
                'FirstTimeStamp', 0, 'TimeStampPerSample', origFs / Fs, ...
                'orig', struct('signal', sig, 'origFs', origFs, 'info', S.info.(sig)));
            data.cfg = struct('previous', [], 'exporter', "FieldTripExport.raw", ...
                'signal', sig, 'units', unitName, 'timeConvention', "t = (sample-1)/Fs");
        end

        function spike = spike(units)
            %spike  FieldTrip spike structure from a readSortedUnits struct.
            arguments
                units (1,1) struct
            end
            nU = numel(units.unitId);
            ts = cell(1, nU);
            for u = 1:nU
                ts{u} = double(units.samples{u}(:)).';
            end
            labels = cellstr(string(units.label(:)).');
            nSamp = NaN;
            if isfield(units, 'durationSec') && isfinite(units.durationSec)
                nSamp = round(units.durationSec * units.fs) + 1;
            end
            orig = units;
            for f = ["samples" "times" "templateFull"]
                if isfield(orig, f); orig = rmfield(orig, f); end
            end
            spike = struct();
            spike.label     = labels;
            spike.timestamp = ts;
            spike.hdr = struct('Fs', units.fs, 'FirstTimeStamp', 0, 'TimeStampPerSample', 1, ...
                'nSamples', nSamp, 'nSamplesPre', 0, 'nTrials', 1, ...
                'label', {labels(:)}, 'chantype', {repmat({'spike'}, nU, 1)}, ...
                'chanunit', {repmat({'unknown'}, nU, 1)}, 'orig', orig);
            spike.cfg = struct('previous', [], 'exporter', "FieldTripExport.spike", ...
                'timestampConvention', "0-based recording sample (Kilosort spike_times)");
        end

        function spike = spikeFromDetected(detected)
            %spikeFromDetected  FieldTrip spike structure from spikesToMat's detected struct.
            %   One "unit" per channel; timestamps are 0-based samples at the
            %   recording rate (t = (index-1)/Fs -> sample index-1).
            arguments
                detected (1,1) struct
            end
            fs = detected.info.fs;
            nCh = numel(detected.ts);
            ts = cell(1, nCh);
            for c = 1:nCh
                ts{c} = round(double(detected.ts{c}(:)).' * fs);
            end
            labels = cellstr(string(detected.channelNames(:)).');
            nSamp = NaN;
            if isfield(detected.info, 'nSamples'); nSamp = double(detected.info.nSamples); end
            spike = struct();
            spike.label     = labels;
            spike.timestamp = ts;
            spike.hdr = struct('Fs', fs, 'FirstTimeStamp', 0, 'TimeStampPerSample', 1, ...
                'nSamples', nSamp, 'nSamplesPre', 0, 'nTrials', 1, ...
                'label', {labels(:)}, 'chantype', {repmat({'spike'}, nCh, 1)}, ...
                'chanunit', {repmat({'unknown'}, nCh, 1)}, ...
                'orig', struct('source', "EphysDataset.detectSpikes", ...
                    'channels', detected.channels, 'detection', detected.detection));
            spike.cfg = struct('previous', [], 'exporter', "FieldTripExport.spikeFromDetected");
        end

        function ev = event(events, Fs)
            %event  FieldTrip event struct array from dig-in [t_on t_off] intervals.
            %   ev = FieldTripExport.event(events, Fs): one element per pulse,
            %   type = line name, sample = round(t_on*Fs) (1-based), value = 1,
            %   offset = 0, duration = pulse length in samples (inclusive).
            arguments
                events struct
                Fs (1,1) double {mustBePositive}
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
                    s = round(iv(r, 1) * Fs);
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
        function [unit, name] = unitsFor(S, sig)
            %unitsFor  FieldTrip chanunit and a units name: uV unless info says volts.
            unit = 'uV'; name = "uV";
            if isfield(S.info.(sig), 'units') && string(S.info.(sig).units) == "volts"
                unit = 'V'; name = "V";
            end
        end

        function labels = labelsFor(S, nCh, sig)
            %labelsFor  The signal's own labels (AUX), else info.labels, else ch1..N.
            labels = string.empty(1, 0);
            if isfield(S.info.(sig), 'labels')
                labels = string(S.info.(sig).labels(:)).';
            elseif isfield(S.info, 'labels')
                labels = string(S.info.labels(:)).';
            end
            if numel(labels) ~= nCh
                labels = "ch" + string(1:nCh);
            end
        end
    end
end
