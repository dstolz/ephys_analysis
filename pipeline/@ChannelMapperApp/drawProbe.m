function drawProbe(obj)
%drawProbe  The probe's sites by shank, labelled as Label sites by says.
%   Sites that do not reach a recorded channel are grey x. Clicking a
%   site (or near one) selects it. The selection ring (obj.SelMarker) is
%   made here once and moved by applySelection.
ax = obj.ProbeAxes;
legend(ax, 'off');
delete(allchild(ax));   % cla keeps objects hidden from the legend (the labels, the ring)
hold(ax, 'on');
obj.SelMarker = line(ax, NaN, NaN, 'LineStyle', 'none', 'Marker', 'o', 'MarkerSize', 17, ...
    'LineWidth', 2.5, 'Color', [0.95 0.5 0], 'HitTest', 'off', 'PickableParts', 'none', 'HandleVisibility', 'off');
obj.ProbeSites = struct('X', [], 'Y', [], 'Site', []);
ax.ButtonDownFcn = @(~, evt) obj.onProbeClick(evt);
R = obj.Result;
if isempty(R) || all(isnan(R.Table.X))
    hold(ax, 'off');
    axis(ax, 'off');
    text(ax, 0.5, 0.5, {'Choose a probe design', 'to see its sites'}, 'Units', 'normalized', ...
        'HorizontalAlignment', 'center', 'Color', [0.45 0.45 0.45], 'FontSize', 12, 'HitTest', 'off');
    return
end
axis(ax, 'on');
T = R.Table;
x = T.X; y = T.Y;
obj.ProbeSites = struct('X', x, 'Y', y, 'Site', T.Site);
ok = T.Flag == "";
shanks = unique(T.Shank(~isnan(T.Shank)));
cmap = lines(max(numel(shanks), 1));
click = @(~, evt) obj.onProbeClick(evt);
hs = gobjects(0);
for s = 1:numel(shanks)
    m = T.Shank == shanks(s) & ok;
    if ~any(m); continue; end
    hs(end + 1) = scatter(ax, x(m), y(m), 46, cmap(s, :), 'filled', 'MarkerEdgeColor', [0.15 0.15 0.15], ...
        'DisplayName', sprintf('shank %g', shanks(s)), 'ButtonDownFcn', click); %#ok<AGROW>
end
if any(~ok)
    hs(end + 1) = scatter(ax, x(~ok), y(~ok), 60, [0.5 0.5 0.5], 'x', 'LineWidth', 1.8, ...
        'DisplayName', 'not recorded', 'ButtonDownFcn', click);
end

% axis equal on a tall, thin probe leaves little width: pad x by the
% height too, so the labels to the right of the sites have room
ext = max([range(x), range(y), 60]);
switch string(obj.LabelModeDrop.Value)
    case "site"
        lab = string(T.Site);
    case "row1"
        lab = string(T.RecordingRow1);
    case "hardware"
        lab = string(T.HardwareChannel);
    otherwise
        lab = strings(0, 1);
end
if ~isempty(lab)
    lab(ismissing(lab) | lab == "NaN") = "";
    text(ax, x + 0.02 * ext, y, lab, 'FontSize', 8, 'Clipping', 'on', 'HitTest', 'off', 'PickableParts', 'none', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'HandleVisibility', 'off');
end
uistack(obj.SelMarker, 'top');
hold(ax, 'off');

padX = max([0.10 * range(x), 0.10 * ext, 25]);
padY = max(0.04 * max(range(y), 1), 15);
axis(ax, 'equal');
xlim(ax, [min(x) - padX, max(x) + padX]);
ylim(ax, [min(y) - padY, max(y) + padY]);
box(ax, 'on');
grid(ax, 'on');
ax.GridAlpha = 0.2;
xlabel(ax, 'x (\mum)');
ylabel(ax, 'y (\mum, from the tip)');
if numel(hs) > 1
    lg = legend(ax, hs, 'Location', 'southoutside', 'Orientation', 'horizontal');
    lg.NumColumns = min(numel(hs), 5);
    lg.HitTest = 'off';
end
end
