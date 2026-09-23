function t = numberText(~, v)
%numberText  A number as the shortest text that reads back as that number.
%   T = obj.numberText(V) is a whole number in full ("30000") and any other
%   with as many significant digits as it takes ("0.1953125", where
%   string(V) keeps only five: "0.19531"), so a config value shown in a
%   text field is gathered back unchanged. Inf and NaN are "Inf" / "NaN".
if v == round(v) && abs(v) < 1e15
    t = sprintf('%d', v);
    return
end
t = sprintf('%.17g', v);
for p = 1:16
    s = sprintf('%.*g', p, v);
    if str2double(s) == v
        t = s;
        return
    end
end
end
