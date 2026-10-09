function [subject, date] = datasetIdentity(obj, names, keys)
%datasetIdentity  Subject ID and recording date of the project datasets NAMES.
%   [SUBJECT, DATE] = datasetIdentity(OBJ, NAMES, KEYS) gives, for each
%   dataset named in NAMES (a string column), its SubjectID, from the
%   Project name pattern, and the day it was recorded ("yyyy-MM-dd"), from
%   the recording's own start, else from the Date and Time of the name
%   (subjectAndDate). KEYS (optional, the datasets' keys) tells apart two
%   datasets of one name; a name or key the project does not hold gives "".
%   The project's datasets are the only source, so a table of results can
%   carry the two columns without the pipeline knowing about them.
arguments
    obj (1,1) EphysPipelineApp
    names (:,1) string
    keys (:,1) string = strings(size(names))
end
n = numel(names);
subject = strings(n, 1);
date = strings(n, 1);
if n == 0 || isempty(obj.Project) || obj.Project.NumDatasets == 0 || isempty(obj.NamePatternField)
    return
end
nd = obj.Project.NumDatasets;
dsName = strings(nd, 1);
dsKey = strings(nd, 1);
dsAcq = NaT(nd, 1);
for i = 1:nd
    d = obj.Project.Datasets(i);
    dsName(i) = d.Name;
    dsKey(i) = obj.Project.datasetKey(i);
    dsAcq(i) = d.AcqDate;
end
[dsSubject, dsDate] = subjectAndDate(dsName, string(obj.NamePatternField.Value), dsAcq);
for k = 1:n
    i = [];
    if keys(k) ~= ""
        i = find(strcmpi(dsKey, keys(k)), 1);
    end
    if isempty(i)
        i = find(dsName == names(k), 1);
    end
    if ~isempty(i)
        subject(k) = dsSubject(i);
        date(k) = dsDate(i);
    end
end
end
