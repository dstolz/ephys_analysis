function S = onRedrawAllFigures(obj)
%onRedrawAllFigures  Draw again the preview of every enabled figure that is out of date, the shown figure first.
%   S = onRedrawAllFigures(OBJ) is the Figures tab's Redraw All button
%   (Ctrl+R): after an edit of the design, the defaults or the dataset,
%   every enabled figure of the config (and the shown one, enabled or not)
%   gets a current preview in its own container (syncFigureView), for its
%   own observation on the active dataset (a session figure: across its
%   datasets), as Preview draws it (refreshFigurePreview, Force: a large
%   signal extract is read too). The shown figure goes first; the others
%   follow in the list's order, each selected in turn (onFigureSelected:
%   the editor and the picker follow it, and Auto may draw it right
%   there) and drawn when its preview is not current yet. A preview that
%   is still current (figureViewFresh: drawn with the key the figure has
%   now) is left as it is, nothing computed. The shown figure is selected
%   again at the end.
%   At most MaxFigureViews previews are kept (syncFigureView drops the
%   least recently shown), so with more enabled figures than that it draws
%   the shown one and the figures shown most recently (then the list's
%   order) up to the cap, and the status bar says how many are left to be
%   drawn when shown. The containers of the figures it draws are counted
%   as just shown, so the cap drops the others' first.
%   The status bar counts it ("Redrawing 3 of 7: <id> ..."); the toolbar's
%   Cancel and the Export tab's (onCancelRun) or the busy card's Cancel
%   over the preview (onCancelFigurePreview) stop it: the figure computing
%   is canceled, no other is drawn. Picking another figure meanwhile (the
%   tree, a favorite) stops it too, and that figure stays shown. Redraw
%   All is off while it goes and while a run goes; it does nothing while a
%   preview computes, or with no scan.
%   S is struct(drawn, current, notDrawn, left, canceled, stopped):
%   the ids drawn, found current, drawn but not to a current preview
%   (skipped, failed, waiting), left out over the cap; canceled and
%   stopped (another figure picked) are logical.
%
%   See also refreshFigurePreview, syncFigureView, figureViewFresh, onGenerateFigure.
arguments
    obj (1,1) EphysAnalysisApp
end
none = strings(1, 0);
S = struct('drawn', none, 'current', none, 'notDrawn', none, 'left', none, 'canceled', false, 'stopped', false);
if obj.FigureRedrawing; return; end
if obj.Running
    obj.setStatus("A run is going: redraw the figures when it is done.");
    return
end
if ismember(obj.FigurePreviewState, ["computing" "drawing"])
    obj.setStatus("A preview is computing: redraw the figures when it is done (or cancel it).");
    return
end
ids = obj.Config.figureIds();
k0 = obj.SelectedFigure;
if k0 < 1 || k0 > numel(ids)
    obj.setStatus("No figure to redraw: add one under the list.");
    return
end
if isempty(obj.Runner)
    obj.setStatus("Scan and pick a dataset to redraw the figures.");
    return
end
shown = ids(k0);
want = ids([obj.Config.Figures.enabled]);
want = [shown want(want ~= shown)];
want = withinCap(obj, want);
S.left = setdiff(ids([obj.Config.Figures.enabled]), want, 'stable');
touchViews(obj, want);
n = numel(want);

obj.FigureRedrawing = true;
obj.FigureRedrawCanceled = false;
obj.FigureRedrawAllButton.Enable = 'off';
obj.CancelButton.Enable = 'on';
obj.ToolbarCancelTool.Enable = 'on';
done = onCleanup(@() finish(obj));
t0 = tic;
at = shown;   % the figure it selected last: another selected meanwhile stops it
for i = 1:n
    if ~isvalid(obj) || isempty(obj.Fig) || ~isvalid(obj.Fig); return; end   % the app was closed meanwhile
    if obj.FigureRedrawCanceled; S.canceled = true; break; end
    ids = obj.Config.figureIds();
    if selectedId(obj, ids) ~= at; S.stopped = true; break; end
    id = want(i);
    k = find(ids == id, 1);
    if isempty(k); continue; end   % removed meanwhile
    if figureViewFresh(obj, k)
        S.current(end+1) = id;
        continue
    end
    obj.setStatus(sprintf("Redrawing %d of %d: %s ... (Cancel on the toolbar stops it)", i, n, id));
    drawnow("limitrate");
    if k ~= obj.SelectedFigure
        obj.onFigureSelected(k);   % its editor, picker and container (Auto may draw it here)
        at = id;
    end
    if ~isvalid(obj) || isempty(obj.Fig) || ~isvalid(obj.Fig); return; end
    if ~figureViewFresh(obj, k) && ~obj.FigureRedrawCanceled && obj.FigurePreviewState ~= "canceled"
        obj.refreshFigurePreview(Force=true);
        if ~isvalid(obj) || isempty(obj.Fig) || ~isvalid(obj.Fig); return; end
    end
    if obj.FigureRedrawCanceled || obj.FigurePreviewState == "canceled"
        S.canceled = true;
        break
    end
    if figureViewFresh(obj, k)
        S.drawn(end+1) = id;
    else
        S.notDrawn(end+1) = id;
    end
end
if ~S.stopped && ~S.canceled && selectedId(obj, obj.Config.figureIds()) ~= at; S.stopped = true; end
if ~S.stopped   % back to the figure shown when it started
    k = find(obj.Config.figureIds() == shown, 1);
    if ~isempty(k) && k ~= obj.SelectedFigure; obj.onFigureSelected(k); end
end
clear done
obj.setStatus(summary(S, toc(t0), obj.MaxFigureViews));
end


function want = withinCap(obj, want)
%withinCap  The figures to draw, at most MaxFigureViews: the shown one, then those shown most recently, in WANT's order.
cap = obj.MaxFigureViews;
if numel(want) <= cap; return; end
V = obj.FigureViews;
used = zeros(1, numel(want));
if ~isempty(V)
    vid = [V.Id];
    for i = 1:numel(want)
        j = find(vid == want(i), 1);
        if ~isempty(j); used(i) = V(j).Used; end
    end
end
used(1) = Inf;   % the shown figure
[~, o] = sort(used, 'descend');   % stable: the figures never shown keep the list's order
want = want(sort(o(1:cap)));
end


function touchViews(obj, want)
%touchViews  The kept containers of WANT counted as just shown, so syncFigureView's cap drops the others first.
V = obj.FigureViews;
if isempty(V); return; end
vid = [V.Id];
for id = want
    j = find(vid == id, 1);
    if isempty(j); continue; end
    obj.FigureViewTick = obj.FigureViewTick + 1;
    V(j).Used = obj.FigureViewTick;
end
obj.FigureViews = V;
end


function id = selectedId(obj, ids)
id = "";
k = obj.SelectedFigure;
if k >= 1 && k <= numel(ids); id = ids(k); end
end


function finish(obj)
%finish  Redraw All done: its button back, Cancel off (a run turns them on again when it starts).
if ~isvalid(obj); return; end
obj.FigureRedrawing = false;
obj.FigureRedrawCanceled = false;
if isempty(obj.Fig) || ~isvalid(obj.Fig); return; end
has = obj.SelectedFigure >= 1 && obj.SelectedFigure <= numel(obj.Config.Figures);
obj.FigureRedrawAllButton.Enable = matlab.lang.OnOffSwitchState(has && ~obj.Running);
if ~obj.Running
    obj.CancelButton.Enable = 'off';
    obj.ToolbarCancelTool.Enable = 'off';
end
end


function txt = summary(S, secs, cap)
%summary  The status bar's "Redraw All: 4 drawn, 2 already current, ..." line.
head = "Redraw All";
if S.canceled; head = "Redraw All canceled"; end
if S.stopped; head = "Redraw All stopped (another figure was picked)"; end
parts = string(sprintf("%d drawn", numel(S.drawn)));
if ~isempty(S.current); parts = parts + sprintf(", %d already current", numel(S.current)); end
if ~isempty(S.notDrawn); parts = parts + sprintf(", %d not drawn (%s: the preview says why)", numel(S.notDrawn), strjoin(S.notDrawn, ", ")); end
txt = head + ": " + parts + sprintf(" (%.1f s)", secs);
if ~isempty(S.left)
    txt = txt + sprintf("; %d more enabled figure(s) are drawn when shown (%d previews are kept)", numel(S.left), cap);
end
end
