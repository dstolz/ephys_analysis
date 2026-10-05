function onTrialsLoad(obj, mode)
%onTrialsLoad  Read the digital lines of the active dataset and pair its trials.
%   mode "recorded" reuses the manifest's cuts when they still match;
%   "none" pairs every trial with every interval in order (Reset cuts). The
%   events are kept in memory (TrialsEvents) so cuts and setting changes
%   re-pair without re-reading. The trials (the Epsych2 session's, or the TDT
%   block's epocs: EphysDataset.readBehavior) are re-read on every Load
%   (TrialsSession: the table's parameter columns).
arguments
    obj (1,1) EphysPreprocessingApp
    mode (1,1) string {mustBeMember(mode, ["recorded" "none"])} = "recorded"
end
d = obj.currentDataset();
if isempty(d)
    obj.setStatus("Trials: scan a project and pick a dataset first.");
    return
end
if trialSource(d) == ""
    obj.clearTrialsView();
    obj.TrialsSummaryLabel.Text = sprintf("%s has no trial source: no Epsych2 session associated (Project tab), and no TDT epoc store named as the trial line.", d.Name);
    obj.TrialsSummaryLabel.FontColor = [0.7 0.1 0.1];
    return
end
idx = obj.SelectedDatasetIdx;
if isempty(obj.TrialsEvents) || obj.TrialsEventsIdx ~= idx
    dlg = uiprogressdlg(obj.Fig, "Title", "Digital lines", ...
        "Message", "Reading the digital lines of " + d.Name + " ...", "Indeterminate", "on");
    closer = onCleanup(@() close(dlg));
    try
        obj.TrialsEvents = d.digitalEvents(Relabel=false, ProgressFcn=@(i, n, name) progress(dlg, i, n, name));
        obj.TrialsEventsIdx = idx;
    catch ME
        delete(closer);
        obj.setStatus("Trials: could not read the digital lines: " + string(ME.message));
        return
    end
    delete(closer);
end
try
    obj.TrialsSession = d.readBehavior();
catch
    obj.TrialsSession = [];
end
obj.fillTrialsLines();
obj.repairTrials(mode);
end


function progress(dlg, i, n, name)
dlg.Indeterminate = "off";
dlg.Value = (i - 1) / max(n, 1);
dlg.Message = sprintf("Reading %s (%d of %d)", name, i, n);
end
