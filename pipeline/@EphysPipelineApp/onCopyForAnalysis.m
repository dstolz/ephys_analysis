function dlg = onCopyForAnalysis(obj)
%onCopyForAnalysis  Open the window that copies the files EphysAnalysisApp needs to another folder.
%   onCopyForAnalysis(obj) (File menu, and the toolbar's folder-arrow tool)
%   opens an AnalysisCopyDialog on the ticked datasets of the Project table
%   (every dataset when none is ticked). The window lists each dataset's
%   files for the settings chosen there (signals, detected spikes, sorted
%   units, the sorted binary, the probe file), copies them to
%   <folder>/<subject>/<session> in the background (OutputTransfer) and
%   shows the progress, so the folder can be opened with EphysAnalysisApp on
%   another computer. DLG = the window ([] when it did not open). Several
%   windows can be open; each works on the datasets it was opened with.
%
%   See also AnalysisCopyDialog, DatasetOutputs.analysisFiles,
%   EphysPipelineApp.onOpenAnalysisApp.
arguments
    obj (1,1) EphysPipelineApp
end
dlg = [];
title = "Copy files for the analysis app";
if isempty(obj.Project) || obj.Project.NumDatasets == 0
    uialert(obj.Fig, "Scan a project first: the copy takes the files of the ticked datasets.", title);
    return
end
try
    platformSupport("copy", Require=true);
catch ME
    uialert(obj.Fig, ME.message, title);
    return
end
idx = obj.selectedDatasetIndices();
dlg = AnalysisCopyDialog(obj.Project.Datasets(idx), Parent=obj.Fig);
if isscalar(idx)
    what = obj.Project.Datasets(idx).Name;
else
    what = sprintf("%d datasets", numel(idx));
end
obj.setStatus("Opened the analysis file copy for " + what + ".", "");
if nargout == 0
    clear dlg
end
end
