function onApplyProbeRules(obj)
%onApplyProbeRules  Assign the probe rules to the datasets without a probe of their own.
%   Works whether or not "Assign automatically" is ticked. The first rule
%   matching a dataset's subject gives its probe (EphysPipeline.probeRule),
%   which is saved in the dataset's manifest; a dataset's own probe and a
%   rule whose probe file is not there are left alone.

if obj.refuseWhileRunning("Apply probe rules"); return; end
if isempty(obj.Project) || obj.Project.NumDatasets == 0
    uialert(obj.Fig, "Scan a parent directory first.", "Probe rules");
    return
end
c = obj.Config.Probe;
if isempty(c.RuleSubjects)
    uialert(obj.Fig, "Add a rule first.", "Probe rules");
    return
end
T = EphysPipeline.assignProbeRules(obj.Project.Datasets, c.RuleSubjects, c.RuleProbes);
obj.refreshDatasetsTable();
obj.syncArtProbeControls();
msg = sprintf("Probe rules assigned a probe to %d dataset(s).", height(T));
if any(~T.Saved)
    msg = msg + sprintf(" %d manifest(s) not written: the change holds until the next scan.", nnz(~T.Saved));
end
obj.ScanStatusLabel.Text = msg;
obj.setStatus(msg, "");
end
