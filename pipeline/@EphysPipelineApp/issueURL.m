function [url, truncated] = issueURL(obj, kind, title, body)
%issueURL  Address of a prefilled "new issue" form on GitHub.
%   URL = issueURL(OBJ, KIND, TITLE, BODY) builds the address the Help
%   menu's issue items open (see onReportIssue): the repository's new-issue
%   form (EphysPipelineApp.RepoURL) with the title, the report and the
%   label filled in. KIND is "bug" (label "bug") or "feature" (label
%   "enhancement"). Nothing is filed: the form opens in the browser for the
%   user to read and submit.
%
%   [URL, TRUNCATED] = ... also says whether BODY had to be cut. GitHub
%   rejects an address beyond roughly 8 kB, so a longer report is cut at a
%   line boundary and the cut is stated in the body itself; the caller
%   leaves the whole report on the clipboard. Nothing else is changed: what
%   is sent is the report as issueReport wrote it, up to the cut.
%
%   The address is built by IssueReport.url, which EphysFigGenApp uses too.
arguments
    obj (1,1) EphysPipelineApp
    kind (1,1) string {mustBeMember(kind, ["bug", "feature"])}
    title (1,1) string = ""
    body (1,1) string = ""
end
[url, truncated] = IssueReport.url(obj.RepoURL, kind, title, body);
end
