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
%   - an EpochWindow's stop, and a raster or heat map panel's
%     rasterSortEvent, is [] or an EventRef (normalized in turn; a line
%     name is short for one)
%   - an EventRef's sequence is a list of SequenceStep structs, a panel's
%     overlays a list of Overlays (a struct array, a cell or one struct in;
%     a 1 x n struct array out)
%
%   See also EphysAnalysisConfig.defaults, EphysAnalysisConfig.normalizeFigure.

arguments
    section (1,1) string
    in = struct()
end

def = EphysAnalysisConfig.defaults(section);
[s, unknown] = EphysAnalysisConfig.coerceStruct(def, in, section);
end
