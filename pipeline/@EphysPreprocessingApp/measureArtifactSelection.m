function measureArtifactSelection(obj)
%measureArtifactSelection  Score the stretch selected on the Artifacts plot with every method.
%   obj.measureArtifactSelection() fills the Artifacts tab's Selection tab
%   (right column) for ArtView.sel, the stretch dragged over the plot with
%   Measure on (onArtViewInput): EphysDataset.measureArtifacts scores it
%   with each detection method (running RMS, MAD, absolute microvolts,
%   common mode) against the window drawn, as the signal is shown (the
%   filter the viewer read it with, referenced as every step reads it),
%   the baselines taken over that whole window as detection takes them over
%   its chunk. So it tells how far a stretch stands from each method's
%   threshold before a Detect / Preview over the recording.
%
%   The method chosen on the left is held to its Threshold, the others to
%   their defaults; Min channels and the RMS window are the left's too, and
%   the dataset's ExcludeChannels take no part. Common mode is scored on
%   the signal as recorded, as its detector reads it: read again
%   unreferenced when the dataset has a common reference (kept with the
%   selection), and left out when its reader cannot read a window.
%
%   Two tables: one row per method (its peak, threshold, channels over it,
%   share of the selection flagged; shaded when it would flag), and one per
%   channel (RMS z, MAD z, peak, RMS and peak-to-peak microvolts; sortable,
%   the channels over the chosen method's threshold shaded), sorted by the
%   chosen method. Without a selection it says how to make one. Display
%   only: nothing is written. Called after a selection, and when the
%   detection controls change (onArtifactControlsChanged).
%
%   See also EphysDataset.measureArtifacts, onArtViewInput, drawArtifactView.

lab = obj.ArtSelectionLabel;
if isempty(lab) || ~isvalid(lab); return; end
mt = obj.ArtSelectionMethodTable;
ct = obj.ArtSelectionTable;
removeStyle(mt);
removeStyle(ct);
mCols = {'Method', 'Peak', 'Threshold', 'Over', 'Flags'};
cCols = {'Channel', 'RMS z', 'MAD z', 'Peak (uV)', 'RMS (uV)', 'P-P (uV)'};

S = obj.ArtView.sel;
w = obj.ArtView.win;
d = obj.currentDataset();
if isempty(S) || isempty(w) || isfield(w, 'error') || isempty(d)
    lab.Text = "Turn Measure on (beside Shade artifacts, or M over the plot) and drag over " + ...
        "the plot to score that stretch with every detection method: running RMS, MAD, " + ...
        "absolute microvolts and common mode.";
    mt.Data = cell2table(cell(0, 5), 'VariableNames', mCols);
    ct.Data = cell2table(cell(0, 6), 'VariableNames', cCols);
    obj.ArtSelectionTab.Title = "Selection";
    return
end

% --- the rows selected: half-open [t0, t1) on the window's sample clock ---------
[m, nCh] = size(w.X);
t = (w.s0 + (0:m - 1)') / w.Fs;
rows = t >= S.span(1) & t < S.span(2);
if ~any(rows)
    [~, i] = min(abs(t - mean(S.span)));
    rows(i) = true;
end

% --- the settings: the left's controls as they are now --------------------------
try
    cur = EphysDataset.normalizeArtifactConfig(EphysPipelineConfig.artifactConfig(obj.gatherArtifactsSection()));
catch
    cur = EphysDataset.normalizeArtifactConfig(d.ArtifactConfig);
end
names = ["rms", "mad", "microvolts", "commonmode"];
chosen = find(names == string(cur.Method), 1);
thr = NaN(1, 4);
if ~isempty(chosen)
    thr(chosen) = cur.Threshold;
end
ch = 1:nCh;
if nCh == d.NumChannels
    ch = setdiff(ch, d.ExcludeChannels);
end

% --- common mode on the signal as recorded ---------------------------------------
[cmX, cmNote] = unreferenced(obj, d, w, S);
M = d.measureArtifacts(w.X, rows, Fs=w.Fs, Thresholds=thr, RmsWindowMs=cur.RmsWindowMs, ...
    MinChannels=cur.MinChannels, Channels=ch, CommonModeX=cmX, CommonMode=cmNote == "");

% --- the summary ---------------------------------------------------------------
nDet = numel(ch);
excl = "";
if nDet < nCh
    excl = sprintf(" (%d excluded)", nCh - nDet);
end
lines = [
    sprintf("%.4f to %.4f s: %s, %d samples, %d channels%s.", t(find(rows, 1)), ...
        t(find(rows, 1, 'last')) + 1 / w.Fs, durationText(M.durationSec), M.nSamples, nCh, excl)
    sprintf("Against the %s window shown (%s), Min channels %d.", ...
        durationText(m / w.Fs), w.view, cur.MinChannels)];
flagged = [M.methods.flags];
if any(flagged)
    lines(end+1) = "Would flag: " + strjoin([M.methods(flagged).label], ", ") + ".";
else
    lines(end+1) = "No method would flag it at these thresholds.";
end
if cmNote ~= ""
    lines(end+1) = "Common mode: " + cmNote + ".";
end
lab.Text = strjoin(lines, newline);
obj.ArtSelectionTab.Title = "Selection" + ifelse(any(flagged), " (flagged)", "");

% --- per method --------------------------------------------------------------
mRows = cell(4, 5);
for i = 1:4
    e = M.methods(i);
    name = e.label;
    if e.method == "rms" && isfinite(e.rmsWindowMs)
        name = sprintf("%s (%.3g ms)", name, e.rmsWindowMs);
    end
    th = valueText(e.threshold, e.unit);
    if i == chosen
        th = th + " (set)";
    end
    if isnan(e.peak)
        over = "-";
        fl = "n/a";
    else
        if e.method == "commonmode"
            over = ifelse(e.channelsOver > 0, "mean", "-");
        else
            over = sprintf("%d of %d", e.channelsOver, nDet);
        end
        fl = ifelse(e.flags, sprintf("yes, %.3g%%", 100 * e.fraction), "no");
    end
    mRows(i, :) = {char(name), char(valueText(e.peak, e.unit)), char(th), char(over), char(fl)};
end
mt.Data = cell2table(mRows, 'VariableNames', mCols);
mt.ColumnWidth = {'auto', 'auto', 'auto', 'auto', 'auto'};
if any(flagged)
    addStyle(mt, uistyle("BackgroundColor", [1 0.9 0.75]), "row", find(flagged));
end
if ~isempty(chosen)
    addStyle(mt, uistyle("FontWeight", "bold"), "row", chosen);
end

% --- per channel ---------------------------------------------------------------
rmsZ = M.methods(1).channelPeak;
madZ = M.methods(2).channelPeak;
cNames = string(w.names(:));
off = setdiff(1:nCh, ch);
cNames(off) = cNames(off) + " (excluded)";
C = table(cNames, round(rmsZ(:), 2), round(madZ(:), 2), round(M.peakUV(:), 1), ...
    round(M.rmsUV(:), 1), round(M.p2pUV(:), 1), 'VariableNames', cCols);
switch string(cur.Method)
    case "rms",        key = rmsZ;
    case "mad",        key = madZ;
    case "microvolts", key = M.peakUV;
    otherwise,         key = [];
end
if ~isempty(key)
    k = key;
    k(off) = -Inf;                       % excluded channels last
    [~, order] = sort(k, 'descend', 'MissingPlacement', 'last');
    C = C(order, :);
    over = find(key(order) > thr(chosen) & ~ismember(order, off));
    if ~isempty(over)
        addStyle(ct, uistyle("BackgroundColor", [1 0.9 0.75]), "row", over(:).');
    end
end
ct.Data = C;
end


function [X, note] = unreferenced(obj, d, w, S)
% The window as recorded, for the common-mode score: [] (X itself) without a
% common reference; read again otherwise, filtered as the window was, and
% kept with the selection. NOTE says why it is left out, "" when it is not.
X = [];
note = "";
acfg = EphysDataset.normalizeArtifactConfig(d.ArtifactConfig);
if string(acfg.Reference) == "none"
    return
end
if isfield(S, 'cmX') && ~isempty(S.cmX)
    X = S.cmX;
    return
end
if ~d.supportsRandomAccess()
    note = "left out (the plot is common-referenced and this recording's reader cannot " + ...
        "read the window again as recorded)";
    return
end
m = size(w.X, 1);
f = w.acfg;
pad = 0;
if f.Filter
    pad = round(max(0.05, 10 / min(f.FilterCutoff)) * w.Fs);
end
a = max(0, w.s0 - pad);
b = w.s0 + m - 1 + pad;
if isfinite(d.NumSamples)
    b = min(b, d.NumSamples - 1);
end
try
    R = d.readWindowUV(a, b - a + 1, Reference=false);
    if f.Filter && size(R, 1) > 6 * f.FilterOrder
        R = d.filterContinuous(R, Type=f.FilterType, Cutoff=f.FilterCutoff, ...
            Order=f.FilterOrder, Fs=w.Fs);
    end
    X = R(w.s0 - a + (1:m), :);
catch ME
    X = [];
    note = "left out (" + string(ME.message) + ")";
    return
end
S.cmX = X;
obj.ArtView.sel = S;
end


function s = valueText(v, unit)
% "14.2 SD", "1834 uV", "-" for NaN.
if isnan(v)
    s = "-";
elseif v >= 100
    s = sprintf("%.0f %s", v, unit);
else
    s = sprintf("%.3g %s", v, unit);
end
end


function s = durationText(sec)
% "5.63 ms" or "1.25 s".
if sec < 1
    s = sprintf('%.3g ms', sec * 1e3);
else
    s = sprintf('%.3g s', sec);
end
end


function v = ifelse(c, a, b)
if c; v = a; else; v = b; end
end
