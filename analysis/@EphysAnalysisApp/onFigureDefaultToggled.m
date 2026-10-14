function onFigureDefaultToggled(obj)
%onFigureDefaultToggled  A "Use default" box of the figure's event, window or selection was toggled.
%   Ticked, the section shows the Alignment tab's values again and the
%   figure uses them (its own are dropped); unticked, the figure keeps the
%   values shown as its own.
obj.onConfigChanged("figure");
obj.applyFigureEditorDefaults();
end
