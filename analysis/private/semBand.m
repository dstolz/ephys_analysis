function semBand(ax, t, m, s, color, group, style)
%semBand  Shaded mean +/- S behind a trace: errorPatch between M - S and M + S.
%   semBand(AX, T, M, S, COLOR, GROUP, STYLE) is errorPatch(AX, T, M - S,
%   M + S, COLOR, GROUP, STYLE): one patch per run of finite samples,
%   tagged "sem" with GROUP (default ""), in STYLE's band look (by default
%   COLOR blended 75% with the ground, opaque, so vector exports stay
%   vector).
%
%   See also errorPatch, errorBounds.
if nargin < 6; group = ""; end
if nargin < 7; style = struct(); end
m = m(:); s = s(:);
errorPatch(ax, t, m - s, m + s, color, group, style);
end
