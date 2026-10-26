function onApplyToFigures(obj, opts)
%onApplyToFigures  Give an edit of one figure to other figures or panels, picked in a modal window.
%   The edit is either the one just made with Ctrl (Cmd) held
%   (onConfigChanged passes Before=, the figures before it, and
%   Control=, the editor's control) or the last step of the undo history
%   (Edit > Apply last change to figures..., Ctrl+Shift+A) that is not
%   itself one given to other figures (Key "applyToFigures#..."), so the
%   same edit can go to more of them later, while it is still in effect
%   in its figure (else the status bar says it was edited again). What it
%   changed in its figure and selected panel (figureEditChanges: not the
%   id, title, places, layers or overlays) goes to the figures, or the
%   panels, that can take it (changeTargets: with a panel's option, the
%   panels whose type takes the value, panelTakes; figure K's other
%   panels too). The window (applyToFiguresDialog) lists them with their
%   values now, shown as the control shows them; the ticks start from
%   the last use (ApplyTicked, ApplySeen: a target never shown before is
%   ticked) and are kept for the next one, with the Replot box
%   (ApplyReplot; preferences).
%   Apply gives the ticked targets the values (applyChanges) as one step
%   of the undo history ("Stack to 3 panels", Key "applyToFigures#<n>"; its
%   own step, apart from the edit's); the status bar names
%   them. The previews are not drawn: the changed figures are marked out
%   of date in the tree, the one shown too. With Replot ticked, the figure
%   shown and the changed figures kept drawn (FigureViews) are drawn again
%   one after the other (each shown in turn, then the one shown before; a
%   session figure waits for Preview). Cancel leaves the edit to its own
%   figure (the preview follows as after any edit).
%   Ticked=KEYS ("<figure id>" for a figure, "<figure id>/<panel id>" for
%   a panel) skips the window and gives the change to those targets, with
%   Replot=TF (default the box's last value), for scripts and tests. The
%   window's table sorts by its column headers and its filters (text,
%   panel type, figure type, will change or has it) narrow the rows shown.
arguments
    obj (1,1) EphysAnalysisApp
    opts.Before = []
    opts.Control = []
    opts.Ticked (1,:) string = string(missing)
    opts.Replot = []
end
fromCtrl = isstruct(opts.Before);
if fromCtrl
    before = opts.Before;
    after = obj.Config.Figures;
    sel = [obj.SelectedFigure obj.SelectedPanel];
    label = figureEditLabel(obj, opts.Control);
    ctl = opts.Control;
else
    H = obj.FigureHistory;
    i = numel(H.Undo);
    while i >= 1 && isApplyKey(H.Undo(i).Key); i = i - 1; end   % the edit given before, not the giving
    if i < 1
        obj.setStatus("Apply to figures: no edit of the figures to apply yet.");
        return
    end
    step = H.Undo(i);
    before = step.Before;
    after = step.After;
    sel = step.Selection(1:2);
    label = step.Label;
    ctl = step.Key;
end
cfg = obj.Config;
k = sel(1);
if k < 1 || k > numel(after) || numel(before) ~= numel(after) || numel(cfg.Figures) ~= numel(after)
    obj.setStatus("Apply to figures: """ + label + """ added or removed a figure; there is no setting to give the others.");
    held(obj, fromCtrl);
    return
end
changes = EphysAnalysisConfig.figureEditChanges(before(k), after(k), sel(2));
if isempty(changes)
    obj.setStatus("""" + label + """ stays with its figure: an id, title, place, layer, overlay or note text is each figure's own.");
    held(obj, fromCtrl);
    return
end
since = EphysAnalysisConfig.figureEditChanges(after(k), cfg.Figures(k), sel(2));
if ~isempty(since) && any(ismember([changes.path], [since.path]))
    obj.setStatus("Apply to figures: """ + label + """ was edited again since; edit it once more to give it to other figures.");
    return
end
T = EphysAnalysisConfig.changeTargets(cfg.Figures, cfg.Defaults, k, sel(2), changes);
what = changeText(label, changes, ctl);
if isempty(T)
    obj.setStatus("No other figure or panel takes " + what + ".");
    held(obj, fromCtrl);
    return
end
keys = targetKeys(T);
if numel(changes) ~= 1; ctl = []; end   % the control shows one value
current = strings(1, numel(T));
for r = 1:numel(T)
    current(r) = strjoin(string(cellfun(@(v) valueText(v, ctl), T(r).current, 'UniformOutput', false)), "; ");
end
from = after(k).id;
if any([changes.scope] == "panel"); from = after(k).panels(sel(2)).id + " of " + from; end
if isscalar(opts.Ticked) && ismissing(opts.Ticked)
    [titles, kinds] = figureLabels(cfg.Figures, T);
    [tick, replot, ok] = applyToFiguresDialog(obj.Fig, what + ", from " + from, T, current, rememberedTicks(obj, T, keys), obj.ApplyReplot, titles, kinds);
    if isvalid(obj.Fig); figure(obj.Fig); end
    if ~ok
        held(obj, fromCtrl);
        return
    end
else
    tick = ismember(keys, opts.Ticked);
    replot = obj.ApplyReplot;
    if ~isempty(opts.Replot); replot = logical(opts.Replot); end
end
remember(obj, T, keys, tick);
obj.ApplyReplot = replot;
rows = T(tick & ~[T.same]);
if isempty(rows)
    obj.setStatus("Apply to figures: nothing ticked needs " + what + ".");
    held(obj, fromCtrl);
    return
end
cfg.Figures = EphysAnalysisConfig.applyChanges(cfg.Figures, cfg.Defaults, rows, changes);
nouns = "figure";
if any([rows.panel] >= 1); nouns = "panel"; end
n = numel(rows);
trackFigureIds(obj, cfg);   % an automatic id that follows the change
recordFigureEdit(obj, cfg, sprintf("%s to %d %s%s", label, n, nouns, repmat('s', 1, n ~= 1)), ...
    Key="applyToFigures#" + string(tic));   % its own step: two given in a second are not one
obj.Config = cfg;
if ~isempty(obj.Runner); obj.Runner.Config = cfg; end
obj.refreshFigureList();
obj.applyFigureEditor();
obj.refreshFigureObservations();
obj.refreshEpochDiagram();
ids = unique(string({cfg.Figures([rows.figure]).id}), 'stable');
names = ids;
if nouns == "panel"
    names = string(arrayfun(@(r) r.panelId + " in " + cfg.Figures(r.figure).id, rows, 'UniformOutput', false));
end
obj.setStatus(what + " went to " + strjoin(names, ", ") + ".");
obj.updateTitle();
if replot
    replotFigures(obj, ids);
else
    if obj.FigurePreviewState == "drawn" && ~figureViewFresh(obj); obj.setFigurePreviewState("stale"); end
    markFigureTree(obj);   % the changed figures out of date
end
end


function tf = isApplyKey(key)
%isApplyKey  Whether an undo step's KEY is one of these steps' ("applyToFigures#<n>").
tf = (isstring(key) || ischar(key)) && startsWith(string(key), "applyToFigures#");
end


function held(obj, fromCtrl)
%held  The edit stays with its figure: the preview follows it as after any edit (it waited for the window).
if fromCtrl; obj.autoFigurePreview(); end
end


function replotFigures(obj, ids)
%replotFigures  Draw again the figures IDS kept drawn (FigureViews), each shown in turn, then the one shown before.
k0 = obj.SelectedFigure;
home = "";
if k0 >= 1 && k0 <= numel(obj.Config.Figures); home = obj.Config.Figures(k0).id; end
kept = string.empty(1, 0);
if ~isempty(obj.FigureViews); kept = [obj.FigureViews.Id]; end
for id = ids(ismember(ids, kept) & ids ~= home)
    k = obj.Config.figureIndex(id);
    if k < 1 || obj.Config.Figures(k).sessions.enabled; continue; end   % a session figure computes every session: it waits for Preview
    obj.onFigureSelected(k);
    if ~figureViewFresh(obj); obj.refreshFigurePreview(); end
    if obj.FigurePreviewState == "canceled"; break; end
end
k = obj.Config.figureIndex(home);
if k < 1; return; end
obj.onFigureSelected(k);
if ~obj.Config.Figures(k).sessions.enabled && ~figureViewFresh(obj) && obj.FigurePreviewState ~= "canceled"
    obj.refreshFigurePreview();
end
end


function [titles, kinds] = figureLabels(F, T)
%figureLabels  Each row's figure title and type (the panel types the figure holds, "psth + raster"), for the window's filters.
titles = strings(numel(T), 1);
kinds = strings(numel(T), 1);
for r = 1:numel(T)
    f = F(T(r).figure);
    titles(r) = string(f.title);
    kinds(r) = strjoin(unique(string({f.panels.type}), 'stable'), " + ");
end
end


function keys = targetKeys(T)
%targetKeys  "<figure id>" for a figure's row, "<figure id>/<panel id>" for a panel's.
keys = string({T.figureId});
p = [T.panel] >= 1;
keys(p) = keys(p) + "/" + string({T(p).panelId});
end


function tick = rememberedTicks(obj, T, keys)
%rememberedTicks  Each row ticked as it was when last shown, else as its figure was, else ticked (never shown).
tick = true(1, numel(T));
for r = 1:numel(T)
    if ismember(keys(r), obj.ApplySeen)
        tick(r) = ismember(keys(r), obj.ApplyTicked);
    elseif ismember(T(r).figureId, obj.ApplySeen)
        tick(r) = ismember(T(r).figureId, obj.ApplyTicked);
    end
end
end


function remember(obj, T, keys, tick)
%remember  Keep the ticks of the rows that could change (and of their figures: ticked when any of theirs is) for the next time.
can = ~[T.same];
figs = string({T.figureId});
seen = unique([keys(can) figs(can)]);
ticked = unique([keys(can & tick) figs(can & tick)]);
obj.ApplyTicked = reshape(union(setdiff(obj.ApplyTicked, seen), ticked), 1, []);
obj.ApplySeen = reshape(union(obj.ApplySeen, seen), 1, []);
end


function t = changeText(label, changes, ctl)
%changeText  The change in words: "Stack: One row per group" (its row's label, its value as the control shows it).
if isscalar(changes)
    t = label + ": " + valueText(changes.value, ctl);
else
    t = label + " (" + strjoin([changes.path], ", ") + ")";
end
end


function t = valueText(v, ctl)
%valueText  A value as text: the drop-down item CTL shows for it, else on / off, the text, the numbers, or a summary.
if ~isempty(ctl) && isscalar(ctl) && isobject(ctl) && isvalid(ctl) && isprop(ctl, 'ItemsData') && ~isempty(ctl.ItemsData) ...
        && (isstring(v) || ischar(v) || (isnumeric(v) && isscalar(v)))
    data = ctl.ItemsData;
    items = string(ctl.Items);
    for i = 1:min(numel(data), numel(items))
        if iscell(data); d = data{i}; else; d = data(i); end
        if isequal(string(d), string(v)); t = items(i); return; end
    end
end
if islogical(v) && isscalar(v)
    t = "off";
    if v; t = "on"; end
elseif isstring(v) || ischar(v)
    t = strjoin(string(v), ", ");
    if t == ""; t = "(blank)"; end
elseif isnumeric(v)
    if isempty(v)
        t = "(auto)";
    elseif isscalar(v)
        t = string(sprintf('%g', v));
    else
        t = "[" + strjoin(compose("%g", v(:).'), " ") + "]";
    end
elseif isstruct(v)
    try
        t = string(jsonencode(v));
    catch
        t = "(" + class(v) + ")";
    end
else
    t = "(" + class(v) + ")";
end
if strlength(t) > 80; t = extractBefore(t, 78) + "..."; end
end
