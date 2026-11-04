function hs = errorPatch(ax, t, lo, hi, color, group, style, role, band)
%errorPatch  An error band between LO and HI behind a trace, drawn as patches in the plot's look.
%   HS = errorPatch(AX, T, LO, HI, COLOR, GROUP, STYLE, ROLE, BAND) draws
%   one patch per run of samples where T, LO and HI are all finite,
%   between LO and HI (an errorBounds band: mean +/- SEM or SD, or a
%   bootstrap CI), tagged ROLE (default "sem") with GROUP (default "") for
%   the aesthetics editor, kept out of legends. COLOR is the trace's.
%   STYLE (a renderer's Style, renderStyle) gives the ground the band is
%   paled towards. Its look comes from BAND (a figure panel's
%   options.band, a renderer's Band: EphysAnalysisConfig.defaults
%   ("ErrorBand"); a field it lacks, or BAND left out, takes the default):
%     faceColor  "" (default): the trace's COLOR; else a color (name,
%                #rrggbb)
%     faceAlpha  NaN (default): opaque -- the trace's color paled 75%
%                towards the ground (paleColor: white, or the design's
%                background), so vector exports stay vector; a face color
%                given is drawn as given. 0-1: that opacity, the face
%                color unpaled (what is under it shows through)
%     edgeColor  "none" (default) | "auto" (the face color, unpaled) | a
%                color
%     edgeStyle  the edge's line style: "-" (default), "--", ":", "-."
%     edgeWidth  the edge's width, points (default 0.5)
%   A color that is not one, an opacity outside 0-1, a style or width that
%   is not valid fall back to the defaults (validate reports them). HS:
%   the patches drawn.
%
%   See also errorBounds, resultBounds, PlotAesthetics.

if nargin < 6; group = ""; end
if nargin < 7; style = struct(); end
if nargin < 8 || string(role) == ""; role = "sem"; end
if nargin < 9; band = struct(); end
hs = gobjects(1, 0);
t = double(t(:)); lo = double(lo(:)); hi = double(hi(:));
ok = isfinite(t) & isfinite(lo) & isfinite(hi);
if ~any(ok); return; end
L = lookOf(color, style, band);
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


function L = lookOf(color, style, band)
%lookOf  The band's face color and opacity, edge color, style and width from BAND (the ground from STYLE).
d = EphysAnalysisConfig.defaults("ErrorBand");
f = @(name) fieldOr(band, name, d.(name));
faceName = strtrim(string(f('faceColor')));
a = double(f('faceAlpha'));
base = color;
given = faceName ~= "";
if given
    c = colorOr(faceName, []);
    if isempty(c); given = false; else; base = c; end
end
if isscalar(a) && isfinite(a)
    L.face = base;
    L.alpha = min(1, max(0, a));
elseif given
    L.face = base;
    L.alpha = 1;
else
    L.face = paleColor(base, 0.75, style);
    L.alpha = 1;
end
edgeName = lower(strtrim(string(f('edgeColor'))));
switch edgeName
    case {"none", ""}
        L.edge = 'none';
    case "auto"
        L.edge = base;
    otherwise
        L.edge = colorOr(edgeName, 'none');
end
L.lineStyle = char(d.edgeStyle);
ls = string(f('edgeStyle'));
if ismember(ls, EphysAnalysisConfig.OverlayLineStyles); L.lineStyle = char(ls); end
L.lineWidth = d.edgeWidth;
w = double(f('edgeWidth'));
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
    c = namedColor(name);
catch
    c = fallback;
end
end
