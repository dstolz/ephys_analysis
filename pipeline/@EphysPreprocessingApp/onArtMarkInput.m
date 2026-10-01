function tf = onArtMarkInput(obj, kind, evt)
%onArtMarkInput  The Mark manual periods view: mark a period, pan, zoom, scale.
%   TF = obj.onArtMarkInput(KIND, EVT) acts on the figure's wheel
%   ("scroll"), key ("key") and button ("down", "up") events, passed on by
%   routeFigureInput while that view is showing, and on the Mark artifacts
%   button ("toggle", EVT its value), and returns whether it took the
%   event. They act only with the pointer over the plot (typing in a field
%   is left alone), except the button's release and Escape:
%     wheel ............ zoom time about the pointer
%     Ctrl+wheel ....... scale the voltage
%     Shift+wheel ...... scroll the lanes
%     keys ............. EphysTraceViewer.handleKey (arrows, Page Up / Down,
%                        Home / End, + / -, A auto scale, R reset)
%     Escape ........... turn marking off
%     drag ............. with Mark artifacts on, the left button marks the
%                        period dragged over (a rubber band, then
%                        EphysDataset.addArtifact), and a click on a marked
%                        period removes it; the right button, or any button
%                        with marking off, pans in time and across the lanes
%   Marked periods go to the shown dataset's ManualArtifacts and its manifest
%   (saveManifests), and the periods table follows. Marking is refused while
%   a run is under way (refuseWhileRunning). Wheel events carry no
%   modifiers, so the wheel reads ArtView.mods (kept by routeFigureInput).
%   A press on the overview strip is the strip's own (buildArtifactsTab).
%
%   See also routeFigureInput, syncArtMark, EphysTraceViewer.handleScroll,
%   EphysTraceViewer.handleKey.

tf = false;
switch kind
    case "toggle"
        tf = toggleMarking(obj, logical(evt));
        return
    case "up"
        tf = endGesture(obj);       % whichever view the button was let go over
        return
end
if ~obj.artMarkActive(); return; end
v = obj.ArtMarkViewer;
switch kind
    case "scroll"
        if ~v.isOver(obj.Fig); return; end
        v.handleScroll(evt.VerticalScrollCount, obj.ArtView.mods, pointerTime(obj));
        tf = true;
    case "key"
        if string(evt.Key) == "escape" && obj.ArtMarkMode
            tf = toggleMarking(obj, false);
            return
        end
        if ~v.isOver(obj.Fig); return; end
        tf = v.handleKey(evt.Key, evt.Modifier);
    case "down"
        tf = startGesture(obj);
end
end


function tf = toggleMarking(obj, on)
% Enter or leave marking mode (the left-drag gesture). Turning it on opens
% the recording view on the active dataset; it stays off when that cannot
% be shown or a run is under way.
tf = true;
if on && obj.refuseWhileRunning("Mark artifacts")
    on = false;
end
if on
    obj.ArtViewTabs.SelectedTab = obj.ArtTabMark;
    obj.syncArtMark();
    on = obj.artMarkActive();
end
obj.ArtMarkMode = on;
obj.ArtMarkButton.Value = on;
if on
    obj.ArtMarkButton.Text = "Mark artifacts: ON (drag to mark)";
    styleButton(obj.ArtMarkButton, "active");
    if isvalid(obj.Fig); obj.Fig.Pointer = "crosshair"; end
else
    obj.ArtMarkButton.Text = "Mark artifacts: off";
    styleButton(obj.ArtMarkButton);
    if isvalid(obj.Fig); obj.Fig.Pointer = "arrow"; end
end
obj.onArtMarkViewChanged();
end


function tf = startGesture(obj)
% A button press over the plot: the left button marks while marking is on,
% any other press pans. The figure's motion callback is set for the gesture
% and cleared by endGesture.
tf = false;
v = obj.ArtMarkViewer;
fig = obj.Fig;
if ~v.isOver(fig); return; end
if obj.ArtMarkMode && strcmp(fig.SelectionType, 'normal')
    obj.ArtMarkGesture = "mark";
    obj.ArtMarkDrag = struct( ...
        'active', true, ...
        'x0',     pointerTime(obj), ...
        'axPix',  obj.ArtMarkAxes.InnerPosition);
    fig.WindowButtonMotionFcn = @(~, ~) markMotion(obj);
else
    obj.ArtMarkGesture = "pan";
    v.beginDrag(fig.CurrentPoint);
    fig.WindowButtonMotionFcn = @(~, ~) v.dragTo(fig.CurrentPoint);
end
tf = true;
end


function tf = endGesture(obj)
% The button let go: finish the mark, the pan or the seek in progress.
tf = false;
gesture = obj.ArtMarkGesture;
obj.ArtMarkGesture = "";
if gesture == ""; return; end
if isvalid(obj.Fig); obj.Fig.WindowButtonMotionFcn = ''; end
v = obj.ArtMarkViewer;
switch gesture
    case "mark"
        finishMark(obj);
    case "pan"
        if ~isempty(v) && isvalid(v); v.endDrag(); end
end
tf = true;
end


function markMotion(obj)
% Stretch the rubber band while a mark is dragged.
D = obj.ArtMarkDrag;
if ~D.active; return; end
x1 = pointerTime(obj);
obj.ArtMarkViewer.setSelection([min(D.x0, x1), max(D.x0, x1)]);
end


function x = pointerTime(obj)
% The figure's pointer as a time X (s) on the plot. Read from the figure's
% CurrentPoint through the axes' inner box (getpixelposition gives the outer
% one, in the figure), as a uiaxes' own CurrentPoint cannot be set.
ax = obj.ArtMarkAxes;
pp = getpixelposition(ax, true);
box = [pp(1:2) + ax.InnerPosition(1:2) - ax.OuterPosition(1:2), ax.InnerPosition(3:4)];
f = (obj.Fig.CurrentPoint - box(1:2)) ./ max(box(3:4), 1);
x = ax.XLim(1) + f(1) * diff(ax.XLim);
end


function finishMark(obj)
% End a mark gesture: a drag defines a period, a click deletes the one under it.
% The plot's time axis is the recording's (seconds from its start), so the
% times go to the dataset as they are, kept inside the recording.
D = obj.ArtMarkDrag;
obj.ArtMarkDrag = struct('active', false);
v = obj.ArtMarkViewer;
if ~isempty(v) && isvalid(v); v.setSelection([]); end
if ~D.active || isempty(v) || ~isvalid(v); return; end
if obj.refuseWhileRunning("Mark artifacts"); return; end
d = obj.ArtMarkDataset;
if isempty(d) || ~isvalid(d); return; end

x0 = D.x0;
x1 = pointerTime(obj);

% A move of a few pixels is a click (delete) rather than a drag.
secPerPix = v.TWidth / max(D.axPix(3), 1);
changed = false;
if abs(x1 - x0) >= 4 * secPerPix
    a = max(0, min(x0, x1));
    b = min(v.TotalDuration, max(x0, x1));
    if b > a
        d.addArtifact(a, b);
        changed = true;
    end
else
    iv = d.ManualArtifacts;
    hit = find(x0 >= iv(:, 1) & x0 <= iv(:, 2), 1);
    if ~isempty(hit)
        iv(hit, :) = [];
        d.ManualArtifacts = iv;
        changed = true;
    end
end
if changed
    obj.saveManifests(d);              % periods persist in the manifest
    obj.refreshManualArtifactsTable();
end
obj.refreshArtMarkShading();
obj.onArtMarkViewChanged();
end
