function log(obj, message)
%log  Add a time-stamped line to the Log tab (the last 2000 lines are kept).
if isempty(obj.LogArea) || ~isvalid(obj.LogArea); return; end
line = string(datetime('now', 'Format', 'HH:mm:ss')) + "  " + string(message);
v = string(obj.LogArea.Value);
v = v(:);
if isscalar(v) && v == ""; v = strings(0, 1); end
v = [v; line];
if numel(v) > 2000; v = v(end-1999:end); end
obj.LogArea.Value = cellstr(v);
end
