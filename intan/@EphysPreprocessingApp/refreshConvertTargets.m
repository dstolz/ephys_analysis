function refreshConvertTargets(obj)
    % Rebuild the targets table (not while a run is updating it).
    if obj.ConvRunning || isempty(obj.ConvTargetsTable) ...
            || ~isvalid(obj.ConvTargetsTable)
        return
    end
    T = obj.convertTargets(obj.gatherConvertConfig());
    obj.ConvTargetsTable.Data = T(:, {'Dataset', 'Format', 'OutputFile', 'Status'});
end
