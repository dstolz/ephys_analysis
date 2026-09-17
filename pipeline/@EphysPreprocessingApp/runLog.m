function runLog(obj, fmt, varargin)
%runLog  Append a timestamped line to the Run-tab log.
if isempty(obj.RunLogArea) || ~isvalid(obj.RunLogArea); return; end
line = string(datetime('now', 'Format', 'HH:mm:ss')) + "  " + string(sprintf(fmt, varargin{:}));
cur = obj.RunLogArea.Value;
if isscalar(cur) && strlength(string(cur{1})) == 0
    cur = cell(0, 1);
end
obj.RunLogArea.Value = [cur; cellstr(line)];
scroll(obj.RunLogArea, 'bottom');
drawnow limitrate;
end
