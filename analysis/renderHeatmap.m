function h = renderHeatmap(R, target, opts)
%renderHeatmap  Units or channels by time, one tile per group.
%   H = renderHeatmap(R, TARGET, Order=, Style=) draws a spikePSTH result
%   (rows = units, rate) or an evokedPotential result (rows = channels, mean)
%   as an image per group, on one colour scale (Style.CLim, else the range
%   of every tile) with Style.HeatColormap ("" = parula).
%
%   Order
%     "probe"    (default) as Style.SortShank / Style.SortDepth say: by shank,
%                then top of the probe first (probe y); neither = as listed
%     "peak"     by the time of each row's maximum (over the groups' mean)
%     "modulation"  an auROC result's units by their mean auROC in the
%                modulation window in the first group, highest first; the
%                other tiles keep that order (as the paper's Fig 3A). Other
%                results: as "probe"
%   Style.LabelShank / Style.LabelDepth append the shank / depth to the row
%   labels.
%
%   An auROC result (spikePSTH BaselineMode "auroc") is coloured on [0 1]
%   unless Style.CLim says otherwise. With a cutoff and
%   R.auroc.settings.marks, a bar along each tile's top spans the
%   modulation window, and a red up or blue down triangle right of the
%   image marks each unit the group's call finds modulated.
%
%   H: layout (tiled layout or []), axes, colorbar.
%
%   See also spikePSTH, evokedPotential, renderPlot.

arguments
    R (1,1) struct
    target
    opts.Order (1,1) string {mustBeMember(opts.Order, ["probe" "peak" "modulation"])} = "probe"
    opts.Style = struct()
end

style = renderStyle(opts.Style);
switch R.kind
    case "psth",   V = R.rate; what = "Units";
    case "evoked", V = R.mean; what = "Channels";
    otherwise
        error('renderHeatmap:BadResult', 'A heatmap draws a psth or an evoked result, not "%s".', R.kind);
end
[~, nR, nG] = size(V);
t = R.t;
auroc = R.kind == "psth" && isAuroc(R);
switch opts.Order
    case "peak"
        m = mean(V, 3, 'omitnan');
        [~, pk] = max(m, [], 1);
        [~, order] = sortrows([pk(:) (1:nR).']);
    otherwise
        order = probeOrder(R.meta, nR, style);
        if opts.Order == "modulation" && auroc
            [~, order] = sortrows([-R.auroc.mean(:, 1) (1:nR).']);   % highest first; NaN last
        end
end
labels = siteLabels(shortUnitLabels(R.labels), R.meta, style);
clim0 = style.CLim;
if ~(numel(clim0) == 2 && clim0(2) > clim0(1))
    v = V(isfinite(V));
    if isempty(v); clim0 = [0 1]; else; clim0 = [min(v) max(v)]; end
    if clim0(2) <= clim0(1); clim0 = clim0 + [-0.5 0.5]; end
    if auroc; clim0 = [0 1]; end
end
[idx, nr, nc] = pageItems(nG, 1, max(nG, 1));
[tl, ax0] = renderLayout(target, nr, nc, style);
if ~isempty(ax0); idx = idx(1:min(1, end)); end
if style.HeatColormap == ""
    maps = "heat";
    if auroc; maps = ["diverging" "heat"]; end   % auROC: centred on 0.5
    cmap = designColormap(style, maps, "parula");
else
    cmap = feval(char(style.HeatColormap), 256);
end
axs = gobjects(1, numel(idx));
for j = 1:numel(idx)
    g = idx(j);
    if ~isempty(ax0); ax = ax0; else; ax = nexttile(tl, j); end
    M = V(:, order, g).';
    tagPart(ax, "axes", "", R.groups.label(g));
    tagPart(imagesc(ax, t, 1:nR, M, 'AlphaData', double(isfinite(M))), "image", R.groups.label(g));
    set(ax, 'YDir', 'reverse');
    colormap(ax, cmap);
    clim(ax, clim0);
    if style.ShowZeroLine; tagPart(xline(ax, 0, '--', 'Color', [1 1 1], 'LineWidth', 1), "zeroLine"); end
    styleAxes(ax, style);
    grid(ax, 'off');
    ylim(ax, [0.5 nR + 0.5]);
    if auroc; heatMarks(ax, R, order, g, style); end
    if nR <= 40
        set(ax, 'YTick', 1:nR, 'YTickLabel', labels(order), 'TickLabelInterpreter', 'none', ...
            'FontSize', max(6, style.FontSize - (nR > 20)));
    end
    title(ax, sprintf('%s (n = %d)', R.groups.label(g), R.n(g)), 'FontWeight', 'normal', 'Interpreter', 'none');
    if ceil(j / nc) == nr || ~isempty(ax0); xlabel(ax, 'Time (s)'); end
    if mod(j - 1, nc) == 0; ylabel(ax, what); end
    axs(j) = ax;
end
cb = gobjects(0);
if ~isempty(axs)
    cb = colorbar(axs(end));
    cb.Label.String = R.units;
    if ~isempty(tl); cb.Layout.Tile = 'east'; end
end
cornerLabels(axs, nr, nc, style);
h = struct('layout', tl, 'axes', axs, 'colorbar', cb);
end


function heatMarks(ax, R, order, g, style)
%heatMarks  Tile G's auROC calls: a bar over the modulation window, a triangle right of each modulated row.
%   The x axis gains a margin right of the image for the triangles (unless
%   Style.XLim is set): red up, modulated upwards; blue down, downwards.
A = R.auroc;
if A.cutoff == "none" || (isfield(A, 'settings') && ~A.settings.marks); return; end
nR = numel(order);
tagPart(line(ax, A.modulationWindow, [0.5 0.5], 'Color', [0 0 0], 'LineWidth', 3, 'Clipping', 'off', ...
    'HandleVisibility', 'off'), "modWindow");
e = R.edges([1 end]);
margin = 0.05 * (e(2) - e(1));
if isempty(style.XLim); xlim(ax, [e(1), e(2) + margin]); end
d = A.direction(order, g);
fs = max(4, min(style.FontSize, round(240 / max(nR, 1))));
calls = ["increase" "decrease"];
glyphs = [char(9650) char(9660)];
colours = [0.85 0.15 0.1; 0.1 0.35 0.85];
for k = 1:2
    rows = find(d == calls(k));
    if isempty(rows); continue; end
    tagPart(text(ax, repmat(e(2) + margin / 2, numel(rows), 1), rows, glyphs(k), 'Color', colours(k, :), ...
        'FontSize', fs, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Clipping', 'off', ...
        'Interpreter', 'none'), "modMarks", calls(k));
end
end
