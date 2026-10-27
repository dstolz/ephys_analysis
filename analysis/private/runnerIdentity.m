function [subject, day] = runnerIdentity(runner, keys)
%runnerIdentity  Each dataset's subject and recording day, as epochMatrix and DatasetBrowser list them.
%   [SUBJECT, DAY] = runnerIdentity(RUNNER, KEYS) for an EphysAnalysisRunner
%   that has found its datasets and the keys KEYS of some of them:
%   subjectAndDate over their names and RUNNER.Config.Source.NamePattern,
%   with the project's AcqDate (the recording's own start) where it is
%   known, else the date and time in the name. SUBJECT is a string column
%   ("" when the name does not match the pattern), DAY a datetime column
%   (the day; NaT when neither gives one). No source is loaded. Both
%   callers use this one function, so the browser's table and epochMatrix's
%   R.rows always agree.
%
%   See also subjectAndDate, epochMatrix, DatasetBrowser.

keys = reshape(string(keys), [], 1);
n = numel(keys);
idx = zeros(n, 1);
for j = 1:n; idx(j) = runner.index(keys(j)); end
names = strings(n, 1);
names(idx > 0) = reshape(runner.Names(idx(idx > 0)), [], 1);
acq = NaT(n, 1);
if ~isempty(runner.Project)
    pk = runner.Project.findByKey(reshape(keys, 1, []));
    for j = reshape(find(pk > 0), 1, [])
        acq(j) = runner.Project.Datasets(pk(j)).AcqDate;
    end
end
[subject, dayText] = subjectAndDate(names, string(runner.Config.Source.NamePattern), acq);
day = NaT(n, 1);
has = dayText ~= "";
if any(has); day(has) = datetime(dayText(has), 'InputFormat', 'yyyy-MM-dd'); end
end
