function nudgePanel(obj, dx, dy, how)
%nudgePanel  Move or resize the selected panel by a step, ten steps or a pixel: Arrange's arrow keys.
%   nudgePanel(OBJ, DX, DY, HOW): DX and DY (-1, 0 or 1) say the direction
%   (right and up positive); HOW how far:
%     "step"       the snap step (the Layout section's Snap step, in its
%                  units on the figure's export page): Arrows
%     "ten"        ten steps: Shift+Arrows
%     "pixel"      one pixel of the preview, the finest move the screen
%                  shows: Ctrl+Arrows
%     "resize"     the right edge (DX) or the top edge (DY) by a step,
%                  out (positive) or in: Alt+Arrows
%     "resizeTen"  ten steps: Alt+Shift+Arrows
%   The panel stays on the page (a resize keeps a width and height of at
%   least 0.01). The others selected with Shift+click (selectedPanelIds)
%   go along: the same shift, the group kept on the page, or the same
%   change of size (arrangeGroup), in the same step ("Move panels",
%   "Resize panels"). Each press is an edit of the figure (commitFigureEdit,
%   "Move panel" or "Resize panel"), but the presses of one burst, under a
%   second apart, are one step of the undo history (Key "arrangeKeys:move"
%   or "arrangeKeys:resize"); the preview is laid out again in place after
%   each (Auto). Its box moves, the smart guides show the nudged place
%   (private/arrangeCues: what it lines up with, the distances) and go a
%   second after the last press. onKeyPress calls it with the Figures tab
%   showing, Arrange on and the overlay clicked last (FigureArrangeFocus).
%
%   See also EphysFigGenApp.onKeyPress, EphysFigGenApp.onArrangeMoving, EphysFigGenApp.syncArrangeOverlay.
arguments
    obj (1,1) EphysFigGenApp
    dx (1,1) double
    dy (1,1) double
    how (1,1) string {mustBeMember(how, ["step" "ten" "pixel" "resize" "resizeTen"])} = "step"
end
k = obj.SelectedFigure;
j = obj.SelectedPanel;
if k < 1 || k > numel(obj.Config.Figures) || j < 1 || j > numel(obj.Config.Figures(k).panels)
    obj.setStatus("Arrange: select a panel to nudge (click its box on the preview).");
    return
end
id = obj.Config.Figures(k).panels(j).id;
C = arrangeContext(obj, id);
if isempty(C) || any(~isfinite(C.rect0)); return; end
switch how
    case "pixel",                s = 1 ./ C.pagePx;
    case {"ten" "resizeTen"},    s = 10 * C.step;
    otherwise,                   s = C.step;
end
r = C.rect0;
resize = startsWith(how, "resize");
if resize
    r(3:4) = r(3:4) + [dx dy] .* s;
    r(3:4) = min(max(r(3:4), 0.01), 1 - r(1:2));
    action = "Resize panel";
else
    r(1:2) = min(max(r(1:2) + [dx dy] .* s, 0), 1 - r(3:4));
    action = "Move panel";
end
sel = selectedPanelIds(obj);   % the others selected with Shift+click go along
pids = [obj.Config.Figures(k).panels.id];
qs = zeros(1, 0);
for o = sel(2:end); qs(end+1) = find(pids == o, 1); end %#ok<AGROW>
R0 = zeros(numel(qs), 4);
for i = 1:numel(qs); R0(i, :) = reshape(double(obj.Config.Figures(k).panels(qs(i)).rect), 1, 4); end
R = R0;
if ~isempty(qs)
    [r, R] = arrangeGroup(C.rect0, r, R0);
    keep = ~ismember(C.names, pids(qs));   % (the guides: not to the panels going along)
    C.others = C.others(keep, :);
    C.names = C.names(keep);
end
if all(abs(r - C.rect0) < 1e-12) && all(abs(R - R0) < 1e-12, 'all')
    obj.setStatus(id + " is at the page's edge" + ternary(resize, " (or its smallest)", "") + ": it goes no further.");
    return
end
cfg = obj.Config;   % the rects alone changed
F = cfg.Figures;   % (set once: each assignment of Figures normalizes the figure changed)
F(k).panels(j).rect = r;
for i = 1:numel(qs); F(k).panels(qs(i)).rect = R(i, :); end
cfg.Figures = F;
verb = ternary(resize, "Resized ", "Moved ");
msg = verb + id + ": " + rectText(r, obj.FigureRectUnits, C.pageCm, C.dpi) + ".";
if ~isempty(qs)
    action = action + "s";
    msg = verb + strjoin(sel, ", ") + " (" + numel(sel) + " panels); " + id + ": " + rectText(r, obj.FigureRectUnits, C.pageCm, C.dpi) + ".";
end
wait = ~isempty(obj.FigureSelectTimer);   % a release's refill waits for this press (fillSelectLater)
if wait; stopSelectTimer(obj); end
commitFigureEdit(obj, cfg, msg, Action=action, Key="arrangeKeys:" + ternary(resize, "resize", "move"), Arrange=true);
if wait; fillSelectLater(obj, ""); end
% the smart guides at the nudged place, gone a second after the last press
[~, g] = snapRect(r, C.rect0, C.others, [0 0], [0 0], Names=C.names);
arrangeCues(obj, r, g);
O = obj.FigureArrangeOverlay;
if ~isstruct(O); return; end
if ~isempty(O.timer) && isvalid(O.timer); stop(O.timer); end   % (it deletes itself)
O.timer = timer('StartDelay', 1, 'ExecutionMode', 'singleShot', 'Tag', 'arrangeCueTimer', ...
    'TimerFcn', @(~, ~) hideCues(obj), 'StopFcn', @(t, ~) delete(t));
obj.FigureArrangeOverlay = O;
start(O.timer);
end


function hideCues(obj)
%hideCues  The nudge's timer: the smart guides hidden, unless a drag shows them now.
if ~isvalid(obj) || obj.FigureArrangeMode == "drag"; return; end
try
    arrangeCues(obj, [], []);
catch
end
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
