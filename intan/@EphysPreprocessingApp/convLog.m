function convLog(obj, fmt, varargin)
    % Append a timestamped line to the Convert log area.
    if isempty(obj.ConvLogArea) || ~isvalid(obj.ConvLogArea); return; end
    line = string(datetime('now', 'Format', 'HH:mm:ss')) + "  " + ...
        string(sprintf(fmt, varargin{:}));
    cur = obj.ConvLogArea.Value;
    if isscalar(cur) && strlength(string(cur{1})) == 0
        cur = cell(0, 1);   % drop the default blank line
    end
    obj.ConvLogArea.Value = [cur; cellstr(line)];
    scroll(obj.ConvLogArea, 'bottom');
    drawnow limitrate;
end
