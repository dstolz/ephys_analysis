function onAddFigure(obj, template)
%onAddFigure  Add a figure from TEMPLATE (a figureTemplates name, or a partial figure struct), edit it and preview it.
%   The new figure is selected with its first panel and layer; the picker
%   lists its observations on the active dataset and, with Auto on, the
%   first one is drawn at once. It observes what its template's following
%   layers read (addFigure: EphysAnalysisConfig.followedData) when the
%   active dataset holds that; else the first data type the dataset holds,
%   in the Observe list's order (sorted units, detected spikes, LFP, MUA,
%   SPIKE, AUX), else the dataset.
arguments
    obj (1,1) EphysAnalysisApp
    template = "rasterPsth"
end
cfg = obj.gatherConfig();
try
    [cfg, id] = cfg.addFigure(template);
catch ME
    obj.setStatus("Config: " + string(ME.message));
    return
end
cfg.Figures(end).observe.data = heldObserveData(obj, cfg.Figures(end).observe.data);
obj.SelectedFigure = numel(cfg.Figures);
obj.SelectedPanel = 1;
obj.SelectedLayer = 1;
obj.applyConfig(cfg);
obj.FigurePreviewResult = [];
obj.FigurePreviewSeconds = 0;
how = "";
if isstring(template) || ischar(template)
    T = EphysAnalysisConfig.figureTemplates();
    how = " from the template """ + T.Label(T.Template == string(template)) + """";
end
obj.setStatus("Added " + id + how + ".");
obj.autoFigurePreview();
end

