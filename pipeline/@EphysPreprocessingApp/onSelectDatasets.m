function onSelectDatasets(obj, mode)
%onSelectDatasets  Tick all / no dataset rows (none = run everything).
%   "all" and "invert" act on the rows shown under the token filters;
%   "none" also clears the ticks on filtered-out rows.
arguments
    obj (1,1) EphysPreprocessingApp
    mode (1,1) string {mustBeMember(mode, ["all", "none", "invert"])}
end
T = obj.DatasetsTable.Data;
if ~istable(T) || ~any(strcmp('Select', T.Properties.VariableNames)); return; end
switch mode
    case "all";    T.Select(:) = true;
    case "none"
        T.Select(:) = false;
        obj.HiddenSelectedKeys = string.empty(1, 0);
        obj.NameTokenStatusLabel.Text = regexprep(obj.NameTokenStatusLabel.Text, ' \(\d+ ticked hidden\)', '');
    case "invert"; T.Select = ~T.Select;
end
obj.DatasetsTable.Data = T;
obj.refreshDatasetMenu();
obj.onConfigChanged();
end
