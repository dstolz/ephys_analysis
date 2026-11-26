function M = datasetFileMarks(obj)
%datasetFileMarks  Which of each dataset's files exist, as the last scan found them: an N x 7 logical.
%   M = datasetFileMarks(OBJ) has a row per dataset of the Runner and a
%   column per kind of file the datasets table marks -- LFP, MUA, SPIKE,
%   AUX, behavior, sorting, spikes (DatasetOutputs.has; datasetFileKinds
%   gives the names, in order). Each check is a round trip over a share,
%   and the table is filled on every star, note, tick and filter edit, so
%   the answers are kept (DatasetFileMarks) and read again only for another
%   Runner: a scan (onScan) makes a new one, so a file that appeared or
%   went away is noticed at the next Scan, as the datasets listed are
%   those of the last scan, and not on an edit of the table.
%
%   See also refreshDatasetsTable, datasetFileKinds, DatasetOutputs.has.
r = obj.Runner;
n = numel(r.Keys);
C = obj.DatasetFileMarks;
if isstruct(C) && isfield(C, 'Runner') && isequal(C.Runner, r) && size(C.Marks, 1) == n
    M = C.Marks;
    return
end
kinds = datasetFileKinds();
M = false(n, numel(kinds));
for k = 1:n
    out = r.Outputs(k);
    for j = 1:numel(kinds)
        M(k, j) = out.has(kinds(j));
    end
end
obj.DatasetFileMarks = struct('Runner', r, 'Marks', M);
end
