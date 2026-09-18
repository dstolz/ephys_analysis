function issues = onValidate(obj)
%onValidate  Check the working config and list its problems.
cfg = obj.gatherConfig();
issues = cfg.validate();
obj.IssuesTable.Data = issues;
nE = nnz(issues.Severity == "error");
nW = nnz(issues.Severity == "warning");
if isempty(issues)
    obj.setStatus("The config is valid.");
else
    obj.setStatus(sprintf("%d error(s), %d warning(s): see the table.", nE, nW));
end
end
