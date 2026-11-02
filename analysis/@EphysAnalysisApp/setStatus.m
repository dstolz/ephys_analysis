function setStatus(obj, message)
%setStatus  Show MESSAGE in the status bar; its tooltip holds the whole text, for a message the bar clips.
%   While the app starts (its window hidden behind the splash: AppSplash)
%   the bar is not painted: a drawnow then would lay out the whole hidden
%   window early, and again after every later change, where the one when
%   it shows lays it out once.
%   What stops an action is an alert (AppDialog.alertFailure), not a line
%   here: the bar is for what happened and what is shown.
if isempty(obj.StatusBar) || ~isvalid(obj.StatusBar); return; end
obj.StatusBar.Text = char(string(message));
obj.StatusBar.Tooltip = char(string(message));
if ~obj.Splash.isActive(); drawnow limitrate; end
end
