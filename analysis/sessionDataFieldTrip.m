function data = sessionDataFieldTrip(D, opts)
%sessionDataFieldTrip  FieldTrip structures of whole sessions: raw for a signal, spike for spikes.
%   DATA = sessionDataFieldTrip(D) turns sessionData structs (DatasetBrowser's
%   B.Sessions after Load whole sessions) into FieldTrip structures, a cell
%   column, one per element of D.
%
%   A signal (data LFP, MUA, SPIKE or AUX) gives a raw structure
%   (ft_datatype_raw), built by FieldTripExport.continuous:
%     trial{1}    [nChan x nSamples], the whole signal, sample k at (k-1)/fs
%     elec        the channels' probe positions, um (when every one is known)
%     hdr         TimeStampPerSample = the recording rate / the signal's, so
%                 the spike structures' timestamps line up
%     cfg.event   every digital line's pulses (derived events included) at
%                 the signal's rate (FieldTripExport.event), for
%                 ft_definetrial
%     cfg.artfctdef.preprocessing.artifact   the periods the Signals step
%                 erased, [begsample endsample], for ft_rejectartifact
%
%   Spikes (data units or detected) give a spike structure
%   (ft_datatype_spike), built by FieldTripExport.spikeTimes:
%     timestamp{u} unit u's spikes, 0-based samples at the recording rate
%                 (hdr.Fs = D.fs), label = D.units.label
%     cfg.event   the pulses at the recording rate (sample = timestamp + 1)
%     cfg.artifact the erased periods, [tStart tEnd] s
%
%   Both carry cfg.dataset, cfg.name and cfg.groups (the session's groups
%   table). Window=[pre post] (s) adds cfg.trl, the trials the Trials tab
%   keeps around Align (a column of D.trials on the digital clock,
%   "TrialOnset" by default), as [beg end offset group trial]: group is the
%   trial's row of cfg.groups, trial its row of D.trials; trials that run off
%   the recording are left out. For a signal, beg and end are samples, for
%   ft_redefinetrial; for spikes, timestamps, for ft_spike_maketrials with
%   cfg.timestampspersecond = hdr.Fs.
%   Class="single" keeps a signal's data single.
%
%   Errors: sessionDataFieldTrip:NoData, sessionDataFieldTrip:NoTrials.
%
%   See also FieldTripExport, epochMatrixFieldTrip, sessionData.

arguments
    D struct
    opts.Window double = []
    opts.Align (1,1) string = "TrialOnset"
    opts.Class (1,1) string {mustBeMember(opts.Class, ["double","single"])} = "double"
end
data = cell(numel(D), 1);
for k = 1:numel(D)
    d = D(k);
    isSpikes = ismember(d.data, ["units" "detected"]);
    if isSpikes && isempty(d.units) || ~isSpikes && isempty(d.signal)
        error('sessionDataFieldTrip:NoData', '%s holds no spikes or signal (data "%s").', d.name, d.data);
    end
    cfg = struct('dataset', d.key, 'name', d.name, 'groups', d.groups);
    if isSpikes
        fs = d.fs;
        nSamples = round(d.durationSec * fs) + 1;
        x = FieldTripExport.spikeTimes(d.spikes, fs, Label=string(d.units.label), ...
            DurationSec=d.durationSec, Cfg=cfg);
        x.cfg.event = FieldTripExport.event(d.events, fs);
        x.cfg.artifact = d.artifacts;
    else
        fs = d.signalFs;
        nSamples = size(d.signal, 1);
        ch = d.channels;
        x = FieldTripExport.continuous(d.signal, fs, Label=ch.label, ChanType=lower(d.data), ...
            ChanUnit=ch.units(1), Positions=[ch.x ch.y], OrigFs=d.fs, Class=opts.Class, Cfg=cfg);
        x.cfg.event = FieldTripExport.event(d.events, fs, EventFs=d.fs);
        x.cfg.artfctdef.preprocessing.artifact = FieldTripExport.artifact(d.artifacts, x);
    end
    if ~isempty(opts.Window)
        if ~d.hasTrials || ~ismember(opts.Align, string(d.trials.Properties.VariableNames))
            error('sessionDataFieldTrip:NoTrials', '%s has no trials with a %s column.', d.name, opts.Align);
        end
        idx = find(d.kept);
        on = d.toContinuous(d.trials.(opts.Align)(idx));
        if isnan(nSamples); nSamples = Inf; end
        x.cfg.trl = FieldTripExport.trl(on, opts.Window, fs, Info=[d.group(idx) idx], NSamples=nSamples);
        if isSpikes
            x.cfg.trl(:, 1:2) = x.cfg.trl(:, 1:2) - 1;   % 1-based samples -> 0-based timestamps
        end
    end
    data{k} = x;
end
end
