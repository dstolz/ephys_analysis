function onPanelDefaultToggled(obj)
%onPanelDefaultToggled  The "Same as the figure" box of the selected panel's alignment was toggled.
%   Ticked, the panel uses the figure's event reference and window again
%   (its own are dropped) and the section shows the figure's; unticked,
%   the panel takes the values shown, both, as its own.
E = obj.FigureEditor;
E.panelSame.UserData = repmat(~E.panelSame.Value, 1, 2);
obj.onConfigChanged("figure");
obj.applyFigureEditorDefaults();
end
