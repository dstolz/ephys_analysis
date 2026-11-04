function a = onOpenAnalysisConfig(obj)
%onOpenAnalysisConfig  Open the Analysis step's config in the analysis app (EphysFigGenApp).
%   With an analysis config chosen, the app opens it (scanning the source
%   saved in it; the step runs it over the datasets selected here instead).
%   Without one, the app opens on this project's selected datasets
%   (onOpenAnalysisApp), to make one: save it there, then choose it here.
%   Edits saved in the app reach this tab on Reload, and the step on its
%   next run. A = the app ([] when it did not open).
%
%   See also EphysPipelineApp.onOpenAnalysisApp, EphysFigGenApp.
a = [];
file = string(strtrim(obj.AnaConfigField.Value));
if file == ""
    a = obj.onOpenAnalysisApp(obj.selectedDatasetIndices());
    if nargout == 0; clear a; end
    return
end
if ~exist('EphysFigGenApp', 'class')
    uialert(obj.Fig, "EphysFigGenApp is not on the MATLAB path. Add the repository's analysis folder " + ...
        "(addpath_nogit on the repository adds it).", "Open in the analysis app");
    return
end
if ~isfile(file)
    uialert(obj.Fig, "Analysis config not found: " + file, "Open in the analysis app");
    return
end
a = EphysFigGenApp(file);
obj.setStatus("Opened " + file + " in the analysis app: save it there, then Reload here.", "");
if nargout == 0
    clear a
end
end
