function syncPlotEditorEnable(obj)
%syncPlotEditorEnable  Enable the editor rows the selected plot's kind and source use.
%   Unit rows for spike sources (classes and groups for sorted units only),
%   bins for PSTHs / rasters / spike heatmaps, raster, bar / line and
%   masking for PSTHs, parameter rows for tuning, value for probe maps, row order for
%   heatmaps and unit correlations, epoch rate and correlation for unit
%   correlations (bins only for their peak rate), tiles for paged grids, and the plot's own event / window /
%   selection only where its "Default ..." box is unticked (not for probe
%   maps, which align to nothing).
E = obj.PlotEditor;
k = obj.SelectedPlot;
ctl = [E.enabled E.id E.title E.source E.layout E.ids E.maxUnits E.channels E.shanks E.binMs E.smoothMs ...
    E.baselineMode E.baseFrom E.baseTo E.withRaster E.histStyle E.maskAfterStop E.param E.seriesParam E.value E.order E.metric E.correlation ...
    E.maxTiles E.fontSize E.showSEM E.showStop E.legend E.grid E.ylim E.heatColormap ...
    E.defaultRef E.defaultWindow E.defaultSelection];
classes = struct2cell(E.classes);
classes = [classes{:}];
if k < 1 || k > numel(obj.Config.Plots)
    set([ctl classes], 'Enable', 'off');
    setPanel(obj.PlotAlignControls.RefPanel, false);
    setPanel(obj.PlotAlignControls.WindowPanel, false);
    setPanel(obj.PlotAlignControls.SelectionPanel, false);
    set([obj.RemovePlotButton obj.DuplicatePlotButton obj.UpPlotButton obj.DownPlotButton], 'Enable', 'off');
    return
end
set(ctl, 'Enable', 'on');
set([obj.RemovePlotButton obj.DuplicatePlotButton], 'Enable', 'on');
obj.UpPlotButton.Enable = matlab.lang.OnOffSwitchState(k > 1);
obj.DownPlotButton.Enable = matlab.lang.OnOffSwitchState(k < numel(obj.Config.Plots));
kind = obj.Config.Plots(k).kind;
source = string(E.source.Value);
spikes = ismember(source, EphysAnalysisConfig.SpikeSources);
aligned = kind ~= "probemap";
en = @(c, tf) set(c, 'Enable', matlab.lang.OnOffSwitchState(tf));
en(classes, source == "units");
en([E.ids E.maxUnits E.shanks], spikes);
en([E.binMs E.smoothMs], ismember(kind, ["psth" "raster"]) || (kind == "heatmap" && spikes) ...
    || (kind == "corrmap" && string(E.metric.Value) == "peak"));
en([E.baselineMode E.baseFrom E.baseTo], ~ismember(kind, ["raster" "probemap"]));
en([E.baseFrom E.baseTo], ~ismember(kind, ["raster" "probemap"]) && string(E.baselineMode.Value) ~= "none");
en([E.withRaster E.histStyle], kind == "psth");
en(E.maskAfterStop, ismember(kind, ["psth" "raster"]) || (kind == "heatmap" && spikes));
en([E.param E.seriesParam], kind == "tuning");
en(E.value, kind == "probemap");
en(E.order, ismember(kind, ["heatmap" "corrmap"]));
en([E.metric E.correlation], kind == "corrmap");
en(E.maxTiles, ismember(kind, ["psth" "raster" "tuning" "evoked"]));
en(E.showStop, ismember(kind, ["psth" "raster"]));
en([E.defaultRef E.defaultWindow E.defaultSelection], aligned);
setPanel(obj.PlotAlignControls.RefPanel, aligned && ~E.defaultRef.Value);
setPanel(obj.PlotAlignControls.WindowPanel, aligned && ~E.defaultWindow.Value);
setPanel(obj.PlotAlignControls.SelectionPanel, aligned && ~E.defaultSelection.Value);
C = obj.PlotAlignControls;
if aligned && ~E.defaultWindow.Value
    en([C.StopLine C.StopEdge C.StopWhich C.StopScope], C.StopOn.Value);
end
end


function setPanel(panel, tf)
%setPanel  Enable or disable every control inside PANEL.
c = findall(panel, '-property', 'Enable');
set(c, 'Enable', matlab.lang.OnOffSwitchState(tf));
end
