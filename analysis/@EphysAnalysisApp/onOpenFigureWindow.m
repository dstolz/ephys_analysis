function h = onOpenFigureWindow(obj)
%onOpenFigureWindow  Draw the figure as previewed into a new MATLAB figure window of its own.
%   H = onOpenFigureWindow(obj) is the Figures tab's "Open in window"
%   button. When the preview is drawn and up to date it draws the result
%   the preview computed (FigurePreviewResult) with the spec it was drawn
%   with; otherwise (out of date, canceled, not yet drawn) it first
%   previews as the Preview button does (refreshFigurePreview, Force), and
%   opens the window only if that draws. The window is a regular figure()
%   named "<figure id>: <observation> (<dataset>)", the size of the
%   preview, drawn by renderFigure (Editable: the right-click aesthetics
%   editor and its Design submenu work in it, and "remember for this
%   figure" reaches the app's config while the app is open). The window is
%   independent of the app: later edits do not follow into it (Preview
%   and Open again for a new one), and closing the app leaves it as it
%   is. H is the figure, [] when none was opened.
%
%   See also refreshFigurePreview, renderFigure, rememberFigureAesthetics.
arguments
    obj (1,1) EphysAnalysisApp
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
if obj.FigurePreviewState ~= "drawn" || isempty(obj.FigurePreviewResult)
    obj.refreshFigurePreview(Force=true);
end
F = obj.FigurePreviewResult;
id = obj.Config.Figures(k).id;
if obj.FigurePreviewState ~= "drawn" || isempty(F) || F.id ~= id
    obj.setStatus("Nothing to open: " + string(obj.FigurePreviewLabel.Text));
    return
end
if obj.Config.Figures(k).sessions.enabled && isstruct(obj.FigureSessionResults) && isfield(obj.FigureSessionResults, 'spec')
    spec = obj.FigureSessionResults.spec;   % as it was computed across the sessions
else
    spec = obj.Config.figureFor(k);
    spec.enabled = true;
end
pos = getpixelposition(obj.FigurePreviewPanel, true);
sz = max(round(pos(3:4)), [400 300]);
name = id + ": " + string(F.observation.label) + " (" + string(F.dataset) + ")";
h = figure("Name", char(name), "NumberTitle", "off", "Position", [60 60 sz]);
app = obj;
renderFigure(F, spec, h, Editable=true, OnRemember=@(rules) rememberIfOpen(app, id, rules));
obj.setStatus("Opened " + name + " in its own window; it does not follow later edits.");
end


function rememberIfOpen(app, id, rules)
%rememberIfOpen  Keep the window's remembered rules in the app's config while the app is open.
if isvalid(app) && ~isempty(app.Fig) && isvalid(app.Fig)
    app.rememberFigureAesthetics(id, rules);
end
end
