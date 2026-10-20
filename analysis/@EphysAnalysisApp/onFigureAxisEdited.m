function onFigureAxisEdited(obj, id, panel, change)
%onFigureAxisEdited  Keep an axis label's right-click edit of a drawn figure: its panel's new label text or axis side.
%   onFigureAxisEdited(OBJ, ID, PANEL, CHANGE) is the preview's (and an
%   open window's, while the app is open) renderFigure OnAxisEdit: the
%   menu of a panel's x or y label ("Edit label text...", "Move to top",
%   ...; PlotAesthetics.enableEditing) sets the fields of CHANGE (a
%   struct of xLabel, yLabel, xSide, ySide) on panel PANEL (an id) of
%   figure ID. The edit goes into the config as the editor's own edits do
%   (commitFigureEdit: the preview is drawn again, or marked out of date);
%   in the selected figure the panel is selected,
%   so its X axis and Y axis rows show the new values.
%
%   See also renderFigure, PlotAesthetics.enableEditing, gotoFigureSetting.
arguments
    obj (1,1) EphysAnalysisApp
    id (1,1) string
    panel (1,1) string
    change (1,1) struct
end
cfg = obj.Config;
id = followedFigureId(obj, id);   % renamed since it was drawn (an automatic id that followed an edit)
k = cfg.figureIndex(id);
if k < 1
    obj.setStatus("Figure " + id + " is gone: the axis was not changed.");
    return
end
j = [];
if ~isempty(cfg.Figures(k).panels); j = find([cfg.Figures(k).panels.id] == panel, 1); end
if isempty(j)
    obj.setStatus(id + " has no panel " + panel + " any more: the axis was not changed.");
    return
end
said = strings(1, 0);
for f = string(fieldnames(change)).'
    v = string(change.(f));
    switch f
        case {"xLabel" "yLabel"}
            v = strtrim(v);
            what = extractBefore(f, 2) + " label ";
            if v == ""; said(end+1) = what + "automatic"; else; said(end+1) = what + """" + v + """"; end %#ok<AGROW>
        case "xSide"
            if ~ismember(v, EphysAnalysisConfig.PanelXSides); continue; end
            said(end+1) = "x axis on the " + v; %#ok<AGROW>
        case "ySide"
            if ~ismember(v, EphysAnalysisConfig.PanelYSides); continue; end
            said(end+1) = "y axis on the " + v; %#ok<AGROW>
        otherwise
            continue
    end
    cfg.Figures(k).panels(j).(f) = v;
end
if isempty(said); return; end
if k == obj.SelectedFigure && j ~= obj.SelectedPanel
    obj.SelectedPanel = j;   % its rows show the change
    obj.SelectedLayer = 1;
end
commitFigureEdit(obj, cfg, id + "." + panel + ": " + strjoin(said, ", ") + ".");
end
