function setStatus(obj, message)
%setStatus  Show MESSAGE in the status bar.
%   While the app starts (its window hidden behind the splash: AppSplash)
%   the bar is not painted: a drawnow then would lay out the whole hidden
%   window early, and again after every later change, where the one when
%   it shows lays it out once.
if isempty(obj.StatusBar) || ~isvalid(obj.StatusBar); return; end
obj.StatusBar.Text = char(string(message));
if ~obj.Splash.isActive(); drawnow limitrate; end
end
