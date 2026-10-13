function onRemovePlot(obj)
%onRemovePlot  Remove the selected plots (every one picked in the tree).
%   The plot that takes the first one's place is selected next. A session
%   plot based on a removed plot stays, and the status bar says so: pick
%   another base plot for it on the Sessions tab (Validate reports it too).
ks = obj.selectedPlots();
if isempty(ks); return; end
cfg = obj.gatherConfig();
ids = [cfg.Plots(ks).id];
for id = ids
    cfg = cfg.removePlot(id);
end
obj.SelectedPlot = min(min(ks), numel(cfg.Plots));
obj.applyConfig(cfg);
if isscalar(ids)
    msg = "Removed plot " + ids + ".";
else
    msg = sprintf("Removed %d plots: %s.", numel(ids), strjoin(ids, ", "));
end
SP = cfg.SessionPlots;
if ~isempty(SP)
    orphans = SP(ismember([SP.plot], ids));
    if ~isempty(orphans)
        msg = msg + " " + sprintf("Session plot(s) %s still use it: pick another base plot on the Sessions tab.", ...
            strjoin([orphans.id], ", "));
    end
end
obj.setStatus(msg);
obj.PreviewSeconds = 0;
obj.autoPreview();
end
