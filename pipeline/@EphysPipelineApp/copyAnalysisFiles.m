function X = copyAnalysisFiles(obj, datasets)
%copyAnalysisFiles  Copy DATASETS' files for the analysis app, with the copy window's settings.
%   X = obj.copyAnalysisFiles(DATASETS) lists, for each EphysDataset, the
%   files EphysAnalysisApp reads (DatasetOutputs.analysisFiles) for the
%   settings last used in File > Copy files for the analysis app...
%   (AnalysisCopyDialog.settings: what to copy, the destination, what to do
%   when the folder has files, the checksum), queues them on an
%   OutputTransfer and follows it on the Run tab like a Run's output copies
%   (followTransfer): the copy goes on in the background. What is missing
%   for a dataset is logged on the Run tab. X is the OutputTransfer, [] when
%   nothing was queued (no destination chosen yet, or no dataset has a file
%   to copy; the Run log says which).
%
%   See also AnalysisCopyDialog, copyAnalysisFilesAfterRun, followTransfer.
arguments
    obj (1,1) EphysPipelineApp
    datasets (1,:)
end
X = [];
tag = "[analysis copy] ";
s = AnalysisCopyDialog.settings();
if ~OutputTransfer.isFullPath(s.Destination)
    obj.runLog("%s", tag + "not made: no destination folder is set. Choose one in File > Copy files for the analysis app...");
    return
end
T = OutputTransfer(s.Destination, IfExists=s.IfExists, Verify=s.Verify, ...
    LogFcn=@(msg) obj.runLog("%s", tag + msg));
queued = 0;
for d = datasets
    try
        [F, notes] = d.outputs().analysisFiles(Signals=s.Signals, Spikes=s.Spikes, Sorting=s.Sorting, ...
            SortedData=s.SortedData, Probe=s.Probe);
        if ~isempty(notes)
            obj.runLog("%s", tag + d.Name + ": " + strjoin(notes, "; "));
        end
        if height(F) == 0; continue; end
        AnalysisCopyDialog.addFiles(T, EphysPipeline.transferKey(d), d, F);
        queued = queued + 1;
    catch ME
        obj.runLog("%s", tag + d.Name + ": not queued: " + string(ME.message));
    end
end
if queued == 0
    obj.runLog("%s", tag + "no file to copy.");
    return
end
T.close();
obj.runLog("%s", tag + sprintf("%d dataset(s) to %s", queued, T.Destination));
obj.followTransfer(T);
X = T;
end
