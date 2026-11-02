function reportFailure(obj, title, action, subject, cause, tryText, opts)
%reportFailure  Tell the user an action failed, in the apps' one wording, and keep it in a log.
%   obj.reportFailure(TITLE, ACTION, SUBJECT, CAUSE, TRYTEXT) shows an alert
%   titled TITLE that reads
%       Could not <ACTION> on <SUBJECT>.
%       <message of CAUSE>
%       Try: <TRYTEXT>.
%       Details: Run tab > Log
%   (AppDialog.alertFailure), writes the same failure to the Run tab's log,
%   and, when CAUSE is an MException, keeps it for Help > Report an issue
%   (LastError). SUBJECT is the dataset or file (blank: none); CAUSE is an
%   MException or the message text; TRYTEXT is the next step in plain words.
%   Where="copy" puts the failure in the Copy tab's log instead, and the
%   alert says so ("Details: Copy tab > Log").
arguments
    obj (1,1) EphysPipelineApp
    title (1,1) string
    action (1,1) string
    subject (1,1) string
    cause
    tryText (1,1) string = ""
    opts.Where (1,1) string {mustBeMember(opts.Where, ["run" "copy"])} = "run"
end
if isa(cause, 'MException')
    msg = string(cause.message);
    obj.LastError = cause;
    obj.LastErrorTime = datetime('now');
else
    msg = string(cause);
end
where = "";
if strip(subject) ~= ""; where = " on " + subject; end
line = "ERROR: could not " + action + where + ": " + strrep(msg, newline, " ");
if opts.Where == "copy"
    obj.copyLog(line);
    details = "Copy tab > Log";
else
    obj.runLog("%s", line);
    details = "Run tab > Log";
end
AppDialog.alertFailure(obj.Fig, title, action, subject, msg, Try=tryText, Details=details);
end
