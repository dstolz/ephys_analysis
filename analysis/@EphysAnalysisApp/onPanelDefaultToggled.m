function onPanelDefaultToggled(obj)
%onPanelDefaultToggled  The "Same as the figure" box of the selected panel's alignment was toggled.
%   Ticked, the panel uses the figure's event reference and window again
%   (its own are dropped: ref and window "default"), and the rows show the
%   figure's, locked. Unticked, the panel takes a copy of the figure's
%   current event and window as its own, both, and the rows are enabled to
%   edit them.
E = obj.FigureEditor;
linked = logical(E.panelSame.Value);
E.panelSame.UserData = repmat(~linked, 1, 2);
if ~linked
    obj.applyFigureEditorDefaults();   % the rows show the figure's current values: the panel's own start from them
end
obj.onConfigChanged("figure", "Panel alignment from the figure");
obj.applyFigureEditorDefaults();
end
