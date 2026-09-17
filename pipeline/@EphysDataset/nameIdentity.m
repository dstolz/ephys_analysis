function id = nameIdentity(name, pattern)
%nameIdentity  Subject and recording start encoded in a dataset name.
%   ID = EphysDataset.nameIdentity(NAME, PATTERN) parses NAME with
%   parseNameTokens(NAME, PATTERN) and returns what labels that recording's
%   units, as a struct:
%     subject         the SubjectID token ("" when not ok)
%     recordingStart  datetime from the Date + Time tokens (NaT when not ok)
%     labelSuffix     "<subject>_<yyMMdd>T<HHmm>", the tail of every unit label
%     ok              true when all three could be derived
%     reason          "" | "pattern" | "nomatch" | "subject" | "datetime"
%     message         why not (for error messages and plan notes)
%   It never throws. With NAME = "" only the pattern is checked: reason is
%   "pattern" when PATTERN cannot label units, else "nomatch".
%
%   PATTERN needs a SubjectID token and Date + Time tokens with datetime
%   formats that together give year, month, day, hour and minute, e.g. the
%   default "{SubjectID}_{Date:yyMMdd}_{Time:HHmmss}". A lab-wide subject
%   prefix is written as literal text so it is not part of the subject:
%   "SUBJ-ID-{SubjectID}_{Date:yyMMdd}_{Time:HHmmss}" gives "SUBJ-ID-1255_260908_103949"
%   subject "1255", recordingStart 2026-09-08 10:39:49, labelSuffix
%   "1255_260908T1039". Two-digit years are 2000-2099. The subject may not
%   contain "_" or white space ("_" separates the parts of a unit label).
%
%   See also EphysDataset.unitIdentity, parseNameTokens, EphysDataset.readPhyUnits.

arguments
    name (1,1) string
    pattern (1,1) string
end

id = struct('subject', "", 'recordingStart', NaT('Format', 'yyyy-MM-dd HH:mm:ss'), ...
    'labelSuffix', "", 'ok', false, 'reason', "", 'message', "");

try
    [values, names, ok, formats] = parseNameTokens(name, pattern);
catch ME
    id = fail(id, "pattern", string(ME.message));
    return
end
need = ["SubjectID" "Date" "Time"];
missing = need(~ismember(need, names));
if ~isempty(missing)
    id = fail(id, "pattern", sprintf( ...
        'Name pattern "%s" has no %s token, so unit labels cannot carry the subject and recording time.', ...
        pattern, strjoin(missing, " / ")));
    return
end
fmt = formats(names == "Date") + formats(names == "Time");
if formats(names == "Date") == "" || formats(names == "Time") == "" || ...
        ~all(arrayfun(@(c) contains(fmt, c), ["y" "M" "d" "H" "m"]))
    id = fail(id, "pattern", sprintf( ...
        ['Name pattern "%s": Date and Time need datetime formats giving year, month, day, ' ...
         'hour (H) and minute, e.g. {Date:yyMMdd} and {Time:HHmmss}.'], pattern));
    return
end
if ~ok
    id = fail(id, "nomatch", sprintf('Name "%s" does not match the name pattern "%s".', name, pattern));
    return
end

subject = values(names == "SubjectID");
if subject == "" || contains(subject, "_") || ~isempty(regexp(subject, '\s', 'once'))
    id = fail(id, "subject", sprintf( ...
        'Name "%s": subject "%s" is empty or contains "_" or white space.', name, subject));
    return
end

txt = values(names == "Date") + values(names == "Time");
try
    t = datetime(txt, 'InputFormat', char(fmt), 'PivotYear', 2000);
catch
    t = NaT;
end
if isnat(t) || string(char(t, char(fmt))) ~= txt
    id = fail(id, "datetime", sprintf('Name "%s": "%s" is not a valid %s date and time.', name, txt, fmt));
    return
end
t.Format = 'yyyy-MM-dd HH:mm:ss';

id.subject        = subject;
id.recordingStart = t;
id.labelSuffix    = subject + "_" + string(char(t, 'yyMMdd')) + "T" + string(char(t, 'HHmm'));
id.ok             = true;
end


function id = fail(id, reason, message)
id.reason  = reason;
id.message = string(message);
end
