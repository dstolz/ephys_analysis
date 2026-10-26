function onFigureAxisEdited(obj, id, panel, change)
%onFigureAxisEdited  Keep a right-click axis edit of a drawn figure: its panels' new label text or axis side.
%   onFigureAxisEdited(OBJ, ID, PANEL, CHANGE) is the preview's (and an
%   open window's, while the app is open) renderFigure OnAxisEdit: the
%   menu of a panel's x or y label ("Edit label text...", "Move to top",
%   ...) or of its axes ("Edit X label text...", "Move Y axis to right",
%   ...; PlotAesthetics.enableEditing) sets the fields of CHANGE (a
%   struct of xLabel, yLabel, xSide, ySide) on the panels PANEL (ids, a
%   string row: one, or every panel of the figure for "Move every panel's
%   X axis to top", ...) of figure ID. The edit goes into the config as
%   the editor's own edits do (commitFigureEdit: the preview is drawn
%   again, or marked out of date), as one undoable step ("Label text",
%   "Axis side", or "Every panel's axis side"); in the selected figure an
%   edit of one panel selects it, so its X axis and Y axis rows show the
%   new values. An every-panel move that changes nothing says so. A
%   panel's own x label text on a panel whose x label the drawn preview
%   hides (an inner panel of a time stack: figureTimeStack) is kept, and
%   the status bar says the stack hides it.
%
%   See also renderFigure, PlotAesthetics.enableEditing, gotoFigureSetting.
arguments
    obj (1,1) EphysAnalysisApp
    id (1,1) string
    panel (1,:) string
    change (1,1) struct
end
cfg = obj.Config;
id = followedFigureId(obj, id);   % renamed since it was drawn (an automatic id that followed an edit)
k = cfg.figureIndex(id);
if k < 1
    obj.setStatus("Figure " + id + " is gone: the axis was not changed.");
    return
end
every = numel(panel) > 1;
js = [];
if ~isempty(cfg.Figures(k).panels); js = find(ismember([cfg.Figures(k).panels.id], panel)); end
if isempty(js)
    obj.setStatus(id + " has no panel " + strjoin(panel, ", ") + " any more: the axis was not changed.");
    return
end
said = strings(1, 0);
moved = false(1, numel(js));   % each panel: a value of it changed
fg = cfg.Figures(k);   % edited here, given back once (each assignment to Figures normalizes them all)
for f = string(fieldnames(change)).'
    v = string(change.(f));
    switch f
        case {"xLabel" "yLabel"}
            v = strtrim(v);
            what = extractBefore(f, 2) + " label ";
            if v == ""
                what = what + "automatic";
            else
                what = what + """" + v + """";
                if f == "xLabel" && ~every && stackHidesXLabel(obj, id, panel)
                    what = what + " (kept, but not shown: the time stack labels its time on another of its panels)";
                end
            end
            said(end+1) = what; %#ok<AGROW>
        case "xSide"
            if ~ismember(v, EphysAnalysisConfig.PanelXSides); continue; end
            said(end+1) = "x axis on the " + v; %#ok<AGROW>
        case "ySide"
            if ~ismember(v, EphysAnalysisConfig.PanelYSides); continue; end
            said(end+1) = "y axis on the " + v; %#ok<AGROW>
        otherwise
            continue
    end
    for i = 1:numel(js)
        moved(i) = moved(i) || fg.panels(js(i)).(f) ~= v;
        fg.panels(js(i)).(f) = v;
    end
end
if isempty(said); return; end
cfg.Figures(k) = fg;
if every
    if ~any(moved)
        obj.setStatus("Every panel of " + id + " has its " + strjoin(said, ", ") + " already.");
        return
    end
    msg = id + ": " + strjoin(said, ", ") + " on every panel (" + strjoin([cfg.Figures(k).panels(js(moved)).id], ", ") + " moved).";
    commitFigureEdit(obj, cfg, msg, Action="Every panel's axis side");   % the Edit menu's "Undo Every panel's axis side"
    return
end
j = js(1);
if k == obj.SelectedFigure && j ~= obj.SelectedPanel
    obj.SelectedPanel = j;   % its rows show the change
    obj.SelectedLayer = 1;
end
action = "Axis side";   % the Edit menu's "Undo Axis side"
if any(isfield(change, ["xLabel" "yLabel"])); action = "Label text"; end
commitFigureEdit(obj, cfg, id + "." + panel + ": " + strjoin(said, ", ") + ".", Action=action);
end


function tf = stackHidesXLabel(obj, id, panel)
%stackHidesXLabel  The preview drawn of figure ID shows no x tick labels or x label on panel PANEL: a time stack tells the time on another of its panels.
%   False when the preview is not drawn, or draws another figure.
tf = false;
F = obj.FigurePreviewResult;
P = obj.FigurePreviewPanel;
if obj.FigurePreviewState ~= "drawn" || ~isstruct(F) || ~isfield(F, 'id') || string(F.id) ~= id || isempty(P) || ~isvalid(P)
    return
end
axs = findall(P, 'Type', 'axes');
axs = axs(arrayfun(@(a) isequal(string(getappdata(a, 'FigurePanel')), panel) ...
    || isequal(string(getappdata(a, 'PlotTile')), panel), axs));   % (a coherence panel's phase strip: tagged with the panel only)
if isempty(axs); return; end
tf = all(arrayfun(@(a) isempty(a.XTickLabel) && strcmp(a.XTickLabelMode, 'manual') ...
    && strjoin(string(a.XLabel.String), "") == "", axs));
end
