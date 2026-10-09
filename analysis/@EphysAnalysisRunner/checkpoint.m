function checkpoint(obj)
%checkpoint  A place computePlot can be stopped: PollFcn runs, then a cancel() throws.
%   Does nothing while PollFcn is empty (a run, a script), so only the
%   app's preview, which sets PollFcn to let its Cancel button act, can
%   stop a plot part-way. Throws EphysAnalysisRunner:Canceled after cancel().
%
%   See also EphysAnalysisRunner.cancel, EphysAnalysisRunner.progress.
if isempty(obj.PollFcn); return; end
obj.PollFcn();
if obj.CancelRequested
    error('EphysAnalysisRunner:Canceled', 'The analysis run was canceled.');
end
end
