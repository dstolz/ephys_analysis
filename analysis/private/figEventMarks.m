function [hs, labels] = figEventMarks(ax, P, look, groups, colorBy)
%figEventMarks  A figure panel's events-marks layers as latency lines and a rug along the top edge.
%   [HS, LABELS] = figEventMarks(AX, P, LOOK, GROUPS, COLORBY) draws, for
%   every mark of the panel's events layers drawn as marks (P.layers(j).R
%   of kind "events": epochEvents' marks, each with its epochs and times
%   from the epoch's event), on a PSTH, continuous or heat map panel:
%     a latency line per trial group in GROUPS (rows of the panel's groups;
%       LOOK.epochs' groupIndex says each epoch's): an xline at the median
%       over the group's epochs of each epoch's first event at or after 0
%       (all its events when none is), tagged "eventLine" with the mark's
%       label; COLORBY "group": in the group's color (LOOK.colors), "mark":
%       in the mark's color (rasterMarkLooks of the layer's EventMark)
%     a rug: every event of those epochs inside the panel's window
%       (LOOK.W) as a short tick along the top edge of the axes (the top as
%       seen, whatever YDir), one line object per mark in its color, tagged
%       "eventRug" with the mark's label
%   Call it once the y limits are final: it fixes them (the rug is drawn in
%   data units inside them). HS: the rugs (the legend's entries), LABELS:
%   their marks' labels.
%
%   See also drawPsthPanel, drawContinuousPanel, drawHeatmapPanel, epochEvents.
hs = gobjects(1, 0);
labels = strings(1, 0);
idx = find(arrayfun(@(l) l.skip == "" && isstruct(l.R) && isfield(l.R, 'kind') && l.R.kind == "events", P.layers));
if isempty(idx); return; end
Ls = look.panel.layers;
marks = [];
specs = [];
for j = idx
    M = P.layers(j).R.marks;
    if isempty(M); continue; end
    marks = [marks reshape(M, 1, [])]; %#ok<AGROW>
    specs = [specs repmat(Ls(j).event, 1, numel(M))]; %#ok<AGROW>
end
if isempty(marks); return; end
mk = rasterMarkLooks(specs, [marks.label]);
gi = [];
E = look.epochs;
if istable(E) && ismember("groupIndex", string(E.Properties.VariableNames)); gi = double(E.groupIndex(:)); end
W = look.W;
if numel(W) ~= 2; W = xlim(ax); end
yl = ylim(ax);
ylim(ax, yl);
h = 0.06 * diff(yl);
if strcmp(ax.YDir, 'reverse')
    y01 = [yl(1); yl(1) + h];
else
    y01 = [yl(2) - h; yl(2)];
end
if isempty(gi); groups = groups(1:min(1, end)); end   % no groups known: one line over every epoch
for m = 1:numel(marks)
    ev = marks(m);
    t = double(ev.t(:));
    ep = double(ev.epoch(:));
    g = NaN(size(ep));
    if ~isempty(gi)
        ok = ep >= 1 & ep <= numel(gi);
        g(ok) = gi(ep(ok));
    end
    for gg = reshape(groups, 1, [])
        sel = true(size(t));
        if ~isempty(gi); sel = g == gg; end
        lat = latencyOf(t(sel), ep(sel));
        if ~(isfinite(lat) && lat >= W(1) && lat <= W(2)); continue; end
        c = mk(m).color;
        if colorBy == "group" && gg <= size(look.colors, 1); c = look.colors(gg, :); end
        tagPart(xline(ax, lat, '-.', 'Color', c, 'LineWidth', 1, 'HandleVisibility', 'off'), "eventLine", ev.label);
    end
    in = t >= W(1) & t <= W(2);
    if ~isempty(gi); in = in & ismember(g, groups); end
    n = nnz(in);
    X = [t(in) t(in) NaN(n, 1)].';
    Y = repmat([y01; NaN], 1, n);
    hs(end+1) = tagPart(line(ax, X(:), Y(:), 'Color', mk(m).color, 'LineWidth', 0.75), "eventRug", ev.label); %#ok<AGROW>
    labels(end+1) = ev.label; %#ok<AGROW>
end
end


function lat = latencyOf(t, ep)
%latencyOf  The median over epochs of each epoch's first event at or after 0 (all events' median when none is).
lat = NaN;
if isempty(t); return; end
after = t >= 0;
if any(after)
    first = accumarray(findgroups(ep(after)), t(after), [], @min);
    lat = median(first);
else
    lat = median(t);
end
end
