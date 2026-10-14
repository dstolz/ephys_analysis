function [p, unknown] = normalizePanel(in, path)
%normalizePanel  Coerce one figure panel to defaults("Panel").
%   [P, UNKNOWN] = EphysAnalysisConfig.normalizePanel(IN, PATH) fills the
%   fields IN leaves out, coerces the rest (see normalizeSection) and drops
%   unknown fields (their paths, prefixed by PATH, in UNKNOWN):
%   - ref and window are the string "default" (the figure's) or a struct,
%     normalized as an EventRef / EpochWindow; an empty value means
%     "default"
%   - layers is a list of layers (a struct array, a cell from jsondecode,
%     one struct or [] for none), each normalizeLayer'd
%   - options are coerced to the type's DefaultOptions (panelTypes), so a
%     changed type re-seeds them: fields the type knows keep their values,
%     the others are dropped. An unknown type keeps an empty options
%     struct (validate reports the type).
%
%   See also EphysAnalysisConfig.normalizeFigure, EphysAnalysisConfig.panelTypes.

arguments
    in = struct()
    path (1,1) string = "Panel"
end

def = EphysAnalysisConfig.defaults("Panel");
sentinels = struct('ref', "EventRef", 'window', "EpochWindow");
held = struct();
if isstruct(in) && ~isempty(in)
    if ~isscalar(in)
        error('EphysAnalysisConfig:BadValue', '%s must be a scalar struct.', path);
    end
    for f = ["ref" "window" "layers" "options"]
        if isfield(in, f)
            held.(f) = in.(f);
            in = rmfield(in, f);
        end
    end
end
[p, unknown] = EphysAnalysisConfig.coerceStruct(def, in, path);

for f = ["ref" "window"]
    if ~isfield(held, f); continue; end
    v = held.(f);
    if isempty(v) || ((isstring(v) || ischar(v)) && lower(strtrim(string(v))) == "default")
        p.(f) = "default";
    elseif isstruct(v)
        [p.(f), u] = EphysAnalysisConfig.coerceStruct(EphysAnalysisConfig.defaults(sentinels.(f)), v, path + "." + f);
        unknown = [unknown, u]; %#ok<AGROW>
    else
        error('EphysAnalysisConfig:BadValue', '%s.%s must be "default" or a struct.', path, f);
    end
end

p.layers = repmat(EphysAnalysisConfig.defaults("Layer"), 1, 0);
if isfield(held, 'layers') && ~isempty(held.layers)
    v = held.layers;
    if isstruct(v)
        v = num2cell(v);
    elseif ~iscell(v)
        error('EphysAnalysisConfig:BadValue', '%s.layers must be a list of structs.', path);
    end
    for k = 1:numel(v)
        if ~isstruct(v{k})
            error('EphysAnalysisConfig:BadValue', '%s.layers(%d) must be a struct.', path, k);
        end
        [L, u] = EphysAnalysisConfig.normalizeLayer(v{k}, path + ".layers(" + k + ")");
        unknown = [unknown, u]; %#ok<AGROW>
        p.layers(1, k) = L;
    end
end

T = EphysAnalysisConfig.panelTypes();
row = T.Type == p.type;
given = [];
if isfield(held, 'options'); given = held.options; end
if any(row)
    [p.options, u] = EphysAnalysisConfig.coerceStruct(T.DefaultOptions{row}, given, path + ".options");
    unknown = [unknown, u];
else
    p.options = struct();
end
end
