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
%   and, for every events layer drawn as a span (R.spans: epochIntervals'),
%     a span line per trial group in GROUPS from the median onset to the
%       median offset over the group's epochs (each epoch's first interval
%       starting at or after 0, else its last one before 0), clipped to the
%       window, under the rug, each group a level lower, in the layer's
%       EventMark look (spanStyle, spanWidth, spanAlpha; its color, or
%       with COLORBY "group" and no color of its own the group's), tagged
%       "eventSpan" with the layer's label
%   Call it once the y limits are final: it fixes them (the rug is drawn in
%   data units inside them). HS: the rugs and a span entry per span layer
%   (the legend's entries), LABELS: their labels.
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
spans = idx(arrayfun(@(j) isfield(P.layers(j).R, 'spans'), idx));
if isempty(marks) && isempty(spans); return; end
mk = [];
if ~isempty(marks); mk = rasterMarkLooks(specs, [marks.label]); end
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

% the spans: a line per group from its median onset to its median offset, a level each under the rug
down = 1 - 2 * strcmp(ax.YDir, 'reverse');   % from the top as seen
top = yl(1 + (down > 0));
level = 0;
for q = 1:numel(spans)
    j = spans(q);
    S = P.layers(j).R.spans;
    ev = Ls(j).event;
    c0 = rasterMarkColor(ev.color, numel(marks) + q);   % after the marks' automatic colors
    sty = {'LineStyle', char(ev.spanStyle), 'LineWidth', ev.spanWidth, 'HandleVisibility', 'off'};
    ep = double(S.epoch(:));
    for gg = reshape(groups, 1, [])
        sel = true(size(ep));
        if ~isempty(gi)
            ok = ep >= 1 & ep <= numel(gi);
            sel = ok;
            sel(ok) = gi(ep(ok)) == gg;
        end
        [a, b] = spanOf(S.on(sel), S.off(sel), ep(sel));
        a = max(a, W(1));
        b = min(b, W(2));
        if ~(isfinite(a) && isfinite(b) && b >= a); continue; end
        level = level + 1;
        y = top - down * (0.06 + 0.035 * level) * diff(yl);
        c = c0;
        if colorBy == "group" && ev.color == "" && gg <= size(look.colors, 1); c = look.colors(gg, :); end
        tagPart(line(ax, [a b], [y y], 'Color', [c ev.spanAlpha], sty{:}), "eventSpan", S.label);
    end
    hs(end+1) = tagPart(line(ax, NaN, NaN, 'Color', [c0 ev.spanAlpha], sty{1:4}), "eventSpan", S.label); %#ok<AGROW>
    labels(end+1) = S.label; %#ok<AGROW>
end
end


function [a, b] = spanOf(on, off, ep)
%spanOf  The median onset and median offset over epochs of each epoch's first interval at or after 0 (else its last before 0).
a = NaN; b = NaN;
if isempty(on); return; end
pick = zeros(0, 1);
for e = reshape(unique(ep), 1, [])
    k = find(ep == e);
    after = k(on(k) >= 0);
    if isempty(after)
        [~, i] = max(on(k));
        pick(end+1, 1) = k(i); %#ok<AGROW>
    else
        [~, i] = min(on(after));
        pick(end+1, 1) = after(i); %#ok<AGROW>
    end
end
a = median(on(pick));
b = median(off(pick));
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
