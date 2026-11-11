function issues = onValidate(obj)
%onValidate  Check the working config and list its problems.
%   The Export tab's table lists them (Section, Field, Severity, Message);
%   a double click on a row goes to the setting it is about
%   (onIssueActivated). The scanned datasets' variables
%   (datasetVariableSets) count as label variables ({probeDepth}).
cfg = obj.gatherConfig();
issues = cfg.validate(DatasetVariables=obj.datasetVariableSets());
obj.IssuesTable.Data = issues;
nE = nnz(issues.Severity == "error");
nW = nnz(issues.Severity == "warning");
if isempty(issues)
    obj.setStatus("The config is valid.");
else
    obj.setStatus(sprintf("%d error(s), %d warning(s): see the table on the Export tab (double-click a row to go to it).", nE, nW));
end
end
