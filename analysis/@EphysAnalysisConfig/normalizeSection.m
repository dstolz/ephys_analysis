function [s, unknown] = normalizeSection(section, in)
%normalizeSection  Coerce a section struct to the type/shape of its defaults.
%   [S, UNKNOWN] = EphysAnalysisConfig.normalizeSection(SECTION, IN) follows
%   EphysPipelineConfig.normalizeSection:
%   - fills missing fields from defaults(SECTION)
%   - coerces each present value to the class and shape of the default:
%     logical scalars, double scalars / rows, string scalars / lists, nested
%     structs recursively; the strings "Inf", "-Inf", "NaN" (writeJsonFile
%     NonFinite="string") and JSON null ([]) become numbers
%   - drops fields the defaults do not have and returns their paths
%   and adds what the analysis config needs on top:
%   - list fields (a string default of one element, such as pairingFlags
%     "ok") stay lists: ListFields names them
%   - an EpochWindow's stop, and a plot's rasterSortEvent, is [] or an
%     EventRef (normalized in turn; a line name is short for one)
%   - an EventRef's sequence is a list of SequenceStep structs, a plot's
%     rasterEvents a list of EventMarks (a struct array, a cell or one
%     struct in; a 1 x n struct array out)
%   - SECTION "Plot" is normalizePlot: ref / window / selection are
%     "default" or a normalized EventRef / EpochWindow / TrialSelection
%   - SECTION "SessionPlot" (one entry of SessionPlots) has its aesthetics
%     rules normalized by PlotAesthetics.normalizeRules, as a plot's
%
%   See also EphysAnalysisConfig.defaults, EphysAnalysisConfig.normalizePlot.

arguments
    section (1,1) string
    in = struct()
end

if section == "Plot"
    [s, unknown] = EphysAnalysisConfig.normalizePlot(in);
    return
end
if section == "SessionPlot"
    [s, unknown] = normalizeSessionPlot(in);
    return
end
def = EphysAnalysisConfig.defaults(section);
[s, unknown] = EphysAnalysisConfig.coerceStruct(def, in, section);
end


function [s, unknown] = normalizeSessionPlot(in)
%normalizeSessionPlot  One session plot: coerced to defaults("SessionPlot"), its aesthetics rules normalized.
path = "SessionPlot";
if isstruct(in) && ~isempty(in) && ~isscalar(in)
    error('EphysAnalysisConfig:BadValue', '%s must be a scalar struct.', path);
end
looks = [];
if isstruct(in) && isfield(in, 'aesthetics')
    looks = in.aesthetics;
    in = rmfield(in, 'aesthetics');
end
[s, unknown] = EphysAnalysisConfig.coerceStruct(EphysAnalysisConfig.defaults("SessionPlot"), in, path);
try
    s.aesthetics = PlotAesthetics.normalizeRules(looks, path + ".aesthetics");
catch ME
    error('EphysAnalysisConfig:BadValue', '%s', ME.message);
end
end
