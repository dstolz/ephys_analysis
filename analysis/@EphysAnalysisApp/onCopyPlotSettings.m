function onCopyPlotSettings(obj, opts)
%onCopyPlotSettings  Copy another plot's settings, part by part, onto the selected plots.
%   The plot list's "Copy from..." button: a modal window
%   (private/pickPlotSettings) offers the other plots and a box per part
%   of their settings -- the plot editor's sections (Units & channels,
%   Event reference, Epoch window, Trial selection, Bins & baseline, the
%   plot type's options, Event marks, Appearance, Unit waveform, Aux
%   signals, Text note, Overlays) and the remembered looks -- of which the
%   parts the plots' types share can be ticked. Copy gives each selected
%   plot the ticked parts of the plot picked (copyPlotSettings), whatever
%   its type: a PSTH's units, alignment and look onto a raster, say. Each
%   keeps its id, type, title and enabled, and what its type does not take
%   (the status bar says what). The editor and the preview follow.
%
%   From=ID (a plot id) skips the window, with Parts=PARTS (plotSettingParts'
%   Part names; default every part shared), for scripts and tests.
arguments
    obj (1,1) EphysAnalysisApp
    opts.From (1,1) string = string(missing)
    opts.Parts string = string(missing)
end
ks = obj.selectedPlots();
cfg = obj.gatherConfig();
if isempty(ks) || numel(cfg.Plots) <= numel(ks)
    obj.setStatus("Copy settings: select a plot, with another plot left to copy from.");
    return
end
if ismissing(opts.From)
    [from, parts, ok] = pickPlotSettings(obj.Fig, cfg.Plots, ks);
    if isvalid(obj.Fig); figure(obj.Fig); end
    if ~ok; return; end
else
    from = cfg.plotIndex(opts.From);
    if from < 1 || ismember(from, ks)
        obj.setStatus("Copy settings: no other plot """ + opts.From + """ to copy from.");
        return
    end
    parts = opts.Parts;
end
src = cfg.Plots(from);
notes = string.empty(1, 0);
copied = string.empty(1, 0);
for k = ks
    [cfg.Plots(k), c, nt] = copyPlotSettings(cfg.Plots(k), src, parts);
    copied = union(copied, c, 'stable');
    if ~isscalar(ks); nt = cfg.Plots(k).id + ": " + nt; end
    notes = [notes, nt]; %#ok<AGROW>
end
obj.applyConfig(cfg);
if ~isscalar(ks); obj.onPlotSelected(ks); end
obj.onConfigChanged("plot");
T = plotSettingParts(src.kind);
labels = T.Label(ismember(T.Part, copied)).';
if isempty(labels)
    msg = "Nothing copied from " + src.id + ".";
else
    msg = "Copied from " + src.id + ": " + strjoin(labels, ", ") + ".";
end
if ~isempty(notes); msg = msg + " " + strjoin(notes, " "); end
obj.setStatus(msg);
end
