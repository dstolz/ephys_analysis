function onPlotDefaultToggled(obj)
%onPlotDefaultToggled  A "Use default" box of the plot's event, window or selection was toggled.
%   Ticked, the section shows the Alignment tab's values again and the plot
%   uses them (its own are dropped); unticked, the plot keeps the values
%   shown as its own.
obj.onConfigChanged("plot");
obj.applyPlotEditorDefaults();
end
