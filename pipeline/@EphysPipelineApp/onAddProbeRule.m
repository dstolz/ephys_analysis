function onAddProbeRule(obj)
%onAddProbeRule  Add a probe rule: the active dataset's subject -> the selected probe.
%   The subject is the SubjectID the active dataset's name carries
%   (Project.NamePattern); "*" (every dataset) when there is none. Edit the
%   pattern in the table, e.g. "su04*" for a group of subjects.
pf = obj.selectedProbeFile();
if pf == "" || ~isfile(pf)
    uialert(obj.Fig, "Select a probe in the table first.", "Probe rules");
    return
end
subject = "*";
d = obj.currentDataset();
if ~isempty(d)
    try
        [v, names, ok] = parseNameTokens(d.Name, d.NamePattern);
        if ok && any(names == "SubjectID") && v(names == "SubjectID") ~= ""
            subject = v(names == "SubjectID");
        end
    catch
    end
end
obj.ProbeRulesTable.Data(end+1, :) = {char(subject), char(pf)};
obj.ProbeRulesTable.UserData = size(obj.ProbeRulesTable.Data, 1);
obj.onConfigChanged();
end
