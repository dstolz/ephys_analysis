function [p, unknown] = normalizePlot(in, path)
%normalizePlot  Coerce one plot entry to defaults("Plot").
%   [P, UNKNOWN] = EphysAnalysisConfig.normalizePlot(IN) fills the fields IN
%   leaves out, coerces the rest (see normalizeSection) and drops unknown
%   fields (their paths in UNKNOWN). ref, window and selection are either
%   the string "default" -- use the config's Defaults.EventRef /
%   Defaults.Window / Defaults.Selection (see plotFor) -- or a struct,
%   normalized as an EventRef / EpochWindow / TrialSelection. An empty value
%   means "default".
%
%   See also EphysAnalysisConfig.defaults, EphysAnalysisConfig.plotFor.

arguments
    in = struct()
    path (1,1) string = "Plot"
end

def = EphysAnalysisConfig.defaults("Plot");
sentinels = struct('ref', "EventRef", 'window', "EpochWindow", 'selection', "TrialSelection");
names = string(fieldnames(sentinels)).';
held = struct();
if isstruct(in) && ~isempty(in)
    if ~isscalar(in)
        error('EphysAnalysisConfig:BadValue', '%s must be a scalar struct.', path);
    end
    for f = names
        if isfield(in, f)
            held.(f) = in.(f);
            in = rmfield(in, f);
        end
    end
end
[p, unknown] = EphysAnalysisConfig.coerceStruct(def, in, path);
for f = names
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
end
