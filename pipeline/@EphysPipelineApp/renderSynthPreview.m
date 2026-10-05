function renderSynthPreview(obj)
%renderSynthPreview  Draw the Synthetic tab's preview from SynthModel (onSynthPreview).
%   Timeline: every digital line (a bar per interval) and every unit's
%   spikes (a tick each, in its event line's colour when linked) from
%   From (s) for Span s, artifacts shaded. Raster / PSTH: the Unit box's
%   unit around its event's edges (a unit with no event: around the trial
%   line's onsets), events sorted by its Parameter when it has one; the
%   PSTH is split by that parameter's values (at most 4 groups) and the
%   model's rate for each group is dashed. LFP: the LFP box's component on
%   its peak channel around up to 20 of its events spread over the
%   recording: single events in grey, their mean in black, the model's mean
%   dashed and, for an oscillation, its envelope dotted (an unlocked one
%   averages away; the envelope shows its power). Probe: each site coloured
%   by the component's gain, its peak ringed.
axs = [obj.SynthTimelineAxes, obj.SynthRasterAxes, obj.SynthPSTHAxes, obj.SynthLFPAxes, obj.SynthProfileAxes];
for ax = axs
    cla(ax); legend(ax, 'off');
    colorbar(ax, 'off');
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
    title(obj.SynthLFPAxes, "LFP around the event"); title(obj.SynthProfileAxes, "Gain over the probe");
    finish(axs);
    return
end
M = T.model;
S = T.schedule;
colors = lineColors(M.lineNames);

drawTimeline(obj.SynthTimelineAxes, M, colors, obj.SynthTimelineStartField.Value, obj.SynthTimelineSpanField.Value);
u = obj.SynthUnitDropDown.Value;
if isnumeric(u) && u >= 1 && u <= numel(M.units)
    drawUnit(obj.SynthRasterAxes, obj.SynthPSTHAxes, M, S, u, colors);
else
    title(obj.SynthRasterAxes, "Raster: no units"); title(obj.SynthPSTHAxes, "PSTH");
end
c = obj.SynthLFPDropDown.Value;
if isnumeric(c) && c >= 1 && c <= numel(M.lfp)
    drawLFP(obj.SynthLFPAxes, obj.SynthProfileAxes, M, c);
else
    title(obj.SynthLFPAxes, "LFP: no event-linked components");
    title(obj.SynthProfileAxes, "Probe");
    scatter(obj.SynthProfileAxes, M.xc, M.yc, 30, [0.6 0.6 0.6], 'filled');
end
finish(axs);
end


function finish(axs)
for ax = axs; hold(ax, 'off'); end
end


function C = lineColors(names)
%lineColors  One colour per digital line (struct: line -> RGB).
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


function [te, label, v, param, rows] = unitEvents(M, S, q)
%unitEvents  The edges a unit is shown around (its own, else the trial line's onsets).
param = q.parameter;
v = NaN(0, 1);
if q.event ~= ""
    te = q.eventTimes;
    label = q.event + " " + q.edge;
    rows = 1:numel(te);
    if param ~= "" && ~isempty(te)
        vals = double(S.trials.(param));
        v = NaN(numel(te), 1);
        has = ~isnan(q.eventTrial);
        v(has) = vals(q.eventTrial(has));
    end
else
    r = M.rows.(M.trialLine);
    r = r(r(:, 1) > 1, :);
    te = (r(:, 1) - 1) / M.Fs;
    label = M.trialLine + " onset (unit not linked)";
    rows = [];
    param = "";
end
end


function drawUnit(axR, axP, M, S, u, colors)
q = M.units(u);
Fs = M.Fs;
[te, label, v, param, idxModel] = unitEvents(M, S, q);
if isempty(te)
    title(axR, "Raster: " + q.name + " has no events in the recording");
    title(axP, "PSTH");
    return
end
pre = 0.5;
post = 1;
if q.event ~= ""
    post = min(3, max(0.6, (q.latencyMs + 1000 * median(q.durations)) / 1000 + 0.4));
end
st = (double(q.samples) - 1) / Fs;
E = [-Inf; st(:); Inf];
lo = discretize(te - pre, E);            % spikes before te - pre (bin k: k - 1 spikes at or before)
hi = discretize(te + post, E) - 1;       % spikes at or before te + post

% raster: up to 150 events, sorted by the parameter when there is one
nE = numel(te);
show = 1:min(nE, 150);
order = show;
if param ~= ""
    [~, k] = sort(v(show)); order = show(k);
end
X = cell(1, numel(order)); Y = X;
for j = 1:numel(order)
    i = order(j);
    rel = st(lo(i):hi(i)) - te(i);
    rel = rel(rel >= -pre & rel < post);
    X{j} = [rel rel NaN(size(rel))].';
    Y{j} = repmat([j - 0.4; j + 0.4; NaN], 1, numel(rel));
end
X = [X{:}]; Y = [Y{:}];
col = [0.2 0.2 0.2];
if q.event ~= ""; col = colors.(q.event); end
if ~isempty(X)
    line(axR, X(:), Y(:), 'Color', col, 'LineWidth', 1);
end
xline(axR, 0, 'Color', [0.8 0.1 0.1]);
if q.event ~= "" && q.latencyMs ~= 0
    xline(axR, q.latencyMs / 1000, '--', 'Color', [0.5 0.5 0.5]);
end
xlim(axR, [-pre post]); ylim(axR, [0.4 max(1, numel(order)) + 0.6]);
ylab = "Event";
if param ~= ""; ylab = "Event (by " + param + ")"; end
ylabel(axR, ylab);
xlabel(axR, "Time from " + label + " (s)");
title(axR, sprintf("%s: %s, %.1f Hz baseline, gain %.2g", q.name, q.modulation, q.baselineHz, q.gain));

% PSTH, split by the parameter
bin = 0.01; if pre + post > 1.6 || param ~= ""; bin = 0.02; end   % split by a parameter: fewer events per curve
edges = -pre:bin:post;
ctr = edges(1:end-1) + bin / 2;
groups = {1:nE}; names = "all " + nE + " events";
if param ~= ""
    [groups, names] = splitByValue(v, param);
end
gc = [0 0 0; 0.00 0.45 0.74; 0.85 0.33 0.10; 0.47 0.67 0.19; 0.49 0.18 0.56];
h = gobjects(0);
for g = 1:numel(groups)
    idx = groups{g};
    if isempty(idx); continue; end
    counts = zeros(1, numel(edges) - 1);
    for i = idx(:).'
        rel = st(lo(i):hi(i)) - te(i);
        counts = counts + histcounts(rel, edges);
    end
    cg = gc(1, :);
    if numel(groups) > 1; cg = gc(mod(g - 1, size(gc, 1) - 1) + 2, :); end
    h(end+1) = stairs(axP, [edges(1:end-1) edges(end)], [counts counts(end)] / (numel(idx) * bin), ...
        'Color', cg, 'LineWidth', 1.2, 'DisplayName', names(g)); %#ok<AGROW>
    if ~isempty(idxModel)
        plot(axP, ctr, M.expectedRate(u, ctr, idx), '--', 'Color', cg, 'LineWidth', 1, 'HandleVisibility', 'off');
    else
        yline(axP, q.baselineHz, '--', 'Color', cg, 'HandleVisibility', 'off');
    end
end
xline(axP, 0, 'Color', [0.8 0.1 0.1], 'HandleVisibility', 'off');
xlim(axP, [-pre post]);
xlabel(axP, "Time from " + label + " (s)");
ylabel(axP, "Rate (Hz)");
title(axP, "PSTH (dashed: the model's rate)");
if numel(h) > 1; legend(axP, h, 'Location', 'northeast', 'Box', 'off'); end
end


function [groups, names] = splitByValue(v, param)
%splitByValue  Events grouped by their parameter value (at most 4 groups; by quartile when more values).
ok = find(isfinite(v));
u = unique(v(ok));
if numel(u) <= 4
    groups = cell(1, numel(u)); names = strings(1, numel(u));
    for k = 1:numel(u)
        groups{k} = ok(v(ok) == u(k));
        names(k) = sprintf("%s = %g (%d)", param, u(k), numel(groups{k}));
    end
else
    x = sort(v(ok));
    q = interp1(linspace(0, 1, numel(x)), x, [0 0.25 0.5 0.75 1]);   % quartiles, no toolbox
    groups = cell(1, 4); names = strings(1, 4);
    for k = 1:4
        m = v(ok) >= q(k) & (v(ok) < q(k + 1) | (k == 4 & v(ok) <= q(k + 1)));
        groups{k} = ok(m);
        names(k) = sprintf("%s %g-%g (%d)", param, q(k), q(k + 1), numel(groups{k}));
    end
end
if isempty(groups); groups = {ok}; names = "no " + param + " value"; end
end


function drawLFP(axL, axP, M, c)
q = M.lfp(c);
Fs = M.Fs;
pk = q.peakChannel;
te = q.eventTimes;
g = q.gain;
% the probe, coloured by gain
scatter(axP, M.xc, M.yc, 40, g(:), 'filled', 'MarkerEdgeColor', [0.5 0.5 0.5]);
plot(axP, M.xc(pk), M.yc(pk), 'o', 'MarkerSize', 11, 'Color', 'k', 'LineWidth', 1.5);
colormap(axP, blueWhiteRed(64));
clim(axP, [-1 1]);
colorbar(axP);
xlabel(axP, "x (um)"); ylabel(axP, "y (um)");
title(axP, "Gain: " + q.profile);
if isempty(te)
    title(axL, "LFP: " + q.name + " has no events in the recording");
    return
end
pre = 0.1;
post = min(2, max(0.3, q.latencyMs / 1000 + median(q.durations) + 0.15));
n = round((pre + post) * Fs);
pick = unique(round(linspace(1, numel(te), min(20, numel(te)))));
step = max(1, floor(Fs / 2000));
tau = ((0:n-1) / Fs - pre).';
tauD = tau(1:step:end);
Y = NaN(numel(tauD), numel(pick));
for j = 1:numel(pick)
    s0 = round((te(pick(j)) - pre) * Fs);
    if s0 < 0 || s0 + n > M.nSamp; continue; end
    x = M.window(s0, n);
    x = movmean(x(:, pk), step);
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
model = M.componentWave(c, tauD, pick) * g(pk);
plot(axL, tauD, model, '--', 'Color', [0.85 0.2 0.1], 'LineWidth', 1.2, 'DisplayName', "model mean");
if q.kind == "oscillation"
    env = M.componentEnvelope(c, tauD, pick) * abs(g(pk));
    plot(axL, tauD, env, ':', 'Color', [0.1 0.4 0.8], 'LineWidth', 1.2, 'DisplayName', "envelope");
    plot(axL, tauD, -env, ':', 'Color', [0.1 0.4 0.8], 'LineWidth', 1.2, 'HandleVisibility', 'off');
end
xline(axL, 0, 'Color', [0.8 0.1 0.1], 'HandleVisibility', 'off');
xlim(axL, [-pre post]);
xlabel(axL, "Time from " + q.event + " " + q.edge + " (s)");
ylabel(axL, sprintf("uV (channel %d)", pk));
kind = q.kind;
if kind == "oscillation"
    lock = "locked"; if ~q.phaseLocked; lock = "induced"; end
    kind = sprintf("%g Hz %s oscillation", q.frequencyHz, lock);
end
title(axL, sprintf("LFP %s: %s", q.name, kind));
legend(axL, 'Location', 'northeast', 'Box', 'off');
end


function C = blueWhiteRed(n)
%blueWhiteRed  A diverging colormap: blue (-1) through white to red (+1).
t = linspace(-1, 1, n).';
C = [min(1, 1 + t), 1 - abs(t), min(1, 1 - t)];
C = 0.15 + 0.85 * C;
end
