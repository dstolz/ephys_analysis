function TB = chronuxTimeBaseOf(src, E, G, panel, opts)
%chronuxTimeBaseOf  The trials a spectral figure panel averages over: its epochs, or segments of the recording.
%   TB = chronuxTimeBaseOf(SRC, E, G, PANEL, Name=Value) is chronuxTimeBase's
%   for the panel PANEL (figureFor's spec) of the dataset SRC
%   (loadAnalysisSource):
%     options.timeBase "aligned" (a spectrogram always)   its epochs E and
%         groups G (epochTable, as figureCompute gives them): trial e covers
%         the panel's window [pre post] around E.t0Continuous(e), one result
%         per trial group (groupsFor fills G's index, label and color)
%     options.timeBase "range"   options.range cut into back-to-back
%         segments clear of SRC.artifacts, one group: on a signal's rows
%         (Fs=, NRows=) or, for spike trains, on the clock itself
%         (Duration: SRC.durationSec, else the last spike, LastSpike=)
%   Options: Segment (the segment's length, s; default options.segmentSec:
%   a coherogram passes its moving window), Fs and NRows (a signal's rate
%   and rows; NaN for spike trains), LastSpike (s; the duration when SRC
%   does not know it).
%   Errors: chronuxTimeBase:NoTrials, chronuxTimeBase:BadValue.
%
%   See also chronuxTimeBase, epochTable, computeSpectrumPanel.
arguments
    src (1,1) struct
    E
    G
    panel (1,1) struct
    opts.Segment double = []
    opts.Fs (1,1) double = NaN
    opts.NRows (1,1) double = NaN
    opts.LastSpike (1,1) double = NaN
end
o = panel.options;
if ~isfield(o, 'timeBase') || o.timeBase == "aligned"
    w = panel.window;
    if ~istable(E)
        error('chronuxTimeBase:NoTrials', 'No epoch is left to analyze.');
    end
    TB = chronuxTimeBase("aligned", E=E, Groups=groupsFor(E, G), Window=[w.pre w.post], UseGroups=true, ...
        Label=eventRefLabel(panel.ref));
    return
end
seg = opts.Segment;
if isempty(seg); seg = o.segmentSec; end
art = zeros(0, 2);
if isfield(src, 'artifacts') && ~isempty(src.artifacts); art = reshape(double(src.artifacts), [], 2); end
if isfinite(opts.Fs)
    TB = chronuxTimeBase("range", Range=o.range, Artifacts=art, Fs=opts.Fs, NRows=opts.NRows, Segment=seg);
else
    d = NaN;
    if isfield(src, 'durationSec'); d = double(src.durationSec); end
    if ~(isfinite(d) && d > 0); d = opts.LastSpike; end
    TB = chronuxTimeBase("range", Range=o.range, Artifacts=art, Duration=d, Segment=seg);
end
end
