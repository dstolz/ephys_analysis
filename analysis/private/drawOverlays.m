function O = drawOverlays(h, overlays)
%drawOverlays  A plot's overlay graphics: lines and patches in data units (renderPlot).
%   O = drawOverlays(H, OVERLAYS) draws the enabled entries of OVERLAYS (a
%   plot's overlays, a struct array of defaults("Overlay")) on the axes a
%   renderer drew: H.axes (a PSTH's rate panels, a trace, a heat map, ...)
%   and H.rasterAxes (a PSTH's rasters). An overlay's panel picks the axes
%   it goes on: "all", "data" (the axes tagged "axes") or "raster" (those
%   tagged "rasterAxes"; a raster plot's own axes are rasters); it is
%   drawn in each of them.
%
%   A line (xline / yline) crosses the whole axis at its value, so over a
%   raster it crosses every row, and over a PSTH panel its full height. A
%   region (xregion / yregion) is a patch between its two values, the full
%   height or width of the axis; the semitransparent fill is its faceAlpha.
%   Both follow the axes' limits when they change. The values are data
%   units: seconds from the event on a time axis, a unit's rate on a PSTH's
%   y axis, a raster's epoch number on its y axis. A stacked PSTH's second
%   y axis is left alone: a y overlay goes on its left axis. Like any
%   constant line, an overlay does not widen the axes' automatic limits.
%
%   The layer says whether an overlay sits "over" the data (drawn after it)
%   or "under" it (behind its lines, points, bars and bands, which hide it
%   where they are opaque): the axes' draw order is set to their child
%   order (SortMethod "childorder"), with the overlays moved to the front
%   or the back of it. Later overlays of one layer sit over earlier ones.
%
%   Each is tagged with the role "overlayLine" or "overlayRegion" and the
%   overlay's name (else "Overlay <n>", n its place in OVERLAYS) as its
%   group, so the aesthetics editor and its rules reach it on its own; they
%   have no handle visibility, like the other lines the renderers add. A
%   region does not take clicks (PickableParts "none"), so a right-click on
%   the plot still reaches the data under it; the aesthetics editor lists
%   the region with the plot's other components all the same. A design
%   saved from a plot (PlotDesign.capture) leaves the overlays out.
%
%   O.handles are the objects drawn; O.rules the overlays' own looks as
%   aesthetics rules (renderPlot applies them after the design's and the
%   user's, so they win over a design). A colour that is not one, an
%   opacity outside 0-1, a line style or width that is not valid are
%   replaced by the default's in the drawing (validate reports them); an
%   overlay with a non-finite position, or a region whose edges are equal,
%   is not drawn. Overlays that are disabled draw nothing. A partial overlay
%   struct is completed from the defaults.
%
%   See also renderPlot, drawNote, EphysAnalysisConfig.defaults, PlotAesthetics.

O = struct('handles', gobjects(1, 0), 'rules', PlotAesthetics.emptyRules());
if isempty(overlays); return; end
axs = gobjects(1, 0);
for f = ["axes" "rasterAxes"]
    if isfield(h, f); axs = [axs, reshape(h.(f), 1, [])]; end %#ok<AGROW>
end
axs = axs(isgraphics(axs));
if isempty(axs); return; end
raster = arrayfun(@(a) strcmp(a.Tag, 'rasterAxes'), axs);
front = repmat({gobjects(1, 0)}, 1, numel(axs));
back = front;
def = EphysAnalysisConfig.defaults("Overlay");
for k = 1:numel(overlays)
    ov = EphysAnalysisConfig.coerceStruct(def, overlays(k), "overlays(" + k + ")");   % complete, typed
    if ~ov.enabled; continue; end
    pos = positionOf(ov);
    if isempty(pos); continue; end
    label = strtrim(string(ov.name));
    if label == ""; label = "Overlay " + k; end
    role = "overlayLine";
    if ov.shape == "region"; role = "overlayRegion"; end
    look = lookOf(ov);
    for a = find(panelMask(string(ov.panel), raster))
        g = drawOne(axs(a), ov, pos);
        tagPart(g, role, label);
        for p = string(fieldnames(look)).'
            PlotAesthetics.setValue(g, p, look.(p));
        end
        if ov.layer == "under"
            back{a}(end+1) = g;
        else
            front{a}(end+1) = g;
        end
        O.handles(end+1) = g;
    end
    for p = string(fieldnames(look)).'
        O.rules(1, end+1) = struct('role', role, 'group', label, 'property', p, 'value', look.(p));
    end
end
for a = 1:numel(axs)
    stack(axs(a), front{a}, back{a});
end
end


function pos = positionOf(ov)
%positionOf  The value of a line, the sorted edges of a region; [] when it cannot be drawn.
pos = [];
if ov.shape == "region"
    p = [ov.from ov.to];
    if all(isfinite(p)) && p(1) ~= p(2); pos = sort(p); end
elseif isfinite(ov.value)
    pos = ov.value;
end
end


function use = panelMask(panel, raster)
%panelMask  Which of the axes (RASTER: those that are rasters) an overlay's PANEL names.
switch panel
    case "data",   use = ~raster;
    case "raster", use = raster;
    otherwise,     use = true(size(raster));   % "all"
end
end


function g = drawOne(ax, ov, pos)
%drawOne  The line or region on axes AX, with no look yet.
side = '';
if ov.axis == "y" && numel(ax.YAxis) > 1
    side = ax.YAxisLocation;   % a yyaxis: the side drawn on now
    yyaxis(ax, 'left');
end
restore = onCleanup(@() restoreSide(ax, side)); %#ok<NASGU>
if ov.shape == "region"
    if ov.axis == "y"
        g = yregion(ax, pos(1), pos(2), 'HandleVisibility', 'off');
    else
        g = xregion(ax, pos(1), pos(2), 'HandleVisibility', 'off');
    end
elseif ov.axis == "y"
    g = yline(ax, pos, 'HandleVisibility', 'off');
else
    g = xline(ax, pos, 'HandleVisibility', 'off');
end
if ov.shape == "region"
    g.PickableParts = 'none';   % a patch over the whole axis would take every right-click from the data under it
end
end


function restoreSide(ax, side)
%restoreSide  Make SIDE ('left' / 'right') of a yyaxis the active one again.
if ~isempty(side) && isgraphics(ax) && numel(ax.YAxis) > 1
    yyaxis(ax, side);
end
end


function stack(ax, front, back)
%stack  Put the overlays FRONT at the front of AX's draw order and BACK at the back.
if isempty(front) && isempty(back); return; end
ax.SortMethod = 'childorder';   % the draw order is the Children's, first on top
shown = get(groot, 'ShowHiddenHandles');
set(groot, 'ShowHiddenHandles', 'on');   % so Children lists the lines the renderers hid, and the overlays
restore = onCleanup(@() set(groot, 'ShowHiddenHandles', shown)); %#ok<NASGU>
kids = ax.Children;
isFront = memberOf(kids, front);
isBack = memberOf(kids, back);
try
    ax.Children = [kids(isFront); kids(~isFront & ~isBack); kids(isBack)];
catch ME
    warning('drawOverlays:Order', 'Cannot put the overlays over or under the data of an axes: %s', ME.message);
end
end


function tf = memberOf(kids, these)
%memberOf  Which of the graphics objects KIDS are among THESE.
tf = false(size(kids));
if isempty(these); return; end
for i = 1:numel(kids)
    tf(i) = any(kids(i) == these);
end
end


function L = lookOf(ov)
%lookOf  An overlay's look as aesthetics properties (PlotAesthetics' names), invalid values given the default's.
d = EphysAnalysisConfig.defaults("Overlay");
L = struct();
if ov.shape == "region"
    L.FaceColor = colorOf(ov.faceColor, d.faceColor);
    L.FaceAlpha = opacityOf(ov.faceAlpha, d.faceAlpha);
    if lower(strtrim(string(ov.edgeColor))) == "none"
        L.EdgeColor = "none";
    else
        L.EdgeColor = colorOf(ov.edgeColor, d.edgeColor);
    end
else
    L.Color = colorOf(ov.color, d.color);
    L.Alpha = opacityOf(ov.alpha, d.alpha);
end
L.LineStyle = d.lineStyle;
if ismember(ov.lineStyle, EphysAnalysisConfig.OverlayLineStyles); L.LineStyle = ov.lineStyle; end
L.LineWidth = d.lineWidth;
if isfinite(ov.lineWidth) && ov.lineWidth > 0; L.LineWidth = ov.lineWidth; end
end


function c = colorOf(name, fallback)
%colorOf  The colour a name or #rrggbb gives as an RGB row; the FALLBACK's when it is neither ("none" is no colour).
try
    c = validatecolor(strtrim(string(name)));
catch
    if lower(strtrim(string(fallback))) == "none"
        c = "none";
    else
        c = validatecolor(fallback);
    end
end
end


function a = opacityOf(a, fallback)
%opacityOf  An opacity within 0-1; the FALLBACK when it is not a number.
if ~isfinite(a); a = fallback; end
a = min(1, max(0, a));
end
