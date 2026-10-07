function onNewMapping(obj)
%onNewMapping  Start an unsaved mapping from the current package: default mates, rows in order, kcoords = shanks.
obj.MappingName = "";
obj.KCoords = zeros(0, 1);
obj.KCoordsFor = "";
obj.RowsMode = "in-order";
obj.ChannelNumbers = double.empty(1, 0);
obj.DatasetName = "";
obj.onChainChanged("headstage");
obj.setStatus('New mapping: choose the probe, package and headstage.', false);
end
