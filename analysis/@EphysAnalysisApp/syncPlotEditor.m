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
%     unit classes                sorted units
%     unit ids, max units, shanks spikes
%     event, window, selection    every kind but probemap (aligns to nothing)
%     bin, smoothing              psth, raster, heatmap of spikes, corrmap
%     mask after the stop event   psth, raster, heatmap of spikes
%     baseline                    every kind but raster and probemap
%     raster, PSTH as, normalize, fill, stack   psth
%     parameter, series           tuning
%     value                       probemap
%     row order                   heatmap, corrmap
%     epoch rate, correlation     corrmap
%     tiles per page              the paged grids: raster; psth, tuning and evoked "grid"
%     line width                  psth, evoked, tuning
%     y limits                    psth, rate, tuning, evoked but "stack"
%     group colours, legend       psth, raster, rate, tuning, evoked but "butterfly"
%     heat colours                heatmap, probemap, corrmap
%     SEM                         psth, tuning, rate "bar", evoked but "butterfly"
%     stop marks                  psth, raster
%     grid                        psth, raster, evoked, rate, tuning
%   The drop-downs list the kind's window modes ("between" for rate,
%   tuning and corrmap), its baseline modes (fewer for signals) and row
%   orders; a value the list lacks stays listed, for Validate to report.
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
grouped = ismember(kind, ["psth" "raster" "rate" "tuning"]) || (kind == "evoked" && layout ~= "butterfly");

% --- what shows ---------------------------------------------------------------------
v = struct();
v.kind = true; v.note = true; v.id = true; v.title = true; v.source = true;
v.layout = numel(ch.Layouts) > 1;
v.classes = source == "units";
v.ids = spikes; v.maxUnits = spikes; v.shanks = spikes;
v.channels = true;
v.binMs = binned; v.smoothMs = binned;
v.maskAfterStop = binned && kind ~= "corrmap";
v.baselineMode = ~ismember(kind, ["raster" "probemap"]);
v.baseFrom = v.baselineMode;
v.withRaster = psth; v.histStyle = psth; v.normalize = psth; v.fill = psth; v.stack = psth;
v.param = kind == "tuning"; v.seriesParam = v.param;
v.value = kind == "probemap";
v.order = ismember(kind, ["heatmap" "corrmap"]);
v.metric = kind == "corrmap"; v.correlation = v.metric;
v.maxTiles = kind == "raster" || (ismember(kind, ["psth" "tuning" "evoked"]) && layout == "grid");
v.fontSize = true;
v.lineWidth = ismember(kind, ["psth" "evoked" "tuning"]);
v.ylim = ismember(kind, ["psth" "rate" "tuning"]) || (kind == "evoked" && layout ~= "stack");
v.colormap = grouped;
v.heatColormap = ismember(kind, ["heatmap" "probemap" "corrmap"]);
boxes = [E.showSEM E.showStop E.legend E.grid];
on = [psth || kind == "tuning" || (kind == "rate" && layout == "bar") || (kind == "evoked" && layout ~= "butterfly"), ...
    ismember(kind, ["psth" "raster"]), grouped, ismember(kind, ["psth" "raster" "evoked" "rate" "tuning"])];
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
offerItems(E.order, ch.Orders);
setWindowModes(C.Mode, ch.WindowModes);

% --- what is enabled ----------------------------------------------------------------
en = @(c, tf) set(c, 'Enable', onoff(tf));
stop = C.StopOn.Value;
stacked = psth && E.stack.Value;
en([E.binMs E.smoothMs], kind ~= "corrmap" || string(E.metric.Value) == "peak");
en([E.baseFrom E.baseTo], string(E.baselineMode.Value) ~= "none");
en([E.maskAfterStop E.showStop], stop);
en(E.fillAlpha, E.fill.Value);
en(E.stackSpacing, stacked);
en([E.legend E.ylim], ~stacked);
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
