function onIssueActivated(obj, evt)
%onIssueActivated  A double-click on a row of the Run tab's issues table: go to the setting it is about.
%   The row's Step and Field (EphysPipelineConfig.validate) name the
%   control that edits it (issueTarget); the tab that holds it is shown and
%   the control scrolled into view, marked and focused (openSetting). An
%   issue with no control of its own (a setting the app has no field for, a
%   whole step) shows its tab alone, and the status bar says which. EVT's
%   InteractionInformation row is the row of the table's Data, whatever
%   the header sort shows.
%
%   See also issueTarget, openSetting, showIssues.
arguments
    obj (1,1) EphysPipelineApp
    evt
end
info = evt.InteractionInformation;
if isempty(info.Row); return; end
T = obj.RunIssuesTable.Data;
row = info.Row(1);
if istable(T)
    if row > height(T); return; end
    step = string(T.Step(row)); field = string(T.Field(row));
elseif iscell(T)
    if row > size(T, 1); return; end
    step = string(T{row, 1}); field = string(T{row, 2});
else
    return
end
if ismember(step, ["" "-"]); return; end   % the "No issues." row
[target, tabName] = issueTarget(step, field);
if target ~= "" && obj.openSetting(target)
    obj.setStatus("Issue: " + step + " > " + field + " is set here.", "");
    return
end
if tabName == ""
    obj.setStatus("Issue: " + step + " > " + field + " has no setting of its own to open.", "");
    return
end
obj.selectTab(obj.(tabName));
obj.setStatus("Issue: " + step + " > " + field + " is on the " + string(obj.(tabName).Title) + " tab.", "");
end
