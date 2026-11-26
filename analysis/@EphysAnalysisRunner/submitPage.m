function job = submitPage(obj, F, spec, onPool, page)
%submitPage  Draw one page now, or send it to a process worker (pageOutput collects it).
%   JOB = r.submitPage(F, SPEC, ONPOOL, PAGE) draws F (one observation of
%   the figure SPEC) with drawExportPage: here when ONPOOL is false (JOB.out
%   is its result), else on the open process pool (parfeval; JOB.future).
%   PAGE holds drawExportPage's options (Export, Base, Formats, Dpi,
%   BatchYLim, Images, Pages); the report's options and page folder are
%   added. Every page, here or on a worker, is drawn in the user's design
%   and remembered plot rules as PageLooks holds them (Design=, UserRules=:
%   taken when the run started, holdPageLooks), never as they are when the
%   page is drawn: a design chosen or a look remembered while the run goes
%   (the analysis app's window stays usable) is the next run's. A worker
%   reads no preferences of its own. With no looks held (submitPage called
%   by itself) the page takes them as they are now (pageLooksNow).
%
%   See also EphysAnalysisRunner.pageOutput, EphysAnalysisRunner.usePagePool,
%   EphysAnalysisRunner.holdPageLooks.

args = namedArgs(page);
if page.Images || page.Pages
    R = obj.Report;
    args = [args {'Report', struct('options', R.options, 'pageFolder', R.pageFolder)}];
end
L = obj.PageLooks;
if isempty(L); L = EphysAnalysisRunner.pageLooksNow(); end
args = [args {'Design', L.design, 'UserRules', L.rules}];
job = struct('future', [], 'out', []);
if ~onPool
    job.out = drawExportPage(F, spec, args{:});
    return
end
job.future = parfeval(gcp('nocreate'), @drawExportPage, 1, F, spec, args{:});
end


function args = namedArgs(s)
%namedArgs  A struct's fields as name, value, name, value, ...
f = fieldnames(s);
args = cell(1, 2 * numel(f));
args(1:2:end) = f;
args(2:2:end) = struct2cell(s);
end
