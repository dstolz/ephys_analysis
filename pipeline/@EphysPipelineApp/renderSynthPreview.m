function renderSynthPreview(obj)
%renderSynthPreview  Draw the Synthetic tab's preview from SynthModel (onSynthPreview).
%   Timeline: every digital line (a bar per interval) and every unit's
%   spikes (a tick each, in its event line's color when linked) from
%   From (s) for Span s, artifacts shaded. Raster / PSTH: the Unit box's
%   unit around its event's edges (a unit with no event: around the trial
%   line's onsets), the model's rate dashed. LFP: the LFP box's evoked
%   potential on its channel (the first, when on every channel) around up
%   to 20 of its events spread over the recording: single events in gray,
%   their mean in black, the model's mean dashed.
axs = [obj.SynthTimelineAxes, obj.SynthRasterAxes, obj.SynthPSTHAxes, obj.SynthLFPAxes];
for ax = axs
    cla(ax); legend(ax, 'off');
    ax.YTick = []; ax.YTickLabel = {}; ax.YTickMode = 'auto'; ax.YTickLabelMode = 'auto';
    ax.XLimMode = 'auto'; ax.YLimMode = 'auto';
    hold(ax, 'on');
end
T = obj.SynthModel;
if isempty(T)
    title(obj.SynthTimelineAxes, "Lines and spikes");
    text(obj.SynthTimelineAxes, 0.5, 0.5, "Press Preview", "Units", "normalized", ...
        "HorizontalAlignment", "center", "Color", [0.5 0.5 0.5], "FontSize", 14);
    title(obj.SynthRasterAxes, "Raster"); title(obj.SynthPSTHAxes, "PSTH");
    title(obj.SynthLFPAxes, "LFP around the event");
    finish(axs);
    return
end
M = T.model;
colors = lineColors(M.lineNames);

drawTimeline(obj.SynthTimelineAxes, M, colors, obj.SynthTimelineStartField.Value, obj.SynthTimelineSpanField.Value);
u = obj.SynthUnitDropDown.Value;
if isnumeric(u) && u >= 1 && u <= numel(M.units)
    drawUnit(obj.SynthRasterAxes, obj.SynthPSTHAxes, M, u, colors);
else
    title(obj.SynthRasterAxes, "Raster: no units"); title(obj.SynthPSTHAxes, "PSTH");
end
c = obj.SynthLFPDropDown.Value;
if isnumeric(c) && c >= 1 && c <= numel(M.lfp)
    drawLFP(obj.SynthLFPAxes, M, c);
else
    title(obj.SynthLFPAxes, "LFP: no evoked potentials");
end
finish(axs);
end


function finish(axs)
for ax = axs; hold(ax, 'off'); end
end


function C = lineColors(names)
%lineColors  One color per digital line (struct: line -> RGB).
base = [0.00 0.45 0.74; 0.85 0.33 0.10; 0.93 0.69 0.13; 0.49 0.18 0.56; 0.47 0.67 0.19; ...
    0.30 0.75 0.93; 0.64 0.08 0.18; 0.25 0.25 0.25];
C = struct();
for k = 1:numel(names)
    C.(names(k)) = base(mod(k - 1, size(base, 1)) + 1, :);
end
end


function drawTimeline(ax, M, colors, t0, span)
Fs = M.Fs;
t0 = min(max(t0, 0), max(0, M.duration - 0.1));
t1 = min(t0 + span, M.duration);
names = M.lineNames;
nL = numel(names); nU = numel(M.units);
nLanes = nL + nU;
labels = strings(1, nLanes);
% artifacts, shaded behind everything
for k = 1:size(M.artifacts, 1)
    a = (M.artifacts(k, 1) - 1) / Fs; b = M.artifacts(k, 2) / Fs;
    if b < t0 || a > t1; continue; end
    patch(ax, [a b b a], [0.4 0.4 nLanes + 0.6 nLanes + 0.6], [1 0.85 0.85], 'EdgeColor', 'none', 'HitTest', 'off');
end
for k = 1:nL
    y = nLanes - k + 1;
    labels(y) = names(k);
    r = M.rows.(names(k));
    iv = [(r(:, 1) - 1) / Fs, r(:, 2) / Fs];
    iv = iv(iv(:, 2) >= t0 & iv(:, 1) <= t1, :);
    if isempty(iv); continue; end
    iv = [max(iv(:, 1), t0), min(iv(:, 2), t1)];
    X = [iv(:, 1) iv(:, 2) iv(:, 2) iv(:, 1)].';
    Y = repmat([y - 0.35; y - 0.35; y + 0.35; y + 0.35], 1, size(iv, 1));
    patch(ax, X, Y, colors.(names(k)), 'EdgeColor', 'none', 'FaceAlpha', 0.85);
end
for u = 1:nU
    q = M.units(u);
    y = nU - u + 1;
    labels(y) = q.name;
    st = (double(q.samples) - 1) / Fs;
    st = st(st >= t0 & st <= t1);
    if isempty(st); continue; end
    col = [0.2 0.2 0.2];
    if q.event ~= ""; col = colors.(q.event); end
    X = [st st NaN(size(st))].';
    Y = repmat([y - 0.4; y + 0.4; NaN], 1, numel(st));
    line(ax, X(:), Y(:), 'Color', col, 'LineWidth', 1);
end
xlim(ax, [t0, max(t1, t0 + 0.01)]);
ylim(ax, [0.4, nLanes + 0.6]);
ax.YTick = 1:nLanes;
ax.YTickLabel = cellstr(labels);
ax.YAxis.FontSize = max(6, min(10, floor(ax.InnerPosition(4) / max(nLanes, 1)) - 2));   % labels that fit their lanes
title(ax, sprintf("Lines and spikes, %.1f-%.1f s of %.1f s", t0, t1, M.duration));
xlabel(ax, "Time (s)");
end


function [te, label, linked] = unitEvents(M, q)
%unitEvents  The edges a unit is shown around (its own, else the trial line's onsets).
linked = q.event ~= "";
if linked
    te = q.eventTimes;
    label = q.event + " " + q.edge;
else
    r = M.rows.(M.trialLine);
    r = r(r(:, 1) > 1, :);
    te = (r(:, 1) - 1) / M.Fs;
    label = M.trialLine + " onset (unit not linked)";
end
end


function drawUnit(axR, axP, M, u, colors)
q = M.units(u);
Fs = M.Fs;
[te, label, linked] = unitEvents(M, q);
if isempty(te)
    title(axR, "Raster: " + q.name + " has no events in the recording");
    title(axP, "PSTH");
    return
end
pre = 0.5;
post = 1;
if linked
    post = min(3, max(0.6, (q.latencyMs + q.durationMs) / 1000 + 0.4));
end
st = (double(q.samples) - 1) / Fs;
E = [-Inf; st(:); Inf];
lo = discretize(te - pre, E);            % spikes before te - pre (bin k: k - 1 spikes at or before)
hi = discretize(te + post, E) - 1;       % spikes at or before te + post

% raster: up to 150 events
nE = numel(te);
show = 1:min(nE, 150);
X = cell(1, numel(show)); Y = X;
for j = show
    rel = st(lo(j):hi(j)) - te(j);
    rel = rel(rel >= -pre & rel < post);
    X{j} = [rel rel NaN(size(rel))].';
    Y{j} = repmat([j - 0.4; j + 0.4; NaN], 1, numel(rel));
end
X = [X{:}]; Y = [Y{:}];
col = [0.2 0.2 0.2];
if linked; col = colors.(q.event); end
if ~isempty(X)
    line(axR, X(:), Y(:), 'Color', col, 'LineWidth', 1);
end
xline(axR, 0, 'Color', [0.8 0.1 0.1]);
if linked && q.latencyMs ~= 0
    xline(axR, q.latencyMs / 1000, '--', 'Color', [0.5 0.5 0.5]);
end
xlim(axR, [-pre post]); ylim(axR, [0.4 max(1, numel(show)) + 0.6]);
ylabel(axR, "Event");
xlabel(axR, "Time from " + label + " (s)");
title(axR, sprintf("%s: %s, %.1f Hz baseline, gain %.2g", q.name, q.modulation, q.baselineHz, q.gain));

% PSTH of every event, the model's rate dashed
bin = 0.01; if pre + post > 1.6; bin = 0.02; end
edges = -pre:bin:post;
ctr = edges(1:end-1) + bin / 2;
counts = zeros(1, numel(edges) - 1);
for i = 1:nE
    rel = st(lo(i):hi(i)) - te(i);
    counts = counts + histcounts(rel, edges);
end
stairs(axP, [edges(1:end-1) edges(end)], [counts counts(end)] / (nE * bin), 'Color', 'k', 'LineWidth', 1.2);
if linked
    plot(axP, ctr, M.expectedRate(u, ctr), '--', 'Color', [0.85 0.2 0.1], 'LineWidth', 1);
else
    yline(axP, q.baselineHz, '--', 'Color', [0.85 0.2 0.1]);
end
xline(axP, 0, 'Color', [0.8 0.1 0.1]);
xlim(axP, [-pre post]);
xlabel(axP, "Time from " + label + " (s)");
ylabel(axP, "Rate (Hz)");
title(axP, sprintf("PSTH of %d events (dashed: the model's rate)", nE));
end


function drawLFP(axL, M, c)
q = M.lfp(c);
Fs = M.Fs;
ch = find(q.gain, 1);
te = q.eventTimes;
if isempty(te)
    title(axL, "LFP: " + q.name + " has no events in the recording");
    return
end
pre = 0.1;
post = min(2, max(0.3, (q.latencyMs + q.durationMs) / 1000 + 0.15));
n = round((pre + post) * Fs);
pick = unique(round(linspace(1, numel(te), min(20, numel(te)))));
step = max(1, floor(Fs / 2000));
tau = ((0:n-1) / Fs - pre).';
tauD = tau(1:step:end);
Y = NaN(numel(tauD), numel(pick));
for j = 1:numel(pick)
    s0 = round((te(pick(j)) - pre) * Fs);
    if s0 < 0 || s0 + n > M.nSamp; continue; end
    x = M.signal(s0, n);
    x = movmean(x(:, ch), step);
    Y(:, j) = x(1:step:end);
end
keep = all(isfinite(Y), 1);
Y = Y(:, keep); pick = pick(keep);
if isempty(pick)
    title(axL, "LFP: " + q.name + ": no event far enough from the recording's edges");
    return
end
nShow = min(8, numel(pick));
plot(axL, tauD, Y(:, 1:nShow), 'Color', [0.75 0.75 0.75], 'HandleVisibility', 'off');
plot(axL, tauD, mean(Y, 2), 'k', 'LineWidth', 1.6, 'DisplayName', sprintf("mean of %d events", numel(pick)));
plot(axL, tauD, M.componentWave(c, tauD, pick), '--', 'Color', [0.85 0.2 0.1], 'LineWidth', 1.2, 'DisplayName', "model mean");
xline(axL, 0, 'Color', [0.8 0.1 0.1], 'HandleVisibility', 'off');
xlim(axL, [-pre post]);
xlabel(axL, "Time from " + q.event + " " + q.edge + " (s)");
ylabel(axL, sprintf("uV (channel %d)", ch));
where = "every channel";
if ~isnan(q.channel); where = sprintf("channel %d", q.channel); end
title(axL, sprintf("Evoked %s: %g uV, %g-%g ms, %s", q.name, q.amplitudeUV, q.latencyMs, q.latencyMs + q.durationMs, where));
legend(axL, 'Location', 'northeast', 'Box', 'off');
end
