function pf = selectedProbeFile(obj)
    % Full path of the probe in the currently selected ProbeTable row
    % ("" if none). The table shows names + metadata; paths live here.
    pf = "";
    r = obj.SelectedProbeRow;
    if r >= 1 && r <= numel(obj.ProbePaths)
        pf = obj.ProbePaths(r);
    end
end
