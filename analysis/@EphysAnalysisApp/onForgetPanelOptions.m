function onForgetPanelOptions(obj)
%onForgetPanelOptions  Edit > Forget remembered panel options: new panels start from their types' defaults again.
%   Empties obj.PanelOptions (the options last set on a panel of each
%   type, rememberPanelOptions, which a new panel starts from: onNewPanel)
%   and writes the preferences at once (savePreferences). The figures and
%   the config are not changed: their panels keep their options (Edit >
%   Reset panel options to defaults gives the selected panel the defaults:
%   onResetPanelOptions). Not an edit of the figures: no undo step.
%
%   See also onResetPanelOptions, onNewPanel.
n = numel(fieldnames(obj.PanelOptions));
obj.PanelOptions = struct();
obj.savePreferences();
if n == 0
    obj.setStatus("No panel options were remembered: new panels start from their types' defaults.");
else
    obj.setStatus(sprintf("Forgot the options remembered for %d panel type(s): new panels start from their types' defaults.", n));
end
end
