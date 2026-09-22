function showArtifactView(obj)
%showArtifactView  Read the signal around one detected artifact and draw it.
%   Takes artifact ArtViewSpinner.Value of ArtView.intervals (the detected
%   artifacts of the last Detect / Preview of the active dataset) and reads
%   the recording from Context before its start to Context after its end
%   (ArtViewContextField; 0 = twice its length, 25 ms to 5 s), as the
%   detector saw it: filtered when the preview filtered before detecting,
%   broadband otherwise. The window, the detected artifacts inside it and
%   the chosen artifact's own span go to ArtView.win, and drawArtifactView
%   draws them with the manual periods. Display only: nothing is written.
%
%   Readers with random access read just the window. The others read the
%   chunk holding the artifact (one *.rhd file) and keep it in ArtView.chunk,
%   so stepping through the artifacts of one file reads it once; the window
%   is then clipped to that chunk, as detection was.
%
%   See also drawArtifactView, onDetectArtifacts, EphysDataset.analyzeArtifacts,
%   EphysDataset.manualArtifactMask.

obj.ArtView.win = [];
iv = obj.ArtView.intervals;
n = size(iv, 1);
d = obj.currentDataset();
if isempty(d) || n == 0
    obj.drawArtifactView();
    return
end

k = min(max(round(obj.ArtViewSpinner.Value), 1), n);
Fs = d.Fs;
on = iv(k, 1);
off = iv(k, 2);
ctxMs = obj.ArtViewContextField.Value;
if ctxMs <= 0
    ctxMs = min(max(25, 2e3 * (off - on)), 5000);
end
acfg = obj.ArtView.settings;          % what the preview detected with

% Window in 0-based recording samples (the manualArtifactMask convention:
% sample g is at g / Fs), plus a margin that absorbs the filter's edges.
a = max(0, floor((on - ctxMs / 1e3) * Fs));
b = ceil((off + ctxMs / 1e3) * Fs);
pad = 0;
if acfg.Filter
    pad = round(max(0.05, 10 / min(acfg.FilterCutoff)) * Fs);
end

try
    % Anchor: the artifact's first sample, so it picks the chunk it is in.
    [X, s0] = readSpan(obj, d, max(0, a - pad), b + pad, round(on * Fs));
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
    obj.setStatus("Could not read artifact " + k + ": " + string(ME.message));
    return
end

m = size(X, 1);
detected = iv(iv(:, 2) >= s0 / Fs & iv(:, 1) <= (s0 + m - 1) / Fs, :);

names = string(d.ChannelNames);
if numel(names) ~= size(X, 2)
    names = compose("ch%d", 1:size(X, 2));
end

w = struct();
w.k = k;
w.n = n;
w.X = X;                  % [m x nChan] microvolts, as detected
w.s0 = s0;                % 0-based recording sample of row 1
w.Fs = Fs;
w.on = on;
w.off = off;
w.names = reshape(names, 1, []);
w.detected = detected;    % detected artifacts in the window (recording s)
w.maskDetected = d.manualArtifactMask(m, s0, Fs, detected);
w.maskFocus = d.manualArtifactMask(m, s0, Fs, iv(k, :));
w.view = viewNote(acfg);
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
