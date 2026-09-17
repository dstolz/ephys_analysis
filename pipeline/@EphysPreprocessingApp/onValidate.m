function onValidate(obj)
%onValidate  Validate the working config and show the issues on the Run tab.
cfg = obj.gatherConfig();
obj.Config = cfg;
issues = cfg.validate();
obj.showIssues(issues);
obj.selectTab(obj.TabRun);
nE = nnz(issues.Severity == "error"); nW = nnz(issues.Severity == "warning");
obj.setStatus(sprintf("Validate: %d error(s), %d warning(s).", nE, nW), "");
end
