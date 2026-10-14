function commitFigureEdit(obj, cfg, msg)
%commitFigureEdit  Take CFG, changed in the selected figure's arrangement, a panel or its layers, and show it.
%   The structural edits of the Figures tab (a panel added, removed, moved
%   or of another type; a layer added, removed or moved) change the gathered
%   config and come here: the runner gets it, the list, the editor (the
%   panel and layer selected: SelectedPanel, SelectedLayer), the
%   observation picker and the epoch diagram follow, the status bar says
%   MSG, and the preview is redrawn (Auto) or marked out of date.
obj.Config = cfg;
if ~isempty(obj.Runner); obj.Runner.Config = cfg; end
obj.refreshFigureList();
obj.applyFigureEditor();
obj.refreshFigureObservations();
obj.refreshEpochDiagram();
if msg ~= ""; obj.setStatus(msg); end
obj.autoFigurePreview();
obj.updateTitle();
end
