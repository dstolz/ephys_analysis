function name = overlayFreeName(items, first, stem)
%overlayFreeName  A name no overlay of ITEMS has: FIRST, else STEM 2, STEM 3, ...
%   Names tell the aesthetics editor's rules which overlay is meant, so the
%   editor gives each new overlay one of its own (a copy: "<name> copy").
used = strings(1, numel(items));
for k = 1:numel(items)
    used(k) = strtrim(string(items(k).name));
end
name = string(first);
n = 1;
while ismember(name, used)
    n = n + 1;
    name = string(stem) + " " + n;
end
end
