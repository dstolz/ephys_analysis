function closeSequenceDialog(obj, holders)
%closeSequenceDialog  Close the Event sequence window when it edits one of HOLDERS.
%   A panel that shows other values (another plot, another config) closes
%   the window editing its sequence, so an Apply cannot land on them.
f = obj.SequenceDialog;
if isempty(f) || ~isvalid(f) || ~isstruct(f.UserData) || ~isfield(f.UserData, 'Holder'); return; end
if any(arrayfun(@(h) isequal(h, f.UserData.Holder), holders))
    delete(f);
end
end
