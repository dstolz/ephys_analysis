function renderReviewPlots(obj)
%renderReviewPlots  Draw the Review-tab axes from cached ReviewData.
%   Units-per-shank and firing-rate plots always show every unit; the
%   amplitude plot shows all units when nothing is selected, or focuses on
%   obj.ReviewSelectedUnit (a row index into ReviewData) when a table row is
%   picked; the inter-spike interval histogram and autocorrelogram show the
%   selected unit only. These five read only the cache, so they are cheap to
%   call on every selection; the sixth, the selected unit's spikes on its
%   shank (renderReviewUnitShank), reads that unit's spikes once. The first
%   three can carry the unit's waveform as a box at a compass point, scaled
%   (the controls above them; drawWaveInsets).

if isempty(obj.ReviewData); return; end
R = obj.ReviewData;
sel = obj.ReviewSelectedUnit;

% Per-shank color for the firing-rate bars.
nSh = max(R.nShank, 1);
shankColors = lines(nSh);
[~, shankIdx] = ismember(R.shank, R.shankIDs);
shankIdx(shankIdx < 1) = 1;

plotUnitsPerShank(obj.ReviewShankAxes, R);
plotISI(obj.ReviewISIAxes, R, sel);
plotACG(obj.ReviewACGAxes, R, sel);
plotAmplitudes(obj.ReviewAmpAxes, R, sel);
plotFiringRates(obj.ReviewRateAxes, R, sel, shankColors, shankIdx);
obj.renderReviewUnitShank();
drawWaveInsets(obj, R, sel);      % after the shank plot, which reads the spikes it shares
end


%% ---------------------------------------------------------------------------
function drawWaveInsets(obj, R, sel)
%drawWaveInsets  The unit's waveform on its peak channel, as a box on the timing plots.
%   Mode, compass point and scale come from the controls above them. The
%   spikes are the cache the shank plot reads (reviewSpikeWaves); without
%   them (the .bin is gone) the unit's template is drawn instead.
mode = obj.ReviewWaveModeDropDown.Value;
if mode == "off" || sel < 1 || sel > numel(R.clusterID); return; end
pk = R.peakChan(sel);
if ~(isfinite(pk) && pk >= 1 && pk <= numel(R.chanShanks)) || isempty(R.wfFull); return; end
chans = find(R.chanShanks == R.chanShanks(pk));
C = obj.ReviewSpikeWaves;
key = struct('folder', string(R.folder), 'unit', R.clusterID(sel), 'n', obj.ReviewShankCountSpinner.Value);
if isempty(C) || ~isequal(C.key, key)
    C = obj.reviewSpikeWaves(chans);
end
j = find(chans == pk, 1);
if C.err == "" && size(C.W, 3) > 0
    W = reshape(C.W(:, j, :), size(C.W, 1), []);       % samples x spikes
    tms = C.info.timeMs(:);
    units = C.info.units;
    caption = R.chanLabels(pk);
else
    W = R.wfFull(:, pk, sel);
    tms = R.tms(:);
    units = R.units.templateUnits;
    caption = R.chanLabels(pk) + " template";
    mode = "mean";                                      % there are no spikes to sample
end
for ax = [obj.ReviewISIAxes, obj.ReviewACGAxes, obj.ReviewAmpAxes]
    drawWaveInset(ax, W, tms, mode, obj.ReviewWaveLocDropDown.Value, ...
        obj.ReviewWaveScaleSpinner.Value, caption, units);
end
end


function drawWaveInset(ax, W, tms, mode, loc, scale, caption, units)
%drawWaveInset  Box of mean (red) and / or spikes (blue) of W at compass point LOC of AX.
%   W is [samples x spikes]; the box is a third of the axes' span each way
%   times SCALE, set in data units from the limits the plot has now (held,
%   so drawing it moves nothing), over a pale ground.
xl = xlim(ax); yl = ylim(ax);
xlim(ax, xl); ylim(ax, yl);
sx = diff(xl); sy = diff(yl);
f = min(scale / 3, 0.9);
w = f * sx; h = f * sy;
pad = 0.03;
anchor = struct('N', [0.5 1], 'NE', [1 1], 'E', [1 0.5], 'SE', [1 0], 'S', [0.5 0], ...
    'SW', [0 0], 'W', [0 0.5], 'NW', [0 1], 'C', [0.5 0.5]).(loc);
x0 = xl(1) + pad * sx + anchor(1) * (sx - 2 * pad * sx - w);
y0 = yl(1) + pad * sy + anchor(2) * (sy - 2 * pad * sy - h);

M = mean(W, 2);
showMean = mode == "mean" || mode == "both";
showSpikes = (mode == "sample" || mode == "both") && size(W, 2) > 1;
V = M;
if showSpikes; V = [M, W]; end
lo = min(V(:)); hi = max(V(:));
if ~(hi > lo); lo = lo - 1; hi = hi + 1; end
span = max(tms) - min(tms);
if ~(span > 0); span = 1; end
xw = x0 + 0.05 * w + ((tms - min(tms)) / span) * 0.9 * w;
yOf = @(v) y0 + 0.05 * h + (v - lo) / (hi - lo) * 0.70 * h;     % the top fifth is the caption

hold(ax, 'on');
patch(ax, x0 + [0 w w 0], y0 + [0 0 h h], [1 1 1], 'FaceAlpha', 0.85, ...
    'EdgeColor', [0.6 0.6 0.6], 'HitTest', 'off');
if showSpikes
    K = size(W, 2);
    line(ax, repmat([xw; NaN], K, 1), reshape([yOf(W); nan(1, K)], [], 1), ...
        'Color', [0.30 0.45 0.75 0.25], 'LineWidth', 0.5, 'HitTest', 'off');
end
if showMean
    line(ax, xw, yOf(M), 'Color', [0.80 0.10 0.10], 'LineWidth', 1.5, 'HitTest', 'off');
end
hold(ax, 'off');
text(ax, x0 + 0.05 * w, y0 + 0.97 * h, sprintf("%s, %.3g %s p-p", caption, max(M) - min(M), unitText(units)), ...
    'FontSize', 7, 'Color', [0.3 0.3 0.3], 'VerticalAlignment', 'top', ...
    'Interpreter', 'none', 'HitTest', 'off', 'Clipping', 'on');
end


function s = unitText(units)
%unitText  The amplitude unit for a caption (EphysDataset.readPhyWaveforms units).
switch units
    case "uV";       s = char(181) + "V";
    case "bin";      s = ".bin units";
    case "whitened"; s = "whitened";
    otherwise;       s = "a.u.";
end
end


%% ---------------------------------------------------------------------------
function plotUnitsPerShank(ax, R)
%plotUnitsPerShank  Stacked good/mua/other counts per shank.
cla(ax, 'reset');
ax.FontSize = 9;
nSh = R.nShank;
counts = zeros(nSh, 3);   % [good mua other]
for s = 1:nSh
    m = R.shank == R.shankIDs(s);
    counts(s, 1) = sum(m & R.group == "good");
    counts(s, 2) = sum(m & R.group == "mua");
    counts(s, 3) = sum(m) - counts(s, 1) - counts(s, 2);
end
b = bar(ax, 1:nSh, counts, 'stacked');
b(1).FaceColor = [0.20 0.60 0.25];   % good
b(2).FaceColor = [0.55 0.55 0.60];   % mua
b(3).FaceColor = [0.80 0.45 0.20];   % other
ax.XTick = 1:nSh;
ax.XTickLabel = string(R.shankIDs);
xlabel(ax, "Shank");
ylabel(ax, "# units");
title(ax, sprintf("Units per shank (%d total)", numel(R.clusterID)));
legend(ax, {'good', 'mua', 'other'}, 'Location', 'eastoutside', 'Box', 'off');
grid(ax, 'on');
end


function plotISI(ax, R, sel)
%plotISI  The selected unit's inter-spike intervals up to 50 ms, those
%   inside the refractory period (REFRACTORYMS) in red.
cla(ax, 'reset');
t = unitSpikeTimes(R, sel);
if numel(t) < 2
    showMessage(ax, "Inter-spike intervals", unitPrompt(R, sel));
    return
end
isi = diff(t) * 1000;                                    % ms
edges = 0:0.5:50;
n = histcounts(isi, edges);
b = bar(ax, edges(1:end-1) + 0.25, n, 1, 'FaceColor', 'flat', 'EdgeColor', 'none');
inRefractory = edges(2:end).' <= refractoryMs();
b.CData = [0 0.35 0.75] .* ~inRefractory + [0.85 0.1 0.1] .* inRefractory;
xlim(ax, edges([1 end]));
xlabel(ax, "Inter-spike interval (ms)");
ylabel(ax, "# intervals");
title(ax, sprintf("%s ISI", R.unitLabel(sel)), 'Interpreter', 'none');
subtitle(ax, sprintf("%.2f%% of %s intervals < %g ms", ...
    100 * mean(isi < refractoryMs()), thousands(numel(isi)), refractoryMs()));
grid(ax, 'on');
end


function plotACG(ax, R, sel)
%plotACG  The selected unit's autocorrelogram over +/-50 ms, as the rate
%   (Hz) of its other spikes at each lag from one of its spikes; the dashed
%   line is its mean firing rate, the level of no correlation.
cla(ax, 'reset');
t = unitSpikeTimes(R, sel);
if numel(t) < 2
    showMessage(ax, "Autocorrelogram", unitPrompt(R, sel));
    return
end
maxLag = 0.05;                                           % s
binSec = 0.0005;
lags = cell(0, 1);
for k = 1:numel(t) - 1       % k-th next spike; lags only grow with k (sorted times)
    d = t(1 + k:end) - t(1:end - k);
    d = d(d <= maxLag);
    if isempty(d); break; end
    lags{end + 1, 1} = d; %#ok<AGROW>
end
lags = vertcat(lags{:}, zeros(0, 1));
edges = -maxLag:binSec:maxLag;
n = histcounts([-lags; lags], edges) / (numel(t) * binSec);
bar(ax, (edges(1:end-1) + binSec / 2) * 1000, n, 1, 'FaceColor', [0 0.35 0.75], 'EdgeColor', 'none');
hold(ax, 'on');
r = refractoryMs();
yl = [0 max([n(:); R.firingRate(sel); 1]) * 1.05];
patch(ax, [-r r r -r], yl([1 1 2 2]), [0.85 0.1 0.1], 'FaceAlpha', 0.12, 'EdgeColor', 'none');
if isfinite(R.firingRate(sel))
    yline(ax, R.firingRate(sel), '--', 'Color', [0.3 0.3 0.3]);
end
hold(ax, 'off');
xlim(ax, [-maxLag maxLag] * 1000);
ylim(ax, yl);
xlabel(ax, "Lag (ms)");
ylabel(ax, "Rate (Hz)");
title(ax, sprintf("%s autocorrelogram", R.unitLabel(sel)), 'Interpreter', 'none');
grid(ax, 'on');
end


function t = unitSpikeTimes(R, sel)
%unitSpikeTimes  The selected unit's spike times (s), sorted; empty with no unit selected.
t = zeros(0, 1);
if sel >= 1 && sel <= numel(R.clusterID)
    t = sort(R.spikeSec(R.spikeUnitIdx == sel));
    t = t(:);
end
end


function msg = unitPrompt(R, sel)
if sel >= 1 && sel <= numel(R.clusterID)
    msg = "Fewer than two spikes.";
else
    msg = "Pick a unit in the table.";
end
end


function ms = refractoryMs()
%refractoryMs  The refractory period the ISI and autocorrelogram plots mark.
ms = 1.5;
end


function showMessage(ax, ttl, msg)
%showMessage  An empty axes with a title and a line of text in the middle.
title(ax, ttl, 'Interpreter', 'none');
text(ax, 0.5, 0.5, msg, 'Units', 'normalized', 'HorizontalAlignment', 'center', ...
    'Color', [0.4 0.4 0.4], 'FontSize', 11);
ax.XTick = []; ax.YTick = [];
end


function plotAmplitudes(ax, R, sel)
%plotAmplitudes  Spike amplitude vs time: all units (colored), or one unit.
cla(ax, 'reset');
budget = 30000;
if sel < 1 || sel > numel(R.clusterID)
    t = R.spikeSec;
    a = R.spikeAmp;
    cidx = R.spikeUnitIdx;
    N = numel(t);
    if N > budget
        keep = round(linspace(1, N, budget));
        t = t(keep); a = a(keep); cidx = cidx(keep);
    end
    cmapU = lines(max(numel(R.clusterID), 1));
    scatter(ax, t, a, 4, cmapU(cidx, :), 'filled', 'MarkerFaceAlpha', 0.35);
    title(ax, sprintf("Amplitudes over time (%d units, %s spikes)", ...
        numel(R.clusterID), thousands(numel(R.spikeSec))));
else
    m = R.spikeUnitIdx == sel;
    t = R.spikeSec(m);
    a = R.spikeAmp(m);
    N = numel(t);
    if N > budget
        keep = round(linspace(1, N, budget));
        t = t(keep); a = a(keep);
    end
    scatter(ax, t, a, 5, [0 0.35 0.75], 'filled', 'MarkerFaceAlpha', 0.4);
    title(ax, sprintf("%s amplitudes (%s spikes)", ...
        R.unitLabel(sel), thousands(N)), 'Interpreter', 'none');
end
xlabel(ax, "Time (s)");
ylabel(ax, "Amplitude (a.u.)");
grid(ax, 'on');
if all(isfinite(R.span)); xlim(ax, R.span); end   % the sorted part of the recording
end


function plotFiringRates(ax, R, sel, shankColors, shankIdx)
%plotFiringRates  Per-unit firing rate, bars colored by shank.
cla(ax, 'reset');
ax.FontSize = 9;
U = numel(R.clusterID);
b = bar(ax, 1:U, R.firingRate, 'FaceColor', 'flat');
b.CData = shankColors(shankIdx, :);
hold(ax, 'on');
if sel >= 1 && sel <= U
    bar(ax, sel, R.firingRate(sel), 'FaceColor', 'none', ...
        'EdgeColor', 'k', 'LineWidth', 1.5);
end
hold(ax, 'off');
xlabel(ax, "Unit index");
ylabel(ax, "Firing rate (Hz)");
title(ax, "Firing rate per unit (color = shank)");
grid(ax, 'on');
if U > 0; xlim(ax, [0.5 U + 0.5]); end
end


function s = thousands(n)
s = regexprep(sprintf('%d', round(n)), '\d(?=(\d{3})+$)', '$0,');
end
