function setStatus(obj, msg, isError)
%setStatus  The status bar: the last action, red when it failed.
if nargin < 3
    isError = false;
end
if isempty(obj.StatusLabel) || ~isvalid(obj.StatusLabel)
    return
end
obj.StatusLabel.Text = char(string(msg));
if isError
    obj.StatusLabel.FontColor = [0.75 0 0];
else
    obj.StatusLabel.FontColor = [0 0 0];
end
end
