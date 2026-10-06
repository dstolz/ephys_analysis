function log(obj, fmt, varargin)
    % Append a timestamped line to the sorting log area.
    line = sprintf("%s  %s", datetime('now', 'Format', 'HH:mm:ss'), ...
        string(sprintf(fmt, varargin{:})));
    obj.appendLogLines(line);
end
