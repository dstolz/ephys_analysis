function [T, labels, widths] = identityTable(obj, id, T, outputLabel)
%identityTable  A per-dataset table with Subject and Date columns, in table ID's sort.
%   [T, LABELS, WIDTHS] = identityTable(OBJ, ID, T, OUTPUTLABEL): T has a
%   Dataset variable (a plan or a run's results). The result has Subject
%   and Date (datasetIdentity) after Dataset, replacing any it has, and its
%   rows are in the order of sortable table ID's remembered header click
%   (tableSort), so the sort holds as the table is filled again. LABELS and
%   WIDTHS are the headers and widths for the table's ColumnName and
%   ColumnWidth: the variables' names (Output reads OUTPUTLABEL, default
%   "Output").
arguments
    obj (1,1) EphysPipelineApp
    id (1,1) string
    T table
    outputLabel (1,1) string = "Output"
end
T = removevars(T, intersect(["Subject" "Date"], string(T.Properties.VariableNames)));
if ismember("Dataset", string(T.Properties.VariableNames))
    keys = strings(height(T), 1);
    if ismember("Key", string(T.Properties.VariableNames))
        keys = string(T.Key);
    end
    [Subject, Date] = datasetIdentity(obj, string(T.Dataset), keys);
    T = addvars(T, Subject, Date, 'After', "Dataset");
end
T = TableSort.apply(T, obj.tableSort(id));
vars = string(T.Properties.VariableNames);
labels = cellstr(vars);
labels(vars == "Output") = {char(outputLabel)};
widths = repmat({'auto'}, 1, numel(vars));
known = ["Step" "Dataset" "Subject" "Date" "Key" "Output" "Status" "Note" "Message" "Seconds"];
w = {'fit', 'fit', 90, 84, 'fit', '2x', 130, '1x', '1x', 64};
[tf, loc] = ismember(vars, known);
widths(tf) = w(loc(tf));
end
