function [shank, x, y] = probeSites(probe, ch)
%probeSites  Shank and site position of recording channels from a probe map.
%   [SHANK, X, Y] = probeSites(PROBE, CH) looks up the 1-based recording
%   channels CH in the probe map PROBE (chanMap 0-based, xc, yc, kcoords):
%   shank 0 and NaN positions where the map has no such channel or there is
%   no map.

n = numel(ch);
shank = zeros(n, 1); x = NaN(n, 1); y = NaN(n, 1);
if isempty(probe) || ~isstruct(probe) || ~all(isfield(probe, {'chanMap', 'xc', 'yc'}))
    return
end
cm = double(probe.chanMap(:)) + 1;
xc = double(probe.xc(:)); yc = double(probe.yc(:));
kc = zeros(size(cm));
if isfield(probe, 'kcoords'); kc = double(probe.kcoords(:)); end
for j = 1:n
    s = find(cm == ch(j), 1);
    if ~isempty(s) && s <= numel(xc)
        x(j) = xc(s); y(j) = yc(s);
        if s <= numel(kc); shank(j) = kc(s); end
    end
end
end
