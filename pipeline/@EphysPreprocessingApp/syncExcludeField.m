function syncExcludeField(obj)
    % Mirror the active dataset's ExcludeChannels into the edit field.
    % No-op for the field's enable; just reflects the per-recording list.
    if isempty(obj.ExcludeChannelsField) || ~isvalid(obj.ExcludeChannelsField)
        return
    end
    d = obj.currentDataset();
    if isempty(d)
        obj.ExcludeChannelsField.Value = '';
    else
        obj.ExcludeChannelsField.Value = ...
            char(EphysDataset.formatChannelList(d.ExcludeChannels));
    end
end
