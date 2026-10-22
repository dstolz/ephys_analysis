function setStatus(obj, message, hint)
    % Update the bottom status bar. MESSAGE describes the last action or
    % current state; the optional HINT (shown italic, on the right) is a
    % suggested next step. Pass HINT = "" or omit it to clear the hint;
    % omit BOTH the hint arg and let suggestNextStep supply a contextual
    % one by passing the sentinel [] (see callers).
    % While the app starts (its window hidden behind the splash: AppSplash)
    % the bar is not painted: a drawnow then would lay out the whole hidden
    % window early, and again after every later change, where the one when
    % it shows lays it out once.
    if isempty(obj.StatusBar) || ~isvalid(obj.StatusBar); return; end
    obj.StatusBar.Text = char(string(message));
    if nargin < 3
        hint = obj.suggestNextStep();
    end
    hint = string(hint);
    if strlength(hint) == 0
        obj.StatusHint.Text = "";
    else
        obj.StatusHint.Text = char("Next: " + hint);
    end
    if ~obj.Splash.isActive(); drawnow limitrate; end
end
