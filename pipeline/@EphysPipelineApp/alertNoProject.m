function alertNoProject(obj, title)
%alertNoProject  Say there is no project yet, in the apps' one wording, with a button to the Project tab.
%   obj.alertNoProject(TITLE) shows AppDialog.noProject ("No project is
%   loaded. On the Project tab choose the folder that holds your recordings
%   (the project root) and press Scan.") as an alert titled TITLE. Unless the
%   Project tab is the one shown, the alert has a "Go to Project tab" button.
%   Every action that needs a scanned project says this, so a person learns
%   one message (Scan, Plan, Run, Assign probe, Apply probe rules, Refresh
%   metadata, ...).
arguments
    obj (1,1) EphysPipelineApp
    title (1,1) string = "No project"
end
goto = [];
if obj.Tabs.SelectedTab ~= obj.TabProject
    goto = @() obj.selectTab(obj.TabProject);
end
AppDialog.alertNoProject(obj.Fig, goto, Where="Project", Title=title);
end
