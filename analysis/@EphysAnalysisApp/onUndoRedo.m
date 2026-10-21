function onUndoRedo(obj, how)
%onUndoRedo  Edit > Undo (Ctrl+Z) or Redo (Ctrl+Y, Ctrl+Shift+Z): the figure editor's last edit taken back, or done again.
%   HOW "undo" shows the figures as they were before the last edit
%   recorded (FigureHistory: recordFigureEdit), "redo" as they were after
%   the last edit undone. Only Config.Figures changes: the Source, Export
%   and Report settings stay as they are. The editor goes back to where
%   the edit was made (its figure, panel and layer, as near as the
%   figures restored allow; a figure or panel that comes back, as a
%   removed one undone, is selected) and shows it through applyConfig, which
%   records nothing; the list, the observation picker, the epoch diagram
%   and the preview follow as after an edit (autoFigurePreview), and the
%   title's "*" goes when the figures are back as saved. The status bar
%   names the edit (Undid "Add panel".); with nothing to undo or redo it
%   says so.
arguments
    obj (1,1) EphysAnalysisApp
    how (1,1) string {mustBeMember(how, ["undo" "redo"])}
end
if how == "undo"
    [H, step] = obj.FigureHistory.undo();
else
    [H, step] = obj.FigureHistory.redo();
end
if isempty(step)
    obj.setStatus("Nothing to " + how + ".");
    return
end
obj.FigureHistory = H;
cfg = obj.Config;
if how == "undo"
    to = step.Before;
    from = step.After;
    done = "Undid";
else
    to = step.After;
    from = step.Before;
    done = "Redid";
end
cfg.Figures = to;
sel = cameBack(to, from, step.Selection);
obj.SelectedFigure = sel(1);
obj.SelectedPanel = sel(2);
obj.SelectedLayer = sel(3);
obj.applyConfig(cfg);   % clamps the selection to the figures restored
if obj.SelectedFigure >= 1; obj.autoFigurePreview(); end
refreshEditMenu(obj);
obj.setStatus(done + " """ + step.Label + """.");
end


function sel = cameBack(to, from, sel)
%cameBack  The selection to show: SEL, or the figure or panel in TO that FROM lacks (one removed, now back).
%   Matched by id where the count differs only: an automatic figure id
%   may follow an edit of the panels.
if numel(to) ~= numel(from)
    k = find(~ismember(figureIds(to), figureIds(from)), 1);
    if ~isempty(k); sel = [k 1 1]; end
    return
end
k = sel(1);
if k < 1 || k > numel(to); return; end
p = to(k).panels;
q = from(k).panels;
if numel(p) ~= numel(q)
    j = find(~ismember(panelIds(p), panelIds(q)), 1);
    if ~isempty(j); sel(2:3) = [j 1]; end
end
end


function ids = figureIds(F)
ids = string.empty(1, 0);
if ~isempty(F); ids = [F.id]; end
end


function ids = panelIds(P)
ids = string.empty(1, 0);
if ~isempty(P); ids = [P.id]; end
end
