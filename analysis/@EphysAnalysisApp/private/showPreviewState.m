function showPreviewState(obj, P, state, opts)
%showPreviewState  Show where a preview is: the badge under it, and a card over it while busy.
%   showPreviewState(OBJ, P, STATE) is the work of setFigurePreviewState
%   (the Figures tab). P names the preview's parts:
%     Panel      the panel it draws in (the busy card goes in it, found by
%                its tag, previewBusyCard)
%     Badge      the badge struct (Grid, Icon, Text)
%     StateProp  the app property that keeps STATE ("FigurePreviewState")
%     CancelFcn  what the card's Cancel button calls
%     Button     its Preview button (orange while stale, primary otherwise)
%     Tips       (optional) a struct of tooltips by state, over the defaults
%   STATE is one of idle, computing, drawing, drawn, stale, waiting,
%   skipped, failed, canceled (setFigurePreviewState says what each means).
%   While computing or drawing, a card in the middle of the panel says
%   what (Message=) over the last figure, and the pointer is a watch; while
%   computing the card also has a Cancel button. The spinners are animated
%   SVG, so they turn while MATLAB is busy.
arguments
    obj (1,1) EphysAnalysisApp
    P (1,1) struct
    state (1,1) string {mustBeMember(state, ["idle" "computing" "drawing" "drawn" "stale" "waiting" "skipped" "failed" "canceled"])}
    opts.Message (1,1) string = ""
end
obj.(P.StateProp) = state;
B = P.Badge;
if isempty(fieldnames(B)) || ~isvalid(B.Grid); return; end
amber = {[1.00 0.93 0.75], [0.55 0.33 0.00]};
blue  = {[0.86 0.92 0.99], [0.10 0.30 0.60]};
green = {[0.85 0.94 0.87], [0.10 0.40 0.20]};
gray  = {[0.92 0.92 0.92], [0.35 0.35 0.35]};
red   = {[0.98 0.86 0.84], [0.60 0.15 0.10]};
switch state
    case "idle";      [word, c, tip] = deal("No preview", gray, "Nothing is previewed: add a figure, scan and pick a dataset.");
    case "computing"; [word, c, tip] = deal("Computing", amber, "Computing the figure on the active dataset.");
    case "drawing";   [word, c, tip] = deal("Drawing", blue, "Drawing the computed figure.");
    case "drawn";     [word, c, tip] = deal("Drawn", green, "The preview is the figure as it is now.");
    case "stale";     [word, c, tip] = deal("Out of date", amber, "The figure changed since this preview was drawn, " + ...
            "and it was not redrawn (Auto is off, or the last preview took " + obj.AutoPreviewSeconds + " s or more): press Preview.");
    case "waiting";   [word, c, tip] = deal("Press Preview", blue, "The extract is large, so it is read only when you press Preview.");
    case "skipped";   [word, c, tip] = deal("Cannot draw", gray, "The active dataset cannot draw this figure (the line below says why).");
    case "failed";    [word, c, tip] = deal("Failed", red, "The preview failed (the line below and the Log tab say why).");
    case "canceled";  [word, c, tip] = deal("Canceled", gray, "The preview was canceled before the figure was computed: press Preview.");
end
if isfield(P, 'Tips') && isfield(P.Tips, state)
    tip = P.Tips.(state);
end
B.Grid.BackgroundColor = c{1};
B.Icon.ImageSource = fullfile(iconFolder(), state + ".svg");
B.Text.Text = word;
B.Text.FontColor = c{2};
set([B.Icon B.Text], "Tooltip", tip);
if state == "stale"   % the Preview button asks for a press, in the badge's amber
    set(P.Button, "BackgroundColor", [1.00 0.62 0.15], "FontColor", [0.10 0.10 0.10]);
else
    styleButton(P.Button, "primary");
end

busy = ismember(state, ["computing" "drawing"]);
card = findobj(P.Panel.Children, "flat", "Tag", "previewBusyCard");
if busy
    if isempty(card); card = busyCard(P.Panel, P.CancelFcn); end
    card.BackgroundColor = c{1};
    card.BorderColor = c{2};
    card.Children.BackgroundColor = c{1};
    ui = card.UserData;
    ui.Icon.ImageSource = B.Icon.ImageSource;
    ui.Text.Text = opts.Message;
    ui.Text.FontColor = c{2};
    canCancel = state == "computing";   % drawing cannot be stopped part-way
    ui.Cancel.Visible = matlab.lang.OnOffSwitchState(canCancel);
    ui.Cancel.Enable = "on";
    ui.Grid.ColumnWidth = {48, '1x', 100 * canCancel};
    obj.Fig.Pointer = "watch";
    % paint it before the work blocks MATLAB; between computing and drawing,
    % without running queued callbacks (an edit there would start a preview
    % inside this one)
    if state == "computing"; drawnow; else; drawnow nocallbacks; end
else
    delete(card);
    obj.Fig.Pointer = "arrow";
end
end


function card = busyCard(panel, cancelFcn)
%busyCard  A card centered in the preview panel, over what it shows: a spinner, a line of text and a Cancel button.
%   The panel's size can lag (a tab shown for the first time lays out
%   later), so the card is centered again whenever the panel changes size.
card = uipanel(panel, "Tag", "previewBusyCard", "Units", "pixels", "BorderType", "line", "BorderWidth", 2);
g = uigridlayout(card, [1 3], "ColumnWidth", {48, '1x', 100}, "Padding", [14 8 14 8], "ColumnSpacing", 14);
ui.Grid = g;
ui.Icon = uiimage(g, "ScaleMethod", "fit");
ui.Text = uilabel(g, "FontSize", 15, "FontWeight", "bold", "WordWrap", "on");
ui.Cancel = uibutton(g, "Text", "Cancel", "Tooltip", "Stop computing this figure", "ButtonPushedFcn", @(~, ~) cancelFcn());
styleButton(ui.Cancel, "danger");
card.UserData = ui;
panel.AutoResizeChildren = "off";   % else SizeChangedFcn does not run; the figure's own layout fills the panel anyway
panel.SizeChangedFcn = @(p, ~) placeCard(p);
placeCard(panel);
end


function placeCard(panel)
card = findobj(panel.Children, "flat", "Tag", "previewBusyCard");
if isempty(card); return; end
pos = panel.InnerPosition;
w = max(min(560, pos(3) - 20), 40);
h = max(min(84, pos(4) - 10), 30);
card.Position = [max((pos(3) - w) / 2, 1), max((pos(4) - h) / 2, 1), w, h];
end


function f = iconFolder()
f = fullfile(fileparts(fileparts(fileparts(mfilename("fullpath")))), "icons", "status");
end
