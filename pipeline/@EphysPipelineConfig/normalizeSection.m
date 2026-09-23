function [s, unknown] = normalizeSection(section, in)
%normalizeSection  Coerce a section struct to the type/shape of its defaults.
%   [S, UNKNOWN] = EphysPipelineConfig.normalizeSection("Spikes", s)
%   - fills missing fields from defaults(section)
%   - coerces each present value to the class and shape of the default:
%     logical scalars, double scalars / rows, string scalars / rows, nested
%     structs (KS4) recursively; the strings "Inf", "-Inf", "NaN"
%     (writeJsonFile NonFinite="string") and JSON null ([]) become numbers
%   - drops fields the defaults do not have and returns their names
%   Nullable Kilosort4 parameters (default []) stay [] when empty. The
%   fields of RowFields have a scalar default but take a row too
%   (Artifacts.FilterCutoff: 300, or [lo hi] for a band-pass), so they are
%   kept as a row.
%
%   See also EphysPipelineConfig.defaults, writeJsonFile.

arguments
    section (1,1) string
    in = struct()
end

def = EphysPipelineConfig.defaults(section);
[s, unknown] = coerceStruct(def, in, section);
end


function tf = isRowField(path)
%isRowField  Numeric fields whose scalar default stands for a row value.
RowFields = "Artifacts.FilterCutoff";
tf = any(path == RowFields);
end


function [out, unknown] = coerceStruct(def, in, path)
out = def;
unknown = string.empty(1, 0);
if isempty(in) || ~isstruct(in)
    return
end
if ~isscalar(in)
    error('EphysPipelineConfig:BadValue', '%s must be a scalar struct.', path);
end
fn = string(fieldnames(in)).';
for f = fn
    if ~isfield(def, f)
        unknown(end+1) = path + "." + f; %#ok<AGROW>
        continue
    end
    d = def.(f);
    v = in.(f);
    if isstruct(d)
        [out.(f), u] = coerceStruct(d, v, path + "." + f);
        unknown = [unknown, u]; %#ok<AGROW>
    else
        out.(f) = coerceValue(d, v, path + "." + f);
    end
end
end


function v = coerceValue(d, v, path)
%coerceValue  Coerce V to the class/shape of default D.
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
    if isempty(v)
        if isscalar(d)
            v = "";                  % scalar string default -> ""
        else
            v = string.empty(1, 0);  % string-list default -> empty list
        end
    elseif iscell(v)
        v = reshape(string(v), 1, []);
    else
        v = string(v);
        if isscalar(d) && ~isscalar(v)
            v = strjoin(v(:).', ", ");
        elseif ~isscalar(d)
            v = reshape(v, 1, []);
        end
    end
    if isscalar(d) && ~isscalar(v); v = string(v(1)); end
    return
end

if isnumeric(d)
    v = toNumeric(v, path);
    if isempty(d)
        % nullable: [] stays [], otherwise a row of what was given
        if ~isempty(v); v = reshape(double(v), 1, []); end
    elseif isscalar(d) && isRowField(path)
        if isempty(v)
            v = d;
        else
            v = reshape(double(v), 1, []);
        end
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

% anything else (cell, etc.): keep as is
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
                    error('EphysPipelineConfig:BadValue', '%s: "%s" is not a number.', path, t);
                end
                v = x;
        end
    else
        v = arrayfun(@(u) toNumeric(u, path), t);
    end
    return
end
error('EphysPipelineConfig:BadValue', '%s: cannot interpret a %s as a number.', path, class(v));
end
