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
%   kept as a row. The fields of MapFields (Sorting.SIParams) are maps:
%   every field whose name is a valid identifier is kept, its value a
%   string (one per SpikeInterface sorter). The fields of ListFields
%   (Behavior.DerivedEvents) are rows of structs, each element normalized
%   as the section ListFields names (DerivedEvent); JSON gives them as an
%   array of objects (a struct array, or a cell array when the objects'
%   fields differ) or [] for none.
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


function tf = isMapField(path)
%isMapField  Struct fields whose keys are names, not fixed fields: name -> string.
MapFields = "Sorting.SIParams";
tf = any(path == MapFields);
end


function sec = listSection(path)
%listSection  The section each element of a list field is normalized as ("" = not a list).
ListFields = ["Behavior.DerivedEvents" "DerivedEvent"];
k = find(ListFields(:, 1) == path, 1);
sec = "";
if ~isempty(k); sec = ListFields(k, 2); end
end


function [out, unknown] = coerceList(def, in, path, sec)
%coerceList  A list field: a row of structs, each normalized as section SEC.
out = def;
unknown = string.empty(1, 0);
if iscell(in)
    if ~all(cellfun(@(c) isstruct(c) && isscalar(c), in))
        error('EphysPipelineConfig:BadValue', '%s must be a list of objects.', path);
    end
elseif isstruct(in)
    in = num2cell(in);
elseif isempty(in)
    return
else
    error('EphysPipelineConfig:BadValue', '%s must be a list of objects.', path);
end
items = cell(1, numel(in));
for k = 1:numel(in)
    [items{k}, u] = coerceStruct(EphysPipelineConfig.defaults(sec), in{k}, sprintf("%s(%d)", path, k));
    unknown = [unknown, u]; %#ok<AGROW>
end
if ~isempty(items); out = [items{:}]; end
end


function [out, unknown] = coerceStruct(def, in, path)
out = def;
unknown = string.empty(1, 0);
sec = listSection(path);
if sec ~= ""
    [out, unknown] = coerceList(def, in, path, sec);
    return
end
if isempty(in) || ~isstruct(in)
    return
end
if ~isscalar(in)
    error('EphysPipelineConfig:BadValue', '%s must be a scalar struct.', path);
end
if isMapField(path)
    for f = string(fieldnames(in)).'
        if ~isvarname(f)
            unknown(end+1) = path + "." + f; %#ok<AGROW>
            continue
        end
        v = in.(f);
        if isstruct(v) || iscell(v)
            v = string(jsonencode(v));    % an object written in place of its text
        end
        out.(f) = coerceValue("", v, path + "." + f);
    end
    return
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
