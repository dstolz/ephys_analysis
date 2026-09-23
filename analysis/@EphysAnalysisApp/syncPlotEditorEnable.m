function syncPlotEditorEnable(obj)
%syncPlotEditorEnable  Enable the editor rows the selected plot's kind and source use.
%   Unit rows for spike sources (classes and groups for sorted units only),
%   bins for PSTHs / rasters / spike heatmaps, raster, bar / line,
%   normalize, fill (its opacity when filled), stack (its spacing when
%   stacked; no legend then) and masking for PSTHs, parameter
%   rows for tuning, value for probe maps, row order for
%   heatmaps and unit correlations, epoch rate and correlation for unit
%   correlations (bins only for their peak rate), group colours for the
%   kinds with groups, heat colours for heatmaps / probe maps / unit
%   correlations, line width for PSTHs / evoked / tuning, y limits where a
%   rate or amplitude axis takes them (unstacked PSTHs, evoked butterfly and
%   grid, rates, tuning; never rasters, stacks, heatmaps or maps), tiles
%   for paged grids, and the plot's own event / window /
%   selection only where its "Default ..." box is unticked (not for probe
%   maps, which align to nothing).
E = obj.PlotEditor;
k = obj.SelectedPlot;
ctl = [E.enabled E.id E.title E.source E.layout E.ids E.maxUnits E.channels E.shanks E.binMs E.smoothMs ...
    E.baselineMode E.baseFrom E.baseTo E.withRaster E.histStyle E.normalize E.fill E.fillAlpha E.stack E.stackSpacing ...
    E.maskAfterStop E.param E.seriesParam E.value E.order E.metric E.correlation ...
    E.maxTiles E.fontSize E.showSEM E.showStop E.legend E.grid E.ylim E.lineWidth E.colormap E.heatColormap ...
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
psth = kind == "psth";
stacked = psth && E.stack.Value;
en([E.withRaster E.histStyle E.normalize E.fill E.stack], psth);
en(E.fillAlpha, psth && E.fill.Value);
en(E.stackSpacing, stacked);
en(E.legend, ~stacked);
en(E.ylim, (psth && ~stacked) || (kind == "evoked" && string(E.layout.Value) ~= "stack") || ismember(kind, ["rate" "tuning"]));
en(E.colormap, ismember(kind, ["psth" "raster" "evoked" "rate" "tuning"]));
en(E.heatColormap, ismember(kind, ["heatmap" "probemap" "corrmap"]));
en(E.lineWidth, ismember(kind, ["psth" "evoked" "tuning"]));
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
    en([C.StopLine C.StopEdge C.StopWhich C.StopN C.StopScope], C.StopOn.Value);
end
end


function setPanel(panel, tf)
%setPanel  Enable or disable every control inside PANEL.
c = findall(panel, '-property', 'Enable');
set(c, 'Enable', matlab.lang.OnOffSwitchState(tf));
end
