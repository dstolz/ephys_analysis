function onResetKS4Params(obj)
%onResetKS4Params  Put every Kilosort4 parameter back to its default.
%   Resets Sorting.KS4 (every kilosortParamSpec entry) and clears
%   KS4ExtraJSON. The Python and execution settings stay.
%
%   See also onOptimizeKS4ForProbe, EphysPipelineConfig.defaults.

S = obj.gatherSortingSection();   % a field that does not parse is reset too
def = EphysPipelineConfig.defaults("Sorting");
S.KS4 = def.KS4;
S.KS4ExtraJSON = def.KS4ExtraJSON;
obj.applySortingSection(S);
obj.onConfigChanged();
obj.log("%s", "Kilosort4 parameters reset to defaults; extra settings JSON cleared.");
obj.setStatus("Kilosort4 parameters reset to defaults.");
end
