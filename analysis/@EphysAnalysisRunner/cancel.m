function cancel(obj)
%cancel  Ask a running run() to stop before its next plot.
%   The plot being drawn finishes; the next progress() call throws
%   EphysAnalysisRunner:Canceled and run() marks what is left "canceled".
obj.CancelRequested = true;
end
