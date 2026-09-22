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
%   to the whole window or to the kept samples only, clipping the rest.
%   Without a window it shows why (no preview yet, nothing detected, a read
%   error). Called on every change to those controls; it never reads data.
%
%   See also showArtifactView, onDetectArtifacts, drawVizArtifacts.

ax = obj.ArtViewAxes;
if isempty(ax) || ~isvalid(ax); return; end
V = obj.ArtView;
n = size(V.intervals, 1);
syncControls(obj, n);
[obj.ArtViewNoteLabel.Text, obj.ArtViewNoteLabel.FontColor] = removalNote(obj, V);

cla(ax);
legend(ax, 'off');
title(ax, "");
subtitle(ax, "");
xlabel(ax, "");
set(ax, 'XLimMode', 'auto', 'YLimMode', 'auto', 'XTickMode', 'auto', ...
    'YTickMode', 'auto', 'YTickLabelMode', 'auto', 'Box', 'on');

w = V.win;
if isempty(w) || isfield(w, 'error')
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

% --- channels: the ones the artifact stands out most on, in channel order -----
kept = ~removed;
if ~any(kept); kept = true(m, 1); end
Xc = w.X - median(w.X(kept, :), 1);          % centred on the kept signal
sd = 1.4826 * median(abs(Xc(kept, :)), 1);   % its robust SD per channel
good = sd > 0 & isfinite(sd);
sd(~good) = max([sd(good), 1]);
focus = w.maskFocus;
if ~any(focus); focus = true(m, 1); end
[~, ord] = sort(max(abs(Xc(focus, :)), [], 1) ./ sd, 'descend');
nShow = min(nCh, max(1, round(obj.ArtViewChannelsField.Value)));
ch = sort(ord(1:nShow));
Y = Xc(:, ch);

% --- lanes ---------------------------------------------------------------------
fitKept = string(obj.ArtViewScaleDropDown.Value) == "kept";
if fitKept
    half = max(abs(Y(kept, :)), [], 'all');
else
    half = max(abs(Y), [], 'all');
end
if ~(half > 0); half = 1; end
clipped = any(abs(Y) > half, 'all');
Y = min(max(Y, -half), half);
spacing = 2.1 * half;
offsets = (nShow - 1:-1:0) * spacing;         % first channel on top

t = ((w.s0 + (0:m - 1)') / w.Fs - w.on) * 1e3;   % ms from the artifact's start
[t, Y, removed] = envelope(t, Y, removed, 10000);

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
hRem  = drawLanes(ax, t, yRem, [0.85 0.1 0.1], "Removed (zeroed)");
hKept = drawLanes(ax, t, yKept, [0.1 0.1 0.1], "Kept");

hold(ax, 'off');
legend(ax, [hKept; hRem; hDet(1:min(1, end)); hMan(1:min(1, end))], ...
    'Location', 'northeastoutside', 'Box', 'off', 'AutoUpdate', 'off');

span = [t(1) t(end)];
if span(2) <= span(1); span = span(1) + [-1 1]; end
set(ax, 'XLim', span, 'YLim', [-0.5, nShow - 0.5] * spacing, 'TickLabelInterpreter', 'none', ...
    'YTick', (0:nShow - 1) * spacing, 'YTickLabel', w.names(ch(end:-1:1)));
xlabel(ax, "Time from the artifact's start (ms)");
title(ax, sprintf('Artifact %d of %d at %.4f s, %s long', w.k, w.n, w.on, durationText(w.off - w.on)));
if nShow == nCh
    chText = sprintf('all %d channels', nCh);
else
    chText = sprintf('the %d of %d channels it is largest on', nShow, nCh);
end
if spacing >= 100
    scaleText = sprintf('lanes %.0f uV apart', spacing);
else
    scaleText = sprintf('lanes %.3g uV apart', spacing);
end
if clipped; scaleText = scaleText + ", larger values clipped"; end
subtitle(ax, chText + " | " + w.view + " | " + scaleText, 'Interpreter', 'none');
end


function h = drawLanes(ax, t, Y, color, name)
% One line per lane, leaving out lanes with nothing to draw, and the first of
% them for the legend (a lone NaN point when every lane is empty). A single
% line holding every lane breaks the uifigure renderer (R2025a: "Could not
% find node in peer tree") when it is redrawn beside one that is all NaN.
h = gobjects(0, 1);
for j = find(any(~isnan(Y), 1))
    h(end+1, 1) = plot(ax, t, Y(:, j), 'Color', color, 'LineWidth', 0.8, 'DisplayName', name); %#ok<AGROW>
end
if isempty(h)
    h = plot(ax, NaN, NaN, 'Color', color, 'LineWidth', 0.8, 'DisplayName', name);
end
h = h(1);
end


function syncControls(obj, n)
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
end


function tf = autoRemoved(obj)
% Whether a run removes the detected artifacts, with the controls as they are.
tf = logical(obj.ArtEnableCheckBox.Value) && (logical(obj.ArtApplySortingCheckBox.Value) ...
    || logical(obj.ArtApplySpikesCheckBox.Value));
end


function [s, color] = removalNote(obj, V)
% One line on what red and black mean on a run, and whether the preview is stale.
s = "";
color = [0.3 0.3 0.3];
if ~V.previewed; return; end
toSort = logical(obj.ArtApplySortingCheckBox.Value);
toSpk  = logical(obj.ArtApplySpikesCheckBox.Value);
if autoRemoved(obj)
    if toSort && toSpk
        uses = "zeroed on every channel for sorting, and spikes inside are rejected";
    elseif toSort
        uses = "zeroed on every channel for sorting (spike detection keeps it)";
    else
        uses = "spikes inside are rejected (sorting keeps the signal)";
    end
    s = "Red is what a run removes: " + uses + ". Black is kept.";
elseif logical(obj.ArtEnableCheckBox.Value)
    s = "Silencing in sorting and rejecting spikes are both off, so a run keeps the detected " + ...
        "artifacts (black). Manual periods (red) are always removed.";
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
