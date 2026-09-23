function drawArtifactView(obj)
%drawArtifactView  Draw one detected artifact: what a run removes and keeps.
%   Draws ArtView.win (read by showArtifactView) on the Artifacts tab's
%   axes: the channels the artifact is largest on (ArtViewChannelsField), one
%   lane each, against time from the artifact's start. Samples a run would
%   remove are red and the ones it keeps black. Detected artifacts are shaded
%   orange (the chosen one outlined) and manual periods red, as on the
%   Visualize tab. What is removed follows the controls as they are now:
%   manual periods always, the detected artifacts when automatic detection
%   is enabled and silences them in sorting or rejects spikes inside them.
%   The line above the axes says which, and flags a preview whose detection
%   settings have since changed. Scale (ArtViewScaleDropDown) fits the lanes
%   to the whole window or to the spread of the signal outside the
%   artifacts, clipping the rest, and ArtView.gain scales that fit
%   (onArtViewInput); Manual takes the lane spacing typed in Lanes
%   (ArtViewLanesField), which otherwise shows the spacing drawn. The y
%   label gives the lane spacing in microvolts.
%
%   With a probe assigned to the dataset (ArtView.layout, from
%   syncArtProbeControls) the channels can come from one shank only (Shank),
%   the lanes follow the probe layout ("Order channels by probe layout":
%   by shank, top of the shank first, dotted lines between shanks) and the
%   kept signal is coloured by shank ("Colour by shank"). Otherwise the
%   lanes are in recording order.
%
%   A redraw of the same window keeps the time zoom (the axes' XLim); a new
%   window starts on its whole span. Long windows are drawn as a min / max
%   envelope, finer as the zoom narrows (ArtView.drawn). Without a
%   window it shows why (no preview yet, nothing detected, a read error).
%   Called on every change to those controls; it never reads data.
%
%   See also showArtifactView, onArtViewInput, onDetectArtifacts, drawVizArtifacts.

ax = obj.ArtViewAxes;
if isempty(ax) || ~isvalid(ax); return; end
V = obj.ArtView;
n = size(V.intervals, 1);
L = V.layout;
hasProbe = ~isempty(L) && L.hasProbe;
syncControls(obj, n, hasProbe);
[obj.ArtViewNoteLabel.Text, obj.ArtViewNoteLabel.FontColor] = removalNote(obj, V);

prevX = ax.XLim;
cla(ax);
legend(ax, 'off');
title(ax, "");
subtitle(ax, "");
xlabel(ax, "");
ylabel(ax, "");
set(ax, 'XLimMode', 'auto', 'YLimMode', 'auto', 'XTickMode', 'auto', ...
    'YTickMode', 'auto', 'YTickLabelMode', 'auto', 'Box', 'on');

w = V.win;
if isempty(w) || isfield(w, 'error')
    obj.ArtView.drawn.key = [];
    if isstruct(w) && isfield(w, 'error')
        msg = "Could not read the artifact: " + w.error;
    elseif ~V.previewed
        msg = "Press Detect / Preview to step through the detected artifacts here.";
    elseif n == 0
        msg = "No artifacts detected with these settings.";
    else
        msg = "";
    end
    set(ax, 'XLim', [0 1], 'YLim', [0 1], 'XTick', [], 'YTick', []);
    text(ax, 0.5, 0.5, msg, 'HorizontalAlignment', 'center', ...
        'Color', [0.45 0.45 0.45], 'Interpreter', 'none');
    return
end

% --- what a run removes -------------------------------------------------------
d = obj.currentDataset();
[m, nCh] = size(w.X);
manual = zeros(0, 2);
if ~isempty(d) && ~isempty(d.ManualArtifacts)
    manual = d.ManualArtifacts;
    manual = manual(manual(:, 2) >= w.s0 / w.Fs & manual(:, 1) <= (w.s0 + m - 1) / w.Fs, :);
end
maskManual = false(m, 1);
if ~isempty(d)
    maskManual = d.manualArtifactMask(m, w.s0, w.Fs, manual);
end
removed = maskManual | (autoRemoved(obj) & w.maskDetected);

% --- channels: the ones the artifact stands out most on (on the chosen shank) --
kept = ~removed;
if ~any(kept); kept = true(m, 1); end
Xc = w.X - median(w.X(kept, :), 1);          % centred on the kept signal
sd = 1.4826 * median(abs(Xc(kept, :)), 1);   % its robust SD per channel
good = sd > 0 & isfinite(sd);
sd(~good) = max([sd(good), 1]);
focus = w.maskFocus;
if ~any(focus); focus = true(m, 1); end

useProbe = hasProbe && numel(L.shank) == nCh;
pool = 1:nCh;
shankSel = string(obj.ArtViewShankDropDown.Value);
if useProbe && shankSel ~= "all"
    pool = find(L.shank == str2double(shankSel));
end
[~, ord] = sort(max(abs(Xc(focus, pool)), [], 1) ./ sd(pool), 'descend');
nShow = min(numel(pool), max(1, round(obj.ArtViewChannelsField.Value)));
ch = pool(ord(1:nShow));
byProbe = useProbe && logical(obj.ArtProbeOrderCheckBox.Value);
if byProbe
    pos(L.order) = 1:nCh;                    % place on the probe
    [~, i] = sort(pos(ch));
    ch = ch(i);
else
    ch = sort(ch);
end
Y = Xc(:, ch);

laneColor = repmat([0.1 0.1 0.1], nShow, 1);
byShank = useProbe && logical(obj.ArtViewShankColorCheckBox.Value);
if byShank
    pal = shankPalette();
    [~, si] = ismember(L.shank(ch), L.shanks);   % 0 off the probe
    on = si > 0;
    laneColor(on, :) = pal(mod(si(on) - 1, size(pal, 1)) + 1, :);
end

% --- lanes ---------------------------------------------------------------------
scale = string(obj.ArtViewScaleDropDown.Value);
fixed = scale == "manual" && obj.ArtViewLanesField.Value > 0;
if fixed
    half = obj.ArtViewLanesField.Value / 2.1;   % the spacing set by hand
elseif scale == "kept"
    % Robust spread of the signal outside every artifact, so leftovers at an
    % artifact's edges (or artifacts a run keeps) are clipped, not fitted.
    bg = ~(maskManual | w.maskDetected);
    if ~any(bg); bg = kept; end
    half = min(6 * max(1.4826 * median(abs(Y(bg, :)), 1)), max(abs(Y), [], 'all'));
else
    half = max(abs(Y), [], 'all');
end
if ~fixed
    if ~(half > 0); half = 1; end
    half = half / V.gain;
end
clipped = any(abs(Y) > half, 'all');
Y = min(max(Y, -half), half);
spacing = 2.1 * half;
obj.ArtViewLanesField.Value = spacing;         % shows the spacing drawn
offsets = (nShow - 1:-1:0) * spacing;         % first channel on top

% --- time: the whole window, or the zoom kept from the last draw of it ---------
t = ((w.s0 + (0:m - 1)') / w.Fs - w.on) * 1e3;   % ms from the artifact's start
span = [t(1) t(end)];
if span(2) <= span(1); span = span(1) + [-1 1]; end
key = [w.k, w.s0, m];
xl = span;
if isequal(V.drawn.key, key)
    xl = clampView(prevX, span);
end
detail = 2 ^ max(0, ceil(log2(diff(span) / diff(xl)) - 1e-9));   % finer envelope when zoomed in
maxBins = 10000 * detail;
[t, Y, removed] = envelope(t, Y, removed, maxBins);
obj.ArtView.drawn = struct('key', key, 'span', span, 'factor', detail, ...
    'decimated', m > 2 * maxBins);

% Removed samples are drawn one sample wider each side, so the red joins the black.
wide = removed | [removed(2:end); false] | [false; removed(1:end-1)];
yKept = Y + offsets;    yKept(removed, :) = NaN;
yRem  = Y + offsets;    yRem(~wide, :) = NaN;

hold(ax, 'on');
rel = @(s) (s - w.on) * 1e3;
hDet = gobjects(0, 1);
for i = 1:size(w.detected, 1)
    r = xregion(ax, rel(w.detected(i, 1)), rel(w.detected(i, 2)), ...
        'FaceColor', [0.95 0.6 0.1], 'FaceAlpha', 0.18, 'DisplayName', "Detected artifact");
    if abs(w.detected(i, 1) - w.on) < 0.5 / w.Fs && abs(w.detected(i, 2) - w.off) < 0.5 / w.Fs
        set(r, 'EdgeColor', [0.8 0.4 0], 'LineWidth', 1, 'LineStyle', '--');   % the chosen one
    end
    hDet(end+1, 1) = r; %#ok<AGROW>
end
hMan = gobjects(0, 1);
for i = 1:size(manual, 1)
    hMan(end+1, 1) = xregion(ax, rel(manual(i, 1)), rel(manual(i, 2)), ...
        'FaceColor', [0.85 0.2 0.2], 'FaceAlpha', 0.15, 'DisplayName', "Manual period"); %#ok<AGROW>
end
if byProbe
    sh = L.shank(ch);                        % a dotted line between shanks
    for i = find(~sameShank(sh(1:end-1), sh(2:end)))
        yline(ax, offsets(i) - spacing / 2, ':', 'Color', [0.55 0.55 0.55]);   % visible, so cla clears it
    end
end
red = [0.85 0.1 0.1];
keptName = repmat("Kept", 1, nShow);
if byShank
    keptName = "Shank " + L.shank(ch);
    keptName(isnan(L.shank(ch))) = "Not on the probe";
end
hRem  = drawLanes(ax, t, yRem, repmat(red, nShow, 1), repmat("Removed (replaced)", 1, nShow));
hKept = drawLanes(ax, t, yKept, laneColor, keptName);

% Legend: the kept signal (one entry per shank when coloured), removed, the shadings.
[~, first] = unique(keptName, 'stable');
hLeg = gobjects(0, 1);
for j = first(:).'
    hLeg(end+1, 1) = legendLine(ax, hKept(keptName == keptName(j)), laneColor(j, :), keptName(j)); %#ok<AGROW>
end
hLeg = [hLeg; legendLine(ax, hRem, red, "Removed (replaced)"); hDet(1:min(1, end)); hMan(1:min(1, end))];
hold(ax, 'off');
legend(ax, hLeg, 'Location', 'southoutside', 'NumColumns', min(numel(hLeg), 4), ...
    'Box', 'off', 'AutoUpdate', 'off');

set(ax, 'XLim', xl, 'YLim', [-0.5, nShow - 0.5] * spacing, 'TickLabelInterpreter', 'none', ...
    'YTick', (0:nShow - 1) * spacing, 'YTickLabel', w.names(ch(end:-1:1)));
xlabel(ax, "Time from the artifact's start (ms)");
title(ax, sprintf('Artifact %d of %d at %.4f s, %s long', w.k, w.n, w.on, durationText(w.off - w.on)));
where = "";
if numel(pool) < nCh
    where = " on shank " + shankSel;
end
if nShow == numel(pool)
    chText = sprintf("all %d channels%s", nShow, where);
else
    chText = sprintf("the %d of %d channels%s it is largest on", nShow, numel(pool), where);
end
sub = chText + " | " + w.view;
if strlength(sub) > 60
    sub = chText + newline + w.view;         % two lines fit a narrow plot
end
subtitle(ax, sub, 'Interpreter', 'none');
if spacing >= 100
    scaleText = sprintf('Lanes %.0f uV apart', spacing);
else
    scaleText = sprintf('Lanes %.3g uV apart', spacing);
end
if clipped; scaleText = scaleText + ", larger values clipped"; end
ylabel(ax, scaleText, 'Interpreter', 'none');
end


function h = drawLanes(ax, t, Y, colors, names)
% One line per lane (a column of Y, in the colour of its row of COLORS,
% named by its entry of NAMES), leaving out lanes with nothing to draw:
% their entries of H stay placeholders. A single line holding every lane
% breaks the uifigure renderer (R2025a: "Could not find node in peer tree")
% when it is redrawn beside one that is all NaN.
h = gobjects(size(Y, 2), 1);
for j = find(any(~isnan(Y), 1))
    h(j) = plot(ax, t, Y(:, j), 'Color', colors(j, :), 'LineWidth', 0.8, 'DisplayName', names(j));
end
end


function h = legendLine(ax, h, color, name)
% The first line of H for the legend; a lone NaN point in COLOR named NAME
% when H has none (every one of its lanes was left out).
h = h(isgraphics(h));
if isempty(h)
    h = plot(ax, NaN, NaN, 'Color', color, 'LineWidth', 0.8, 'DisplayName', name);
end
h = h(1);
end


function tf = sameShank(a, b)
% A == B elementwise, NaN (not on the probe) matching NaN.
tf = a == b | (isnan(a) & isnan(b));
end


function pal = shankPalette()
% Shank colours: blues, greens, purple and grey, clear of the red of the
% removed samples and the orange / red of the shadings (lines() is not).
pal = [0.00 0.45 0.74
       0.13 0.55 0.13
       0.49 0.18 0.56
       0.00 0.60 0.60
       0.35 0.35 0.35
       0.30 0.70 0.95
       0.47 0.67 0.19
       0.25 0.25 0.60];
end


function v = clampView(v, span)
% Time limits V moved inside SPAN (and no wider); SPAN when V is unusable.
if numel(v) ~= 2 || ~all(isfinite(v)) || v(2) <= v(1)
    v = span;
    return
end
wid = min(v(2) - v(1), span(2) - span(1));
a = min(max(v(1), span(1)), span(2) - wid);
v = [a, a + wid];
end


function syncControls(obj, n, hasProbe)
% Spinner range and the enable state of the viewer's controls.
has = n > 0;
sp = obj.ArtViewSpinner;
sp.Limits = [1 max(n, 1)];     % clamps Value
sp.Enable = matlab.lang.OnOffSwitchState(has);
obj.ArtViewCountLabel.Text = "of " + n;
obj.ArtViewPrevButton.Enable = matlab.lang.OnOffSwitchState(has && sp.Value > 1);
obj.ArtViewNextButton.Enable = matlab.lang.OnOffSwitchState(has && sp.Value < n);
obj.ArtViewContextField.Enable = matlab.lang.OnOffSwitchState(has);
obj.ArtViewChannelsField.Enable = matlab.lang.OnOffSwitchState(has);
obj.ArtViewScaleDropDown.Enable = matlab.lang.OnOffSwitchState(has);
obj.ArtViewLanesField.Enable = matlab.lang.OnOffSwitchState(has);
obj.ArtViewShankDropDown.Enable = matlab.lang.OnOffSwitchState(has && hasProbe);
obj.ArtViewShankColorCheckBox.Enable = matlab.lang.OnOffSwitchState(has && hasProbe);
obj.ArtViewResetButton.Enable = matlab.lang.OnOffSwitchState(has);
end


function tf = autoRemoved(obj)
% Whether a run removes the detected artifacts, with the controls as they are.
tf = logical(obj.ArtEnableCheckBox.Value) && (logical(obj.ArtApplySortingCheckBox.Value) ...
    || logical(obj.ArtApplySpikesCheckBox.Value) || logical(obj.ArtApplySignalsCheckBox.Value));
end


function [s, color] = removalNote(obj, V)
% One line on what red and black mean on a run, and whether the preview is stale.
s = "";
color = [0.3 0.3 0.3];
if ~V.previewed; return; end
if autoRemoved(obj)
    uses = strings(1, 0);
    if logical(obj.ArtApplySortingCheckBox.Value)
        uses(end+1) = "replaced on every channel for sorting";
    end
    if logical(obj.ArtApplySpikesCheckBox.Value)
        uses(end+1) = "spikes inside are rejected";
    end
    if logical(obj.ArtApplySignalsCheckBox.Value)
        uses(end+1) = "erased in the signals (LFP / MUA / SPIKE)";
    end
    s = "Red is what a run removes: " + strjoin(uses, "; ") + ". Black is kept.";
elseif logical(obj.ArtEnableCheckBox.Value)
    s = "Erasing in sorting and in the signals and rejecting spikes are all off, so a run keeps the " + ...
        "detected artifacts (black). Manual periods (red) are always removed.";
else
    s = "Automatic detection is off, so a run keeps the detected artifacts (black). " + ...
        "Manual periods (red) are always removed.";
end
cur = EphysDataset.normalizeArtifactConfig(EphysPipelineConfig.artifactConfig(obj.gatherArtifactsSection()));
if ~isequaln(rmfield(cur, 'Enabled'), rmfield(V.settings, 'Enabled'))
    s = "Detection settings changed since this preview: press Detect / Preview to update. " + s;
    color = [0.8 0.35 0];
end
end


function [t, Y, r] = envelope(t, Y, r, maxBins)
% Min / max per bin when there are far more samples than pixels, so long
% windows draw quickly with their peaks intact. A bin is removed when any of
% its samples is.
m = numel(t);
if m <= 2 * maxBins; return; end
bsz = ceil(m / maxBins);
nb = ceil(m / bsz);
extra = nb * bsz - m;
dt = t(2) - t(1);
t = reshape([t; t(end) + (1:extra)' * dt], bsz, nb);
Y = reshape([Y; repmat(Y(end, :), extra, 1)], bsz, nb, []);
r = any(reshape([r; repmat(r(end), extra, 1)], bsz, nb), 1);
t = reshape([t(1, :); t(end, :)], [], 1);
Y = reshape([min(Y, [], 1); max(Y, [], 1)], 2 * nb, []);
r = reshape([r; r], [], 1);
end


function s = durationText(sec)
% "5.63 ms" or "1.25 s".
if sec < 1
    s = sprintf('%.3g ms', sec * 1e3);
else
    s = sprintf('%.3g s', sec);
end
end
