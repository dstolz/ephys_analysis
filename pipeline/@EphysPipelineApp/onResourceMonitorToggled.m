function onResourceMonitorToggled(obj)
%onResourceMonitorToggled  Start or stop watching CPU, memory, disk and GPU use.
%   Ticked (Monitor CPU, memory, disk and GPU), the Resource use panel
%   opens under the Steps panel and a sampler starts outside MATLAB
%   (startResourceMonitor); unticked, the sampler is stopped and the panel
%   closes. The switch is a preference (MonitorResources).

show = logical(obj.RunMonitorCheckBox.Value);
obj.RunMonitorPanel.Visible = show;
if show
    obj.RunLeftGrid.RowHeight = {'1x', 'fit'};
    obj.startResourceMonitor();
else
    obj.RunLeftGrid.RowHeight = {'1x', 0};
    obj.stopResourceMonitor();
end
end
