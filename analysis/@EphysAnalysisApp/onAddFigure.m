function onAddFigure(obj, template)
%onAddFigure  Add a figure, edit it and preview it: a blank one and the New panel window, or one from TEMPLATE.
%   onAddFigure(OBJ) (the Add button) adds a blank figure (one empty
%   cell) with an automatic id ("Blank dataset") and opens the New panel
%   window on it (onNewPanel): OK adds its first panel, which the id
%   ("PSTH units") and, for a figure that observed the dataset, the
%   Observe choice then follow; Cancel leaves the figure blank.
%   onAddFigure(OBJ, TEMPLATE) adds a figure from TEMPLATE (a
%   figureTemplates name, or a partial figure struct) without the
%   window, for scripts and tests; the app offers no template.
%   The new figure is selected with its first panel and layer; the picker
%   lists its observations on the active dataset and, with Auto on, the
%   first one is drawn at once. It observes what its following layers
%   read (addFigure: EphysAnalysisConfig.followedData) when the active
%   dataset holds that; else the first data type the dataset holds, in
%   the Observe list's order (sorted units, detected spikes, LFP, MUA,
%   SPIKE, AUX), else the dataset.
arguments
    obj (1,1) EphysAnalysisApp
    template = string(missing)
end
ask = isstring(template) && isscalar(template) && ismissing(template);   % the Add button: blank, then New panel
if ask; template = "blank"; end
cfg = obj.gatherConfig();
try
    cfg = cfg.addFigure(template);
catch ME
    obj.setStatus("Config: " + string(ME.message));
    return
end
cfg.Figures(end).observe.data = heldObserveData(obj, cfg.Figures(end).observe.data);
id = cfg.Figures(end).id;   % an automatic id follows the data observed
obj.SelectedFigure = numel(cfg.Figures);
obj.SelectedPanel = 1;
obj.SelectedLayer = 1;
obj.applyConfig(cfg);
obj.FigurePreviewResult = [];
obj.FigurePreviewSeconds = 0;
if ask
    obj.setStatus("Added " + id + ", a blank figure: pick its first panel.");
    obj.autoFigurePreview();
    obj.onNewPanel();
    return
end
how = "";
if isstring(template) || ischar(template)
    T = EphysAnalysisConfig.figureTemplates();
    how = " from the template """ + T.Label(T.Template == string(template)) + """";
end
obj.setStatus("Added " + id + how + ".");
obj.autoFigurePreview();
end
