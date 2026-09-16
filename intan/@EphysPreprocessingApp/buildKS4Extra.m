function [extra, errMsg] = buildKS4Extra(obj)
%buildKS4Extra  Kilosort4 settings struct from the tab controls.
%   [EXTRA, ERRMSG] = obj.buildKS4Extra() reads the controls into a config
%   Sorting section (gatherSortingSection) and hands it to
%   EphysPipelineConfig.ks4Settings - the same code the headless pipeline
%   uses - so the GUI and a script produce identical Kilosort4 settings.
%   ERRMSG is "" on success or describes the first parse failure.

[S, errMsg] = obj.gatherSortingSection();
if errMsg ~= ""
    extra = struct();
    return
end
[extra, errMsg] = EphysPipelineConfig.ks4Settings(S);
end
