function t = numberText(v)
%numberText  A number as the shortest text that reads back as that number.
%   T = EphysPipelineConfig.numberText(V) is a whole number in full
%   ("30000", "120000", not "1.2e+05") and any other with as many
%   significant digits as it takes for STR2DOUBLE to give V back
%   ("0.1953125", where string(V) keeps only five: "0.19531"), so a config
%   value shown in a text field is gathered back unchanged. Inf and NaN are
%   "Inf" / "NaN". T is a string.
%
%   See also EphysPipelineConfig.ks4ParamText, STR2DOUBLE.

if v == round(v) && abs(v) < 1e15
    t = string(sprintf('%d', v));
    return
end
for p = 1:17
    t = string(sprintf('%.*g', p, v));
    if str2double(t) == v
        return
    end
end
end
