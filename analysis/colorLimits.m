function [out, msg] = colorLimits(spec, values, auto)
%colorLimits  A map's color limits: fixed numbers, or ends taken from the data drawn (min, max, a percentage of either).
%   CL = colorLimits(SPEC, VALUES, AUTO) is the color scale [lo hi] a map
%   is drawn at. SPEC is a panel's options.cLim (or a renderer's
%   Style.CLim):
%     []         automatic: AUTO, the map's own scale
%     [lo hi]    those two numbers (lo < hi)
%     "lo hi"    text: two ends, low then high, each a number or a word
%                for the data drawn (VALUES):
%                  min, max      the smallest / largest finite value
%                  P%min, P%max  P percent of it (80%max: 0.8 x the largest)
%                  -min, -max    its negative (-max max: symmetric about 0)
%                for example "0 max", "min 0.5", "min 80%max", "-max max".
%                Letter case, a comma between the ends, and a space or
%                "of" after the % ("80% of max") do not matter. Text of
%                two numbers ("0 30") is [0 30].
%   VALUES are the values the map draws (any shape; NaN and Inf are left
%   out). CL is AUTO when SPEC is automatic or not valid, when it names
%   the data and VALUES has no finite value, or when its ends do not come
%   out ascending (say "min 0" on data all above 0). AUTO may be [] (the
%   caller then picks its own scale).
%
%   [SPEC, MSG] = colorLimits(SPEC) checks and tidies SPEC as a config
%   keeps it: [] (or blank text) is [], two numbers (as numbers or as
%   text) are a 1 x 2 double, and text naming the data is a string of its
%   two ends, lowercase, a space between them and none inside an end
%   ("min 80%max"). MSG is "" for a valid SPEC, else the reason it is
%   not; an invalid SPEC comes back as given (text as one string), for
%   EphysAnalysisConfig.validate to report.
%
%   See also EphysAnalysisConfig.validate, renderHeatmap, renderProbeMap,
%   renderCorrMap, chronuxAutoLimits.
[s, ends, msg] = parse(spec);
if nargin < 2
    out = s;
    return
end
if nargin < 3; auto = []; end
out = auto;
if msg ~= "" || isempty(s); return; end
if isnumeric(s); out = s; return; end
v = double(values(isfinite(values)));
if isempty(v); return; end
range = [min(v) max(v)];
lim = [endValue(ends(1), range) endValue(ends(2), range)];
if all(isfinite(lim)) && lim(2) > lim(1); out = lim; end
end


function x = endValue(e, range)
%endValue  One end's value: its number, else its fraction of the data's min or max.
switch e.word
    case "min", x = e.x * range(1);
    case "max", x = e.x * range(2);
    otherwise,  x = e.x;
end
end


function [s, ends, msg] = parse(spec)
%parse  SPEC tidied (see colorLimits), its two ends (word "", "min" or "max"; x the number or the fraction), and why it is not valid.
ends = struct('word', {}, 'x', {});
msg = "";
s = spec;
if isempty(spec) && (isnumeric(spec) || ischar(spec) || isstring(spec) || iscell(spec))
    s = [];
    return
end
if isnumeric(spec)
    s = reshape(double(spec), 1, []);
    if ~(isreal(s) && numel(s) == 2 && all(isfinite(s)) && s(2) > s(1))
        msg = sprintf("Color limits [lo hi] are two finite numbers with lo < hi, not %s.", mat2str(spec));
    end
    return
end
if ~(ischar(spec) || isstring(spec) || iscell(spec))
    msg = sprintf("Color limits are [] (automatic), [lo hi] or text such as ""0 max"", not a %s.", class(spec));
    return
end
try
    given = strjoin(reshape(string(spec), 1, []), " ");
catch
    msg = "Color limits are [] (automatic), [lo hi] or text such as ""0 max"": a list of numbers and words.";
    return
end
s = given;
t = lower(strtrim(given));
if t == ""; s = []; return; end
t = regexprep(replace(t, ",", " "), '\s*%\s*(of\s+)?', '%');
parts = split(t).';
parts = parts(parts ~= "");
if numel(parts) ~= 2
    msg = sprintf("Color limits take two ends, low then high, such as ""0 max"" or ""min 80%%max"", not ""%s"".", given);
    return
end
for k = 1:2
    p = parts(k);
    w = string(regexp(char(p), '^([+-]?)(min|max)$', 'tokens', 'once'));   % min, max, -min, -max
    q = string(regexp(char(p), '^([+-]?(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?)%(min|max)$', 'tokens', 'once'));   % P%min, P%max
    x = str2double(p);
    if numel(w) == 2
        ends(k) = struct('word', w(2), 'x', 1 - 2 * (w(1) == "-"));
    elseif numel(q) == 2
        ends(k) = struct('word', q(2), 'x', str2double(q(1)) / 100);
    elseif isreal(x) && isfinite(x)
        ends(k) = struct('word', "", 'x', x);
    else
        msg = sprintf("A color limit is a number, min, max or a percentage of either (80%%max), not ""%s"" (in ""%s"").", ...
            p, given);
        return
    end
end
if all([ends.word] == "")
    s = [ends.x];
    if s(2) <= s(1)
        msg = sprintf("Color limits [lo hi] are two finite numbers with lo < hi, not ""%s"".", given);
        s = given;
    end
    return
end
s = strjoin(parts, " ");
end
