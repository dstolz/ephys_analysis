function onCopySorted(obj, evt)
%onCopySorted  Remember a header click in the Copy tab's table and put the sessions in its order.
%   The click is the table's sort (onTableSorted, id "Copy"). Refreshing the
%   table then sorts the sessions themselves (refreshCopyTable), so the
%   table stays one list with CopySessions and the ticks and results. While
%   a background copy runs the sessions keep their order (the copy goes by
%   position) and the table shows the click only.
arguments
    obj (1,1) EphysPipelineApp
    evt
end
obj.onTableSorted("Copy", evt);
if isempty(obj.CopyJob)
    obj.refreshCopyTable();
end
end
