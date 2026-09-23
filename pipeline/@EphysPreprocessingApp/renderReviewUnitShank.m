function renderReviewUnitShank(obj)
%renderReviewUnitShank  Draw the selected unit's spikes on the shank it was detected on.
%   Every sorted channel on the unit's shank (the peak channel's, as the
%   Shank column gives it) is drawn at its site on the probe
%   (channel_positions.npy; without it, in a column in channel order),
%   labelled with its name or recording channel:
%     - the unit's spikes as thin lines (Spikes; at most the number beside
%       it, picked at random, the same ones each time),
%     - their mean with an error band (Mean +/-; SD, SEM or none).
%   The peak channel is drawn in red. The spikes are cut from the sorted
%   .bin by EphysDataset.readPhyWaveforms, prepared as Kilosort4 saw them
%   (referenced and high-passed, not whitened), in the templates' units; a
%   scale bar gives the amplitude and time. The last unit's spikes are kept
%   (ReviewSpikeWaves), so changing what is drawn does not read them again.
%   When they cannot be read (the .bin is gone), the unit's template is
%   drawn instead, the subtitle says so and the status bar says why. With no
%   unit selected the axes asks for one.
%
%   See also EphysPreprocessingApp.renderReviewPlots, EphysDataset.readPhyWaveforms.

ax = obj.ReviewUnitShankAxes;
cla(ax, 'reset');
R = obj.ReviewData;
u = obj.ReviewSelectedUnit;
if isempty(R) || u < 1 || u > numel(R.clusterID)
    showMessage(ax, "Unit on its shank", "Pick a unit in the table to see its spikes on its shank.");
    return
end
pk = R.peakChan(u);
if ~(isfinite(pk) && pk >= 1 && pk <= numel(R.chanShanks)) || isempty(R.wfFull)
    showMessage(ax, R.unitLabel(u), "No template, so no peak channel or shank.");
    return
end
chans = find(R.chanShanks == R.chanShanks(pk));
[pos, placed] = sitePositions(R.chanPos, chans);

% --- the unit's spikes: read once per unit and count -------------------------------
n = obj.ReviewShankCountSpinner.Value;
key = struct('folder', string(R.folder), 'unit', R.clusterID(u), 'n', n);
C = obj.ReviewSpikeWaves;
if isempty(C) || ~isequal(C.key, key)
    C = struct('key', key, 'W', [], 'info', [], 'err', "", 'errId', "");
    pointer = obj.Fig.Pointer;
    obj.Fig.Pointer = 'watch';
    drawnow;
    try
        [C.W, C.info] = EphysDataset.readPhyWaveforms(R.folder, R.units.samples{u}, ...
            Channels=chans, MaxSpikes=n);
    catch ME
        C.err = string(ME.message);
        C.errId = string(ME.identifier);
    end
    obj.Fig.Pointer = pointer;
    obj.ReviewSpikeWaves = C;
end

K = size(C.W, 3);
useSpikes = C.err == "" && K > 0;
if useSpikes
    W = C.W;
    tms = C.info.timeMs;
    units = C.info.units;
else
    W = R.wfFull(:, chans, u);             % the template in its place
    tms = R.tms;
    units = R.units.templateUnits;
    why = "no spike could be read";
    hint = "";
    if C.errId == "EphysDataset:readPhyWaveforms:NoDataFile"
        why = "the sorted .bin is not there";
        hint = "Connect the disk that holds it, or run the Sorting step again.";
    end
    detail = C.err;
    if detail == ""; detail = "Every spike's window leaves the sorted .bin."; end
    obj.setStatus(R.unitLabel(u) + ": its template is shown. " + detail, hint);
end
M = mean(W, 3);
switch obj.ReviewShankBandDropDown.Value
    case 'SD';  B = std(W, 0, 3);
    case 'SEM'; B = std(W, 0, 3) / sqrt(K);
    otherwise;  B = [];
end
if ~useSpikes; B = []; end

% --- layout: each waveform in a box at its site ------------------------------------
[dx, dy] = sitePitch(pos);
ref = max(max(M, [], 1) - min(M, [], 1));
if ~(ref > 0); ref = 1; end
gain = 1.5 * dy / ref;                     % the biggest mean spans 1.5 site rows
span = max(tms) - min(tms);
if ~(span > 0); span = 1; end
xw = ((tms(:) - min(tms)) / span - 0.5) * 0.85 * dx;
isPk = chans == pk;
cSpk = [0.30 0.45 0.75 0.20; 0.80 0.25 0.25 0.25];     % RGBA: other channels, peak
cMean = [0.10 0.15 0.40; 0.80 0.10 0.10];
cBand = [0.25 0.40 0.80; 0.85 0.25 0.25];

hold(ax, 'on');
for c = 1:numel(chans)
    x0 = pos(c, 1); y0 = pos(c, 2); j = 1 + isPk(c);
    if useSpikes && obj.ReviewShankSpikesCheckBox.Value
        V = reshape(W(:, c, :), [], K) * gain + y0;
        line(ax, repmat([xw + x0; NaN], K, 1), reshape([V; nan(1, K)], [], 1), ...
            'Color', cSpk(j, :), 'LineWidth', 0.5, 'HitTest', 'off');
    end
    if obj.ReviewShankMeanCheckBox.Value || ~useSpikes
        if ~isempty(B)
            fill(ax, [xw; flipud(xw)] + x0, [M(:, c) + B(:, c); flipud(M(:, c) - B(:, c))] * gain + y0, ...
                cBand(j, :), 'FaceAlpha', 0.30, 'EdgeColor', 'none', 'HitTest', 'off');
        end
        line(ax, xw + x0, M(:, c) * gain + y0, 'Color', cMean(j, :), 'LineWidth', 1 + 0.5 * isPk(c));
    end
    text(ax, x0 - 0.47 * dx, y0, R.chanLabels(chans(c)), 'FontSize', 8, ...
        'Color', [0.45 0.45 0.45], 'HorizontalAlignment', 'right', 'Interpreter', 'none');
end
scaleBar(ax, pos, dx, dy, gain, ref, span, units);
hold(ax, 'off');

xlim(ax, [min(pos(:, 1)) - 0.75 * dx, max(pos(:, 1)) + 0.6 * dx]);
ylim(ax, [min(pos(:, 2)) - 3 * dy, max(pos(:, 2)) + 1.6 * dy]);
xlabel(ax, "x (" + char(181) + "m)");
ylabel(ax, "y (" + char(181) + "m)");
if placed
    xlabel(ax, "");
    ylabel(ax, "Channel order (no site positions)");
    ax.XTick = []; ax.YTick = [];
end
title(ax, sprintf("%s on shank %g", R.unitLabel(u), R.chanShanks(pk)), 'Interpreter', 'none');
if useSpikes
    sub = sprintf("%s of %s spikes", thousands(K), thousands(R.nSpikes(u)));
    if obj.ReviewShankMeanCheckBox.Value
        band = string(obj.ReviewShankBandDropDown.Value);
        if band == "none"; sub = sub + ", mean"; else; sub = sub + ", mean " + char(177) + " " + band; end
    end
else
    sub = "Template: " + why;
end
subtitle(ax, sub, 'Interpreter', 'none');
end


%% ---------------------------------------------------------------------------
function showMessage(ax, ttl, msg)
%showMessage  An empty axes with a title and a line of text in the middle.
title(ax, ttl, 'Interpreter', 'none');
text(ax, 0.5, 0.5, msg, 'Units', 'normalized', 'HorizontalAlignment', 'center', ...
    'Color', [0.4 0.4 0.4], 'FontSize', 11);
ax.XTick = []; ax.YTick = [];
end


function [pos, placed] = sitePositions(chanPos, chans)
%sitePositions  Site x / y (um) of CHANS; a column in channel order (PLACED) without positions.
placed = ~(size(chanPos, 2) >= 2 && size(chanPos, 1) >= max(chans));
if placed
    n = numel(chans);
    pos = [zeros(n, 1), (n:-1:1).' * 20];
else
    pos = double(chanPos(chans, 1:2));
end
end


function [dx, dy] = sitePitch(pos)
%sitePitch  Horizontal and vertical site spacing on the shank (um).
%   DY is the closest spacing of two sites in one column, else between any
%   two rows; DX that between columns, else DY (a single column).
dy = Inf;
xs = unique(round(pos(:, 1), 3));
for x = xs.'
    y = unique(round(pos(abs(pos(:, 1) - x) < 1e-3, 2), 3));
    if numel(y) > 1; dy = min(dy, min(diff(y))); end
end
if ~isfinite(dy)
    y = unique(round(pos(:, 2), 3));
    dy = 20;
    if numel(y) > 1; dy = min(diff(y)); end
end
dx = dy;
if numel(xs) > 1; dx = min(diff(xs)); end
end


function scaleBar(ax, pos, dx, dy, gain, ref, span, units)
%scaleBar  An L-shaped amplitude / time bar below the lowest site.
aBar = niceValue(ref / 2);
tBar = niceValue(span / 2);
x0 = min(pos(:, 1)) - 0.425 * dx;
y0 = min(pos(:, 2)) - 2.2 * dy;
w = tBar / span * 0.85 * dx;
h = aBar * gain;
line(ax, [x0 + w, x0, x0], [y0, y0, y0 + h], 'Color', 'k', 'LineWidth', 1.5, 'HitTest', 'off');
text(ax, x0 + w / 2, y0, sprintf("%g ms", tBar), 'VerticalAlignment', 'top', ...
    'HorizontalAlignment', 'center', 'FontSize', 8);
text(ax, x0 + 0.03 * dx, y0 + h / 2, sprintf("%g %s", aBar, unitText(units)), ...
    'HorizontalAlignment', 'left', 'FontSize', 8, 'Interpreter', 'tex');
end


function v = niceValue(x)
%niceValue  The largest 1, 2 or 5 x 10^k at most X.
if ~(x > 0); v = 1; return; end
p = 10 ^ floor(log10(x));
steps = [1 2 5 10] * p;
v = steps(find(steps <= x, 1, 'last'));
end


function s = unitText(units)
%unitText  The amplitude unit for the scale bar (EphysDataset.readPhyWaveforms units).
switch units
    case "uV";       s = "\muV";
    case "bin";      s = ".bin units";
    case "whitened"; s = "whitened";
    otherwise;       s = "a.u.";
end
end


function s = thousands(n)
s = regexprep(sprintf('%d', round(n)), '\d(?=(\d{3})+$)', '$0,');
end
