function setStatus(obj, message)
%setStatus  Show MESSAGE in the status bar.
if isempty(obj.StatusBar) || ~isvalid(obj.StatusBar); return; end
obj.StatusBar.Text = char(string(message));
drawnow limitrate;
end
