function onRowsModeChanged(obj)
%onRowsModeChanged  The Rows dropdown or the channel list changed.
if obj.Applying
    return
end
mode = string(obj.RowsModeDrop.Value);
switch mode
    case "in-order"
        obj.setRows("in-order");
    case "dataset"
        if obj.RowsMode == "dataset" && ~isempty(obj.ChannelNumbers)
            return
        end
        obj.onUseDataset();
        if obj.RowsMode ~= "dataset"
            obj.fillCascade();    % nothing chosen: back to what it was
        end
    case "custom"
        txt = strtrim(string(obj.CustomRowsField.Value));
        if txt == ""
            obj.RowsMode = "custom";
            obj.fillCascade();
            obj.setStatus('Type the recorded hardware channels (0-based) in recording order, e.g. 0-31.', false);
            return
        end
        try
            v = ChannelMapperApp.parseChannelList(txt);
            obj.setRows("custom", v);
            obj.setStatus(sprintf('Rows from a list of %d channels.', numel(v)), false);
        catch ME
            obj.setStatus(ME.message, true);
        end
end
end
