function onClearBehavior(obj)
%onClearBehavior  Remove the active dataset's Epsych2 association.
if obj.refuseWhileRunning("Clear"); return; end
d = obj.currentDataset();
if isempty(d); return; end
d.BehaviorFile = "";
obj.saveManifests(d);
obj.refreshDatasetsTable();
obj.setStatus(d.Name + ": behavior association cleared.", "");
end
