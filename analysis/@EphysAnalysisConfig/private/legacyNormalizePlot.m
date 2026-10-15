function [p, unknown] = legacyNormalizePlot(in, path, section)
%legacyNormalizePlot  Read one entry of a version-1 config's Plots or SessionPlots, for its migration only.
%   [P, UNKNOWN] = legacyNormalizePlot(IN, PATH) coerces a version-1 plot
%   (a struct of jsondecode) to legacyPlotDefaults("Plot") as version 1's
%   normalizePlot did: missing fields take their defaults, the rest are
%   coerced (EphysAnalysisConfig.coerceStruct), unknown fields are dropped
%   and their paths (prefixed PATH, default "Plot") returned in UNKNOWN.
%   ref, window and selection are "default" (also an empty value) or a
%   normalized EventRef / EpochWindow / TrialSelection; rasterEvents a list
%   of EventMarks; aesthetics PlotAesthetics' rules.
%
%   [P, UNKNOWN] = legacyNormalizePlot(IN, PATH, "SessionPlot") reads one
%   entry of SessionPlots (legacyPlotDefaults("SessionPlot")): its data a
%   list of words, its aesthetics rules normalized.
%
%   Errors: EphysAnalysisConfig:BadValue (not a scalar struct, a value that
%   cannot be coerced). Nothing but legacyMigrate uses it.
%
%   See also legacyMigrate, legacyPlotDefaults, EphysAnalysisConfig.coerceStruct.

arguments
    in = struct()
    path (1,1) string = "Plot"
    section (1,1) string = "Plot"
end

if isstruct(in) && ~isempty(in) && ~isscalar(in)
    error('EphysAnalysisConfig:BadValue', '%s must be a scalar struct.', path);
end
if ~isstruct(in)
    error('EphysAnalysisConfig:BadValue', '%s must be a struct.', path);
end
def = legacyPlotDefaults(section);
held = struct();
pulled = "aesthetics";
if section == "Plot"
    pulled = ["aesthetics" "ref" "window" "selection" "rasterEvents"];
else
    pulled = [pulled "data"];
end
for f = pulled
    if isfield(in, f)
        held.(f) = in.(f);
        in = rmfield(in, f);
    end
end
[p, unknown] = EphysAnalysisConfig.coerceStruct(def, in, path);

looks = [];
if isfield(held, 'aesthetics'); looks = held.aesthetics; end
try
    p.aesthetics = PlotAesthetics.normalizeRules(looks, path + ".aesthetics");
catch ME
    error('EphysAnalysisConfig:BadValue', '%s', ME.message);
end

if section == "SessionPlot"
    if isfield(held, 'data')
        v = held.data;
        if isempty(v); v = string.empty(1, 0); end
        p.data = reshape(string(v), 1, []);
    end
    return
end

sentinels = struct('ref', "EventRef", 'window', "EpochWindow", 'selection', "TrialSelection");
for f = ["ref" "window" "selection"]
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
if isfield(held, 'rasterEvents') && ~isempty(held.rasterEvents)
    v = held.rasterEvents;
    if isstruct(v)
        v = num2cell(v);
    elseif ~iscell(v)
        error('EphysAnalysisConfig:BadValue', '%s.rasterEvents must be a list of structs.', path);
    end
    mk = EphysAnalysisConfig.defaults("EventMark");
    for k = 1:numel(v)
        if ~isstruct(v{k})
            error('EphysAnalysisConfig:BadValue', '%s.rasterEvents(%d) must be a struct.', path, k);
        end
        [p.rasterEvents(1, k), u] = EphysAnalysisConfig.coerceStruct(mk, v{k}, path + ".rasterEvents(" + k + ")");
        unknown = [unknown, u]; %#ok<AGROW>
    end
end
end
