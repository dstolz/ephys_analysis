function setTrialsLineItems(obj, names, trialLine)
%setTrialsLineItems  Trial-line dropdown: the given line names plus TRIALLINE (selected).
items = unique([reshape(string(names), [], 1); string(trialLine)], 'stable');
obj.TrialsLineDropDown.Items = cellstr(items);
obj.TrialsLineDropDown.Value = char(trialLine);
end
