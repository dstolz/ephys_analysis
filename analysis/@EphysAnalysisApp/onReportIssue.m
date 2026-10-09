function onReportIssue(obj, kind)
%onReportIssue  Compose a GitHub issue about this session and open it prefilled.
%   onReportIssue(OBJ, "bug") opens the Help menu's issue dialog: a title, a
%   box for what happened, tick boxes for what to send with it (system info,
%   the analysis config and the Log tab) and a preview of the whole report
%   exactly as it will be sent (issueReport). "Open on GitHub" copies the
%   report to the clipboard and opens the repository's new-issue form with
%   the title, the report and the "bug" label filled in (issueURL); nothing
%   is filed until the user submits it there.
%
%   onReportIssue(OBJ, "feature") is the same dialog for a feature request:
%   it asks what the app should do instead, starts with only the system info
%   ticked and uses the "enhancement" label.
%
%   If no browser opens, an alert shows the address to copy instead. The
%   dialog itself is IssueReport.dialog, which EphysPipelineApp uses too.
arguments
    obj (1,1) EphysAnalysisApp
    kind (1,1) string {mustBeMember(kind, ["bug", "feature"])}
end

includes = struct( ...
    "Label",   {"System info", "Analysis config", "Log tab"}, ...
    "Tooltip", {"MATLAB release, platform, memory, GPU and the toolboxes installed.", ...
                "The working config, including the project, output and figure paths it names.", ...
                "The tail of the Log tab: what the scans, previews and runs reported."}, ...
    "Bug",     {true, true, true}, ...
    "Feature", {true, false, false});

IssueReport.dialog(obj.Fig, kind, Name="EphysAnalysisApp", Includes=includes, ...
    Repo=obj.RepoURL, ...
    Report=@(k, desc, on) obj.issueReport(k, Description=desc, ...
        System=on(1), Config=on(2), Logs=on(3)), ...
    Status=@(msg) obj.setStatus(msg));
end
