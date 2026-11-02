function setStatus(obj, message, hint)
    % Update the bottom status bar. MESSAGE describes the last action or
    % current state; the optional HINT (shown italic, on the right) is a
    % suggested next step. Pass HINT = "" or omit it to clear the hint;
    % omit BOTH the hint arg and let suggestNextStep supply a contextual
    % one by passing the sentinel [] (see callers).
    % A hint that is not blank stays; otherwise, when the selected tab is
    % amber or red (syncTabStrip), the right side says why instead
    % (showTabReason). The bar's tooltip holds the whole message, for one
    % the bar clips.
    % While the app starts (its window hidden behind the splash: AppSplash)
    % the bar is not painted: a drawnow then would lay out the whole hidden
    % window early, and again after every later change, where the one when
    % it shows lays it out once.
    if isempty(obj.StatusBar) || ~isvalid(obj.StatusBar); return; end
    obj.StatusBar.Text = char(string(message));
    obj.StatusBar.Tooltip = char(string(message));
    given = nargin >= 3;   % a hint the caller chose (blank: none), not the suggested one
    if ~given
        hint = obj.suggestNextStep();
    end
    hint = string(hint);
    if strlength(hint) == 0
        obj.StatusHint.Text = "";
        obj.StatusHint.Tag = "";
    else
        obj.StatusHint.Text = char("Next: " + hint);
        obj.StatusHint.Tag = "";
        if given; obj.StatusHint.Tag = "explicit"; end
    end
    obj.StatusHint.Tooltip = char(hint);
    obj.StatusHint.FontColor = [0.15 0.45 0.75];
    obj.showTabReason();
    if ~obj.Splash.isActive(); drawnow limitrate; end
end
