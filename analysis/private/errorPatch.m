function hs = errorPatch(ax, t, lo, hi, color, group, style, role, alpha)
%errorPatch  An error band between LO and HI behind a trace, drawn as patches in the plot's look.
%   HS = errorPatch(AX, T, LO, HI, COLOR, GROUP, STYLE) draws one patch per
%   run of samples where T, LO and HI are all finite, between LO and HI
%   (an errorBounds band: mean +/- SEM or SD, or a bootstrap CI), tagged
%   ROLE (default "sem") with GROUP (default "") for the aesthetics editor,
%   kept out of legends. COLOR is the trace's. Its look comes from STYLE (a
%   renderer's Style, renderStyle; a field it lacks takes the default):
%     ErrorFaceColor  "" (default): the trace's COLOR; else a color (name,
%                     #rrggbb)
%     ErrorFaceAlpha  NaN (default): opaque -- the trace's color paled 75%
%                     towards the ground (paleColor: white, or the design's
%                     background), so vector exports stay vector; a face
%                     color given is drawn as given. 0-1: that opacity, the
%                     face color unpaled (what is under it shows through)
%     ErrorEdgeColor  "none" (default) | "auto" (the face color, unpaled) |
%                     a color
%     ErrorEdgeStyle  the edge's line style: "-" (default), "--", ":", "-."
%     ErrorEdgeWidth  the edge's width, points (default 0.5)
%   ALPHA (optional, 0-1) is the opacity used instead of an opaque band
%   when ErrorFaceAlpha is NaN: a band drawn over other data (an aux signal
%   on a PSTH's right axis) must not hide it. A color that is not one, an
%   opacity outside 0-1, a style or width that is not valid fall back to
%   the defaults (Validate reports them). HS: the patches drawn.
%
%   See also errorBounds, semBand, PlotAesthetics.

if nargin < 6; group = ""; end
if nargin < 7; style = struct(); end
if nargin < 8 || string(role) == ""; role = "sem"; end
if nargin < 9; alpha = NaN; end
hs = gobjects(1, 0);
t = double(t(:)); lo = double(lo(:)); hi = double(hi(:));
ok = isfinite(t) & isfinite(lo) & isfinite(hi);
if ~any(ok); return; end
L = lookOf(color, style, alpha);
d = diff([false; ok; false]);
starts = find(d == 1);
stops = find(d == -1) - 1;
for k = 1:numel(starts)
    r = starts(k):stops(k);
    hs(end+1) = tagPart(patch(ax, [t(r); flipud(t(r))], [lo(r); flipud(hi(r))], 'k', 'FaceColor', L.face, ...
        'FaceAlpha', L.alpha, 'EdgeColor', L.edge, 'LineStyle', L.lineStyle, 'LineWidth', L.lineWidth, ...
        'HandleVisibility', 'off'), role, group); %#ok<AGROW>
end
end


function L = lookOf(color, style, alpha)
%lookOf  The band's face color and opacity, edge color, style and width from STYLE's Error* fields.
d = EphysAnalysisConfig.defaults("Style");
f = @(name) fieldOr(style, name, d.(name));
faceName = strtrim(string(f('ErrorFaceColor')));
a = double(f('ErrorFaceAlpha'));
base = color;
given = faceName ~= "";
if given
    c = colorOr(faceName, []);
    if isempty(c); given = false; else; base = c; end
end
if isscalar(a) && isfinite(a)
    L.face = base;
    L.alpha = min(1, max(0, a));
elseif isscalar(alpha) && isfinite(alpha)
    L.face = base;
    L.alpha = min(1, max(0, alpha));
elseif given
    L.face = base;
    L.alpha = 1;
else
    L.face = paleColor(base, 0.75, style);
    L.alpha = 1;
end
edgeName = lower(strtrim(string(f('ErrorEdgeColor'))));
switch edgeName
    case {"none", ""}
        L.edge = 'none';
    case "auto"
        L.edge = base;
    otherwise
        L.edge = colorOr(edgeName, 'none');
end
L.lineStyle = char(d.ErrorEdgeStyle);
ls = string(f('ErrorEdgeStyle'));
if ismember(ls, EphysAnalysisConfig.OverlayLineStyles); L.lineStyle = char(ls); end
L.lineWidth = d.ErrorEdgeWidth;
w = double(f('ErrorEdgeWidth'));
if isscalar(w) && isfinite(w) && w > 0; L.lineWidth = w; end
end


function v = fieldOr(s, name, default)
%fieldOr  S.(NAME), or DEFAULT when S lacks it.
v = default;
if isstruct(s) && isfield(s, name); v = s.(name); end
end


function c = colorOr(name, fallback)
%colorOr  The RGB row of a color name or #rrggbb; FALLBACK when it is neither.
try
    c = validatecolor(char(name));
catch
    c = fallback;
end
end
