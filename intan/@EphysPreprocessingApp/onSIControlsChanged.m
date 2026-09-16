function onSIControlsChanged(obj)
    % Sync enable states, push the config onto every scanned dataset, and
    % persist it whenever a preprocessing control changes.
    obj.syncSIEnableStates();
    if ~isempty(obj.Project) && obj.Project.NumDatasets > 0
        sicfg = obj.gatherSIConfig();
        for k = 1:obj.Project.NumDatasets
            obj.Project.Datasets(k).SIConfig = sicfg;
        end
    end
    obj.savePreferences();
end
