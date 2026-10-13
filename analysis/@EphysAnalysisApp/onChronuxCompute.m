function R = onChronuxCompute(obj)
%onChronuxCompute  Run the Chronux tab's analysis on the active dataset and draw it.
%   The settings (gatherChronuxSettings) give the time base
%   (chronuxTimeBase): the Alignment tab's event and trial selection
%   (epochTable, with this tab's fixed window, so epochs that leave the
%   recording or touch an artifact period are left out), or segments of
%   a stretch clear of the file's artifact periods. Only the rows those
%   need, of the channels picked, are read from the Chronux file
%   (loadChronuxExport, at most ChronuxMaxMB), then analyzed
%   (chronuxSpectrum, chronuxSpecgram, chronuxCoherence) and drawn
%   (drawChronux). The spike
%   analyses (chronuxSpikeSpectrum, chronuxUnitCoherence) take the file's
%   spike trains (chronuxSpikeTrains: the sorted units or the detections,
%   those picked) and read no signal; the spike-field coherence
%   (chronuxSpikeField) also reads the field channel. The Cancel button
%   stops it between blocks of rows and between channels or trains
%   (chronuxCheck). R: the result ([] when it did not finish).
R = [];
if ismember(obj.ChronuxState, ["computing" "creating"]); return; end
k = obj.ActiveIdx;
I = obj.ChronuxIndex;
if isempty(obj.Runner) || k < 1 || isempty(I)
    obj.setChronuxState("idle", Message="Scan, pick a dataset and create its Chronux file first.");
    return
end
if ~ChronuxDataset.hasChronux()
    obj.setChronuxState("failed", Message="The Chronux toolbox is not on the MATLAB path: add toolboxes/chronux.");
    return
end
try
    S = obj.gatherChronuxSettings();
catch ME
    obj.setChronuxState("failed", Message=string(ME.message));
    return
end
[ok, why] = chronuxCanCompute(I, S.analysis, S.spikeSource);
if ~ok
    obj.setChronuxState("failed", Message=why);
    return
end
spikes = ismember(S.analysis, ["spikeSpectrum" "spikeField" "unitCoherence"]);
read = S.channels;   % the channels read from the file ([] = all)
switch S.analysis
    case "spikeField"
        read = S.fieldChannel;   % only the field channel
    case "coherence"   % the pair is read even when not picked
        if S.pairMode == "pair"
            read = unique([S.seed S.partner], 'stable');
        elseif ~isempty(read)
            read = union(read, S.seed);
        end
end
needSignal = ~spikes || S.analysis == "spikeField";
if needSignal && ~isfield(I.signals, S.signal)
    obj.setChronuxState("failed", Message="The Chronux file holds no " + S.signal + " signal.");
    return
end
L = [];
if needSignal; L = I.signals.(S.signal); end
name = obj.Runner.Names(k);
obj.ChronuxCancelRequested = false;
obj.ChronuxPage = 1;
S.display.page = 1;
if spikes
    what = S.analysis + " of " + S.spikeSource + " on " + name;
else
    what = S.analysis + " of " + S.signal + " on " + name;
end
obj.setChronuxState("computing", Message="Computing the " + what + " ...");
t0 = tic;
try
    SP = [];
    if spikes
        which = S.units;
        if S.analysis == "unitCoherence" && ~isempty(which)   % the pair is read even when not picked
            which = union(which, S.unitSeed);
            if S.pairMode == "pair"; which = union(which, S.unitPartner); end
        end
        SP = chronuxSpikeTrains(I, S.spikeSource, which);
    end
    if S.timeBase == "aligned"
        src = obj.Runner.source(k);
        D = obj.Config.Defaults;
        win = epochWindow(mode="fixed", pre=S.window(1), post=S.window(2));
        [E, G] = epochTable(src, D.EventRef, Window=win, Selection=D.Selection);
        TB = chronuxTimeBase("aligned", E=E, Groups=G, Window=S.window, UseGroups=S.useGroups, ...
            Label=eventRefLabel(D.EventRef));
    else
        seg = S.segmentSec;
        if S.analysis == "specgram" || (S.analysis == "coherence" && S.overTime); seg = S.movingwin(1); end
        if needSignal
            TB = chronuxTimeBase("range", Range=S.range, Artifacts=I.artifacts, Fs=L.fs, NRows=L.nSamples, Segment=seg);
        else   % spike trains alone: segments on the recording's clock
            TB = chronuxTimeBase("range", Range=S.range, Artifacts=I.artifacts, Duration=recordingSeconds(I, SP), ...
                Segment=seg);
        end
    end
    obj.ChronuxControls.coverage.Text = TB.text + ".";
    check = @() obj.chronuxCheck();
    prov = struct('file', obj.ChronuxFile, 'where', obj.ChronuxFileWhere, 'created', I.created, 'export', I.export);
    if needSignal
        data = loadChronuxExport(obj.ChronuxFile, Signal=S.signal, Channels=read, Span=TB.span, Index=I, ...
            MaxMB=obj.ChronuxMaxMB, Check=check);
    end
    switch S.analysis
        case "spectrum"
            R = chronuxSpectrum(data, TB, S, Check=check, Provenance=prov, Dataset=name);
        case "specgram"
            R = chronuxSpecgram(data, TB, S, Check=check, MaxMB=obj.ChronuxMaxMB, Provenance=prov, Dataset=name);
        case "coherence"
            R = chronuxCoherence(data, TB, S, Check=check, MaxMB=obj.ChronuxMaxMB, Provenance=prov, Dataset=name);
        case "spikeSpectrum"
            R = chronuxSpikeSpectrum(SP, TB, S, Check=check, Provenance=prov, Dataset=name);
        case "spikeField"
            R = chronuxSpikeField(data, SP, TB, S, Check=check, Provenance=prov, Dataset=name);
        case "unitCoherence"
            R = chronuxUnitCoherence(SP, TB, S, Check=check, Provenance=prov, Dataset=name);
    end
    clear data
    obj.ChronuxResult = R;
    obj.drawChronux();
catch ME
    if ~isvalid(obj) || ~isvalid(obj.Fig); return; end   % the app was closed meanwhile
    obj.ChronuxResult = [];
    R = [];
    if ME.identifier == "EphysAnalysisApp:ChronuxCanceled"
        obj.setChronuxState("canceled", Message="The " + what + " was canceled.");
        obj.log("Chronux: " + what + " canceled.");
    else
        obj.setChronuxState("failed", Message=string(ME.message));
        obj.log("Chronux: " + what + " failed: " + string(ME.message));
    end
    return
end
secs = toc(t0);
msg = sprintf("%s (%.1f s). %s.", what, secs, TB.text);
if ~isempty(R.tapers.notes); msg = msg + " " + strjoin(R.tapers.notes, "; ") + "."; end
obj.ChronuxStatusLabel.Text = msg;
obj.log("Chronux: " + msg);
end


function d = recordingSeconds(I, SP)
%recordingSeconds  The recording's length on the continuous clock: its longest signal, else the last spike.
d = 0;
for sig = string(fieldnames(I.signals)).'
    d = max(d, I.signals.(sig).durationSec);
end
if d == 0   % no continuous signal in the file
    for k = 1:numel(SP.times)
        t = SP.times(k).times;
        if ~isempty(t); d = max(d, max(t)); end
    end
end
end
