function onValidate(obj)
%onValidate  Validate the working config and show the issues on the Run tab.
try
    cfg = obj.gatherConfig();
catch ME
    obj.reportFailure("Validate", "read the settings", "", ME, "fix the field the message names (a text field that does not parse), then press Validate config again");
    return
end
obj.Config = cfg;
issues = cfg.validate();
obj.showIssues(issues);
obj.selectTab(obj.TabRun);
nE = nnz(issues.Severity == "error"); nW = nnz(issues.Severity == "warning");
obj.setStatus(sprintf("Validate: %d error(s), %d warning(s).", nE, nW), "");
end
