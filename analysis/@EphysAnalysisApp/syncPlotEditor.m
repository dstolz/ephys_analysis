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
%     event, window, selection    every kind but probemap and waveforms (align to nothing;
%       (window: Epoch Diagram)     the whole section hides, below)
%     bin, smoothing              psth, raster, heatmap of spikes, corrmap
%     mask after the stop event   psth, raster, heatmap of spikes
%     measure                     psth, rate, tuning, heatmap of spikes
%     baseline                    every kind but raster, probemap and behavior
%     grid spacing                every kind but rate and behavior (only grids use it)
%     raster, PSTH as, normalize, fill, stack   psth
%     sort raster by (and its direction), sort event and its sequence,
%       rows by group, mark events,
%       mark look                 psth, raster (enabled with a raster; the
%                                 sort event when sorting by "event"; the
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
%     unit waveform               spikes: raster; psth and tuning "grid";
%                                 waveforms (its spikes, location, box,
%                                 size and labels enabled when it is not
%                                 Off; the location and box for the
%                                 first three only; the amplitude scale
%                                 for waveforms, its size, sites and unit
%                                 names for the "probe" layout)
%     text note                   every kind (its place, alignment, rotation,
%                                 font, colours and interpreter enabled when
%                                 it has text; x and y at "At x, y")
%     overlays                    every kind: the list and its buttons; the
%                                 rows of the overlay picked -- a line: its
%                                 position, colour and opacity; a patch: its
%                                 edges, fill and opacity and outline -- with
%                                 Duplicate and Remove enabled, and the line
%                                 style and width for a line or an outlined
%                                 patch. The section's title counts them.
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
%
%   With several plots selected (selectedPlots) a row shows only when
%   every one of them uses it, the others' own kind, source, layout and
%   options deciding theirs; never the id or title (each its own); the
%   source and layout only when they all offer the same ones; the waveform
%   rows not when unit-waveforms plots are mixed with other kinds (the mode
%   is a plot's to one, an inset's to the other); the overlays only while all
%   the plots hold the same ones (none, to add one to every plot), since an
%   edit gives each the first's list. The drop-downs offer
%   what all of them take, and Up / Down are off. What is enabled follows
%   the values shown, the first plot's.
E = obj.PlotEditor;
C = obj.PlotAlignControls;
S = obj.PlotSections;
k = obj.SelectedPlot;
ks = obj.selectedPlots();
has = k >= 1 && k <= numel(obj.Config.Plots);
onoff = @(tf) matlab.lang.OnOffSwitchState(tf);
set([obj.RemovePlotButton obj.DuplicatePlotButton], 'Enable', onoff(has));
obj.UpPlotButton.Enable = onoff(has && k > 1 && isscalar(ks));
obj.DownPlotButton.Enable = onoff(has && k < numel(obj.Config.Plots) && isscalar(ks));
if ~has
    for i = 1:numel(S)
        S(i).Shown(:) = false;
        S(i).Visible = S(i).Name == "general";
    end
    obj.PlotSections = formShow(S, "note", true);
    obj.layoutPlotEditor();
    return
end

items = overlayGather(E);
overlayList(E, items, E.ovList.UserData.shown);   % the labels follow the name and position edited
kind = obj.Config.Plots(k).kind;
source = string(E.source.Value);
layout = string(E.layout.Value);
ch = plotEditorChoices(kind, source);
K = EphysAnalysisConfig.plotKinds();
row = K(K.Kind == kind, :);
psth = kind == "psth";

% --- what shows ---------------------------------------------------------------------
[v, on] = rowsUsed(kind, source, layout, string(E.baselineMode.Value), string(E.aCutoff.Value), ...
    string(E.respTest.Value), string(E.raCutoff.Value));
auroc = v.aMethod;
aligned = row.Aligned;
kinds = kind;
for q = obj.Config.Plots(ks(2:end))
    lq = q.layout;
    if lq == ""; lq = K.DefaultLayout(K.Kind == q.kind); end
    [vq, onq] = rowsUsed(q.kind, q.source, lq, q.baseline.Mode, q.auroc.cutoff, q.units.response.test, ...
        q.units.response.auroc.cutoff);
    for f = string(fieldnames(v)).'
        v.(f) = v.(f) && vq.(f);
    end
    on = on & onq;
    cq = plotEditorChoices(q.kind, q.source);
    v.source = v.source && isequal(cq.Sources, ch.Sources);
    v.layout = v.layout && isequal(cq.Layouts, ch.Layouts);
    for f = ["BaselineModes" "Orders" "WindowModes"]
        ch.(f) = intersect(ch.(f), cq.(f), 'stable');
    end
    aligned = aligned && any(K.Aligned(K.Kind == q.kind));
    kinds(end+1) = q.kind; %#ok<AGROW>
end
if ~isscalar(ks)
    v.id = false; v.title = false;
    if any(kinds == "waveforms") && ~all(kinds == "waveforms")
        for f = ["waveMode" "waveLocation" "waveLabel" "waveScale" "waveAmp" "waveSites" "waveNames"]
            v.(f) = false;
        end
    end
end
at = E.ovList.UserData.shown;
picked = at >= 1 && at <= numel(items);
isLine = startsWith(string(E.ovKind.Value), "line");
v.ovList = true;
v.ovName = picked; v.ovKind = picked; v.ovPanel = picked; v.ovStyle = picked;
v.ovValue = picked && isLine; v.ovColor = picked && isLine;
v.ovFrom = picked && ~isLine; v.ovFill = picked && ~isLine; v.ovEdge = picked && ~isLine;
if ~isscalar(ks)
    held = {obj.Config.Plots(ks).overlays};
    if ~all(cellfun(@(o) isequaln(o, held{1}), held(2:end)))   % an edit would give each the first's list
        for f = ["ovList" "ovName" "ovKind" "ovPanel" "ovStyle" "ovValue" "ovColor" "ovFrom" "ovFill" "ovEdge"]
            v.(f) = false;
        end
    end
end
v.showSEM = any(on);
for f = string(fieldnames(v)).'
    S = formShow(S, f, v.(f));
end
packBoxes([E.showSEM E.showStop E.legend E.grid], on);
names = [S.Name];
for i = 1:numel(S)
    S(i).Visible = ~ismember(names(i), ["ref" "window" "selection"]) || aligned;
end
S(names == "units").Title = "Units & channels";
if ~v.ids; S(names == "units").Title = "Channels"; end   % ids: the spike sources'
S(names == "bins").Title = "Bins & baseline";
if ~v.binMs; S(names == "bins").Title = "Baseline"; end
S(names == "kind").Title = "Options";
if all(kinds == kind); S(names == "kind").Title = row.Label + " options"; end
S(names == "overlays").Title = "Overlays";
if ~isempty(items); S(names == "overlays").Title = "Overlays (" + numel(items) + ")"; end
obj.PlotSections = S;

% --- what the drop-downs offer ---------------------------------------------------------
offerItems(E.baselineMode, ch.BaselineModes);
orders = ch.Orders;
if v.aMethod && all(kinds == "heatmap"); orders(end+1) = "modulation"; end
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
en([E.rasterSort E.rasterSortOrder E.rasterByGroup E.markLines E.markEdge E.markScope E.markSeqText E.markSeqEdit], raster);
en([E.sortLine E.sortEdge E.sortSeqText E.sortSeqEdit], raster && strtrim(string(E.rasterSort.Value)) == "event");
en([E.markMarker E.markSize E.markColor], raster && (strtrim(string(E.markLines.Value)) ~= "" || ~isempty(E.markSeqText.UserData)));
en(E.jitter, layout == "points");
en([E.legend E.ylim], ~stacked);
en([E.legendLoc E.legendOrient E.legendBox], ~stacked && E.legend.Value);
en([E.waveSpikes E.waveLocation E.waveBox E.waveScale E.wavePP E.waveCount], string(E.waveMode.Value) ~= "off");
noted = strtrim(strjoin(string(E.annText.Value(:)).', newline)) ~= "";
en([E.annPlace E.annAlign E.annVAlign E.annRotation E.annFont E.annSize E.annBold E.annItalic E.annBox ...
    E.annColor E.annBackground E.annInterp], noted);
en([E.annX E.annY], noted && string(E.annPlace.Value) == "custom");
set([E.ovDuplicate E.ovRemove], 'Enable', onoff(picked));
outlined = isLine || ~ismember(lower(strtrim(string(E.ovEdge.Value))), ["" "none"]);
en([E.ovStyle E.ovWidth], outlined);
syncAlignEnable(C);
obj.layoutPlotEditor();
end


function [v, on] = rowsUsed(kind, source, layout, baselineMode, aCutoff, respTest, raCutoff)
%rowsUsed  The editor's rows a plot uses: V.(key) for each row's first key, ON for the Show boxes.
%   From its kind, source and layout, and the options that add rows: its
%   baseline mode and auROC cutoff, its response test and that test's auROC
%   cutoff. ON: SEM, stop marks, legend, grid.
spikes = ismember(source, EphysAnalysisConfig.SpikeSources);
ch = plotEditorChoices(kind, source);
psth = kind == "psth";
binned = ismember(kind, ["psth" "raster" "corrmap"]) || (kind == "heatmap" && spikes);
behavior = kind == "behavior";
grouped = ismember(kind, ["psth" "raster" "rate" "tuning" "behavior"]) || (kind == "evoked" && layout ~= "butterfly");
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
v.baselineMode = ~ismember(kind, ["raster" "probemap" "behavior" "waveforms"]);
v.baseFrom = v.baselineMode;
auroc = v.baselineMode && baselineMode == "auroc";
v.aMethod = auroc; v.aWinMs = auroc; v.aModFrom = auroc; v.aCutoff = auroc; v.aMarks = auroc;
v.aTest = auroc && aCutoff == "test";
respAuroc = spikes && respTest == "auroc";
v.raMethod = respAuroc; v.raWinMs = respAuroc; v.raCutoff = respAuroc;
v.raTest = respAuroc && raCutoff == "test";
v.withRaster = psth; v.histStyle = psth; v.normalize = psth; v.fill = psth; v.stack = psth;
v.rasterSort = ismember(kind, ["psth" "raster"]) && spikes;
v.rasterByGroup = v.rasterSort; v.markLines = v.rasterSort; v.markSeqText = v.rasterSort; v.markMarker = v.rasterSort;
v.sortLine = v.rasterSort; v.sortSeqText = v.rasterSort;
v.param = ismember(kind, ["tuning" "behavior"]); v.seriesParam = v.param;
v.yParam = behavior; v.xScale = behavior;
v.value = kind == "probemap";
v.order = kind == "heatmap";
v.metric = kind == "corrmap"; v.correlation = v.metric;
v.maxTiles = kind == "raster" || (ismember(kind, ["psth" "tuning" "evoked" "waveforms"]) && layout == "grid");
v.tileSpacing = ~ismember(kind, ["rate" "behavior"]) && ~(kind == "waveforms" && layout == "probe");
v.fontSize = true;
v.sortDepth = ~ismember(kind, ["probemap" "behavior"]) && ~(kind == "waveforms" && layout == "probe"); v.labelDepth = v.sortDepth;
v.lineWidth = ismember(kind, ["psth" "evoked" "tuning" "behavior" "waveforms"]);
v.siteSize = kind == "probemap";
v.ylim = ismember(kind, ["psth" "rate" "tuning" "behavior"]) || (kind == "evoked" && layout ~= "stack") ...
    || (kind == "waveforms" && layout == "grid");
v.colormap = grouped;
v.legendLoc = grouped;
v.heatColormap = ismember(kind, ["heatmap" "probemap" "corrmap"]);
inset = spikes && (kind == "raster" || (ismember(kind, ["psth" "tuning"]) && layout ~= "overlay"));
wavePlot = spikes && kind == "waveforms";
v.waveMode = inset || wavePlot;
v.waveLocation = inset;
v.waveLabel = v.waveMode;
v.waveScale = inset || (wavePlot && layout == "probe");
v.waveAmp = wavePlot;
v.waveSites = wavePlot && layout == "probe"; v.waveNames = v.waveSites;
for f = ["annText" "annPlace" "annX" "annAlign" "annRotation" "annFont" "annBold" "annColor" "annInterp"]
    v.(f) = true;   % the text note is every kind's
end
v.ovList = true;   % so are the overlays (their rows follow the overlay picked: syncPlotEditor)
on =[psth || ismember(kind, ["tuning" "behavior"]) || (kind == "rate" && layout == "bar") || (kind == "evoked" && layout ~= "butterfly"), ...
    ismember(kind, ["psth" "raster"]), grouped, ismember(kind, ["psth" "raster" "evoked" "rate" "tuning" "behavior"]) ...
    || (kind == "waveforms" && layout == "grid")];
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
