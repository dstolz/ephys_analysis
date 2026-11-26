function out = drawExportPage(F, spec, opts)
%drawExportPage  Draw one page and write what a run needs of it: figure files, the HTML image, the PDF page.
%   OUT = drawExportPage(F, SPEC, Name=Value) draws F (figureCompute's
%   result for one observation of the figure SPEC) into a hidden page
%   (newExportFigure, renderFigure), writes it and closes it. OUT has
%     files   the figure files written (exportFigure; none without Base)
%     image   the HTML report's image (reportImage; [] without Images)
%     page    the PDF report's page file (reportPdfPage; "" without Pages)
%     title   the page's title (renderFigure's H.title)
%   The report reuses a file just written (Base): an Export PNG is the
%   HTML image (at the Export Dpi), an Export PDF the PDF page, so no page
%   is written twice. A page whose files were kept (Export.Overwrite off:
%   no Base, its files left as they are) is put in the report as drawn
%   here, never as the file on disk: an earlier run drew that, maybe with
%   other settings, and the report's caption and config are this run's.
%
%   EphysAnalysisRunner draws every page of a run through it, in this
%   MATLAB or on the process workers that draw the pages (Workers): a
%   worker reads none of the user's preferences, so the runner passes the
%   design (Design=, a PlotDesign struct) and a preference file holding the
%   user's remembered plot rules (PrefsFile=; AppPrefs reads it while the
%   page is drawn).
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
%     PrefsFile  an AppPrefs store to read the user's plot rules from ("" =
%                the store in use)
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
    opts.PrefsFile (1,1) string = ""
end

if opts.PrefsFile ~= ""
    previous = AppPrefs.storeFile();
    AppPrefs.useFile(opts.PrefsFile);
    back = onCleanup(@() AppPrefs.useFile(previous)); %#ok<NASGU>
end
fig = newExportFigure(opts.Export, F, spec);
closer = onCleanup(@() close(fig)); %#ok<NASGU> closes the page on a failure too
h = renderFigure(F, spec, fig, BatchYLim=opts.BatchYLim, Design=opts.Design);
out = struct('files', string.empty(1, 0), 'image', [], 'page', "", 'title', string(h.title));
if opts.Base ~= ""
    out.files = exportFigure(fig, opts.Base, Format=opts.Formats, Dpi=opts.Dpi);
end
have = out.files;   % what this run wrote of this page: never a kept file (an earlier run's drawing)
if opts.Images
    out.image = reportImage(fig, opts.Report, Title=h.title, Files=have);
end
if opts.Pages
    out.page = reportPdfPage(fig, opts.Report, Files=have);
end
end
