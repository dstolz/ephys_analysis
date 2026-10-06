function D = matchFiles(D, patterns)
%matchFiles  The entries of a dir struct whose name matches a wildcard.
%   D = matchFiles(D, PATTERNS) keeps the elements of the dir struct D
%   whose name matches any of the dir wildcards PATTERNS ("*" any run of
%   characters, "?" one character), matched against the whole name and
%   ignoring case on Windows, as dir does there.
%
%   See also listTree, dir.

arguments
    D struct
    patterns (1,:) string
end

if isempty(D) || isempty(patterns)
    D = D([]);
    return
end
rx = arrayfun(@(p) string(regexptranslate('escape', char(p))), patterns);
rx = replace(rx, ["\*" "\?"], [".*" "."]);
rx = char("^(" + strjoin(rx, "|") + ")$");
if ispc
    hit = regexpi({D.name}, rx, 'once');
else
    hit = regexp({D.name}, rx, 'once');
end
D = D(~cellfun('isempty', hit));
end
