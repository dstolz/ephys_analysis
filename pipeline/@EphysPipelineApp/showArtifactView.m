function showArtifactView(obj, span)
%showArtifactView  Read the signal around one detected artifact, or a stretch of the recording, and draw it.
%   obj.showArtifactView("artifact") takes artifact ArtViewSpinner.Value of
%   ArtView.intervals (the detected artifacts of the last Detect / Preview
%   of the active dataset) and reads the recording from Context before its
%   start to Context after its end (ArtViewContextField; 0 = twice its
%   length, 25 ms to 5 s), as the detector saw it: filtered when the
%   preview filtered before detecting, broadband otherwise. Its start and
%   end are the detector's and, when they were moved by hand
%   (EphysDataset.adjustArtifacts), the moved ones too.
%
%   obj.showArtifactView([T0 T1]) reads the recording from T0 to T1 s
%   instead (Go to, a page on from a stretch, the Visualize tab's Mark
%   artifacts here), kept inside the recording and to at most 10 s, with
%   no artifact chosen (ArtView.free holds it), so manual periods can be
%   marked anywhere. It is filtered as the last preview detected, else as
%   the dataset's detection settings say. obj.showArtifactView() reads
%   again what is shown (the stretch, else the artifact).
%
%   The window and the chosen artifact's detected span (none for a stretch)
%   go to ArtView.win, and drawArtifactView draws them with the detected
%   artifacts and the manual periods. Display only: nothing is written.
%
%   Readers with random access read just the window. The others read the
%   chunk holding the artifact (one *.rhd file) and keep it in ArtView.chunk,
%   so stepping through the artifacts of one file reads it once; the window
%   is then clipped to that chunk, as detection was.
%
%   See also drawArtifactView, onDetectArtifacts, EphysDataset.analyzeArtifacts,
%   EphysDataset.manualArtifactMask.

if nargin < 2
    span = obj.ArtView.free;          % what is shown
elseif isequal(span, "artifact")
    span = [];
end
obj.ArtView.win = [];
obj.ArtView.free = [];
iv = obj.ArtView.intervals;
n = size(iv, 1);
d = obj.currentDataset();
if isempty(d) || (n == 0 && isempty(span))
    obj.drawArtifactView();
    return
end

if isempty(span)
    k = min(max(round(obj.ArtViewSpinner.Value), 1), n);
    Fs = d.Fs;
    on = iv(k, 1);                        % as detected
    off = iv(k, 2);
    bounds = d.adjustArtifacts(iv(k, :)); % as a run uses it
    ctxMs = obj.ArtViewContextField.Value;
    if ctxMs <= 0
        ctxMs = min(max(25, 2e3 * diff(bounds)), 5000);
    end
    acfg = obj.ArtView.settings;          % what the preview detected with

    % Window in 0-based recording samples (the manualArtifactMask convention:
    % sample g is at g / Fs).
    a = max(0, floor((min(on, bounds(1)) - ctxMs / 1e3) * Fs));
    b = ceil((max(off, bounds(2)) + ctxMs / 1e3) * Fs);
    anchor = round(on * Fs);              % the artifact's first sample picks the chunk
else
    k = 0;                                % no artifact chosen
    try
        if d.NumFiles == 0; d.discoverFiles(); end
        if d.NumFiles > 0 && (isnan(d.Fs) || isempty(d.PerFile)); d.refreshMetadata(); end
    catch ME
        obj.ArtView.win = struct('error', string(ME.message));
        obj.drawArtifactView();
        return
    end
    Fs = d.Fs;
    if ~isfinite(Fs)
        obj.ArtView.win = struct('error', "the recording of " + d.Name + " cannot be read");
        obj.drawArtifactView();
        return
    end
    dur = Inf;
    if isfinite(d.NumSamples); dur = d.NumSamples / Fs; end
    wid = min(max(span(2) - span(1), 20 / Fs), min(10, dur));
    t0 = min(max(span(1), 0), max(0, dur - wid));
    if ~isfinite(t0); t0 = 0; end         % the end of a recording of unknown length
    span = [t0, t0 + wid];
    on = span(1);
    off = span(2);
    if obj.ArtView.previewed
        acfg = obj.ArtView.settings;
    else
        acfg = EphysDataset.normalizeArtifactConfig(d.ArtifactConfig);
    end
    a = floor(span(1) * Fs);
    b = ceil(span(2) * Fs);
    anchor = a;
end

% A margin that absorbs the filter's edges.
pad = 0;
if acfg.Filter
    pad = round(max(0.05, 10 / min(acfg.FilterCutoff)) * Fs);
end

try
    [X, s0] = readSpan(obj, d, max(0, a - pad), b + pad, anchor);
    if acfg.Filter && size(X, 1) > 6 * acfg.FilterOrder
        X = d.filterContinuous(X, Type=acfg.FilterType, Cutoff=acfg.FilterCutoff, ...
            Order=acfg.FilterOrder, Fs=Fs);
    end
    g = s0 + (0:size(X, 1) - 1)';      % recording sample of each row
    keep = g >= a & g <= b;             % drop the filter margin
    first = find(keep, 1);
    if isempty(first)
        error('EphysPreprocessingApp:ArtifactView:Empty', 'No samples around the artifact.');
    end
    X = X(keep, :);
    s0 = s0 + first - 1;
catch ME
    obj.ArtView.win = struct('error', string(ME.message));
    obj.drawArtifactView();
    if k > 0
        obj.setStatus("Could not read artifact " + k + ": " + string(ME.message));
    else
        obj.setStatus("Could not read the recording: " + string(ME.message));
    end
    return
end

m = size(X, 1);
names = string(d.ChannelNames);
if numel(names) ~= size(X, 2)
    names = compose("ch%d", 1:size(X, 2));
end

w = struct();
w.k = k;                  % 0: a stretch of the recording, no artifact chosen
w.n = n;
w.X = X;                  % [m x nChan] microvolts, as detected
w.s0 = s0;                % 0-based recording sample of row 1
w.Fs = Fs;
w.on = on;                % the artifact as detected (recording s); the stretch asked for
w.off = off;
w.names = reshape(names, 1, []);
% The detected samples pick the channels drawn, so moving a bound keeps
% them; a stretch picks them over all of it.
if k > 0
    w.maskFocus = d.manualArtifactMask(m, s0, Fs, iv(k, :));
else
    w.maskFocus = true(m, 1);
    obj.ArtView.free = [s0, s0 + m - 1] / Fs;   % as read (a chunk may clip it)
end
w.view = viewNote(acfg);
w.acfg = acfg;            % the settings it was read with (measureArtifactSelection)
obj.ArtView.win = w;
obj.drawArtifactView();
end


function [X, s0] = readSpan(obj, d, a, b, anchor)
%readSpan  Recording samples a..b (0-based, inclusive) in microvolts.
%   Clipped to the recording with random access, and otherwise to the chunk
%   holding sample ANCHOR, which is read once and kept in ArtView.chunk.
%   S0 is the recording sample of X's first row.
if d.supportsRandomAccess()
    if isfinite(d.NumSamples)
        b = min(b, d.NumSamples - 1);
    end
    X = d.readWindowUV(a, max(0, b - a + 1));
    s0 = a;
    return
end

c = obj.ArtView.chunk;
if isempty(c) || c.folder ~= string(d.Folder) || anchor < c.offset ...
        || anchor >= c.offset + size(c.X, 1)
    plan = d.streamPlan();
    ns = [plan.nSamples];
    ns(~isfinite(ns)) = 0;
    starts = [0, cumsum(ns)];
    i = find(anchor >= starts(1:end-1) & anchor < starts(2:end), 1);
    if isempty(i)
        error('EphysPreprocessingApp:ArtifactView:OutOfRange', ...
            'Sample %d is past the end of %s.', anchor, d.Name);
    end
    obj.ArtView.chunk = [];            % let the previous chunk go before reading
    dlg = uiprogressdlg(obj.Fig, "Title", "Artifacts", "Indeterminate", "on", ...
        "Message", "Reading " + plan(i).name + "...");
    closer = onCleanup(@() delete(dlg));
    c = struct('folder', string(d.Folder), 'offset', starts(i), ...
        'X', single(d.readChunkUV(plan(i))));
    obj.ArtView.chunk = c;
    clear closer
end
a = max(a, c.offset);
b = min(b, c.offset + size(c.X, 1) - 1);
X = double(c.X(a - c.offset + 1 : b - c.offset + 1, :));
s0 = a;
end


function s = viewNote(acfg)
%viewNote  The signal shown, in words.
if ~acfg.Filter
    s = "broadband, as detected";
    return
end
cut = strjoin(compose("%g", acfg.FilterCutoff), "-");
switch string(acfg.FilterType)
    case "highpass", s = "high-passed at " + cut + " Hz, as detected";
    case "lowpass",  s = "low-passed at " + cut + " Hz, as detected";
    otherwise,       s = "band-passed " + cut + " Hz, as detected";
end
end
