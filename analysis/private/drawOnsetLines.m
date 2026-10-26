function h = drawOnsetLines(ax, O, u, mode, colors, style, spans)
%drawOnsetLines  A unit's response onset as vertical lines: one over every epoch, or each trial group's in its color.
%   H = drawOnsetLines(AX, O, U, MODE, COLORS, STYLE, SPANS) draws, for
%   unit U of O (a layer's R.onset: responseOnset's struct, the figure's
%   latency block's CUSUM onset: figureLatencies), MODE "unit" (O.onset(U),
%   over every epoch: one line in the plot's ink, dark on a light ground,
%   light on a dark one: STYLE.Design's background) or "groups" (each
%   group's O.groupOnset(:, U), in its color, COLORS(g, :)), dashed.
%   SPANS (optional) says how far up each line goes: [] (default) the
%   axes' whole height (xline); else [y0 y1] for the unit's line, or one
%   row per group (NaN: that group's line is not drawn), as a raster's rows
%   take them. A unit or group with no onset (NaN) has no line. Each line
%   is tagged "latencyOnset" with its group's label ("" for the unit's)
%   and carries appdata LatencyOnset (onset, group, settings) for its
%   data tip. H: the lines drawn.
%
%   See also responseOnset, rasterInto, drawPsthPanel, figureLatencies.
if nargin < 7; spans = []; end
h = gobjects(1, 0);
if ~isstruct(O) || ~isfield(O, 'onset') || u < 1 || u > numel(O.onset); return; end
g0 = [1 1 1];
if isfield(style, 'Design') && isfield(style.Design, 'background') && numel(style.Design.background) == 3
    g0 = style.Design.background;
end
ink = [0.2 0.2 0.2];
if mean(g0) < 0.5; ink = [0.85 0.85 0.85]; end
lw = 1;
if isfield(style, 'LineWidth') && isfinite(style.LineWidth); lw = style.LineWidth; end
if mode == "unit"
    h = one(O.onset(u), ink, "", spanOf(spans, 1));
    return
end
if mode ~= "groups" || ~isfield(O, 'groupOnset'); return; end
labels = strings(size(O.groupOnset, 1), 1);
if isfield(O, 'groups') && istable(O.groups) && height(O.groups) == numel(labels); labels = string(O.groups.label); end
for g = 1:size(O.groupOnset, 1)
    c = ink;
    if g <= size(colors, 1); c = colors(g, :); end
    h = [h one(O.groupOnset(g, u), c, labels(g), spanOf(spans, g))]; %#ok<AGROW>
end

    function hh = one(t, c, label, span)
        %one  One onset's line at T, color C, tagged with LABEL; SPAN [y0 y1] or [] (the axes' height).
        hh = gobjects(1, 0);
        if ~isfinite(t) || (~isempty(span) && ~all(isfinite(span))); return; end
        if isempty(span)
            hh = xline(ax, t, '--', 'Color', c, 'LineWidth', lw, 'HandleVisibility', 'off');
        else
            hh = line(ax, [t t], span, 'Color', c, 'LineStyle', '--', 'LineWidth', lw, 'HandleVisibility', 'off');
        end
        tagPart(hh, "latencyOnset", label);
        setappdata(hh, 'LatencyOnset', struct('onset', t, 'group', label, 'settings', O.settings));
    end
end


function s = spanOf(spans, i)
%spanOf  Row I of SPANS ([] when there are none: the axes' height).
s = [];
if isempty(spans); return; end
s = spans(min(i, size(spans, 1)), :);
end
