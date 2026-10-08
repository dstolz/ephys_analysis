function syncPlotEditor(obj)
%syncPlotEditor  Show, enable and list the plot editor's rows for the selected plot.
%   What the plot draws decides what shows: its kind, source and layout.
%   Rows it does not use are hidden, and so is a section left with none
%   (layoutPlotEditor). Its other options decide which of the rows shown
%   are enabled: the fill opacity only when filled; the stack spacing only
%   when stacked (no y limits or legend then); the baseline window only
%   with a baseline; a unit correlation's bins only for its peak rate; the
%   mask and the stop marks only with a stop event; the alignment
%   controls as syncAlignEnable says.
%
%   Shown for (spikes: units or detected; signals: LFP / MUA / SPIKE / AUX)
%     layout                      the kinds with more than one
%     unit classes, quality       sorted units
%     response test               spikes (its settings enabled when ticked)
%     unit ids, max units, shanks spikes
%     channels                    every kind but behavior (no units or channels)
%     event, window, selection    every kind but probemap (aligns to nothing)
%     bin, smoothing              psth, raster, heatmap of spikes, corrmap
%     mask after the stop event   psth, raster, heatmap of spikes
%     measure                     psth, rate, tuning, heatmap of spikes
%     baseline                    every kind but raster, probemap and behavior
%     grid spacing, corner labels every kind but rate and behavior (only grids use them)
%     raster, PSTH as, normalize, fill, stack   psth
%     sort raster by (and its direction), rows by group, mark events,
%       mark look                 psth, raster (enabled with a raster; the
%                                 look with lines to mark)
%     parameter, series           tuning, behavior
%     y value, x axis             behavior (jitter enabled for points)
%     value                       probemap
%     row order                   heatmap
%     sort by, label with         every kind but probemap and behavior (no units)
%     epoch rate, correlation     corrmap
%     tiles per page              the paged grids: raster; psth, tuning and evoked "grid"
%     line width                  psth, evoked, tuning, behavior
%     y limits                    psth, rate, tuning, behavior, evoked but "stack"
%     group colours, legend       psth, raster, rate, tuning, behavior, evoked but "butterfly"
%       (its place, orientation and box: enabled with the legend on)
%     heat colours                heatmap, probemap, corrmap
%     SEM                         psth, tuning, behavior, rate "bar", evoked but "butterfly"
%     stop marks                  psth, raster
%     grid                        psth, raster, evoked, rate, tuning, behavior
%     unit waveform               spikes: raster; psth and tuning "grid"
%                                 (its spikes, location, box and size
%                                 enabled when it is not Off)
%   The drop-downs list the kind's window modes ("between" for rate,
%   tuning and corrmap), its baseline modes (fewer for signals) and row
%   orders ("modulation" too for a heatmap with the auROC baseline); a
%   value the list lacks stays listed, for Validate to report.
%
%   The auROC rows show with baseline "auroc" (the plot's: from, windows,
%   call window, cutoff, calls; its unit test with cutoff "per-unit test")
%   and with the response test "auROC" (the test's: from, windows and
%   bins, cutoff; its unit test likewise). The step is enabled for
%   sliding windows, the threshold for a fixed cutoff, the resamples for
%   bootstrap and shuffle, the calls with a cutoff; smoothing and
%   normalize are off under an auROC baseline (it compares the bins as
%   counted, on its own scale).
E = obj.PlotEditor;
C = obj.PlotAlignControls;
S = obj.PlotSections;
k = obj.SelectedPlot;
has = k >= 1 && k <= numel(obj.Config.Plots);
onoff = @(tf) matlab.lang.OnOffSwitchState(tf);
set([obj.RemovePlotButton obj.DuplicatePlotButton], 'Enable', onoff(has));
obj.UpPlotButton.Enable = onoff(has && k > 1);
obj.DownPlotButton.Enable = onoff(has && k < numel(obj.Config.Plots));
if ~has
    for i = 1:numel(S)
        S(i).Shown(:) = false;
        S(i).Visible = S(i).Name == "general";
    end
    obj.PlotSections = formShow(S, "note", true);
    obj.layoutPlotEditor();
    return
end

kind = obj.Config.Plots(k).kind;
source = string(E.source.Value);
layout = string(E.layout.Value);
spikes = ismember(source, EphysAnalysisConfig.SpikeSources);
ch = plotEditorChoices(kind, source);
K = EphysAnalysisConfig.plotKinds();
row = K(K.Kind == kind, :);
psth = kind == "psth";
binned = ismember(kind, ["psth" "raster" "corrmap"]) || (kind == "heatmap" && spikes);
behavior = kind == "behavior";
grouped = ismember(kind, ["psth" "raster" "rate" "tuning" "behavior"]) || (kind == "evoked" && layout ~= "butterfly");

% --- what shows ---------------------------------------------------------------------
v = struct();
v.kind = true; v.note = true; v.id = true; v.title = true; v.source = true;
v.layout = numel(ch.Layouts) > 1;
v.classes = source == "units";
v.quality = source == "units";
v.response = spikes; v.respBaseFrom = spikes; v.respParam = spikes;
v.ids = spikes; v.maxUnits = spikes; v.shanks = spikes;
v.channels = ~behavior;
v.binMs = binned; v.smoothMs = binned;
v.maskAfterStop = binned && kind ~= "corrmap";
v.measure = ismember(kind, ["psth" "rate" "tuning"]) || (kind == "heatmap" && spikes);
v.baselineMode = ~ismember(kind, ["raster" "probemap" "behavior"]);
v.baseFrom = v.baselineMode;
auroc = v.baselineMode && string(E.baselineMode.Value) == "auroc";
v.aMethod = auroc; v.aWinMs = auroc; v.aModFrom = auroc; v.aCutoff = auroc; v.aMarks = auroc;
v.aTest = auroc && string(E.aCutoff.Value) == "test";
respAuroc = spikes && string(E.respTest.Value) == "auroc";
v.raMethod = respAuroc; v.raWinMs = respAuroc; v.raCutoff = respAuroc;
v.raTest = respAuroc && string(E.raCutoff.Value) == "test";
v.withRaster = psth; v.histStyle = psth; v.normalize = psth; v.fill = psth; v.stack = psth;
v.rasterSort = ismember(kind, ["psth" "raster"]) && spikes;
v.rasterByGroup = v.rasterSort; v.markLines = v.rasterSort; v.markMarker = v.rasterSort;
v.param = ismember(kind, ["tuning" "behavior"]); v.seriesParam = v.param;
v.yParam = behavior; v.xScale = behavior;
v.value = kind == "probemap";
v.order = kind == "heatmap";
v.metric = kind == "corrmap"; v.correlation = v.metric;
v.maxTiles = kind == "raster" || (ismember(kind, ["psth" "tuning" "evoked"]) && layout == "grid");
v.tileSpacing = ~ismember(kind, ["rate" "behavior"]);
v.fontSize = true;
v.sortDepth = ~ismember(kind, ["probemap" "behavior"]); v.labelDepth = v.sortDepth;
v.lineWidth = ismember(kind, ["psth" "evoked" "tuning" "behavior"]);
v.siteSize = kind == "probemap";
v.ylim = ismember(kind, ["psth" "rate" "tuning" "behavior"]) || (kind == "evoked" && layout ~= "stack");
v.colormap = grouped;
v.legendLoc = grouped;
v.heatColormap = ismember(kind, ["heatmap" "probemap" "corrmap"]);
v.waveMode = spikes && (kind == "raster" || (ismember(kind, ["psth" "tuning"]) && layout ~= "overlay"));
v.waveLocation = v.waveMode;
boxes = [E.showSEM E.showStop E.legend E.grid];
on = [psth || ismember(kind, ["tuning" "behavior"]) || (kind == "rate" && layout == "bar") || (kind == "evoked" && layout ~= "butterfly"), ...
    ismember(kind, ["psth" "raster"]), grouped, ismember(kind, ["psth" "raster" "evoked" "rate" "tuning" "behavior"])];
v.showSEM = any(on);
for f = string(fieldnames(v)).'
    S = formShow(S, f, v.(f));
end
packBoxes(boxes, on);
names = [S.Name];
for i = 1:numel(S)
    S(i).Visible = ~ismember(names(i), ["ref" "window" "selection"]) || row.Aligned;
end
S(names == "units").Title = "Units & channels";
if ~spikes; S(names == "units").Title = "Channels"; end
S(names == "bins").Title = "Bins & baseline";
if ~binned; S(names == "bins").Title = "Baseline"; end
S(names == "kind").Title = row.Label + " options";
obj.PlotSections = S;

% --- what the drop-downs offer ---------------------------------------------------------
offerItems(E.baselineMode, ch.BaselineModes);
orders = ch.Orders;
if auroc && kind == "heatmap"; orders(end+1) = "modulation"; end
offerItems(E.order, orders);
setWindowModes(C.Mode, ch.WindowModes);

% --- what is enabled ----------------------------------------------------------------
en = @(c, tf) set(c, 'Enable', onoff(tf));
stop = C.StopOn.Value;
stacked = psth && E.stack.Value;
en([E.binMs E.smoothMs], kind ~= "corrmap" || string(E.metric.Value) == "peak");
en([E.baseFrom E.baseTo], string(E.baselineMode.Value) ~= "none");
en([E.maskAfterStop E.showStop], stop);
en(E.fillAlpha, E.fill.Value);
en([E.respTest E.respDirection E.respBaseFrom E.respBaseTo E.respFrom E.respTo E.respParam E.respCorrection E.respAlpha], E.response.Value);
if auroc; en(E.smoothMs, false); end
en(E.normalize, ~auroc);
en(E.aStepMs, string(E.aWindows.Value) == "sliding");
en(E.aThreshold, string(E.aCutoff.Value) == "fixed");
en(E.aResamples, string(E.aTest.Value) ~= "ranksum");
en([E.aMarks E.aModOnly], string(E.aCutoff.Value) ~= "none");
on = logical(E.response.Value);
en([E.raMethod E.raWindows E.raWinMs E.raBinMs E.raCutoff E.raTest], on);
en(E.raStepMs, on && string(E.raWindows.Value) == "sliding");
en(E.raThreshold, on && string(E.raCutoff.Value) == "fixed");
en(E.raResamples, on && string(E.raTest.Value) ~= "ranksum");
en(E.stackSpacing, stacked);
raster = kind == "raster" || E.withRaster.Value;
en([E.rasterSort E.rasterSortOrder E.rasterByGroup E.markLines E.markEdge E.markScope], raster);
en([E.markMarker E.markSize E.markColor], raster && strtrim(string(E.markLines.Value)) ~= "");
en(E.jitter, layout == "points");
en([E.legend E.ylim], ~stacked);
en([E.legendLoc E.legendOrient E.legendBox], ~stacked && E.legend.Value);
en([E.waveSpikes E.waveLocation E.waveBox E.waveScale], string(E.waveMode.Value) ~= "off");
syncAlignEnable(C);
obj.layoutPlotEditor();
end


function packBoxes(boxes, on)
%packBoxes  The check boxes ON shown side by side from the left; the others hidden.
order = [find(on) find(~on)];
for i = 1:numel(order)
    boxes(order(i)).Layout.Column = i;
end
boxes(1).Parent.ColumnWidth = [repmat({'fit'}, 1, nnz(on)) repmat({0}, 1, nnz(~on))];
for i = 1:numel(boxes)
    boxes(i).Visible = matlab.lang.OnOffSwitchState(on(i));
end
end
