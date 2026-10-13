function onDuplicateSessionPlot(obj)
%onDuplicateSessionPlot  Copy the selected session plot under a new id ("<base>_sessions_<n>"), right after it, and select the copy.
%   The copy keeps every setting, its remembered looks too.
k = obj.SelectedSessionPlot;
if k < 1 || k > numel(obj.Config.SessionPlots); return; end
cfg = obj.gatherConfig();
sp = cfg.SessionPlots(k);
from = sp.id;
sp.id = "";
[cfg, id] = cfg.addSessionPlot(sp);   % appended
P = cfg.SessionPlots;
cfg.SessionPlots = [P(1:k) P(end) P(k+1:end-1)];
obj.SelectedSessionPlot = k + 1;
obj.applyConfig(cfg);
resetSessionPreview(obj, "Press Preview to draw " + id + " over its sessions.");
obj.setStatus("Duplicated session plot " + from + " as " + id + ".");
obj.autoSessionPreview();
end
