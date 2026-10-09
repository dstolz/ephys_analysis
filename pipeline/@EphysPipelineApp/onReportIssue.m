function onReportIssue(obj, kind)
%onReportIssue  Compose a GitHub issue about this session and open it prefilled.
%   onReportIssue(OBJ, "bug") opens the Help menu's issue dialog: a title, a
%   box for what happened, tick boxes for what to send with it (system info,
%   the pipeline options, the logs and the last error) and a preview of the
%   whole report exactly as it will be sent (issueReport). "Open on GitHub"
%   copies the report to the clipboard and opens the repository's new-issue
%   form with the title, the report and the "bug" label filled in
%   (issueURL); nothing is filed until the user submits it there.
%
%   onReportIssue(OBJ, "feature") is the same dialog for a feature request:
%   it asks what the app should do instead, starts with only the system info
%   ticked and uses the "enhancement" label.
%
%   If no browser opens, an alert shows the address to copy instead. The
%   dialog itself is IssueReport.dialog, which EphysAnalysisApp uses too.
arguments
    obj (1,1) EphysPipelineApp
    kind (1,1) string {mustBeMember(kind, ["bug", "feature"])}
end

includes = struct( ...
    "Label",   {"System info", "Pipeline options", "Logs and last error"}, ...
    "Tooltip", {"MATLAB release, platform, memory, GPU, Python and the toolboxes installed.", ...
                "The working config, including the project and output paths it names.", ...
                "The tail of the Run, Sorting and Copy logs and the error the last run stopped on."}, ...
    "Bug",     {true, true, true}, ...
    "Feature", {true, false, false});

IssueReport.dialog(obj.Fig, kind, Name="EphysPipelineApp", Includes=includes, ...
    Repo=obj.RepoURL, ...
    Report=@(k, desc, on) obj.issueReport(k, Description=desc, ...
        System=on(1), Config=on(2), Logs=on(3)), ...
    Status=@(msg) obj.setStatus(msg, ""));
end
