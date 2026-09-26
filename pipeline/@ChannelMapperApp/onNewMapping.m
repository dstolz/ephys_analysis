function onNewMapping(obj)
%onNewMapping  Start an unsaved mapping from the current package: default mates, rows in order.
obj.MappingName = "";
obj.RowsMode = "in-order";
obj.ChannelNumbers = double.empty(1, 0);
obj.DatasetName = "";
obj.onChainChanged("headstage");
obj.setStatus('New mapping: choose the probe, package and headstage.', false);
end
