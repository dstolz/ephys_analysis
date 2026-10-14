function [L, unknown] = normalizeLayer(in, path)
%normalizeLayer  Coerce one figure layer to defaults("Layer").
%   [L, UNKNOWN] = EphysAnalysisConfig.normalizeLayer(IN, PATH) fills the
%   fields IN leaves out, coerces the rest (see normalizeSection) and drops
%   unknown fields (their paths, prefixed by PATH, in UNKNOWN). The nested
%   units (a UnitSelection without its source), event (an EventMark) and
%   event.sequence (SequenceStep each) are coerced as a plot's are.
%
%   See also EphysAnalysisConfig.normalizePanel, EphysAnalysisConfig.defaults.

arguments
    in = struct()
    path (1,1) string = "Layer"
end

[L, unknown] = EphysAnalysisConfig.coerceStruct(EphysAnalysisConfig.defaults("Layer"), in, path);
end
