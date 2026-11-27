function [files, stopped] = stopPages(obj, jobs)
%stopPages  A figure that stops before it is done (an error, cancel()): cancel its pages still on the workers, and list the files its finished pages wrote.
%   [FILES, STOPPED] = r.stopPages(JOBS), JOBS a figure's pages
%   (submitPage's JOB each, in order; runDataset, its probe page and
%   runSessionFigure), cancels the pages still drawn or waiting on the
%   workers and returns FILES, the figure files written by the pages that
%   were finished:
%     - a page drawn here: submitPage returned its JOB.out, so
%       drawExportPage returned, after exportFigure had written and closed
%       each of its files (a page that failed here threw out of submitPage
%       and has no JOB);
%     - a page taken from its worker (pageOutput; the caller then keeps its
%       OUT in JOB.out and empties JOB.future);
%     - a page a worker finished without an error before it could be
%       canceled (its future "finished", Error empty: drawExportPage
%       returned there too).
%     - a page whose report image or PDF page failed after its figure
%       files were written (drawExportPage Partial=; keepStray noted them:
%       takeStrayFiles, here or on a worker).
%   A page canceled, or failed, on its worker is not listed: it may have
%   stopped while it wrote a file. STOPPED counts the pages that were being
%   drawn on a worker when they were canceled (each may have left a file
%   partly written: the caller says so in the Log). Files kept from an
%   earlier run (Export.Overwrite off) are not a page's writing and are not
%   listed; FILES are also noted in WrittenFiles. Never throws: a future
%   that cannot be read or canceled is passed over.
%
%   The figure's Results row ("error", or "canceled") lists FILES, so the
%   run record and the lab database's record (LabCapture.analysisRun) name
%   every file the run wrote.
%
%   See also EphysAnalysisRunner.submitPage, EphysAnalysisRunner.pageOutput,
%   EphysAnalysisRunner.runDataset, EphysAnalysisRunner.runSessionFigure.

files = string.empty(1, 0);
stopped = 0;
for j = 1:numel(jobs)
    job = jobs{j};
    if ~isstruct(job) || ~isfield(job, 'future'); continue; end
    if isempty(job.future)   % drawn here, or taken from its worker: finished
        if isfield(job, 'out') && isstruct(job.out) && isfield(job.out, 'files')
            files = [files reshape(string(job.out.files), 1, [])]; %#ok<AGROW>
        end
        continue
    end
    f = job.future;
    try
        wasRunning = string(f.State) == "running";
        if string(f.State) ~= "finished"; cancel(f); end
        if string(f.State) == "finished" && isempty(f.Error)   % finished before it could be canceled
            out = fetchOutputs(f);
            files = [files reshape(string(out.files), 1, [])]; %#ok<AGROW>
        elseif wasRunning
            stopped = stopped + 1;   % stopped while it drew: it may have left a file partly written
        end
    catch
    end
end
files = [files obj.takeStrayFiles()];
files = unique(files(files ~= ""), 'stable');
obj.noteWritten(files);
end
