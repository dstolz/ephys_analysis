function txt = copyText(obj, format)
%copyText  The result table as text ("tsv", "csv", "markdown", "matlab"), in the Sort order.
%   Built from obj.Result.Table (ChannelMap.toText), never from the table
%   control, so the numbers are exact.
arguments
    obj
    format (1,1) string = "tsv"
end
txt = "";
if isempty(obj.Result)
    return
end
txt = ChannelMap.toText(obj.Result.Table, Format=format, SortBy=string(obj.SortDrop.Value));
end
