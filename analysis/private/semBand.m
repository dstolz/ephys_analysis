function semBand(ax, t, m, s, color, group)
%semBand  Shaded mean +/- SEM behind a trace (opaque, so vector exports stay vector).
%   One patch per run of finite samples; the fill is COLOR blended 75% with
%   white instead of transparency. The patches are tagged "sem", with GROUP
%   (default "") as their group (tagPart).
if nargin < 6; group = ""; end
t = t(:); m = m(:); s = s(:);
ok = isfinite(t) & isfinite(m) & isfinite(s);
if ~any(ok); return; end
fillColor = color + (1 - color) * 0.75;
d = diff([false; ok; false]);
starts = find(d == 1);
stops = find(d == -1) - 1;
for k = 1:numel(starts)
    r = starts(k):stops(k);
    tagPart(patch(ax, [t(r); flipud(t(r))], [m(r) - s(r); flipud(m(r) + s(r))], fillColor, ...
        'EdgeColor', 'none', 'HandleVisibility', 'off'), "sem", group);
end
end
