function tf = usePagePool(obj, n)
%usePagePool  Whether a figure's N pages go to the process workers that draw pages (Workers).
%   TF = r.usePagePool(N) counts N pages toward the run's pages and is true
%   when they are drawn on process workers: Workers is at least 1, N is at
%   least 2 and the Parallel Computing Toolbox is there; and a process pool
%   is open (gcp), or the run has come to MinPoolPages pages, when one of
%   Workers workers is started (parpool "Processes"; it stays open for the
%   next runs until its idle timeout). A pool that cannot start is logged
%   and the run draws its pages here; a thread pool is not used (a thread
%   worker cannot draw a figure). On a worker itself TF is false.
%
%   See also EphysAnalysisRunner.submitPage, drawExportPage.

obj.PagesSeen = obj.PagesSeen + n;
tf = false;
if obj.Workers < 1 || n < 2 || obj.PoolFailed || ~havePct(); return; end
pool = gcp('nocreate');
if ~isempty(pool)
    tf = isa(pool, 'parallel.ProcessPool');
    return
end
if obj.PagesSeen < obj.MinPoolPages; return; end
obj.log("Starting %d workers to draw the pages ...", obj.Workers);
obj.progress(obj.LastFraction, sprintf("Starting %d workers to draw the pages ...", obj.Workers));
try
    parpool("Processes", obj.Workers);
    tf = true;
catch ME
    obj.PoolFailed = true;
    obj.log("No workers (%s): the pages are drawn here.", ME.message);
end
end


function tf = havePct()
%havePct  The Parallel Computing Toolbox is installed and licensed, and this is not one of its workers.
persistent have
if isempty(have)
    have = ~isempty(ver('parallel')) && license('test', 'Distrib_Computing_Toolbox');
end
tf = have && isempty(getCurrentTask());
end
