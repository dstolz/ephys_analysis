function [sz, ok] = figureSizeParse(txt, units)
%figureSizeParse  A page size typed or picked: "6 x 4 in", "1200x800 px", "15 x 10", a suggestion's label.
%   [SZ, OK] = figureSizeParse(TXT, UNITS) reads TXT as the Figures tab's
%   Size drop-down takes it: one of figureSizePresets' labels (a size of
%   its own), else "<width> x <height> [unit]" -- the separator x, X, the
%   multiplication sign or *, the unit px, in (inch, inches, "), cm or mm
%   (kept in cm), UNITS (default "cm") when none is typed. SZ is a struct
%   of width, height and units ("px", "in" or "cm"), OK true; for text it
%   cannot read SZ is [] and OK false. The labels "Export tab size" and
%   "Fit preview" have no size of their own: not read here (OK false).
%
%   See also figureSizePresets, figureSizeText, figureExportSize.
arguments
    txt (1,1) string
    units (1,1) string = "cm"
end
sz = [];
ok = false;
txt = strtrim(txt);
T = figureSizePresets();
i = find(lower(T.Label) == lower(txt), 1);
if ~isempty(i)
    if isfinite(T.Width(i))
        sz = struct('width', T.Width(i), 'height', T.Height(i), 'units', T.Units(i));
        ok = true;
    end
    return
end
num = '(\d+\.?\d*|\.\d+)';
tok = regexp(char(txt), ['^' num '\s*(?:x|X|\x{D7}|\*)\s*' num '\s*(px|pixels?|in|inch|inches|"|cm|mm)?$'], 'tokens', 'once');
if isempty(tok); return; end
w = str2double(tok{1});
h = str2double(tok{2});
u = lower(string(tok{3}));
switch u
    case ""
        u = units;
    case {"px" "pixel" "pixels"}
        u = "px";
    case {"in" "inch" "inches" """"}
        u = "in";
    case "mm"
        u = "cm";
        w = w / 10;
        h = h / 10;
end
if ~ismember(u, EphysAnalysisConfig.FigureSizeUnits) || ~(w > 0 && h > 0 && isfinite(w) && isfinite(h)); return; end
sz = struct('width', w, 'height', h, 'units', u);
ok = true;
end
