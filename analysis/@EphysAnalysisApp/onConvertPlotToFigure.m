function onConvertPlotToFigure(obj)
%onConvertPlotToFigure  Make a figure of each selected plot (EphysAnalysisConfig.convertPlotToFigure) and show the last on the Figures tab.
%   The plot list's "Convert to figure" button. Each selected plot becomes
%   a figure that draws what it draws (plotToFigure: a PSTH's raster, its
%   event marks and aux signal as panels; the plot's alignment, unit
%   filter, bins and look); the plots stay. The last figure made is
%   selected on the Figures tab and previewed. The status bar says what
%   was converted and what could not be carried (the notes, joined by
%   "; "), or why a plot cannot be converted (rate, tuning and behavior
%   plots have no panel type yet).
ks = obj.selectedPlots();
if isempty(ks)
    obj.setStatus("Convert to figure: select a plot.");
    return
end
cfg = obj.gatherConfig();
msgs = string.empty(1, 0);
made = 0;
for k = ks
    pid = cfg.Plots(k).id;
    try
        [cfg, id, notes] = cfg.convertPlotToFigure(pid);
    catch ME
        if ME.identifier ~= "EphysAnalysisConfig:NotConvertible"; rethrow(ME); end
        msgs(end+1) = string(ME.message); %#ok<AGROW>
        continue
    end
    made = numel(cfg.Figures);
    m = "Converted " + pid + " to figure " + id + ".";
    if ~isempty(notes); m = m + " " + strjoin(notes, "; "); end
    msgs(end+1) = m; %#ok<AGROW>
end
if made > 0
    obj.SelectedFigure = made;
    obj.SelectedPanel = 1;
    obj.SelectedLayer = 1;
    obj.applyConfig(cfg);
    obj.FigurePreviewResult = [];
    obj.FigurePreviewSeconds = 0;
    obj.selectTab(obj.TabFigures);   % onTabChanged previews it (Auto)
end
obj.setStatus(strjoin(msgs, " "));
end
