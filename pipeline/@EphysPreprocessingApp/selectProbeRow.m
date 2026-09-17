function selectProbeRow(obj, row)
    % Programmatically focus a ProbeTable row (highlight + info panel).
    if row < 1 || row > numel(obj.ProbePaths); return; end
    obj.SelectedProbeRow = row;
    try
        obj.ProbeTable.Selection = row;   % R2023a+ row highlight
    catch
    end
    obj.onProbeSelected();
end
