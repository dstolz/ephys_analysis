function S = sessionTable(obj, idx)
%sessionTable  The sessions of some datasets, by date: sessionTable over the runner's datasets.
%   S = r.sessionTable(IDX) (dataset indices, keys or names; left out:
%   all; an empty IDX: none) is sessionTable(Names, Keys, NamePattern=Source.NamePattern,
%   AcqDates=, Folders=, Index=, Sort=true): AcqDates from the project's
%   datasets (each recording's own start; NaT in folders mode), Folders
%   their output folders and index the runner's dataset index; sorted by
%   date, then name, before the labels are made unique.
%
%   See also sessionTable, EphysAnalysisRunner.sessionFigureObservations.
arguments
    obj (1,1) EphysAnalysisRunner
    idx = []
end
if nargin < 2
    idx = 1:numel(obj.Outputs);
elseif ~isnumeric(idx)
    idx = arrayfun(@(k) obj.index(k), reshape(string(idx), 1, []));
    idx = idx(idx > 0);
end
idx = reshape(idx, [], 1);
n = numel(idx);
acq = NaT(n, 1);
folders = strings(n, 1);
for j = 1:n
    folders(j) = obj.datasetFolder(idx(j));
end
if ~isempty(obj.Project) && n > 0
    pk = obj.Project.findByKey(obj.Keys(idx));
    for j = reshape(find(pk > 0), 1, [])
        a = obj.Project.Datasets(pk(j)).AcqDate;
        if isdatetime(a) && ~isempty(a); acq(j) = a(1); end
    end
end
S = sessionTable(reshape(obj.Names(idx), [], 1), reshape(obj.Keys(idx), [], 1), ...
    NamePattern=obj.Config.Source.NamePattern, AcqDates=acq, Folders=folders, Index=idx, Sort=true);
end
