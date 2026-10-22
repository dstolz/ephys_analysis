function c = namedColor(spec)
%namedColor  The RGB row of a color name or #RRGGBB code; an error for anything else.
%   Like validatecolor, which knows only red, green, blue, cyan, magenta,
%   yellow, black and white (and their letters) and the hex codes, plus
%   "gray" and "grey" ([0.5 0.5 0.5]), which the figure editor's color lists
%   offer. A color field that is not a name or code is the caller's to catch.
spec = strtrim(string(spec));
if isscalar(spec) && any(lower(spec) == ["gray" "grey"])
    c = [0.5 0.5 0.5];
else
    c = validatecolor(char(spec));
end
end
