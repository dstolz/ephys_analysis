function [out, unknown] = coerceStruct(def, in, path)
%coerceStruct  Coerce struct IN to the fields, classes and shapes of DEF.
%   [OUT, UNKNOWN] = EphysAnalysisConfig.coerceStruct(DEF, IN, PATH) is the
%   engine behind normalizeSection: missing fields keep DEF's values, known
%   ones are coerced (see normalizeSection), unknown ones are dropped and
%   their dotted paths returned. PATH prefixes those paths and error
%   messages.

out = def;
unknown = string.empty(1, 0);
if isempty(in) || ~isstruct(in)
    return
end
if ~isscalar(in)
    error('EphysAnalysisConfig:BadValue', '%s must be a scalar struct.', path);
end
for f = string(fieldnames(in)).'
    if ~isfield(def, f)
        unknown(end+1) = path + "." + f; %#ok<AGROW>
        continue
    end
    d = def.(f);
    v = in.(f);
    if f == "stop" || f == "rasterSortEvent"
        [out.(f), u] = coerceStop(v, path + "." + f);
        unknown = [unknown, u]; %#ok<AGROW>
    elseif f == "sequence" || f == "sequences" || f == "overlays"
        [out.(f), u] = coerceList(f, v, path + "." + f);
        unknown = [unknown, u]; %#ok<AGROW>
    elseif isstruct(d)
        [out.(f), u] = EphysAnalysisConfig.coerceStruct(d, v, path + "." + f);
        unknown = [unknown, u]; %#ok<AGROW>
    else
        out.(f) = coerceValue(d, v, path + "." + f, ismember(f, EphysAnalysisConfig.ListFields));
    end
end
end


function [v, unknown] = coerceStop(v, path)
%coerceStop  An epoch window's stop, or a plot's rasterSortEvent: [] (none) or an EventRef.
unknown = string.empty(1, 0);
if isempty(v) || ((isstring(v) || ischar(v)) && any(lower(strtrim(string(v))) == ["" "none"]))
    v = [];
elseif isstruct(v)
    [v, unknown] = EphysAnalysisConfig.coerceStruct(EphysAnalysisConfig.defaults("EventRef"), v, path);
elseif isstring(v) || ischar(v)
    % shorthand: a line name
    v = EphysAnalysisConfig.coerceStruct(EphysAnalysisConfig.defaults("EventRef"), struct('line', string(v)), path);
else
    error('EphysAnalysisConfig:BadValue', '%s must be [] or an EventRef struct.', path);
end
end


function [out, unknown] = coerceList(field, v, path)
%coerceList  A list of structs: an EventRef's sequence (SequenceStep each), the
%   raster marks' sequences (EventRef each) or a plot's overlays (Overlay
%   each). V is a struct array, a cell (jsondecode of elements whose fields
%   differ), one struct or [] (none).
unknown = string.empty(1, 0);
if field == "sequence"
    def = EphysAnalysisConfig.defaults("SequenceStep");
elseif field == "overlays"
    def = EphysAnalysisConfig.defaults("Overlay");
else
    def = EphysAnalysisConfig.defaults("EventRef");
end
out = repmat(def, 1, 0);
if isempty(v); return; end
if isstruct(v)
    v = num2cell(v);
elseif ~iscell(v)
    error('EphysAnalysisConfig:BadValue', '%s must be a list of structs.', path);
end
for k = 1:numel(v)
    if ~isstruct(v{k})
        error('EphysAnalysisConfig:BadValue', '%s(%d) must be a struct.', path, k);
    end
    [out(1, k), u] = EphysAnalysisConfig.coerceStruct(def, v{k}, path + "(" + k + ")"); %#ok<AGROW>
    unknown = [unknown, u]; %#ok<AGROW>
end
end


function v = coerceValue(d, v, path, isList)
%coerceValue  Coerce V to the class / shape of default D.
if islogical(d)
    if isempty(v)
        v = d;
    elseif ischar(v) || isstring(v)
        v = any(lower(strtrim(string(v))) == ["1" "true" "yes" "on"]);
    else
        v = logical(v(1));
    end
    return
end

if isstring(d) || ischar(d)
    list = isList || ~isscalar(d);
    if isempty(v)
        if list
            v = string.empty(1, 0);
        else
            v = "";
        end
    elseif iscell(v)
        v = reshape(string(v), 1, []);
    else
        v = reshape(string(v), 1, []);
    end
    if ~list
        if numel(v) > 1
            v = strjoin(v, ", ");
        elseif isempty(v)
            v = "";
        end
    end
    return
end

if isnumeric(d)
    v = toNumeric(v, path);
    if isempty(d)
        if ~isempty(v); v = reshape(double(v), 1, []); end   % nullable: [] stays []
    elseif isscalar(d)
        if isempty(v)
            v = d;
        else
            v = double(v(1));
        end
    else
        v = reshape(double(v), 1, []);
    end
    return
end
% anything else: keep as is
end


function v = toNumeric(v, path)
if isnumeric(v) || islogical(v)
    v = double(v);
    return
end
if iscell(v)
    out = zeros(1, numel(v));
    for k = 1:numel(v)
        out(k) = toNumeric(v{k}, path);
    end
    v = out;
    return
end
if ischar(v) || isstring(v)
    t = strtrim(string(v));
    if isscalar(t)
        switch lower(t)
            case {"inf", "+inf", "infinity"}, v = Inf;
            case {"-inf", "-infinity"},       v = -Inf;
            case {"nan", ""},                 v = NaN;
            otherwise
                x = str2double(t);
                if isnan(x)
                    error('EphysAnalysisConfig:BadValue', '%s: "%s" is not a number.', path, t);
                end
                v = x;
        end
    else
        v = arrayfun(@(u) toNumeric(u, path), t);
    end
    return
end
error('EphysAnalysisConfig:BadValue', '%s: cannot interpret a %s as a number.', path, class(v));
end
