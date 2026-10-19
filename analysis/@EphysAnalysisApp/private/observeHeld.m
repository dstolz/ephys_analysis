function has = observeHeld(src)
%observeHeld  Which data types a dataset holds to observe, one logical per EphysAnalysisConfig.ObserveData.
%   HAS = observeHeld(SRC) for a loaded dataset SRC (loadAnalysisSource):
%   units its hasUnits, detected its hasDetected, each signal whether its
%   extract is there (SRC.signals), the dataset always. Nothing is read:
%   the flags come from the source as it was loaded.
%
%   See also EphysAnalysisConfig.ObserveData, loadAnalysisSource.
types = EphysAnalysisConfig.ObserveData;
has = true(size(types));
for i = 1:numel(types)
    switch types(i)
        case "units",    has(i) = src.hasUnits;
        case "detected", has(i) = src.hasDetected;
        case "dataset"
        otherwise,       has(i) = isfield(src.signals, types(i)) && src.signals.(types(i));
    end
end
end
