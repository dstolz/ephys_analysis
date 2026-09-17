function onTrialsApprove(obj, status)
%onTrialsApprove  Save the shown pairing in the manifest as approved / unreviewed.
arguments
    obj (1,1) EphysPreprocessingApp
    status (1,1) string {mustBeMember(status, ["approved" "unreviewed"])}
end
P = obj.TrialsPairing;
d = obj.currentDataset();
if isempty(P) || isempty(d); return; end
d.setTrialPairing(P, status);
P.status = status;
P.recorded = true;
P.stale = false;
obj.TrialsPairing = P;
obj.refreshTrialsView();
obj.refreshDatasetsTable();
obj.setStatus(sprintf("Trials: pairing of %s saved as %s.", d.Name, status), ...
    "Run the behavior step (or Write behavior .mat) to update <name>_behavior.mat.");
end
