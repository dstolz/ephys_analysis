function out = pageOutput(obj, job, fraction, message)
%pageOutput  The result of a page submitPage drew or sent to a worker (drawExportPage's OUT).
%   OUT = r.pageOutput(JOB, FRACTION, MESSAGE) returns JOB.out, or waits
%   for JOB.future, reporting progress (FRACTION, MESSAGE) every quarter
%   second, so cancel() stops the wait (EphysAnalysisRunner:Canceled). A
%   page that failed on its worker rethrows the worker's error.
%
%   See also EphysAnalysisRunner.submitPage, EphysAnalysisRunner.cancelPages.

if isempty(job.future)
    out = job.out;
    return
end
f = job.future;
while ~wait(f, 'finished', 0.25)
    obj.progress(fraction, message);
end
if ~isempty(f.Error)
    ME = f.Error;
    if isprop(ME, 'remotecause') && ~isempty(ME.remotecause); ME = ME.remotecause{1}; end
    throw(ME);
end
out = fetchOutputs(f);
end
