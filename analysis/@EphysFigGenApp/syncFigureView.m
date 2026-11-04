function switched = syncFigureView(obj)
%syncFigureView  Show the selected figure's own preview container; the one it leaves keeps its drawing.
%   SWITCHED = syncFigureView(OBJ) makes the Figures tab's preview show the
%   figure the editor shows (SelectedFigure), by its id. Each figure has a
%   container of its own (a uipanel in FigurePreviewHost, newFigureView;
%   the containers share the cell, only the shown one visible: a tab
%   group's tab strip cannot be hidden reliably), made when the figure is
%   first shown. The preview's state lives in the FigurePreview*
%   properties while its figure shows (FigurePreviewPanel, Result,
%   State, Drawn, Seconds, FigureSessionResults and the status line); on
%   a switch they are kept in the container's entry of FigureViews and the
%   next figure's are taken from its own, so its drawing, badge, status
%   line and "Figure:" drop-down (a session figure's) come back as they
%   were, with nothing computed or drawn. Whether that drawing is still
%   current is the caller's to decide (previewFigureView: figureViewKey
%   against the key it was drawn with). The tree follows the badge
%   (markFigureTree, from setFigurePreviewState). SWITCHED is true when
%   another container is shown now.
%   The figures gone from the config (removed, an add undone) free their
%   containers; beyond MaxFigureViews, the containers shown least recently
%   are dropped (their figures drawn again when shown). The container ""
%   (no figure selected) is always kept and not counted.
%   While a preview computes or draws nothing changes: its figure's
%   container stays shown until it is done, and refreshFigurePreview then
%   calls this again (so the selection can move meanwhile: the editor
%   follows at once, the preview when it is drawn).
%   Called by refreshFigureList (every selection or change of the figures)
%   and refreshFigurePreview.
%
%   See also newFigureView, previewFigureView, figureViewKey, markFigureTree, clearFigureViews.
switched = false;
H = obj.FigurePreviewHost;
if isempty(H) || ~isvalid(H) || isempty(obj.FigureViews); return; end
if ismember(obj.FigurePreviewState, ["computing" "drawing"]); return; end   % refreshFigurePreview calls again when done
ids = obj.Config.figureIds();
k = obj.SelectedFigure;
id = "";
if k >= 1 && k <= numel(ids); id = ids(k); end
V = obj.FigureViews;
vid = [V.Id];
cur = obj.FigureViewId;
gone = ~ismember(vid, [ids ""]);   % figures removed: their containers go
if id == cur && any(vid == cur) && ~any(gone)
    return
end
i = find(vid == cur, 1);
if ~isempty(i) && ~gone(i)   % the figure left keeps what it shows
    V(i).Result = obj.FigurePreviewResult;
    V(i).State = obj.FigurePreviewState;
    V(i).Drawn = obj.FigurePreviewDrawn;
    V(i).Seconds = obj.FigurePreviewSeconds;
    V(i).Sessions = obj.FigureSessionResults;
    V(i).Label = string(obj.FigurePreviewLabel.Text);
end
for j = find(gone)
    if isvalid(V(j).Panel); delete(V(j).Panel); end
end
V(gone) = [];
j = find([V.Id] == id, 1);
if isempty(j)
    V(end+1) = newFigureView(obj, id);
    j = numel(V);
end
obj.FigureViewTick = obj.FigureViewTick + 1;
V(j).Used = obj.FigureViewTick;
% the cap: the containers of the figures shown least recently go (not the shown one, not "")
kept = find([V.Id] ~= "");
over = numel(kept) - obj.MaxFigureViews;
if over > 0
    [~, o] = sort([V(kept).Used]);
    drop = kept(o(1:over));
    drop(drop == j) = [];
    for d = drop
        if isvalid(V(d).Panel); delete(V(d).Panel); end
    end
    V(drop) = [];
    j = find([V.Id] == id, 1);
end
others = [V([1:j-1, j+1:end]).Panel];
if ~isempty(others); set(others(isvalid(others)), 'Visible', 'off'); end
V(j).Panel.Visible = 'on';
obj.FigureViews = V;
switched = id ~= cur || isempty(i) || gone(i);
obj.FigureViewId = id;
v = V(j);
obj.FigurePreviewPanel = v.Panel;
obj.FigurePreviewResult = v.Result;
obj.FigurePreviewDrawn = v.Drawn;
obj.FigurePreviewSeconds = v.Seconds;
obj.FigureSessionResults = v.Sessions;
obj.FigurePreviewLabel.Text = v.Label;
K = v.Sessions;
if isstruct(K) && isfield(K, 'res') && numel(K.res) > 1   % the "Figure:" drop-down of a session figure's figures, as left
    labels = string({K.res.label});
    q = find(labels == K.label, 1);
    if isempty(q); q = 1; end
    showSessionPicker(obj, labels, q);
else
    showSessionPicker(obj, []);
end
obj.setFigurePreviewState(v.State);   % the badge (and the tree's marks)
obj.markFigurePanel();   % the selected panel's outline, in this container
end
