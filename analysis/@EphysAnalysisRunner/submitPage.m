function job = submitPage(obj, F, spec, onPool, page)
%submitPage  Draw one page now, or send it to a process worker (pageOutput collects it).
%   JOB = r.submitPage(F, SPEC, ONPOOL, PAGE) draws F (one observation of
%   the figure SPEC) with drawExportPage: here when ONPOOL is false (JOB.out
%   is its result), else on the open process pool (parfeval; JOB.future).
%   PAGE holds drawExportPage's options (Export, Base, Formats, Dpi, Kept,
%   BatchYLim, Images, Pages); the report's options and page folder are
%   added. A worker gets the user's design and remembered plot rules as
%   they are when the run sends its first page (pageLooks): it reads no
%   preferences of its own.
%
%   See also EphysAnalysisRunner.pageOutput, EphysAnalysisRunner.usePagePool.

args = namedArgs(page);
if page.Images || page.Pages
    R = obj.Report;
    args = [args {'Report', struct('options', R.options, 'pageFolder', R.pageFolder)}];
end
job = struct('future', [], 'out', []);
if ~onPool
    job.out = drawExportPage(F, spec, args{:});
    return
end
L = pageLooks(obj);
args = [args {'Design', L.design, 'PrefsFile', L.file}];
job.future = parfeval(gcp('nocreate'), @drawExportPage, 1, F, spec, args{:});
end


function args = namedArgs(s)
%namedArgs  A struct's fields as name, value, name, value, ...
f = fieldnames(s);
args = cell(1, 2 * numel(f));
args(1:2:end) = f;
args(2:2:end) = struct2cell(s);
end


function L = pageLooks(obj)
%pageLooks  The user's design and a preference file with their remembered plot rules, for the workers (once per run).
if ~isempty(obj.PageLooks); L = obj.PageLooks; return; end
file = string(tempname) + "_page_looks.mat";
prefs = struct();
g = char(PlotAesthetics.PrefGroup);
if AppPrefs.ispref(g); prefs.(g) = AppPrefs.getpref(g); end
save(file, 'prefs');
L = struct('design', PlotDesign.current(), 'file', file, 'cleanup', onCleanup(@() deleteQuiet(file)));
obj.PageLooks = L;
end


function deleteQuiet(file)
if isfile(file); delete(file); end
end
