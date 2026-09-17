function showIssues(obj, issues)
%showIssues  Fill the Run-tab issues table.
if isempty(obj.RunIssuesTable) || ~isvalid(obj.RunIssuesTable); return; end
if height(issues) == 0
    obj.RunIssuesTable.Data = table("" + string.empty(0, 1), strings(0, 1), strings(0, 1), "no issues" + string.empty(0, 1), ...
        'VariableNames', {'Step', 'Field', 'Severity', 'Message'});
    obj.RunIssuesTable.Data = {'-', '-', 'ok', 'No issues.'};
else
    obj.RunIssuesTable.Data = issues;
end
end
