function onTrialsApprove(obj, status)
%onTrialsApprove  Save the shown pairing in the manifest as approved / unreviewed.
%   An existing <name>_behavior.mat is rewritten with it (setTrialPairing).
arguments
    obj (1,1) EphysPipelineApp
    status (1,1) string {mustBeMember(status, ["approved" "unreviewed"])}
end
if obj.refuseWhileRunning("Trial pairing"); return; end
P = obj.TrialsPairing;
d = obj.currentDataset();
if isempty(P) || isempty(d); return; end
[file, saved] = d.setTrialPairing(P, status);
if ~saved
    obj.saveManifests(d);   % tries once more, and says why the manifest (which holds the pairing) is not written
end
P.status = status;
P.autoApproved = false;
P.recorded = true;
P.stale = false;
obj.TrialsPairing = P;
obj.refreshTrialsView();
obj.refreshDatasetsTable();
msg = sprintf("Trials: pairing of %s saved as %s", d.Name, status);
if file ~= ""
    obj.setStatus(msg + sprintf("; rewrote %s.", file));
elseif isfile(fullfile(d.outputFolder(), d.Name + "_behavior.mat"))   % EphysPipeline.outputPathFor("behavior")
    obj.setStatus(msg + ".");
else
    obj.setStatus(msg + ".", "Run the behavior step (or Write behavior .mat) to write <name>_behavior.mat.");
end
end
