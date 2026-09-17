function onClearBehavior(obj)
%onClearBehavior  Remove the selected dataset's Epsych2 association.
d = obj.currentDataset();
if isempty(d); return; end
d.BehaviorFile = "";
d.writeManifest();
obj.refreshDatasetsTable();
obj.setStatus(d.Name + ": behavior association cleared.", "");
end
