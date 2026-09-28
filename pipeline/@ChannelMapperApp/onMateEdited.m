function onMateEdited(obj, evt)
%onMateEdited  A cell of the mates table was edited: change the chain and resolve.
if obj.Applying
    return
end
k = evt.Indices(1);
cols = ["", "Headstage", "HSConnector", "Orientation", "Offset"];
col = cols(evt.Indices(2));
value = evt.NewData;
if col == "Offset" && ~(isscalar(value) && isfinite(value) && value >= 0 && value == round(value))
    obj.refreshMatesTable();
    obj.setStatus('A channel offset is a whole number from 0 (32 for a second 32-channel headstage).', true);
    return
end
if iscategorical(value)
    value = string(value);
end
obj.applyMateEdit(k, col, value);
end
