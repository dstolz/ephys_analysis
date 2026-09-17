function onProbeNotesEdited(obj, evt)
    % Persist an edited Notes cell back into the probe .json file.
    if isempty(evt.Indices); return; end
    row = evt.Indices(1);
    if row < 1 || row > numel(obj.ProbePaths); return; end
    pf = obj.ProbePaths(row);
    try
        obj.saveProbeNotes(pf, string(evt.NewData));
    catch ME
        uialert(obj.Fig, "Could not save notes: " + string(ME.message), ...
            "Probe notes");
        T = obj.ProbeTable.Data;   % revert the displayed value
        if istable(T) && row <= height(T)
            T.Notes(row) = string(evt.PreviousData);
            obj.ProbeTable.Data = T;
        end
    end
end
