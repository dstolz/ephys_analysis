function recordFigureEdit(obj, cfg, label, opts)
%recordFigureEdit  Note an edit of the figures (CFG about to be the config) in the undo history, named LABEL.
%   Called just before obj.Config = CFG by each path that edits the
%   figures: onConfigChanged (an editor control), commitFigureEdit (a
%   structural edit), applyConfig with Action= (the figure list's Add,
%   Remove, Duplicate, Up / Down), setFiguresEnabled,
%   rememberFigureAesthetics, onPickFigureDatasets, onApplyToFigures and
%   onCopyFigureSettings (Copy settings...). The step holds
%   obj.Config.Figures and CFG.Figures and the figure, panel and layer
%   selected (FigureEditHistory.record); an edit that leaves the figures as
%   they were is not one. Key=KEY (the control) lets a burst of edits
%   from one control be one step. Undo and Redo (onUndoRedo) record
%   nothing: they apply through applyConfig without Action. The Edit menu
%   follows (refreshEditMenu). The options the edit set on the selected
%   figure's panels are remembered for new panels of their types
%   (rememberPanelOptions: a preference, not the config).
arguments
    obj (1,1) EphysAnalysisApp
    cfg (1,1) EphysAnalysisConfig
    label (1,1) string
    opts.Key = []
end
rememberPanelOptions(obj, obj.Config.Figures, cfg.Figures);   % a new panel of the type starts from them
obj.FigureHistory = obj.FigureHistory.record(obj.Config.Figures, cfg.Figures, label, Key=opts.Key, ...
    Selection=[obj.SelectedFigure obj.SelectedPanel obj.SelectedLayer]);
refreshEditMenu(obj);
end
