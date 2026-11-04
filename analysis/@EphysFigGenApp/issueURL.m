function [url, truncated] = issueURL(obj, kind, title, body)
%issueURL  Address of a prefilled "new issue" form on GitHub.
%   URL = issueURL(OBJ, KIND, TITLE, BODY) builds the address the Help
%   menu's issue items open (see onReportIssue): the repository's new-issue
%   form (EphysAnalysisApp.RepoURL) with the title, the report and the
%   label filled in. KIND is "bug" (label "bug") or "feature" (label
%   "enhancement"). Nothing is filed: the form opens in the browser for the
%   user to read and submit.
%
%   [URL, TRUNCATED] = ... also says whether BODY had to be cut: a report
%   beyond what an address holds is cut at a line boundary, says so in the
%   body, and the whole of it is left on the clipboard (IssueReport.url).
arguments
    obj (1,1) EphysAnalysisApp
    kind (1,1) string {mustBeMember(kind, ["bug", "feature"])}
    title (1,1) string = ""
    body (1,1) string = ""
end
[url, truncated] = IssueReport.url(obj.RepoURL, kind, title, body);
end
