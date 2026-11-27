function changed = changeFigures(obj, cfg, label)
%changeFigures  Take CFG, the config with some figures changed from the command line, as one edit, and show it.
%   CHANGED = changeFigures(OBJ, CFG, LABEL) is how the command line's
%   changes (OBJ.Plots, a PlotConsole) reach the app: CFG is the app's
%   config (OBJ.Config) with figures changed -- their remembered looks
%   (aesthetics), their settings or their panels' -- and as many figures
%   in the same order. The change is one step of the undo history, named
%   LABEL (recordFigureEdit: the Edit menu's "Undo <LABEL>"); the runner
%   gets the config, the title shows unsaved changes, and the status bar
%   says which figures changed. CHANGED are their indices (empty: CFG
%   holds the figures as they are, and nothing is done).
%
%   What is shown follows what changed:
%   - looks alone (every figure changed differs in its aesthetics only):
%     the editor's Design and looks line counts them (showLooksCount). The
%     figure shown is drawn again at once from the result its preview
%     holds, nothing computed, when that drawing was current
%     (figureViewFresh, redrawFigurePreview), as the aesthetics editor's
%     OK does; a drawing that was not current follows as after any edit
%     (autoFigurePreview: drawn again when Auto allows, else Out of date).
%   - anything else: the figure list, the editor, the observation picker
%     and the epoch diagram are filled again, as after Copy settings
%     (onCopyFigureSettings), and the figure shown follows as after any
%     edit (autoFigurePreview).
%   The other figures changed are marked out of date in the tree (their
%   kept previews: markFigureTree). An automatic figure id that follows
%   the change is tracked (trackFigureIds), so OBJ.Plots' figures follow
%   it (figureIndexOf).
%
%   Error: EphysFigGenApp:FiguresChanged when CFG holds another number of
%   figures (the command line adds, removes and moves none).
%
%   See also PlotConsole, rememberFigureAesthetics, onCopyFigureSettings, figureIndexOf.
arguments
    obj (1,1) EphysFigGenApp
    cfg (1,1) EphysAnalysisConfig
    label (1,1) string = "Command line edit"
end
old = obj.Config;
n = numel(old.Figures);
if numel(cfg.Figures) ~= n
    error('EphysFigGenApp:FiguresChanged', 'The config given holds %d figures, the app''s %d: changeFigures changes figures, it adds and removes none.', ...
        numel(cfg.Figures), n);
end
changed = zeros(1, 0);
looks = true;   % only the remembered looks changed
for i = 1:n
    a = cfg.Figures(i);
    b = old.Figures(i);
    if isequaln(a, b); continue; end
    changed(end+1) = i; %#ok<AGROW>
    a.aesthetics = b.aesthetics;
    looks = looks && isequaln(a, b);
end
if isempty(changed); return; end
k = obj.SelectedFigure;
shown = ismember(k, changed);
fresh = shown && figureViewFresh(obj, k);   % the drawing shown is the figure as it was before the change
panelsBefore = string.empty(1, 0);
if shown; panelsBefore = [panelsBefore old.Figures(k).panels.id]; end
trackFigureIds(obj, cfg);   % an automatic id that follows the change
recordFigureEdit(obj, cfg, label);
obj.Config = cfg;
if ~isempty(obj.Runner); obj.Runner.Config = cfg; end
if looks
    if shown; showLooksCount(obj, k); end
else
    if shown && ~isequal([string.empty(1, 0) cfg.Figures(k).panels.id], panelsBefore)   % the figure shown has other panels now
        obj.SelectedPanel = min(1, numel(cfg.Figures(k).panels));
        obj.SelectedLayer = 1;
    end
    obj.refreshFigureList();
    obj.applyFigureEditor();
    obj.refreshFigureObservations();
    obj.refreshEpochDiagram();
end
obj.setStatus(label + " (" + strjoin([cfg.Figures(changed).id], ", ") + ").");
obj.updateTitle();
if shown && ~(looks && fresh && obj.redrawFigurePreview())
    obj.autoFigurePreview();   % as after any edit: drawn again when Auto allows, else Out of date
else
    markFigureTree(obj);       % the others changed: their kept previews out of date
end
end
