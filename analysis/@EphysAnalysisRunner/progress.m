function progress(obj, fraction, message)
%progress  Report progress; throw EphysAnalysisRunner:Canceled after cancel().
%   Calls ProgressFcn(fraction, message) when set. The ProgressFcn may call
%   cancel() itself (e.g. from a cancelable progress dialog).
if ~isempty(obj.ProgressFcn)
    obj.ProgressFcn(fraction, string(message));
end
if obj.CancelRequested
    error('EphysAnalysisRunner:Canceled', 'The analysis run was canceled.');
end
end
