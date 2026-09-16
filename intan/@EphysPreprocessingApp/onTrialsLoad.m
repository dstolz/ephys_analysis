function onTrialsLoad(obj, mode)
%onTrialsLoad  Read the digital lines of the Trials-tab dataset and pair its trials.
%   mode "recorded" reuses the manifest's pairing when it still matches;
%   "auto" re-aligns from the timestamps. The events are kept in memory
%   (TrialsEvents) so edits and setting changes re-pair without re-reading.
arguments
    obj (1,1) EphysPreprocessingApp
    mode (1,1) string {mustBeMember(mode, ["recorded" "auto"])} = "recorded"
end
d = obj.currentTrialsDataset();
if isempty(d)
    obj.setStatus("Trials: scan a project and pick a dataset first.");
    return
end
if d.BehaviorFile == "" || ~isfile(d.BehaviorFile)
    obj.clearTrialsView();
    obj.TrialsSummaryLabel.Text = sprintf("%s has no Epsych2 session associated (Project tab).", d.Name);
    obj.TrialsSummaryLabel.FontColor = [0.7 0.1 0.1];
    return
end
idx = obj.TrialsDatasetDropDown.Value;
if isempty(obj.TrialsEvents) || obj.TrialsEventsIdx ~= idx
    dlg = uiprogressdlg(obj.Fig, "Title", "Digital lines", ...
        "Message", "Reading the digital lines of " + d.Name + " ...", "Indeterminate", "on");
    closer = onCleanup(@() close(dlg));
    try
        obj.TrialsEvents = d.digitalEvents(ProgressFcn=@(i, n, name) progress(dlg, i, n, name));
        obj.TrialsEventsIdx = idx;
    catch ME
        delete(closer);
        obj.setStatus("Trials: could not read the digital lines: " + string(ME.message));
        return
    end
    delete(closer);
end
obj.fillTrialsLines();
obj.repairTrials(mode);
end


function progress(dlg, i, n, name)
dlg.Indeterminate = "off";
dlg.Value = (i - 1) / max(n, 1);
dlg.Message = sprintf("Reading %s (%d of %d)", name, i, n);
end
