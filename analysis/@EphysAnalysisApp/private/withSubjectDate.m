function T = withSubjectDate(obj, T)
%withSubjectDate  T with Subject and Date columns after its Dataset column.
%   For a table of per-dataset rows (the plan, a run's results): the
%   dataset's SubjectID and the day it was recorded, as the Data tab's
%   datasets table gives them (subjectAndDate, from the config's name
%   pattern and, in a project, the recording's own start). T is returned as
%   it is without a Dataset column or a scanned runner.
arguments
    obj (1,1) EphysAnalysisApp
    T
end
r = obj.Runner;
if ~istable(T) || isempty(r) || ~ismember("Dataset", string(T.Properties.VariableNames))
    return
end
T = removevars(T, intersect(["Subject" "Date"], string(T.Properties.VariableNames)));
names = string(T.Dataset);
acq = NaT(height(T), 1);
if ~isempty(r.Project)
    [tf, loc] = ismember(names, r.Names);
    pk = zeros(height(T), 1);
    pk(tf) = r.Project.findByKey(r.Keys(loc(tf)));
    for k = reshape(find(pk > 0), 1, [])
        acq(k) = r.Project.Datasets(pk(k)).AcqDate;
    end
end
[Subject, Date] = subjectAndDate(names, string(r.Config.Source.NamePattern), acq);
T = addvars(T, Subject, Date, 'After', "Dataset");
end
