function file = writePdfReport(report, file, opts)
%writePdfReport  Write a report as one multi-page PDF.
%   FILE = writePdfReport(REPORT, FILE) writes a title page (the report's
%   title, when it was made, its datasets and figures), then for each dataset
%   (and each addReportSection section, such as "Across sessions") a
%   summary page (IncludeSummary: a dataset's recording, trials and units;
%   a section's tables, e.g. "Sessions") and the vector pages of every figure
%   (a page per observation). The title and summary pages are drawn here; the
%   figures' pages are those they were added with (addReportFigure: the
%   reportPdfPage files made from the pages as they were drawn), so
%   no figure is drawn again. The pages are joined in that order with the
%   Apache PDFBox library MATLAB ships (PDFMergerUtility, on its Java class
%   path); no Report Generator is needed. Figures that failed are listed on
%   their dataset's summary page. A starred dataset (its starred field:
%   DatasetFavorites) is named "<name> (starred)" on the title page and its
%   summary page. A report started for HTML only keeps no pages: start it
%   with Format "pdf" or "both".
%
%   Report.Order (REPORT.options.Order) sets the order of a section's
%   figure pages: "figure" (the default) a figure at a time, all its
%   observations' pages together; "unit" an observation at a time
%   (reportGroups): each unit's, channel's or the dataset's pages of every
%   figure, in the figures' order, the summary page listing each
%   observation's pages ("Pages by observation:  u12  ch 5  300 µm: pages
%   4-6 (rp, wf)"). A figure added without its pages' observations (a
%   session figure) follows the groups whole.
%
%   Report.FiguresPerPage (1, the default: every figure page a page of its
%   own, at the size it was drawn) puts up to that many figure pages on one
%   sheet of Report.PageSize ("letter" | "a4"), Report.PageOrientation
%   ("auto" | "portrait" | "landscape"). Each section's pages are grouped
%   by reportSheets -- in order, a figure's pages (by unit: an
%   observation's) kept on one sheet when they fit what is left of it,
%   else started on the next; a figure of more pages than a sheet holds
%   spread evenly over as few sheets as hold it -- and each sheet is laid
%   out by reportPageLayout: the rows and orientation that draw its pages
%   largest, every page at one scale and never enlarged. The pages stay
%   vector (imported whole, PDFBox LayerUtility). The summary page's
%   "Pages by observation" then counts sheets.
%
%   writePdfReport(..., ProgressFcn=F) calls F(done, total, message)
%   before each page it draws ("Writing the report: page 3/12") and before
%   the pages are joined.
%
%   Errors: writePdfReport:NoPages, writePdfReport:Tile, writePdfReport:Merge.
%
%   See also writeHtmlReport, newAnalysisReport, reportPdfPage, exportFigure,
%   reportPageLayout.

arguments
    report (1,1) struct
    file (1,1) string
    opts.ProgressFcn = []
end

folder = fileparts(file);
if strlength(folder) > 0 && ~isfolder(folder); mkdir(folder); end
if isfile(file); delete(file); end
tmp = string(tempname);   % the title and summary pages
mkdir(tmp);
removeTmp = onCleanup(@() removeFolder(tmp)); %#ok<NASGU>

lines = [report.title; ""; "Generated " + report.created];
if isfield(report, 'provenance') && isstruct(report.provenance)
    lines = [lines; "ephys_analysis " + report.provenance.code; ...
        "MATLAB " + report.provenance.matlab + " on " + report.provenance.host];
end
lines(end+1) = "";
for d = 1:numel(report.datasets)
    D = report.datasets(d);
    lines(end+1) = sprintf("%d. %s (%d figure(s))", d, D.name + starWord(D), numel(D.entries)) + tagsWord(D); %#ok<AGROW>
end
byUnit = isfield(report.options, 'Order') && report.options.Order == "unit";
perSheet = 1;
if isfield(report.options, 'FiguresPerPage'); perSheet = max(1, round(report.options.FiguresPerPage)); end
nPages = numel(report.datasets) + 1;   % the title page and a summary page per dataset; joining them is the last step
say(0, sprintf("Writing the report: page 1/%d", nPages));
parts = page(lines, report.title, 0);

for d = 1:numel(report.datasets)
    say(d, sprintf("Writing the report: page %d/%d", d + 1, nPages));
    D = report.datasets(d);
    L = strings(0, 1);
    if ~isempty(D.summary)
        S = D.summary;
        for f = string(fieldnames(S)).'
            T = S.(f);
            if f == "recording"
                L = [L; tableLines(T); ""]; %#ok<AGROW>
            elseif ismember(f, ["lines" "topRates"])   % a dataset's page keeps to its recording, trials and units
                continue
            elseif istable(T) && height(T) > 0
                L = [L; summaryLabel(f); tableLines(T); ""]; %#ok<AGROW>
            end
        end
    end
    status = string({D.entries.status});
    for e = D.entries(status ~= "done")
        L(end+1) = e.plot + ": " + e.status + " - " + e.message; %#ok<AGROW>
    end
    for e = D.entries(status == "done")
        if isempty(e.pages)
            error('writePdfReport:NoPages', ...
                'Figure %s of %s holds no PDF pages: start the report with Format "pdf" or "both".', e.plot, D.name);
        end
    end
    at = numel(parts) + 1;   % this section's summary page; its figures' pages (or sheets) follow
    figPages = strings(0, 1);
    counts = zeros(1, 0);   % the pages of each block: an observation's (by unit), a figure's
    rest = find(status == "done");
    G = [];
    if byUnit
        [G, rest] = reportGroups(D);
        rest = rest(status(rest) == "done");
        for g = 1:numel(G)
            n0 = numel(figPages);
            for q = 1:numel(G(g).entry)
                e = D.entries(G(g).entry(q));
                figPages = [figPages; reshape(e.pages(G(g).pages{q}), [], 1)]; %#ok<AGROW>
            end
            counts(end+1) = numel(figPages) - n0; %#ok<AGROW>
        end
    end
    for k = rest
        figPages = [figPages; reshape(D.entries(k).pages, [], 1)]; %#ok<AGROW>
        counts(end+1) = numel(D.entries(k).pages); %#ok<AGROW>
    end
    sheets = reportSheets(counts, perSheet);
    sheetOf = zeros(numel(figPages), 1);   % each figure page's page of the section, after its summary page
    for j = 1:numel(sheets); sheetOf(sheets{j}) = j; end
    if ~isempty(G); L(end+1) = "Pages by observation:"; end
    last = 0;
    for g = 1:numel(G)
        span = last + (1:counts(g));
        last = last + counts(g);
        if isempty(span); continue; end
        L(end+1) = sprintf("  %s: %s (%s)", G(g).label, pageRange(at + sheetOf(span(1)), at + sheetOf(span(end))), ...
            strjoin(string({D.entries(G(g).entry).plot}), ", ")); %#ok<AGROW>
    end
    if perSheet > 1
        tiled = strings(numel(sheets), 1);
        for j = 1:numel(sheets)
            tiled(j) = tileSheet(figPages(sheets{j}), fullfile(tmp, "sheet" + d + "_" + j + ".pdf"), report.options);
        end
        figPages = tiled;
    end
    parts = [parts; page(L, D.name + starWord(D), d); figPages]; %#ok<AGROW>
end
say(nPages, sprintf("Writing the report: joining %d page file(s)", numel(parts)));
mergePages(parts, file);

    function say(done, msg)
        %say  ProgressFcn(done, of the pages and the joining, MSG).
        if ~isempty(opts.ProgressFcn)
            opts.ProgressFcn(done, nPages + 1, msg);
        end
    end

    function f = page(txt, heading, k)
        %page  One page of text, drawn and written as a one-page PDF.
        fig = newExportFigure(report.export);
        c = onCleanup(@() close(fig));
        ax = axes(fig, 'Position', [0.06 0.05 0.9 0.9], 'Visible', 'off');
        text(ax, 0, 1, heading, 'FontSize', 14, 'FontWeight', 'bold', 'VerticalAlignment', 'top', 'Interpreter', 'none');
        body = txt;
        if ~isempty(body) && body(1) == heading; body = body(2:end); end
        text(ax, 0, 0.92, strjoin(body, newline), 'FontName', 'FixedWidth', 'FontSize', 7, ...
            'VerticalAlignment', 'top', 'Interpreter', 'none');
        xlim(ax, [0 1]); ylim(ax, [0 1]);
        f = exportFigure(fig, fullfile(tmp, "page" + k), Format="pdf");
    end
end


function s = pageRange(a, b)
%pageRange  "page 5" or "pages 5-9".
if a == b
    s = "page " + a;
else
    s = "pages " + a + "-" + b;
end
end


function s = summaryLabel(f)
%summaryLabel  The heading of a summary table: a known field's label, else its name.
switch f
    case "trials",   s = "Trials";
    case "units",    s = "Units";
    case "sessions", s = "Sessions";
    otherwise,       s = f;
end
end


function L = tableLines(T)
%tableLines  A table as plain text lines.
txt = formattedDisplayText(T, 'SuppressMarkup', true);
L = splitlines(string(txt));
L = L(strlength(strtrim(L)) > 0);
end


function mergePages(parts, file)
%mergePages  Join the one-page (or several-page) PDFs PARTS, in order, into FILE (PDFBox).
try
    m = org.apache.pdfbox.multipdf.PDFMergerUtility();
    for f = reshape(parts, 1, [])
        m.addSource(java.io.File(char(f)));
    end
    m.setDestinationFileName(char(file));
    m.mergeDocuments([]);   % [] = in memory
catch ME
    error('writePdfReport:Merge', 'The report''s %d page file(s) could not be joined into %s with PDFBox: %s', ...
        numel(parts), file, ME.message);
end
end


function file = tileSheet(pages, file, P)
%tileSheet  The one-page PDFs PAGES on one sheet, as the PDF FILE (Report.FiguresPerPage).
%   reportPageLayout places them (P.PageSize, P.PageOrientation); each is
%   imported whole as a form (PDFBox LayerUtility) and drawn scaled into its
%   place, so it stays vector and its text stays text.
pt = 72 / 2.54;   % PDF points a cm
target = org.apache.pdfbox.pdmodel.PDDocument();
src = cell(1, numel(pages));
try
    sizes = zeros(numel(pages), 2);
    for i = 1:numel(pages)
        src{i} = org.apache.pdfbox.pdmodel.PDDocument.load(java.io.File(char(pages(i))));
        p = src{i}.getPage(0);
        box = p.getCropBox();
        sizes(i, :) = [box.getWidth() box.getHeight()] / pt;
        if mod(p.getRotation(), 180) == 90; sizes(i, :) = fliplr(sizes(i, :)); end
    end
    L = reportPageLayout(sizes, PageSize=P.PageSize, Orientation=P.PageOrientation);
    sheet = org.apache.pdfbox.pdmodel.PDPage(org.apache.pdfbox.pdmodel.common.PDRectangle( ...
        single(L.sheetCm(1) * pt), single(L.sheetCm(2) * pt)));
    target.addPage(sheet);
    layer = org.apache.pdfbox.multipdf.LayerUtility(target);
    cs = org.apache.pdfbox.pdmodel.PDPageContentStream(target, sheet);
    for i = 1:numel(pages)
        form = layer.importPageAsForm(src{i}, 0);
        cs.saveGraphicsState();
        cs.transform(org.apache.pdfbox.util.Matrix(single(L.scale), single(0), single(0), single(L.scale), ...
            single(L.pos(i, 1) * pt), single(L.pos(i, 2) * pt)));
        cs.drawForm(form);
        cs.restoreGraphicsState();
    end
    cs.close();
    target.save(java.io.File(char(file)));
catch ME
    closeDocs([{target} src]);
    error('writePdfReport:Tile', 'The %d figure page(s) could not be put on one sheet (%s) with PDFBox: %s', ...
        numel(pages), strjoin(pages, ", "), ME.message);
end
closeDocs([{target} src]);
end


function closeDocs(docs)
%closeDocs  Close each PDFBox document of the cell DOCS ([] where none was opened).
for k = 1:numel(docs)
    if ~isempty(docs{k})
        try
            docs{k}.close();
        catch
        end
    end
end
end


function removeFolder(folder)
if isfolder(folder)
    try
        rmdir(folder, 's');
    catch
    end
end
end


function s = starWord(D)
%starWord  " (starred)" after a starred dataset's name (its starred field), else "".
s = "";
if D.starred; s = " (starred)"; end
end


function s = tagsWord(D)
%tagsWord  " [draft, pilot]" after a dataset's line (its tags field), else "".
s = "";
if ~isempty(D.tags); s = " [" + TagSet.toText(D.tags, TagSet.DisplayDelimiter) + "]"; end
end
