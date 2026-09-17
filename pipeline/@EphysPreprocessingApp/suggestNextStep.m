function hint = suggestNextStep(obj)
%suggestNextStep  Next useful action from the project / config state.
P = obj.Project;
if isempty(P) || P.NumDatasets == 0
    hint = "Set the project root on the Project tab and click Scan.";
    return
end
ds = P.Datasets;
n  = numel(ds);
nProbe = 0; nKS = 0;
for k = 1:n
    pf = string(ds(k).ProbeFile);
    if strlength(pf) > 0 && isfile(char(pf)); nProbe = nProbe + 1; end
    if ds(k).hasKilosortResults(); nKS = nKS + 1; end
end
if nProbe < n && obj.Config.Probe.DefaultProbeFile == ""
    hint = sprintf("Assign a probe on the Probe tab (%d/%d have one).", nProbe, n);
elseif isempty(obj.Config.enabledSteps())
    hint = "Enable steps on their tabs (or the Run tab), then Run pipeline.";
elseif nKS >= n
    hint = "All datasets sorted - Run the remaining steps or open Review.";
else
    hint = sprintf("Run pipeline on the Run tab (%d/%d sorted).", nKS, n);
end
end
