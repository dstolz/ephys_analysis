function hint = suggestNextStep(obj)
    % Suggest the next useful action from the current project state:
    % scan -> assign a probe -> run Kilosort4 (SpikeInterface) -> review.
    P = obj.Project;
    if isempty(P) || P.NumDatasets == 0
        hint = "Browse to a parent folder and click Scan.";
        return
    end
    ds = P.Datasets;
    n  = numel(ds);
    nProbe = 0; nKS = 0;
    for k = 1:n
        pf = string(ds(k).ProbeFile);
        if strlength(pf) > 0 && isfile(char(pf)); nProbe = nProbe + 1; end
        if ds(k).hasPhyOutput(); nKS = nKS + 1; end
    end
    if nProbe < n
        hint = sprintf("Assign a probe on the Probe tab (%d/%d have one).", nProbe, n);
    elseif nKS >= n
        hint = "All datasets sorted - open the Review tab to inspect units.";
    else
        hint = sprintf("Set up the Kilosort tab, then Run Kilosort4 (%d/%d sorted).", nKS, n);
    end
end
