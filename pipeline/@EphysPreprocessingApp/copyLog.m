function copyLog(obj, msg)
%copyLog  Append a timestamped line to the Copy-tab log.
%   MSG is used as is (not as a sprintf format: paths hold backslashes).
if isempty(obj.CopyLogArea) || ~isvalid(obj.CopyLogArea); return; end
line = string(datetime('now', 'Format', 'HH:mm:ss')) + "  " + string(msg);
cur = obj.CopyLogArea.Value;
if isscalar(cur) && strlength(string(cur{1})) == 0
    cur = cell(0, 1);
end
obj.CopyLogArea.Value = [cur; cellstr(line)];
scroll(obj.CopyLogArea, 'bottom');
drawnow limitrate;
end
