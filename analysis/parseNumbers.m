function v = parseNumbers(txt, name, opts)
%parseNumbers  Numbers typed in a field: "1:4", "1 3", "[-1 -0.5]", "1, 2", "1:2:7" (blank = []); never eval.
%   V = parseNumbers(TXT, NAME) reads TXT as a row of numbers: single
%   values and ranges a:b or a:step:b, apart by spaces, commas or
%   semicolons, brackets ignored. Blank text gives [] (= all, or none, as
%   a settings file gives it back). Anything else raises
%   parseNumbers:BadValue, its message starting with NAME (the field's
%   name), e.g. 'Channels: "x" is not a number or a range a:b.'.
%   ErrorId=ID raises ID instead (the dataset browser's
%   DatasetBrowser:BadValue).
%
%   numbersText writes a row back so that parseNumbers reads it again.
%
%   See also numbersText, DatasetBrowser, ProbePickDialog.
arguments
    txt
    name (1,1) string = "Value"
    opts.ErrorId (1,1) string = "parseNumbers:BadValue"
end
t = strtrim(string(txt));
v = [];   % blank: [] (= all / none), as a settings file gives it back
if t == ""; return; end
v = zeros(1, 0);
t = regexprep(t, '[\[\]\(\)]', ' ');
t = regexprep(t, '[,;]', ' ');
t = regexprep(t, '\s*:\s*', ':');
parts = split(strtrim(t));
for p = reshape(parts(parts ~= ""), 1, [])
    q = split(p, ":");
    x = str2double(q);
    if any(isnan(x)) || numel(q) > 3
        error(char(opts.ErrorId), '%s: "%s" is not a number or a range a:b.', name, p);
    end
    switch numel(q)
        case 1; v = [v x]; %#ok<AGROW>
        case 2; v = [v x(1):x(2)]; %#ok<AGROW>
        case 3; v = [v x(1):x(2):x(3)]; %#ok<AGROW>
    end
end
end
