function R = onChronuxCompute(obj)
%onChronuxCompute  Run the Chronux tab's analysis on the active dataset and draw it.
%   The settings (gatherChronuxSettings) give the time base
%   (chronuxTimeBase): the Alignment tab's event and trial selection
%   (epochTable, with this tab's fixed window, so epochs that leave the
%   recording or touch an artifact period are left out), or segments of
%   a stretch clear of the file's artifact periods. Only the rows those
%   need, of the channels picked, are read from the Chronux file
%   (loadChronuxExport, at most ChronuxMaxMB), then analyzed
%   (chronuxSpectrum, chronuxSpecgram) and drawn (drawChronux). The Cancel
%   button stops it between blocks of rows and between channels
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
if ~isfield(I.signals, S.signal)
    obj.setChronuxState("failed", Message="The Chronux file holds no " + S.signal + " signal.");
    return
end
L = I.signals.(S.signal);
name = obj.Runner.Names(k);
obj.ChronuxCancelRequested = false;
obj.ChronuxPage = 1;
S.display.page = 1;
what = S.analysis + " of " + S.signal + " on " + name;
obj.setChronuxState("computing", Message="Computing the " + what + " ...");
t0 = tic;
try
    if S.timeBase == "aligned"
        src = obj.Runner.source(k);
        D = obj.Config.Defaults;
        win = epochWindow(mode="fixed", pre=S.window(1), post=S.window(2));
        [E, G] = epochTable(src, D.EventRef, Window=win, Selection=D.Selection);
        TB = chronuxTimeBase("aligned", E=E, Groups=G, Window=S.window, UseGroups=S.useGroups, ...
            Label=eventRefLabel(D.EventRef));
    else
        seg = S.segmentSec;
        if S.analysis == "specgram"; seg = S.movingwin(1); end
        TB = chronuxTimeBase("range", Range=S.range, Artifacts=I.artifacts, Fs=L.fs, NRows=L.nSamples, Segment=seg);
    end
    obj.ChronuxControls.coverage.Text = TB.text + ".";
    check = @() obj.chronuxCheck();
    data = loadChronuxExport(obj.ChronuxFile, Signal=S.signal, Channels=S.channels, Span=TB.span, Index=I, ...
        MaxMB=obj.ChronuxMaxMB, Check=check);
    prov = struct('file', obj.ChronuxFile, 'where', obj.ChronuxFileWhere, 'created', I.created, 'export', I.export);
    switch S.analysis
        case "spectrum"
            R = chronuxSpectrum(data, TB, S, Check=check, Provenance=prov, Dataset=name);
        case "specgram"
            R = chronuxSpecgram(data, TB, S, Check=check, MaxMB=obj.ChronuxMaxMB, Provenance=prov, Dataset=name);
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
