function out = drawExportPage(F, spec, opts)
%drawExportPage  Draw one page and write what a run needs of it: figure files, the HTML image, the PDF page.
%   OUT = drawExportPage(F, SPEC, Name=Value) draws F (figureCompute's
%   result for one observation of the figure SPEC) into a hidden page
%   (newExportFigure, renderFigure), writes it and closes it. OUT has
%     files   the figure files written (exportFigure; none without Base)
%     image   the HTML report's image (reportImage; [] without Images)
%     page    the PDF report's page file (reportPdfPage; "" without Pages)
%     title   the page's title (renderFigure's H.title)
%     error   [] ; with Partial=true, the error of a report image or PDF
%             page that failed after the figure files were written (FILES:
%             those, finished), instead of throwing it
%   The report reuses a file just written (Base): an Export PNG is the
%   HTML image (at the Export Dpi), an Export PDF the PDF page, so no page
%   is written twice. A page whose files were kept (Export.Overwrite off:
%   no Base, its files left as they are) is put in the report as drawn
%   here, never as the file on disk: an earlier run drew that, maybe with
%   other settings, and the report's caption and config are this run's.
%
%   EphysAnalysisRunner draws every page of a run through it, in this
%   MATLAB or on the process workers that draw the pages (Workers), and
%   passes the user's design (Design=, a PlotDesign struct) and remembered
%   plot rules (UserRules=, the PlotAesthetics preference group as a
%   struct) as they were when the run started: every page, here or on a
%   worker, is drawn in them, though the design or a remembered look may
%   change while the run goes (the analysis app's window stays usable),
%   and a worker reads none of the user's preferences.
%
%   Options
%     Export     the config's Export section (newExportFigure: the page size)
%     Base       the figure files' path without extension ("" = none written)
%     Formats    their formats (exportFigure Format=), Dpi their PNG dpi
%     BatchYLim  renderFigure's BatchYLim=
%     Report     the report (newAnalysisReport; its options and pageFolder
%                are all that is read)
%     Images     make the HTML report's image; Pages: the PDF report's page
%     Design     renderFigure's Design= ("" = the user's design)
%     UserRules  renderFigure's UserRules= ([] = the user's remembered plot
%                rules, read from the preferences while the page is drawn)
%     Partial    true: a report image or PDF page that fails after
%                exportFigure has written the page's files does not throw:
%                OUT.error holds the error and OUT.files the files written
%                (EphysAnalysisRunner.submitPage and pageOutput then name
%                them in the figure's row before the error goes on); false
%                (the default): it throws
%     PrefsFile  an AppPrefs store to read the user's plot rules from ("" =
%                the store in use): the whole store is switched while the
%                page is drawn, so pass it only where nothing else reads
%                preferences meanwhile (a worker); UserRules does not
%                touch the store
%
%   See also EphysAnalysisRunner.runDataset, exportFigure, reportImage,
%   reportPdfPage.

arguments
    F (1,1) struct
    spec (1,1) struct
    opts.Export = struct()
    opts.Base (1,1) string = ""
    opts.Formats (1,:) string = "png"
    opts.Dpi (1,1) double {mustBePositive} = 150
    opts.BatchYLim = []
    opts.Report = []
    opts.Images (1,1) logical = false
    opts.Pages (1,1) logical = false
    opts.Design = ""
    opts.UserRules = []
    opts.Partial (1,1) logical = false
    opts.PrefsFile (1,1) string = ""
end

if opts.PrefsFile ~= ""
    previous = AppPrefs.storeFile();
    AppPrefs.useFile(opts.PrefsFile);
    back = onCleanup(@() AppPrefs.useFile(previous)); %#ok<NASGU>
end
fig = newExportFigure(opts.Export, F, spec);
closer = onCleanup(@() close(fig)); %#ok<NASGU> closes the page on a failure too
h = renderFigure(F, spec, fig, BatchYLim=opts.BatchYLim, Design=opts.Design, UserRules=opts.UserRules);
out = struct('files', string.empty(1, 0), 'image', [], 'page', "", 'title', string(h.title), 'error', []);
if opts.Base ~= ""
    out.files = exportFigure(fig, opts.Base, Format=opts.Formats, Dpi=opts.Dpi);
end
have = out.files;   % what this run wrote of this page: never a kept file (an earlier run's drawing)
try
    if opts.Images
        out.image = reportImage(fig, opts.Report, Title=h.title, Files=have);
    end
    if opts.Pages
        out.page = reportPdfPage(fig, opts.Report, Files=have);
    end
catch ME
    if ~opts.Partial || isempty(have); rethrow(ME); end
    out.image = [];   % the page's files are written and finished: the caller names them, then throws ME
    out.page = "";
    out.error = ME;
end
end
