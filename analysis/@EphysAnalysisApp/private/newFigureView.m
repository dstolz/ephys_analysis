function v = newFigureView(obj, id)
%newFigureView  A figure's preview container, not drawn yet: an entry of FigureViews (syncFigureView).
%   V = newFigureView(OBJ, ID) makes a hidden uipanel in FigurePreviewHost,
%   in its one cell (every container is stacked there), saying it is not
%   drawn yet, and returns its entry:
%     Id        the figure's id (trackFigureIds follows a rename); "" for
%               the container shown while no figure is selected
%     Panel     the container: renderFigure draws in it, the busy card
%               (showPreviewState) and the selected panel's outline
%               (markFigurePanel) sit in it
%     State     its badge's state (setFigurePreviewState): "idle"
%     Result    computeFigure's F drawn there ([] = none)
%     Drawn     what it was drawn from (figureViewKey; [] = not drawn)
%     Seconds   how long its last preview took (autoFigurePreview)
%     Sessions  a session figure's kept results (FigureSessionResults)
%     Label     the status line under the preview while it shows
%     Used      when it was last shown (FigureViewTick; the cap drops the
%               least recently used)
P = uipanel(obj.FigurePreviewHost, "BackgroundColor", "w", "BorderType", "line", "Visible", "off");
P.Layout.Row = 1;
P.Layout.Column = 1;
if id == ""
    msg = "Add a figure, scan and pick a dataset to preview.";
else
    msg = id + " is not drawn yet: Preview draws it.";
end
g = uigridlayout(P, [1 1]);
uilabel(g, "Text", msg, "WordWrap", "on", "HorizontalAlignment", "center", "FontColor", [0.4 0.4 0.4]);
v = struct('Id', string(id), 'Panel', P, 'State', "idle", 'Result', [], 'Drawn', [], 'Seconds', 0, ...
    'Sessions', [], 'Label', msg, 'Used', 0);
end
