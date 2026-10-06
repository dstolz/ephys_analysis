function onBrowseTransferDest(obj)
%onBrowseTransferDest  Choose the folder the Run copies the outputs to (Transfer.Destination).
start = obj.RunTransferDestField.Value;
if isempty(start) || ~isfolder(start); start = pwd; end
d = uigetdir(start, "Select the folder the outputs are copied to (<folder>\<subject>\<session>)");
figure(obj.Fig);
if isequal(d, 0); return; end
obj.RunTransferDestField.Value = d;
obj.onConfigChanged();
end
