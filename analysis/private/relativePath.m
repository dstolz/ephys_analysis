function r = relativePath(fromFolder, file)
%relativePath  A link from FROMFOLDER to FILE: relative, "/" separated, percent-encoded.
%   Both are made absolute first (a relative path is from pwd, "." and ".."
%   resolved). On another drive or share the link is a file:// URL. Each
%   path segment is percent-encoded as UTF-8 (every byte but A-Z a-z 0-9
%   - . _ ~), so "#", "%", "?" or a space in a folder name keep the link
%   whole.
a = segments(fromFolder);
b = segments(file);
if ~strcmpi(a(1), b(1))
    if startsWith(b(1), "//")   % a share: file://server/share/...
        r = "file:" + b(1) + "/" + strjoin(arrayfun(@encode, b(2:end)), "/");
    elseif endsWith(b(1), ":")   % a drive: file:///C:/...
        r = "file:///" + b(1) + "/" + strjoin(arrayfun(@encode, b(2:end)), "/");
    else
        r = "file:///" + strjoin(arrayfun(@encode, b), "/");
    end
    return
end
n = 0;
while n < min(numel(a), numel(b) - 1) && strcmpi(a(n + 1), b(n + 1))
    n = n + 1;
end
up = repmat("..", numel(a) - n, 1);
r = strjoin([up; arrayfun(@encode, b(n+1:end))], "/");
end


function s = segments(p)
%segments  The absolute path P as its segments: a drive ("C:"), a share
%   ("//server"), or a POSIX path's first folder, then the rest.
p = replace(string(p), "\", "/");
if ~(startsWith(p, "/") || ~isempty(regexp(p, '^[A-Za-z]:', 'once')))
    p = replace(string(pwd), "\", "/") + "/" + p;
end
share = startsWith(p, "//");
parts = split(p, "/");
s = strings(0, 1);
for x = parts(parts ~= "" & parts ~= ".").'
    if x == ".." && numel(s) > 1
        s(end) = [];
    elseif x ~= ".."
        s(end+1, 1) = x; %#ok<AGROW>
    end
end
if share; s(1) = "//" + s(1); end
end


function e = encode(seg)
%encode  Percent-encode one path segment (UTF-8; A-Z a-z 0-9 - . _ ~ kept).
b = unicode2native(char(seg), 'UTF-8');
keep = (b >= '0' & b <= '9') | (b >= 'A' & b <= 'Z') | (b >= 'a' & b <= 'z') | ismember(b, uint8('-._~'));
c = cell(1, numel(b));
c(keep) = num2cell(char(b(keep)));
c(~keep) = arrayfun(@(x) sprintf('%%%02X', x), b(~keep), 'UniformOutput', false);
e = string([c{:}]);
end
