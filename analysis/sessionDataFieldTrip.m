function data = sessionDataFieldTrip(D, opts)
%sessionDataFieldTrip  FieldTrip raw structures of whole-session signals.
%   DATA = sessionDataFieldTrip(D) turns sessionData structs of a signal
%   (DatasetBrowser's B.Sessions after Load whole sessions with Data LFP,
%   MUA, SPIKE or AUX) into FieldTrip raw structures (ft_datatype_raw), a
%   cell column, one per element of D, built by FieldTripExport.continuous:
%     trial{1}    [nChan x nSamples], the whole signal, sample k at (k-1)/fs
%     elec        the channels' probe positions, um (when every one is known)
%     hdr         TimeStampPerSample = the recording rate / the signal's, so
%                 FieldTripExport.spike timestamps line up
%     cfg.event   every digital line's pulses (derived events included) at
%                 the signal's rate (FieldTripExport.event), for
%                 ft_definetrial
%     cfg.artfctdef.preprocessing.artifact   the periods the Signals step
%                 erased, [begsample endsample], for ft_rejectartifact
%     cfg.dataset, cfg.name, cfg.groups (the session's groups table)
%   Window=[pre post] (s) adds cfg.trl, the trials the Trials tab keeps
%   around Align (a column of D.trials on the digital clock, "TrialOnset" by
%   default), as [begsample endsample offset group trial] for
%   ft_redefinetrial: group is the trial's row of cfg.groups, trial its row
%   of D.trials; trials that run off the signal are left out.
%   Class="single" keeps the data single.
%
%   Errors: sessionDataFieldTrip:NoSignal, sessionDataFieldTrip:NoTrials.
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
    if isempty(d.signal)
        error('sessionDataFieldTrip:NoSignal', '%s holds no signal (data "%s").', d.name, d.data);
    end
    fs = d.signalFs;
    ch = d.channels;
    cfg = struct('dataset', d.key, 'name', d.name, 'groups', d.groups);
    x = FieldTripExport.continuous(d.signal, fs, Label=ch.label, ChanType=lower(d.data), ...
        ChanUnit=ch.units(1), Positions=[ch.x ch.y], OrigFs=d.fs, Class=opts.Class, Cfg=cfg);
    x.cfg.event = FieldTripExport.event(d.events, fs, EventFs=d.fs);
    x.cfg.artfctdef.preprocessing.artifact = FieldTripExport.artifact(d.artifacts, x);
    if ~isempty(opts.Window)
        if ~d.hasTrials || ~ismember(opts.Align, string(d.trials.Properties.VariableNames))
            error('sessionDataFieldTrip:NoTrials', '%s has no trials with a %s column.', d.name, opts.Align);
        end
        idx = find(d.kept);
        on = d.toContinuous(d.trials.(opts.Align)(idx));
        x.cfg.trl = FieldTripExport.trl(on, opts.Window, fs, Info=[d.group(idx) idx], ...
            NSamples=size(d.signal, 1));
    end
    data{k} = x;
end
end
