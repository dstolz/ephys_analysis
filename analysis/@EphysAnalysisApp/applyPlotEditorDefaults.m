function applyPlotEditorDefaults(obj)
%applyPlotEditorDefaults  Show the Defaults in the plot's alignment panels that use them.
%   Called after the Alignment tab changes, so a plot that follows the
%   defaults shows the values it will use.
k = obj.SelectedPlot;
if k < 1 || k > numel(obj.Config.Plots); return; end
E = obj.PlotEditor;
p = obj.Config.Plots(k);
D = obj.Config.Defaults;
ref = D.EventRef; win = D.Window; sel = D.Selection;
if ~E.defaultRef.Value && isstruct(p.ref); ref = p.ref; end
if ~E.defaultWindow.Value && isstruct(p.window); win = p.window; end
if ~E.defaultSelection.Value && isstruct(p.selection); sel = p.selection; end
wasApplying = obj.Applying;
obj.Applying = true;
obj.applyAlignControls(obj.PlotAlignControls, ref, win, sel);
obj.Applying = wasApplying;
obj.syncPlotEditorEnable();
end
