function onTrialsWriteBehavior(obj)
%onTrialsWriteBehavior  Write <name>_behavior.mat with the shown pairing.
P = obj.TrialsPairing;
d = obj.currentDataset();
if isempty(P) || isempty(d); return; end
file = fullfile(d.outputFolder(), d.Name + "_behavior.mat");   % EphysPipeline.outputPathFor("behavior")
try
    r = d.behaviorToMat(File=file, Overwrite=true, Pairing=P);
    obj.setStatus(sprintf("Trials: wrote %s (%d trials, pairing %s).", r.file, r.nTrials, P.status));
catch ME
    obj.setStatus("Trials: could not write the behavior file: " + string(ME.message));
end
end
