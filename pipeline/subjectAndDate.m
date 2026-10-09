function [subject, date] = subjectAndDate(names, pattern, acq)
%subjectAndDate  Subject ID and recording day of datasets, for the tables that list them.
%   [SUBJECT, DATE] = subjectAndDate(NAMES, PATTERN, ACQ) gives, for each
%   dataset name in NAMES (a string column), the SubjectID token of PATTERN
%   (a Project name pattern, see parseNameTokens) and the day it was
%   recorded as "yyyy-MM-dd": from ACQ, the recording's own start (a
%   datetime column, NaT = not known), else from the Date and Time tokens of
%   the name (EphysDataset.nameIdentity). A name that does not match, or a
%   pattern without those tokens, gives "". SubjectID needs no Date or Time
%   token to be read.
%
%   See also EphysDataset.nameIdentity, parseNameTokens.
arguments
    names (:,1) string
    pattern (1,1) string
    acq (:,1) datetime = NaT(numel(names), 1)
end
n = numel(names);
subject = strings(n, 1);
date = strings(n, 1);
if n == 0; return; end
if numel(acq) ~= n
    acq = NaT(n, 1);
end
for k = 1:n
    id = EphysDataset.nameIdentity(names(k), pattern);
    if id.ok
        subject(k) = id.subject;
    else
        try
            [vals, tokens, ok] = parseNameTokens(names(k), pattern);
            if ok && any(tokens == "SubjectID")
                subject(k) = vals(tokens == "SubjectID");
            end
        catch
        end
    end
    if ~isnat(acq(k))
        date(k) = string(acq(k), 'yyyy-MM-dd');
    elseif id.ok
        date(k) = string(id.recordingStart, 'yyyy-MM-dd');
    end
end
end
