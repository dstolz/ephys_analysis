function test_EphysTraceViewer()
%test_EphysTraceViewer  Verification suite for EphysTraceSource and EphysTraceViewer.
%   Builds a small universal-format recording (8 channels at 20 kHz, 3 s,
%   one large spike on channel 3 at 1.5 s), a Kilosort4-style .bin with
%   its JSON sidecar, a -v7.3 LFP extract (columns in reverse channel
%   order) and a -v7 MUA extract, then checks:
%     - EphysTraceSource: which sources a dataset has, and that every kind
%       reads exactly the rows asked for (recording, .bin scale, HDF5
%       windows, a loaded -v7 signal), with its channels' recording numbers
%     - EphysTraceViewer: samples drawn at (row-1)/Fs, a binned spike at its
%       bin's first sample, the samples kept in memory (a zoom in reads
%       nothing), panning inside the margin moving the limits only, the
%       voltage scale, lanes and their names, heatmap mode, shading,
%       sorted-unit and detected-spike layers as ticks, as the trace
%       recoloured and as stored waveforms on their own lanes, spikes only
%       (no trace), the read limit, the wheel, keys and drags.
%
%   Usage:  test_EphysTraceViewer
%
%   The fixtures live in a temp folder which is deleted on completion; the
%   figure is invisible.
%
%   See also EphysTraceSource, EphysTraceViewer.

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

root = fullfile(tempdir, sprintf('TraceViewer_test_%s', ...
    datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's'));

nPass = 0; nFail = 0;
    function check(cond, msg)
        if cond
            nPass = nPass + 1;
            fprintf('  PASS: %s\n', msg);
        else
            nFail = nFail + 1;
            fprintf(2, '  FAIL: %s\n', msg);
        end
    end

%% ---- fixtures -------------------------------------------------------------
Fs = 20000; nCh = 8; nS = 3 * Fs;
name = "recV_260101_120000";
folder = fullfile(root, name);
mkdir(folder);
rng(1);
raw = int16(round(20 * randn(nS, nCh)));      % microvolts (gain 1)
raw = raw + int16(100 * (1:nCh));              % a different level per channel
sp = 1.5 * Fs;                                 % 0-based sample of the spike
raw(sp + 1, 3) = 2000;
fid = fopen(fullfile(folder, 'data.bin'), 'w');
fwrite(fid, raw.', 'int16');
fclose(fid);
BinaryReader.writeDescriptor(folder, struct('data_file', "data.bin", 'dtype', "int16", ...
    'n_chan', nCh, 'fs', Fs, 'gain_to_uV', 1, 'name', name));
d = EphysDataset(folder);
d.ArtifactConfig.Reference = "none";

% The Sorting .bin: 5 counts per microvolt, as toBin writes it.
scale = 5;
fid = fopen(d.BinFile, 'w');
fwrite(fid, int16(double(raw) * scale).', 'int16');
fclose(fid);
writeJsonFile(fullfile(folder, name + ".json"), struct('n_chan_bin', nCh, 'fs', Fs, ...
    'dtype', "int16", 'n_samples', nS, 'scale', scale, 'offset', 0, ...
    'reference', struct('mode', "cmr", 'channels', 1:nCh), 'artifact_fill', "noise"));

% A -v7.3 LFP extract (1 kHz, columns = channels 8..1) and a -v7 MUA extract.
lfpFs = 1000;
lfp = single(reshape(1:(3 * lfpFs * nCh), [], nCh));
S = struct();
S.Y = struct('LFP', lfp);
S.info = struct('LFP', struct('Fs', lfpFs, 'nSamples', size(lfp, 1)), ...
    'labels', {cellstr(compose("L%d", nCh:-1:1))}, ...
    'importOptions', struct('keepAmpChannels', [], 'channelRemap', nCh:-1:1));
S.conversion = struct('tool', "test", 'dataset', name, 'sourceFolder', folder);
save(fullfile(folder, name + "_extract_LFP.mat"), '-struct', 'S', '-v7.3');
muaFs = 2000;
mua = single(-reshape(1:(3 * muaFs * nCh), [], nCh));
S.Y = struct('MUA', mua);
S.info = struct('MUA', struct('Fs', muaFs, 'nSamples', size(mua, 1)), ...
    'labels', {cellstr(compose("M%d", 1:nCh))});
save(fullfile(folder, name + "_extract_MUA.mat"), '-struct', 'S', '-v7');

fprintf('\n== 1. EphysTraceSource ==\n');
srcs = EphysTraceSource.forDataset(d);
check(isequal([srcs.Name], ["Recording" "Sorting .bin" "LFP" "MUA"]) && isequal([srcs.Kind], ["recording" "bin" "signal" "signal"]), ...
    'a dataset''s sources: the recording, the .bin, then the extract''s signals');
rec = srcs(1); bin = srcs(2); L = srcs(3); M = srcs(4);
X = rec.read(sp - 5, 10);
check(isa(X, 'single') && isequal(size(X), [10 nCh]) && isequal(X, single(raw(sp - 4:sp + 5, :))), ...
    'the recording reads rows r0 .. r0+n-1 (0-based) of every channel, in microvolts');
check(isequal(size(rec.read(nS - 3, 10)), [3 nCh]) && isempty(rec.read(nS + 5, 10)) && isequal(rec.read(-4, 2), single(raw(1:2, :))), ...
    'reads are clipped to the recording');
Xb = bin.read(sp - 5, 10);
check(bin.NumSamples == nS && bin.Fs == Fs && max(abs(Xb - X), [], 'all') < 1e-4 ...
    && contains(bin.Note, "common median reference") && contains(bin.Note, "filled"), ...
    'the .bin reads back in microvolts through its scale, and says what was done to it');
[mn1, mx1] = bin.readMinMax(100, 1003, 10, [2 5]);
[mn2, mx2] = EphysTraceSource.binMinMax(bin.read(100, 1003), 10);
check(size(mn1, 1) == 101 && max(abs(mn1 - mn2(:, [2 5])), [], 'all') < 1e-4 && max(abs(mx1 - mx2(:, [2 5])), [], 'all') < 1e-4, ...
    'a .bin''s min / max per bin, taken on its stored integers, equal those of the samples read (the short last bin too)');
Xl = L.read(1000, 5);
check(isequal(Xl, lfp(1001:1005, :)) && L.Fs == lfpFs && L.NumSamples == 3 * lfpFs ...
    && isequal(L.RecordingChannels, nCh:-1:1) && L.ChannelNames(1) == "L8", ...
    'a -v7.3 signal reads a window of rows; its columns carry their recording channels (channelRemap) and labels');
Xm = M.read(10, 3);
check(isequal(Xm, mua(11:13, :)) && M.NumChannels == nCh && isequal(M.RecordingChannels, 1:nCh), ...
    'a -v7 signal is loaded and indexed');

fprintf('\n== 2. EphysTraceViewer: traces ==\n');
fig = uifigure('Visible', 'off', 'Position', [50 50 1000 700]);
figCleanup = onCleanup(@() delete(fig));
ax = uiaxes(fig, 'Position', [60 120 900 560]);
ov = uiaxes(fig, 'Position', [60 20 900 60]);
v = EphysTraceViewer(ax, OverviewAxes=ov);
v.RenderDelay = 0;
v.RemoveOffset = false;
v.setSource(rec);
v.setVisibleLanes(8);
v.setSpacing(1000);
v.setView(1.5 - 5 / Fs, 10 / Fs);           % 10 samples: one point per sample
tr = traceLines(ax);
[x, y] = lanePoints(tr, 3);
k = find(abs(x - 1.5) < 0.1 / Fs);
check(v.LastRender.bin == 1 && ~isempty(k) && abs(y(k) - (-2 + 2000 / 1000)) < 1e-6, ...
    'zoomed in, each sample is drawn at (row-1)/Fs: the spike at 1.5 s on lane 3 (centred at -2)');
v.setView(0, 3);
b = v.LastRender.bin;
[x, y] = lanePoints(traceLines(ax), 3);
[~, iPk] = max(y);
check(b > 1 && x(iPk) <= 1.5 && x(iPk) > 1.5 - b / Fs && v.LastRender.read, ...
    'zoomed out, lanes are min / max per bin and the spike is drawn at its bin''s first sample');
v.setView(1, 0.5);
check(~v.LastRender.read && v.LastRender.bin < b, 'a zoom in draws again from the samples in memory, reading nothing');
r0 = v.LastRender;
v.setView(1.1, 0.5);
check(isequal(ax.XLim, [1.1 1.6]) && isequal(v.LastRender, r0), ...
    'a pan inside the margin moves the axes limits only (no draw)');
v.setView(2.2, 0.5);
check(v.TStart == 2.2 && ax.XLim(1) == 2.2 && ~isequal(v.LastRender, r0), 'a pan past the margin draws again');
v.setView(1.25, 0.5);
b0 = v.LastRender.bin;
v.setView(1.1875, 0.625);                   % one wheel notch out: the finer samples in memory still serve
[x, y] = lanePoints(traceLines(ax), 3);
[~, iPk] = max(y);
check(~v.LastRender.read && v.LastRender.bin == b0 && x(iPk) <= 1.5 && x(iPk) > 1.5 - b0 / Fs, ...
    'a small zoom out redraws from the finer samples in memory, each bin at its own time');
check(isequal(ax.YTickLabel(end), {'ch1'}) && numel(ax.YTick) == 8 && isequal(ax.YLim, [-7.5 0.5]), ...
    'lanes: first channel on top, their names as ticks');
v.setView(0, 3);
[~, y1] = lanePoints(traceLines(ax), 3);
v.scaleVoltage(2);
[~, y2] = lanePoints(traceLines(ax), 3);
check(v.Spacing == 500 && abs((max(y2) + 2) - 2 * (max(y1) + 2)) < 1e-6, 'scaleVoltage(2) doubles the traces about their lanes');
v.RemoveOffset = true;
v.autoScale();
check(ismember(v.Spacing / 10 ^ floor(log10(v.Spacing)), [1 2 5]) && v.Spacing < 1000, ...
    'autoScale picks a round spacing from the signal in view (offsets removed)');
v.setVisibleLanes(4);
v.scrollLanes(10);
check(v.FirstLane == 5 && isequal(ax.YLim, [-7.5 -3.5]), 'lanes scroll, no further than the last');
v.setVisibleLanes(8);
v.Mode = "heatmap";
v.render();
im = findall(ax, 'Type', 'image');
check(strcmp(im.Visible, 'on') && size(im.CData, 1) == 8 && all(strcmp(get(traceLines(ax), 'Visible'), 'off')), ...
    'heatmap mode: one image row per lane, the trace lines hidden');
v.Mode = "traces";
v.Shading = struct('intervals', {[0.1 0.2; 1.0 1.1; 2.9 3.0], [0.5 0.6]}, ...
    'color', {[0.95 0.6 0.1], [0.85 0.2 0.2]}, 'alpha', {0.15, 0.18});
v.setView(0, 1);
v.render();
p = findall(ax, 'Type', 'patch', 'Visible', 'on');
nFaces = arrayfun(@(h) size(h.XData, 2), p);
check(numel(p) == 2 && isequal(sort(nFaces(:)).', [1 2]), 'shading: one patch per set, one rectangle per period in the drawn span');

fprintf('\n== 3. spike layers ==\n');
units = struct('unitId', [7; 9], 'label', ["su007_x"; "mua009_x"], 'channel', [3; 5], ...
    'times', {{[0.5; 1.5; 2.0]; 1.2}}, 'templateWaveform', {{[0; -50; 20]; [0; -10; 5]}}, ...
    'templateTimeMs', [-0.05 0 0.05], 'templateUnits', "uV");
U = EphysTraceViewer.unitLayer(units);
check(isequal(U.t, [0.5; 1.2; 1.5; 2.0]) && isequal(double(U.g), [1; 2; 1; 1]) && isequal(U.labels, ["su007" "mua009"]), ...
    'unitLayer: every spike sorted by time with its unit; short unit labels');
v.RemoveOffset = false;
v.setSpacing(1000);
v.setLayers(U);
v.setView(0, 3);
[sx, sy] = spikePoints(ax);
t15 = abs(sx - 1.5) < 1e-9;
check(any(t15) && all(sy(t15) >= -2 + 0.15 - 1e-9 & sy(t15) <= -2 + 0.45 + 1e-9) && any(abs(sx - 1.2) < 1e-9), ...
    'ticks on the trace lane of the unit''s peak channel, in its top half');
v.setLayerStyle("Sorted units", "waveforms");
v.setView(1.49, 0.02);
[sx, sy] = spikePoints(ax);
check(v.LastRender.styles == "waveforms" && any(abs(sy - (-2 + 2)) < 1e-6) && all(sx(~isnan(sx)) >= 1.5 + U.winMs(1) / 1e3 - 1 / Fs), ...
    'waveforms: the trace is recoloured over the spike''s window (the spike''s own sample included)');
v.MaxWaveforms = 1;
v.setView(0, 3);
check(v.LastRender.styles == "ticks" && any(contains(v.LastRender.notes, "ticks shown")), ...
    'more spikes in view than MaxWaveforms: ticks, with a note');
v.MaxWaveforms = 4000;
v.setLayerStyle("Sorted units", "ticks", "raster");
v.setVisibleLanes(nCh + 2);
v.setView(0, 3);
check(v.NumLanes == nCh + 2 && any(strcmp(ax.YTickLabel, 'su007')), 'raster placement: one lane per unit after the traces, named by unit');
v.setSource(L);
v.setLayerStyle("Sorted units", "ticks", "channels");
v.setView(0, 3);
[sx, sy] = spikePoints(ax);
t15 = abs(sx - 1.5) < 1e-9;
check(any(t15) && all(sy(t15) >= -5 + 0.15 - 1e-9 & sy(t15) <= -5 + 0.45 + 1e-9), ...
    'on a signal whose columns are reordered, a unit lands on the lane of its recording channel');
det = struct('ts', {{[], [], [0.7; 1.5]}}, 'wf', {{[], [], single([0 -80 30; 0 -60 20])}}, ...
    'channels', [1 2 3], 'channelNames', ["A-0" "A-1" "A-2"], ...
    'info', struct('windowMs', [-0.05 0.05], 'waveformTimeMs', [-0.05 0 0.05]));
D = EphysTraceViewer.detectedLayer(det);
v.setSource([]);
v.Duration = 3;
v.setLayers(D);
v.setLayerStyle("Detected spikes", "waveforms", "raster");
v.setVisibleLanes(8);
v.setView(1.4999, 0.0002);
[sx, sy] = spikePoints(ax);
check(v.NumLanes == 3 && v.LastRender.styles == "waveforms" && any(abs(sx - (1.5 - 0.05e-3)) < 1e-9) ...
    && any(abs(sy - (-2 - 60 / v.Spacing)) < 1e-9), ...
    'spikes only: one lane per channel, the stored waveforms drawn at their spike times');

fprintf('\n== 4. limits and input ==\n');
v.setSource(rec);
v.setLayers([]);
v.MaxReadSamples = nCh * Fs * 1;               % one second of every channel
v.setView(0, 3);
check(abs(v.TWidth - 1) < 1e-9, 'a view wider than MaxReadSamples lets one draw read is narrowed');
v.MaxReadSamples = 2^27;
v.setView(1, 1);
v.handleScroll(-1, string.empty, 1.5);
check(abs(v.TWidth - 0.8) < 1e-9 && abs(v.TStart - 1.1) < 1e-9, 'the wheel zooms time about the pointer');
s0 = v.Spacing;
v.handleScroll(1, "control", 1.5);
check(abs(v.Spacing - s0 * 1.25) < 1e-9, 'Ctrl+wheel scales the voltage');
tf = v.handleKey("rightarrow", string.empty);
check(tf && abs(v.TStart - 1.3) < 1e-9, 'right arrow pans a quarter window');
v.handleKey("home", string.empty);
check(v.TStart == 0 && ~v.handleKey("q", string.empty), 'Home goes to the start; other keys are not taken');
fig.CurrentPoint = [500 300];
w0 = ax.InnerPosition(3);
v.beginDrag([500 300]);
v.dragTo([400 300]);
moved = v.endDrag();
check(moved && abs(v.TStart - 100 * 0.8 / w0) < 1e-9,'a drag to the left pans later in time by the pixels moved');
v.seekOverview(2);
check(abs(v.TStart + v.TWidth / 2 - 2) < 1e-9, 'the overview centres the view on a time');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
clear figCleanup cleanup
if nFail > 0
    error('test_EphysTraceViewer:Failures', '%d checks failed.', nFail);
end
end


function h = traceLines(ax)
% The viewer's trace lines (width 0.5), in creation order.
h = flipud(findall(ax, 'Type', 'line', 'LineWidth', 0.5));
end


function [x, y] = lanePoints(h, lane)
% The points of the LANE-th lane shown: the lanes of one colour are one
% line, in lane order, NaN between them.
x = []; y = [];
for i = 1:numel(h)
    if ~strcmp(h(i).Visible, 'on') || all(isnan(h(i).YData)); continue; end
    X = h(i).XData(:); Y = h(i).YData(:);
    seg = cumsum(isnan(Y)) + 1;
    in = seg == lane & ~isnan(Y);
    x = X(in); y = Y(in);
    return
end
end


function [x, y] = spikePoints(ax)
% Every vertex of the viewer's spike lines (width 1.2).
h = findall(ax, 'Type', 'line', 'LineWidth', 1.2, 'Visible', 'on');
x = []; y = [];
for i = 1:numel(h)
    x = [x; h(i).XData(:)]; y = [y; h(i).YData(:)]; %#ok<AGROW>
end
end
