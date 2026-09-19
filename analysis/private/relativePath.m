function r = relativePath(fromFolder, file)
%relativePath  FILE relative to FROMFOLDER, with "/" separators (for links).
%   Falls back to a file:/// URL when the two are on different drives.
a = split(strip(replace(string(fromFolder), "\", "/"), "right", "/"), "/");
b = split(replace(string(file), "\", "/"), "/");
if isempty(a) || isempty(b) || ~strcmpi(a(1), b(1))
    r = "file:///" + replace(string(file), "\", "/");
    return
end
n = 0;
while n < min(numel(a), numel(b) - 1) && strcmpi(a(n + 1), b(n + 1))
    n = n + 1;
end
up = repmat("..", numel(a) - n, 1);
r = strjoin([up; b(n+1:end)], "/");
end
