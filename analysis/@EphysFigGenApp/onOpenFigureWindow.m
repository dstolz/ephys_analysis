function h = onOpenFigureWindow(obj)
%onOpenFigureWindow  Draw the figure as previewed into a new MATLAB figure window of its own.
%   H = onOpenFigureWindow(obj) is the Figures tab's "Open in window"
%   button. When the preview is drawn and up to date -- drawn from the key
%   the figure has now (figureViewFresh: figureViewKey), whatever the
%   badge says -- it draws the result the preview computed
%   (FigurePreviewResult) with the spec it was drawn with; otherwise (out
%   of date, canceled, not yet drawn) it first previews as the Preview
%   button does (refreshFigurePreview, Force), and opens the window only
%   if that draws the figure as it is now (an edit made while it computed
%   leaves it Out of date: the status bar says so). So a result computed
%   for another observation, dataset or version of the figure is never
%   drawn with the figure's spec of now. The window is a regular figure()
%   named "<figure id>: <observation> (<dataset>)", the shape of the
%   figure's export page (figureExportSize; a probe figure's from its
%   result, the tiles' rows) at its true size on screen
%   (96 dpi; scaled down to fit when it is larger than the screen), drawn
%   by renderFigure (Editable: the right-click aesthetics
%   editor and its Design submenu work in it, and "remember for this
%   figure" reaches the app's config while the app is open (the preview
%   then follows as after an edit: rememberFigureAesthetics Preview=false); so does an
%   axis label's own text or side, set from its menu or the panel axes'
%   (one panel's, or every panel's side at once), which also draws the
%   window again; a Ctrl+Click on a panel selects it in the app's
%   figure editor, bringing the app forward: onFigurePanelClicked). The
%   window is independent of the app: later edits do
%   not follow into it (Preview and Open again for a new one), and closing
%   the app leaves it as it is. H is the figure, [] when none was opened.
%
%   See also refreshFigurePreview, renderFigure, rememberFigureAesthetics.
arguments
    obj (1,1) EphysFigGenApp
end
h = [];
if obj.Running
    obj.setStatus("A run is going: open the figure when it is done.");
    return
end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures)
    obj.setStatus("No figure to open: add one first.");
    return
end
if ~figureViewFresh(obj) || isempty(obj.FigurePreviewResult)   % not the figure as it is now: computed again first
    obj.refreshFigurePreview(Force=true);
end
F = obj.FigurePreviewResult;
id = obj.Config.Figures(k).id;
if ~figureViewFresh(obj) || isempty(F) || F.id ~= id
    why = string(obj.FigurePreviewLabel.Text);   % why it was not drawn (the preview's line)
    if obj.FigurePreviewState == "stale"; why = "the figure changed while it was computed: press Preview, then open it."; end
    obj.setStatus("Nothing to open: " + why);
    return
end
if obj.Config.Figures(k).sessions.enabled && isstruct(obj.FigureSessionResults) && isfield(obj.FigureSessionResults, 'spec')
    spec = obj.FigureSessionResults.spec;   % as it was computed across the sessions
else
    spec = obj.Config.figureFor(k);
    spec.enabled = true;
end
Fs = [];
if isfield(F, 'kind') && string(F.kind) == "probeFigure"; Fs = F; end   % a probe figure's page is as tall as its rows of tiles need
cm = figureExportSize(obj.Config.Export, Fs, spec);
sz = cm / 2.54 * 96;   % the page at its true size on screen, scaled down to fit
scr = get(groot, 'ScreenSize');
sz = max(round(sz * min(1, min(0.9 * scr(3:4) ./ sz))), 100);
name = id + ": " + string(F.observation.label) + " (" + string(F.dataset) + ")";
h = figure("Name", char(name), "NumberTitle", "off", "Position", [60 60 sz]);
drawWindow(obj, id, F, spec, h);
obj.setStatus("Opened " + name + " in its own window; it does not follow later edits.");
end


function drawWindow(app, id, F, spec, h)
%drawWindow  Draw the window's figure H: its right-click menus reach the app while it is open.
pos = getpixelposition(h);
renderFigure(F, spec, h, Scale=previewScale(app, spec, pos(3)), Editable=true, OnRemember=@(rules) rememberIfOpen(app, id, rules), ...
    OnGoto=@(role, panel) gotoIfOpen(app, id, role, panel), ...
    OnAxisEdit=@(panel, change) axisEdited(app, id, F, spec, h, panel, change), ...
    OnSelect=@(panel, ctrl, shift) selectIfOpen(app, id, panel, ctrl, shift));
end


function axisEdited(app, id, F, spec, h, panel, change)
%axisEdited  An axis menu edit of the panels PANEL (ids) in the window: kept in the app's config while the app is open, and the window drawn again with it.
if isvalid(app) && ~isempty(app.Fig) && isvalid(app.Fig)
    app.onFigureAxisEdited(id, panel, change);
end
if ~isgraphics(h); return; end
ks = find(ismember([spec.panels.id], panel));
if isempty(ks); return; end
for k = ks
    for f = string(fieldnames(change)).'
        spec.panels(k).(f) = change.(f);
    end
end
drawWindow(app, id, F, spec, h);
end


function rememberIfOpen(app, id, rules)
%rememberIfOpen  Keep the window's remembered rules in the app's config while the app is open (its editor redraws the window, not the preview).
if isvalid(app) && ~isempty(app.Fig) && isvalid(app.Fig)
    app.rememberFigureAesthetics(id, rules, Preview=false);
end
end


function selectIfOpen(app, id, panel, ctrl, shift)
%selectIfOpen  Select the Ctrl+Clicked panel (Shift+Click: add it to the selected panels, or take it out) in the figure editor while the app is open.
if isvalid(app) && ~isempty(app.Fig) && isvalid(app.Fig)
    app.onFigurePanelClicked(id, panel, ctrl, true, shift);
end
end


function gotoIfOpen(app, id, role, panel)
%gotoIfOpen  Go to the figure editor's setting for a part of the window's figure while the app is open.
if isvalid(app) && ~isempty(app.Fig) && isvalid(app.Fig)
    app.gotoFigureSetting(id, role, panel);
end
end
