function nasLog(obj, msg)
%nasLog  Append a timestamped line to the NAS-tab log.
%   MSG is used as is (not as a sprintf format: paths hold backslashes).
if isempty(obj.NasLogArea) || ~isvalid(obj.NasLogArea); return; end
line = string(datetime('now', 'Format', 'HH:mm:ss')) + "  " + string(msg);
cur = obj.NasLogArea.Value;
if isscalar(cur) && strlength(string(cur{1})) == 0
    cur = cell(0, 1);
end
obj.NasLogArea.Value = [cur; cellstr(line)];
scroll(obj.NasLogArea, 'bottom');
drawnow limitrate;
end
