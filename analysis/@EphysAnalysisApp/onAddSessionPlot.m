function onAddSessionPlot(obj, base)
%onAddSessionPlot  Add a session plot on the base plot BASE (default: the one picked under the list) and edit it.
%   Its id is "<base>_sessions_<n>"; every other field is the default
%   (EphysAnalysisConfig.defaults("SessionPlot")): the ticked datasets, a
%   color per session, units pooled, trial groups pooled.
arguments
    obj (1,1) EphysAnalysisApp
    base (1,1) string = string(obj.AddSessionBaseDropDown.Value)
end
if base == ""
    obj.setStatus("Sessions: add a PSTH, raster, evoked, rate, tuning, behavior, heatmap or waveforms plot on the Plots tab first.");
    return
end
cfg = obj.gatherConfig();
if cfg.plotIndex(base) == 0
    obj.setStatus("Sessions: there is no plot " + base + ".");
    return
end
[cfg, id] = cfg.addSessionPlot(base);
obj.SelectedSessionPlot = numel(cfg.SessionPlots);
obj.applyConfig(cfg);
resetSessionPreview(obj, "Press Preview to draw " + id + " over its sessions.");
obj.setStatus("Added session plot " + id + " on " + base + ".");
obj.autoSessionPreview();
end
