function tf = onArtViewInput(obj, kind, evt)
%onArtViewInput  The Artifacts tab's plot: scale it, shade it, move a bound, mark a period.
%   TF = obj.onArtViewInput(KIND, EVT) acts on the figure's wheel ("scroll"),
%   key ("key", "release") and button ("down", "up") events, passed on by
%   routeFigureInput while the Artifacts tab is showing (key releases on
%   any tab), on Reset view ("reset"), Shade artifacts ("shade"),
%   Restore bounds ("restore"), Mark artifacts ("mark", EVT its value) and
%   Measure ("measure", EVT its value), turns either off ("stop"), and
%   returns whether it took the event. The
%   wheel and the keys act with the pointer over the plot:
%     wheel, Shift+wheel ......... zoom time about the pointer
%     Ctrl+wheel ................. scale the voltage (Ctrl+Shift+wheel too)
%     left / right arrow ......... pan time by a quarter of the view
%     Shift+left / right arrow ... zoom time out / in about the view's centre
%     up / down arrow, + / - ..... scale the voltage up / down
%     page down / n, page up / p . next / previous artifact (Shift: 10 on);
%                                  on a stretch of the recording (Go to),
%                                  the next / previous stretch as wide
%     end, home .................. last / first artifact; on a stretch, the
%                                  end / start of the recording
%     s .......................... shading on / off (as Shade artifacts)
%     r .......................... reset (as Reset view)
%     m .......................... Measure on / off
%     escape ..................... Mark artifacts / Measure off (anywhere)
%   Dragging pans too (the axes' own pan, along time only). The voltage
%   scale is ArtView.gain, a factor on the Scale fit kept from one artifact
%   to the next until a reset or a new Scale (with Scale: Manual they
%   change the lane spacing, ArtViewLanesField); the time zoom is the axes'
%   XLim, kept while the same window is drawn (drawArtifactView). Reset
%   shows the whole window at the Scale fit. Wheel events carry no
%   modifiers, so the wheel reads ArtView.mods (kept by routeFigureInput).
%
%   Moving a bound: while Ctrl is held the pointer over the plot turns into
%   a left or right resize arrow for the chosen artifact's bound nearer to
%   it (onset or offset), and Ctrl+drag moves that bound, on the sample
%   grid and at least a sample from the other. Letting go of the button
%   records the new bounds for the dataset (EphysDataset.
%   setArtifactAdjustment, saved in its manifest) and every step that uses
%   the detected artifacts takes them so (artifactIntervals). Restore
%   bounds puts them back as detected. Refused while a run is under way.
%
%   Marking a manual period: with Mark artifacts on, the pointer is a
%   crosshair and a left-button drag over the plot marks the time dragged
%   over (a purple band follows the pointer; EphysDataset.addArtifact
%   merges it with the periods it touches), kept inside the window drawn;
%   a click (under four pixels of movement) on a manual period removes it.
%   The axes' own pan gives way to it (the wheel and the arrows still
%   move the view), and Ctrl+drag still moves a bound. The periods go to
%   the dataset's ManualArtifacts and its manifest (saveManifests), and
%   the periods table, the plot and a Visualize plot of the dataset follow.
%   Marking is refused while a run is under way, and stops with Escape,
%   on leaving the tab (onTabChanged) and when no window is drawn
%   (drawArtifactView).
%
%   Measuring a stretch: Measure is the same drag in another mode (one of
%   the two is on at a time; turning one on turns the other off). The time
%   dragged over becomes ArtView.sel, kept with the window drawn and shaded
%   blue on it, and measureArtifactSelection scores it with every detection
%   method on the Selection tab, which comes to the front; a click clears
%   it. Nothing is written, so it works during a run too.
%
%   See also drawArtifactView, routeFigureInput, EphysDataset.adjustArtifacts,
%   EphysDataset.addArtifact.

tf = false;
switch kind
    case "release"
        if string(evt.Key) == "control"
            armBound(obj, false);
        end
        return
    case "down"
        tf = startBound(obj) || startMark(obj);
        return
    case "up"
        tf = finishBound(obj) || finishMark(obj);
        return
    case "mark"
        tf = setMarking(obj, logical(evt), "mark");
        return
    case "measure"
        tf = setMarking(obj, logical(evt), "measure");
        return
    case "stop"
        tf = setMarking(obj, false);     % whichever drag mode is on
        return
    case "shade"
        shadeChanged(obj);
        tf = true;
        return
    case "restore"
        tf = restoreBounds(obj);
        return
    case "key"
        if obj.ArtView.edit.armed && string(evt.Key) ~= "control" && ~any(string(evt.Modifier) == "control")
            armBound(obj, false);            % Ctrl was let go outside the figure
        end
        if string(evt.Key) == "escape" && obj.ArtView.mark.on
            tf = setMarking(obj, false);
            return
        end
end
w = obj.ArtView.win;
if isempty(w) || isfield(w, 'error'); return; end   % nothing drawn
if kind == "reset"
    obj.ArtView.gain = 1;
    obj.ArtView.drawn.key = [];          % the next draw starts on the whole window
    obj.drawArtifactView();
    tf = true;
    return
end
if kind == "key" && string(evt.Key) == "control"
    armBound(obj, true);
    tf = true;
    return
end
ax = obj.ArtViewAxes;
if ~overAxes(obj, ax); return; end

switch kind
    case "scroll"
        mods = obj.ArtView.mods;
        sc = evt.VerticalScrollCount;
        if any(mods == "control" | mods == "command")
            scaleVoltage(obj, 1.25 ^ (-sc));
        else
            zoomTime(obj, 1.25 ^ sc, ax.CurrentPoint(1, 1));
        end
    case "key"
        mods = string(evt.Modifier);
        if any(mods == "control" | mods == "command" | mods == "alt"); return; end
        shift = any(mods == "shift");
        switch string(evt.Key)
            case {"uparrow", "equal", "add"}
                scaleVoltage(obj, 1.25);
            case {"downarrow", "hyphen", "subtract"}
                scaleVoltage(obj, 1 / 1.25);
            case "rightarrow"
                if shift; zoomTime(obj, 1 / 1.5, []); else; panTime(obj, 0.25); end
            case "leftarrow"
                if shift; zoomTime(obj, 1.5, []); else; panTime(obj, -0.25); end
            case {"pagedown", "n"}
                if w.k == 0
                    pageStretch(obj, 1);
                else
                    gotoArtifact(obj, obj.ArtViewSpinner.Value + ifelse(shift, 10, 1));
                end
            case {"pageup", "p"}
                if w.k == 0
                    pageStretch(obj, -1);
                else
                    gotoArtifact(obj, obj.ArtViewSpinner.Value - ifelse(shift, 10, 1));
                end
            case "home"
                if w.k == 0; pageStretch(obj, -Inf); else; gotoArtifact(obj, 1); end
            case "end"
                if w.k == 0; pageStretch(obj, Inf); else; gotoArtifact(obj, Inf); end
            case "s"
                obj.ArtViewShadeButton.Value = ~obj.ArtViewShadeButton.Value;
                shadeChanged(obj);
            case "r"
                tf = obj.onArtViewInput("reset", []);
                return
            case "m"
                M = obj.ArtView.mark;
                setMarking(obj, ~(M.on && M.kind == "measure"), "measure");
            otherwise
                return
        end
    otherwise
        return
end
tf = true;
end


function gotoArtifact(obj, k)
% Show artifact K (in recording order), kept inside 1 to the count.
sp = obj.ArtViewSpinner;
k = min(max(round(k), sp.Limits(1)), sp.Limits(2));
if k ~= sp.Value
    sp.Value = k;
    obj.showArtifactView("artifact");
end
end


function pageStretch(obj, step)
% A stretch of the recording (Go to): the next (STEP 1) or previous (-1)
% one as wide, or the recording's end (Inf) or start (-Inf);
% showArtifactView keeps it inside the recording.
free = obj.ArtView.free;
wid = diff(free);
if isinf(step)
    t0 = ifelse(step > 0, Inf, 0);
else
    t0 = free(1) + step * wid;
end
obj.showArtifactView([t0, t0 + wid]);
end


function scaleVoltage(obj, f)
% Lanes F times taller (within limits), redrawn. A scale set by hand
% (Scale: Manual) changes the lane spacing instead.
if obj.ArtViewScaleDropDown.Value == "manual" && obj.ArtViewLanesField.Value > 0
    obj.ArtViewLanesField.Value = obj.ArtViewLanesField.Value / f;
    obj.drawArtifactView();
    return
end
obj.ArtView.gain = min(max(obj.ArtView.gain * f, 1 / 64), 1024);
obj.drawArtifactView();
end


function zoomTime(obj, f, anchor)
% The view F times wider, ANCHOR (s; [] = the view's centre) staying put.
% No narrower than 20 samples.
ax = obj.ArtViewAxes;
xl = ax.XLim;
if isempty(anchor) || ~isfinite(anchor); anchor = mean(xl); end
anchor = min(max(anchor, xl(1)), xl(2));
span = obj.ArtView.drawn.span;
wid = min(max(diff(xl) * f, min(20 / obj.ArtView.win.Fs, diff(span))), diff(span));
a = anchor - (anchor - xl(1)) * wid / diff(xl);
setTime(obj, [a, a + wid]);
end


function panTime(obj, frac)
% The view moved by FRAC of its width.
xl = obj.ArtViewAxes.XLim;
setTime(obj, xl + frac * diff(xl));
end


function setTime(obj, xl)
% Show XL (s), moved inside the window drawn. A zoom finer than the
% envelope drawn is redrawn (drawArtifactView keeps the XLim set here).
D = obj.ArtView.drawn;
wid = min(diff(xl), diff(D.span));
a = min(max(xl(1), D.span(1)), D.span(2) - wid);
obj.ArtViewAxes.XLim = [a, a + wid];
if D.decimated && 2 ^ ceil(log2(diff(D.span) / wid) - 1e-9) > D.factor
    obj.drawArtifactView();
end
end


function tf = overAxes(obj, ax)
% True when the pointer is inside AX (pixel coordinates).
pp = getpixelposition(ax, true);
cp = obj.Fig.CurrentPoint;
tf = cp(1) >= pp(1) && cp(1) <= pp(1) + pp(3) && cp(2) >= pp(2) && cp(2) <= pp(2) + pp(4);
end


function shadeChanged(obj)
% Shade artifacts toggled (its button or S): amber while on, then redrawn.
b = obj.ArtViewShadeButton;
if b.Value
    styleButton(b, "active");
else
    styleButton(b);
end
obj.drawArtifactView();
end


%% --- moving a bound (Ctrl+drag) ----------------------------------------------
function armBound(obj, on)
% Ctrl pressed (ON) or let go. While it is held the figure's motion shows,
% in the pointer, which bound a drag would move (hoverBound), and the axes'
% own pan and data tips give way to that drag. Entering keeps the pointer
% and interactions to put back; a drag under way keeps them until it ends.
E = obj.ArtView.edit;
if on
    if ~E.armed && E.bound == ""
        E = enterEdit(obj, E);
    end
    E.armed = true;
    obj.ArtView.edit = E;
    hoverBound(obj);
elseif E.armed
    E.armed = false;
    obj.ArtView.edit = E;
    if E.bound == ""
        leaveEdit(obj);
    end
end
end


function E = enterEdit(obj, E)
% Keep the pointer and the axes' interactions, then follow the pointer.
ax = obj.ArtViewAxes;
E.pointer = obj.Fig.Pointer;
E.interactions = ax.Interactions;
ax.Interactions = [];
obj.Fig.WindowButtonMotionFcn = @(~, ~) hoverBound(obj);
end


function leaveEdit(obj)
% Put back the pointer and the interactions enterEdit kept.
E = obj.ArtView.edit;
fig = obj.Fig;
if isvalid(fig)
    fig.WindowButtonMotionFcn = '';
    fig.Pointer = E.pointer;
end
ax = obj.ArtViewAxes;
if isvalid(ax) && ~isempty(E.interactions)
    ax.Interactions = E.interactions;
end
E.interactions = [];
obj.ArtView.edit = E;
end


function hoverBound(obj)
% The pointer while Ctrl is held: a resize arrow over the plot for the bound
% a drag would move, the pointer kept by enterEdit elsewhere.
b = nearBound(obj);
switch b
    case "on";  p = 'left';
    case "off"; p = 'right';
    otherwise;  p = obj.ArtView.edit.pointer;
end
if ~strcmp(obj.Fig.Pointer, p)
    obj.Fig.Pointer = p;
end
end


function [b, x] = nearBound(obj)
% The chosen artifact's bound nearer the pointer ("on" / "off") and the
% pointer's time X (s); "" with the pointer off the plot box (over the
% labels or the legend, say), nothing drawn or no artifact chosen (a
% stretch of the recording).
b = "";
x = NaN;
w = obj.ArtView.win;
if isempty(w) || isfield(w, 'error') || w.k == 0 || isempty(obj.currentDataset())
    return
end
[x, inside] = pointerTime(obj);
if ~inside
    x = NaN;
    return
end
c = chosenBounds(obj);
if abs(x - c(1)) <= abs(x - c(2))
    b = "on";
else
    b = "off";
end
end


function [x, inside] = pointerTime(obj)
% The figure's pointer as a time X (s) on the plot, and whether it is in
% the plot box. Read from the figure's CurrentPoint through the axes' inner
% box (getpixelposition gives the outer one, in the figure), as a uiaxes'
% own CurrentPoint cannot be set.
ax = obj.ArtViewAxes;
pp = getpixelposition(ax, true);
box = [pp(1:2) + ax.InnerPosition(1:2) - ax.OuterPosition(1:2), ax.InnerPosition(3:4)];
f = (obj.Fig.CurrentPoint - box(1:2)) ./ max(box(3:4), 1);
x = ax.XLim(1) + f(1) * diff(ax.XLim);
inside = all(f >= 0 & f <= 1);
end


function c = chosenBounds(obj)
% The chosen artifact's [onset offset] as a run uses them, in the plot's s.
w = obj.ArtView.win;
c = obj.currentDataset().adjustArtifacts([w.on w.off]);
end


function tf = startBound(obj)
% A button press: Ctrl+press (SelectionType "alt") on the plot starts
% moving the nearer bound; a plain press ("normal") shows Ctrl is no longer
% held (let go outside the figure), so the editing ends.
tf = false;
E = obj.ArtView.edit;
if ~E.armed; return; end
switch string(obj.Fig.SelectionType)
    case "normal"
        armBound(obj, false);
        return
    case "alt"
    otherwise
        return                           % a double-click, Shift+press
end
[b, x] = nearBound(obj);
if b == ""; return; end
if obj.refuseWhileRunning("Move an artifact's bound")
    armBound(obj, false);
    return
end
E.bound = b;
E.x = NaN;                               % until the pointer moves
obj.ArtView.edit = E;
obj.Fig.Pointer = ifelse(b == "on", 'left', 'right');
obj.Fig.WindowButtonMotionFcn = @(~, ~) dragBound(obj);
dragBound(obj, x);
tf = true;
end


function dragBound(obj, x)
% The bound being moved follows the pointer (X, s; default the pointer's),
% on the sample grid, inside the view and at least a sample from the other.
E = obj.ArtView.edit;
if E.bound == ""; return; end
w = obj.ArtView.win;
ax = obj.ArtViewAxes;
if nargin < 2
    x = pointerTime(obj);
end
xl = ax.XLim;
x = min(max(x, xl(1)), xl(2));
x = round(x * w.Fs) / w.Fs;   % the sample grid
c = chosenBounds(obj);
one = 1 / w.Fs;
if E.bound == "on"
    x = min(x, c(2) - one);
    c(1) = x;
    tag = 'artOnset';
else
    x = max(x, c(1) + one);
    c(2) = x;
    tag = 'artOffset';
end
E.x = x;
obj.ArtView.edit = E;
set(findobj(ax, 'Tag', tag), 'Value', x);
set(findobj(ax, 'Tag', 'artChosen'), 'Value', c);
end


function tf = finishBound(obj)
% The button let go: record the moved bound for the dataset (its manifest)
% and redraw with it; a press that never moved changes nothing.
tf = false;
E = obj.ArtView.edit;
if E.bound == ""; return; end
bound = E.bound;
x = E.x;
E.bound = "";
E.x = NaN;
obj.ArtView.edit = E;
if E.armed
    obj.Fig.WindowButtonMotionFcn = @(~, ~) hoverBound(obj);
    hoverBound(obj);
else
    leaveEdit(obj);
end
tf = true;
w = obj.ArtView.win;
d = obj.currentDataset();
if isnan(x) || isempty(w) || isfield(w, 'error') || isempty(d)
    obj.drawArtifactView();              % the lines back where they were
    return
end
detected = [w.on w.off];
bounds = d.adjustArtifacts(detected);
was = bounds;
bounds(1 + (bound == "off")) = x;
if isequal(round(bounds * w.Fs), round(was * w.Fs))
    obj.drawArtifactView();
    return
end
try
    d.setArtifactAdjustment(detected, bounds);
catch ME
    obj.drawArtifactView();
    obj.setStatus("Could not move the bound: " + string(ME.message));
    return
end
obj.saveManifests(d);                    % the bounds persist in the manifest
obj.drawArtifactView();
obj.setStatus(boundNote(w, bound, bounds, was));
end


function tf = restoreBounds(obj)
% Restore bounds: the chosen artifact as the detector found it.
tf = false;
w = obj.ArtView.win;
d = obj.currentDataset();
if isempty(w) || isfield(w, 'error') || w.k == 0 || isempty(d); return; end
if obj.refuseWhileRunning("Restore bounds"); return; end
[~, moved] = d.adjustArtifacts([w.on w.off]);
if ~moved; return; end
d.setArtifactAdjustment([w.on w.off]);
obj.saveManifests(d);
obj.drawArtifactView();
obj.setStatus(sprintf("Artifact %d is back as detected: %.4f to %.4f s.", w.k, w.on, w.off));
tf = true;
end


%% --- marking a manual period (Mark artifacts) ----------------------------------
function tf = setMarking(obj, on, kind)
% Mark artifacts or Measure (KIND "mark" / "measure"; default the one on)
% on or off: the buttons' text and colour, the pointer, and the axes' own
% pan and data tips given way to the drag (kept to put back; while a bound
% edit holds them, in its place). Turning one on while the other is on
% switches the drag over. Marking stays off with no window drawn or a run
% under way, measuring with no window; turning off drops a drag in progress.
tf = true;
M = obj.ArtView.mark;
if nargin < 3; kind = M.kind; end
w = obj.ArtView.win;
if on && (isempty(w) || isfield(w, 'error') || isempty(obj.currentDataset()))
    on = false;
end
if on && kind == "mark" && obj.refuseWhileRunning("Mark artifacts")
    on = false;
end
if ~on && M.on && M.kind ~= kind
    modeButtons(obj, true, M.kind);      % the other mode stays on
    return
end
modeButtons(obj, on, kind);
E = obj.ArtView.edit;
editing = E.armed || E.bound ~= "";
ax = obj.ArtViewAxes;
fig = obj.Fig;
if on && M.on                            % switched over: the pointer stays given way
    M = dropDrag(M, ax, fig, editing);
    M.kind = kind;
    obj.ArtView.mark = M;
    return
end
if M.on == on; return; end
if on
    if editing
        M.interactions = E.interactions;
        E.interactions = [];
        E.pointer = 'crosshair';
    else
        M.interactions = ax.Interactions;
        ax.Interactions = [];
        if isvalid(fig); fig.Pointer = 'crosshair'; end
    end
else
    M = dropDrag(M, ax, fig, editing);
    if editing
        E.interactions = M.interactions;
        E.pointer = 'arrow';
    else
        if isvalid(ax); ax.Interactions = M.interactions; end
        if isvalid(fig); fig.Pointer = 'arrow'; end
    end
    M.interactions = [];
end
M.on = on;
M.kind = kind;
obj.ArtView.mark = M;
obj.ArtView.edit = E;
end


function M = dropDrag(M, ax, fig, editing)
% A drag in progress (marking or measuring) is dropped.
if isnan(M.x0); return; end
M.x0 = NaN;
delete(findobj(ax, 'Tag', 'artMarkBand'));
if isvalid(fig) && ~editing; fig.WindowButtonMotionFcn = ''; end
end


function modeButtons(obj, on, kind)
% Mark artifacts and Measure as the drag mode says: the one on in amber.
b = obj.ArtMarkButton;
b.Value = on && kind == "mark";
if b.Value
    b.Text = "Mark artifacts: ON (drag on the plot)";
    styleButton(b, "active");
else
    b.Text = "Mark artifacts: off";
    styleButton(b);
end
b = obj.ArtMeasureButton;
if isempty(b) || ~isvalid(b); return; end
b.Value = on && kind == "measure";
if b.Value
    b.Text = "Measure: ON";
    styleButton(b, "active");
else
    b.Text = "Measure: off";
    styleButton(b);
end
end


function tf = startMark(obj)
% A plain left press over the plot box with marking on starts a mark: the
% figure's motion stretches a band from there (markMotion).
tf = false;
M = obj.ArtView.mark;
if ~M.on || ~strcmp(obj.Fig.SelectionType, 'normal'); return; end
[x, inside] = pointerTime(obj);
if ~inside; return; end
M.x0 = x;
obj.ArtView.mark = M;
obj.Fig.WindowButtonMotionFcn = @(~, ~) markMotion(obj);
tf = true;
end


function markMotion(obj)
% The band between where the mark started and the pointer, inside the window.
x0 = obj.ArtView.mark.x0;
if isnan(x0); return; end
ax = obj.ArtViewAxes;
span = markSpan(obj, x0, pointerTime(obj));
h = findobj(ax, 'Tag', 'artMarkBand');
if span(2) <= span(1)
    delete(h);
elseif isempty(h)
    col = artifactColors();
    face = col.manual;
    if obj.ArtView.mark.kind == "measure"
        face = col.selection;
    end
    xregion(ax, span(1), span(2), 'FaceColor', face, 'FaceAlpha', 0.35, ...
        'Tag', 'artMarkBand');   % visible, so findobj finds it; the legend lists its own handles
else
    h(1).Value = span;
end
end


function span = markSpan(obj, x0, x1)
% [start end] (s) between X0 and X1, inside the window drawn.
D = obj.ArtView.drawn.span;
span = [max(min(x0, x1), D(1)), min(max(x0, x1), D(2))];
end


function tf = finishMark(obj)
% The button let go after startMark: a drag adds the period dragged over, a
% click (under four pixels) removes the manual period under it. Saved in the
% dataset's manifest; the table, this plot and a Visualize plot follow.
tf = false;
M = obj.ArtView.mark;
if isnan(M.x0); return; end
x0 = M.x0;
M.x0 = NaN;
obj.ArtView.mark = M;
tf = true;
fig = obj.Fig;
if obj.ArtView.edit.armed
    fig.WindowButtonMotionFcn = @(~, ~) hoverBound(obj);
else
    fig.WindowButtonMotionFcn = '';
end
ax = obj.ArtViewAxes;
delete(findobj(ax, 'Tag', 'artMarkBand'));
x1 = pointerTime(obj);
secPerPix = diff(ax.XLim) / max(ax.InnerPosition(3), 1);
dragged = abs(x1 - x0) >= 4 * secPerPix;
if M.kind == "measure"
    finishMeasure(obj, dragged, markSpan(obj, x0, x1));
    return
end
d = obj.currentDataset();
if isempty(d) || obj.refuseWhileRunning("Mark artifacts"); return; end

if dragged
    span = markSpan(obj, x0, x1);
    if span(2) <= span(1); return; end
    d.addArtifact(span(1), span(2));
    msg = sprintf("%s: manual period %.4f to %.4f s marked (saved in the manifest).", d.Name, span(1), span(2));
else
    iv = d.ManualArtifacts;
    hit = [];
    if ~isempty(iv)
        hit = find(x0 >= iv(:, 1) & x0 <= iv(:, 2), 1);
    end
    if isempty(hit); return; end
    msg = sprintf("%s: manual period %.4f to %.4f s removed.", d.Name, iv(hit, 1), iv(hit, 2));
    iv(hit, :) = [];
    d.ManualArtifacts = iv;
end
obj.saveManifests(d);                    % periods persist in the manifest
obj.refreshManualArtifactsTable();       % redraws this plot too
shown = obj.currentVizDataset();
if ~isempty(shown) && shown == d
    obj.refreshVizShading();
end
obj.updateVizArtStatus();
obj.setStatus(msg);
end


function finishMeasure(obj, dragged, span)
% Measure: a drag selects SPAN on the window drawn and scores it (the
% Selection tab comes to the front); a click clears the selection.
w = obj.ArtView.win;
if isempty(w) || isfield(w, 'error'); return; end
if dragged && span(2) > span(1)
    obj.ArtView.sel = struct('span', span, 'key', [w.k, w.s0, size(w.X, 1)], 'cmX', []);
    obj.ArtResultTabs.SelectedTab = obj.ArtSelectionTab;
elseif isempty(obj.ArtView.sel)
    return
else
    obj.ArtView.sel = [];
end
obj.drawArtifactView();
obj.measureArtifactSelection();
end


function s = boundNote(w, bound, cur, was)
% The status line after a move: which bound, how far, the span now.
if bound == "on"
    name = "onset";
    dt = cur(1) - was(1);
else
    name = "offset";
    dt = cur(2) - was(2);
end
way = ifelse(dt < 0, "earlier", "later");
s = sprintf("Artifact %d: %s moved %.3g ms %s; now %.4f to %.4f s (saved in the manifest).", ...
    w.k, name, abs(dt) * 1e3, way, cur(1), cur(2));
end


function v = ifelse(c, a, b)
if c; v = a; else; v = b; end
end
