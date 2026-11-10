function src = source(obj, k)
%source  The analysis source of dataset K (an index, key or name), loaded once.
%   SRC = r.source(K) is loadAnalysisSource(r.Outputs(K), Key=r.Keys(K)),
%   kept in r.Sources until datasets() or clearSources(). A source whose
%   behavior file names no subject gets the SubjectID token of its name
%   (subjectAndDate with Config.Source.NamePattern), so {Subject} in a
%   figure's text and the Data tab's Subject column agree.
%
%   See also loadAnalysisSource, EphysAnalysisRunner.datasets.

i = obj.index(k);
if i == 0
    error('EphysAnalysisRunner:NoDataset', 'No dataset "%s".', string(k));
end
key = char(obj.Keys(i));
if isKey(obj.Sources, key)
    src = obj.Sources(key);
    return
end
src = loadAnalysisSource(obj.Outputs(i), Key=obj.Keys(i));
if src.subject == ""   % no subject in the behavior file: the name's SubjectID, as the Data tab lists it
    src.subject = subjectAndDate(string(obj.Names(i)), string(obj.Config.Source.NamePattern));
end
obj.Sources(key) = src;
end
