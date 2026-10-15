function applyFigureEditorDefaults(obj)
%applyFigureEditorDefaults  Show the Defaults in the figure's alignment sections that use them, and the figure's in a panel that does.
%   Called after the Alignment tab changes, and after the figure's own
%   alignment or a "Use default" / "Same as the figure" box changes, so
%   every section shows the values the figure and its selected panel will
%   use.
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
E = obj.FigureEditor;
fig = obj.Config.Figures(k);
D = obj.Config.Defaults;
ref = D.EventRef; win = D.Window; sel = D.Selection;
if ~E.defaultRef.Value && isstruct(fig.ref); ref = fig.ref; end
if ~E.defaultWindow.Value && isstruct(fig.window); win = fig.window; end
if ~E.defaultSelection.Value && isstruct(fig.selection); sel = fig.selection; end
wasApplying = obj.Applying;
obj.Applying = true;
obj.applyAlignControls(obj.FigureAlignControls, ref, win, sel);
j = obj.SelectedPanel;
if j >= 1 && j <= numel(fig.panels)
    p = fig.panels(j);
    if isstruct(p.ref); ref = p.ref; end
    if isstruct(p.window); win = p.window; end
    if isstruct(p.selection); sel = p.selection; end
    obj.applyAlignControls(obj.PanelAlignControls, ref, win, sel);
end
obj.Applying = wasApplying;
obj.syncFigureEditor();
end
