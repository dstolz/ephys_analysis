function progress(obj, fraction, message)
%progress  Report progress; throw EphysAnalysisRunner:Cancelled after cancel().
%   Calls ProgressFcn(fraction, message) when set. The ProgressFcn may call
%   cancel() itself (e.g. from a cancelable progress dialog).
if ~isempty(obj.ProgressFcn)
    obj.ProgressFcn(fraction, string(message));
end
if obj.CancelRequested
    error('EphysAnalysisRunner:Cancelled', 'The analysis run was cancelled.');
end
end
