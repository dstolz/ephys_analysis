function spec = plotSpecFor(R, spec)
%plotSpecFor  A complete plot spec: the one given (normalized) or R.kind's defaults.
%   Layout "" becomes the kind's default layout.
if isempty(spec)
    spec = struct('kind', R.kind);
    if isfield(R, 'spec') && isstruct(R.spec); spec = R.spec; end
end
if ~all(isfield(spec, fieldnames(EphysAnalysisConfig.defaults("Plot"))))
    spec = EphysAnalysisConfig.normalizePlot(spec);
end
spec.style = EphysAnalysisConfig.normalizeSection("Style", spec.style);
if spec.layout == ""
    K = EphysAnalysisConfig.plotKinds();
    spec.layout = K.DefaultLayout(K.Kind == spec.kind);
end
end
