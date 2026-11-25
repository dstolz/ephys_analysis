function onLocalReference(obj)
%onLocalReference  Open the Local reference window on the active dataset's probe.
%   The window (LocalReferenceDialog) draws the probe the steps would use
%   for the active dataset (its own, a rule's or the default:
%   EphysPipeline.resolveProbe; the sites of channels disabled at
%   acquisition left out, EphysDataset.recordedProbe) with the dataset's local reference map
%   (EphysDataset.LocalReferenceMap), and lists what a run would stop on
%   (EphysDataset.localReferenceProblems on that probe). Save keeps the map
%   on the active dataset, Save to ticked datasets on every dataset ticked
%   in the Project table that is on the same probe (saveLocalReference).
%   An open window is closed first: it belongs to the dataset it was opened on.
%
%   See also LocalReferenceDialog, saveLocalReference, refreshReferencePanel,
%   EphysDataset.applyLocalReference.

d = obj.currentDataset();
if isempty(d)
    obj.alertNoProject("Local reference");
    return
end
if obj.refuseWhileRunning("Local reference")
    return
end
pf = EphysPipeline.resolveProbe(obj.Config.Probe, d);
probe = [];
if pf ~= ""
    probe = readJsonFile(pf, ErrorOnFail=false);
end
if isempty(probe) || ~isstruct(probe) || ~all(isfield(probe, {'chanMap', 'xc', 'yc'}))
    if pf == ""
        why = d.Name + " has no probe, and the config has no default probe";
    else
        why = "The probe " + pf + " cannot be read";
    end
    uialert(obj.Fig, why + ". The local reference is picked on the probe map: assign a probe on the Probe tab.", ...
        "Local reference", "Icon", "warning");
    return
end
if ~isempty(obj.ArtRefLocalDialog) && isvalid(obj.ArtRefLocalDialog)
    delete(obj.ArtRefLocalDialog);
end
[~, nm, ext] = fileparts(pf);
probe = d.recordedProbe(probe);   % channels disabled at acquisition: their sites left out, the others at their rows
obj.ArtRefLocalDialog = LocalReferenceDialog(d.LocalReferenceMap, Probe=probe, NumChannels=d.NumChannels, ...
    Dataset=d.Name, ProbeName=string(nm) + string(ext), ...
    CheckFcn=@(m) d.localReferenceProblems(Map=m, ProbeFile=pf), ...
    OnSave=@(m, ticked) obj.saveLocalReference(d, m, pf, ticked), ...
    Ticked=numel(obj.tickedDatasetIndices()), Parent=obj.Fig);
end
