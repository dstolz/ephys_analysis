function h = renderEvoked(R, target, opts)
%renderEvoked  Draw an evokedPotential result.
%   H = renderEvoked(R, TARGET, Name=Value)
%
%   Options
%     Layout  "stack" (default): one panel, channels stacked top of the probe
%             first (probe y, else channel order), groups in their colours;
%             "butterfly": one tile per group, every channel overlaid,
%             coloured by depth; "grid": one tile per channel (MaxTiles per
%             page), groups overlaid with SEM bands
%     Page    page of channels in grid layout
%     Style   EphysAnalysisConfig.defaults("Style") fields; StackSpacing
%             (NaN = 1.2 x the 90th percentile of the channels' ranges).
%             YLim sets the amplitude axis of the butterfly and grid
%             layouts; a stack ignores it (its offsets set the y axis, so
%             every channel stays in view)
%
%   An axes TARGET gets the stack (or the first tile of the other layouts).
%   H: layout (tiled layout or []), axes, spacing (stack).
%
%   See also evokedPotential, renderHeatmap, renderPlot.

arguments
    R (1,1) struct
    target
    opts.Layout (1,1) string {mustBeMember(opts.Layout, ["stack" "butterfly" "grid"])} = "stack"
    opts.Page (1,1) double {mustBePositive, mustBeInteger} = 1
    opts.Style = struct()
end

style = EphysAnalysisConfig.normalizeSection("Style", opts.Style);
colors = groupPalette(R.groups, style);
[~, nC, nG] = size(R.mean);
order = depthOrder(R.meta, nC);
t = R.t;
h = struct('layout', [], 'axes', gobjects(0), 'spacing', NaN);
yl = "Amplitude (" + unitText(R.units) + ")";

switch opts.Layout
    case "stack"
        [tl, ax] = renderLayout(target, 1, 1);
        if isempty(ax); ax = nexttile(tl); end
        rng1 = max(R.mean, [], 1) - min(R.mean, [], 1);   % [1 x nC x nG]
        rng1 = rng1(isfinite(rng1));
        spacing = style.StackSpacing;
        if ~(isfinite(spacing) && spacing > 0)
            spacing = 1.2 * pct90(rng1);
            if ~(isfinite(spacing) && spacing > 0); spacing = 1; end
        end
        hold(ax, 'on');
        lh = gobjects(1, nG);
        for k = 1:nC
            c = order(k);
            off = -(k - 1) * spacing;
            for g = 1:nG
                m = R.mean(:, c, g) + off;
                if style.ShowSEM
                    semBand(ax, t, m, R.sem(:, c, g), colors(g, :));
                end
                lh(g) = plot(ax, t, m, 'Color', colors(g, :), 'LineWidth', style.LineWidth);
            end
        end
        if style.ShowZeroLine; xline(ax, 0, ':', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off'); end
        hold(ax, 'off');
        offs = -(0:nC-1) * spacing;
        set(ax, 'YTick', fliplr(offs), 'YTickLabel', flipud(R.labels(order)), 'TickLabelInterpreter', 'none');
        ylim(ax, [offs(end) - spacing, spacing]);
        xlim(ax, t([1 end]));
        flat = style;
        flat.YLim = [];
        styleAxes(ax, flat);
        xlabel(ax, 'Time (s)');
        ylabel(ax, sprintf('Channel (%s per row)', compactNumber(spacing) + " " + unitText(R.units)));
        if style.Legend && nG > 1
            legend(ax, lh, R.groups.label, 'Location', 'bestoutside', 'Box', 'off', 'Interpreter', 'none', ...
                'FontSize', max(6, style.FontSize - 1));
        end
        h.layout = tl; h.axes = ax; h.spacing = spacing;

    case "butterfly"
        [idx, nr, nc] = pageItems(nG, 1, max(nG, 1));
        [tl, ax0] = renderLayout(target, nr, nc);
        if ~isempty(ax0); idx = idx(1:min(1, end)); end
        depthColors = parula(max(nC, 2));
        depthColors = depthColors(round(linspace(1, size(depthColors, 1) * 0.85, nC)), :);
        axs = gobjects(1, numel(idx));
        for j = 1:numel(idx)
            g = idx(j);
            if ~isempty(ax0); ax = ax0; else; ax = nexttile(tl, j); end
            hold(ax, 'on');
            for k = 1:nC
                plot(ax, t, R.mean(:, order(k), g), 'Color', depthColors(k, :), 'LineWidth', style.LineWidth * 0.8);
            end
            if style.ShowZeroLine; xline(ax, 0, ':', 'Color', [0.3 0.3 0.3]); end
            hold(ax, 'off');
            xlim(ax, t([1 end]));
            styleAxes(ax, style);
            title(ax, sprintf('%s (n = %d)', R.groups.label(g), R.nEpochs(g)), 'FontWeight', 'normal', 'Interpreter', 'none');
            if ceil(j / nc) == nr; xlabel(ax, 'Time (s)'); end
            if mod(j - 1, nc) == 0; ylabel(ax, yl); end
            axs(j) = ax;
        end
        if ~isempty(axs)
            colormap(axs(end), depthColors);
            cb = colorbar(axs(end));
            cb.Ticks = [0 1];
            cb.TickLabels = {'top', 'deep'};
            cb.Direction = 'reverse';
        end
        h.layout = tl; h.axes = axs;

    case "grid"
        [idx, nr, nc] = pageItems(nC, opts.Page, style.MaxTiles);
        [tl, ax0] = renderLayout(target, nr, nc);
        if ~isempty(ax0); idx = idx(1:min(1, end)); end
        axs = gobjects(1, numel(idx));
        for j = 1:numel(idx)
            c = order(idx(j));
            if ~isempty(ax0); ax = ax0; else; ax = nexttile(tl, j); end
            hold(ax, 'on');
            lh = gobjects(1, nG);
            for g = 1:nG
                if style.ShowSEM; semBand(ax, t, R.mean(:, c, g), R.sem(:, c, g), colors(g, :)); end
                lh(g) = plot(ax, t, R.mean(:, c, g), 'Color', colors(g, :), 'LineWidth', style.LineWidth);
            end
            if style.ShowZeroLine; xline(ax, 0, ':', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off'); end
            hold(ax, 'off');
            xlim(ax, t([1 end]));
            styleAxes(ax, style);
            title(ax, R.labels(c), 'FontWeight', 'normal', 'Interpreter', 'none');
            if ceil(j / nc) == nr || ~isempty(ax0); xlabel(ax, 'Time (s)'); end
            if mod(j - 1, nc) == 0; ylabel(ax, yl); end
            if j == 1 && style.Legend && nG > 1
                legend(ax, lh, R.groups.label, 'Location', 'best', 'Box', 'off', 'Interpreter', 'none', ...
                    'FontSize', max(6, style.FontSize - 1));
            end
            axs(j) = ax;
        end
        h.layout = tl; h.axes = axs;
end
end


function s = unitText(u)
s = replace(string(u), "uV", "µV");
end


function s = compactNumber(x)
s = string(sprintf('%.3g', x));
end


function v = pct90(x)
%pct90  90th percentile (nearest rank) without the Statistics Toolbox.
x = sort(x(:));
if isempty(x); v = NaN; return; end
v = x(max(1, ceil(0.9 * numel(x))));
end