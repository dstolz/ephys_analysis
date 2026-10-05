function file = writePdfReport(report, file)
%writePdfReport  Write a report as one multi-page PDF.
%   FILE = writePdfReport(REPORT, FILE) writes a title page (the report's
%   title, when it was made, its datasets and plots), then for each dataset
%   a summary page (IncludeSummary) and the vector pages of every plot (each
%   page of a paged grid). The title and summary pages are drawn here; the
%   plots' pages are those they were added with (addReportFigure: the
%   reportPdfPage files made from the exported figures, or drawn then), so
%   no plot is drawn again. The pages are joined in that order with the
%   Apache PDFBox library MATLAB ships (PDFMergerUtility, on its Java class
%   path); no Report Generator is needed. Plots that failed are listed on
%   their dataset's summary page. A report started for HTML only keeps no
%   pages: start it with Format "pdf" or "both".
%
%   Errors: writePdfReport:NoPages, writePdfReport:Merge.
%
%   See also writeHtmlReport, newAnalysisReport, reportPdfPage, exportFigure.

arguments
    report (1,1) struct
    file (1,1) string
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
    lines(end+1) = sprintf("%d. %s (%d plot(s))", d, D.name, numel(D.entries)); %#ok<AGROW>
end
parts = page(lines, report.title, 0);

for d = 1:numel(report.datasets)
    D = report.datasets(d);
    L = strings(0, 1);
    if ~isempty(D.summary)
        S = D.summary;
        L = [L; tableLines(S.recording); ""]; %#ok<AGROW>
        if height(S.trials) > 0; L = [L; "Trials"; tableLines(S.trials); ""]; end %#ok<AGROW>
        if height(S.units) > 0; L = [L; "Units"; tableLines(S.units); ""]; end %#ok<AGROW>
    end
    status = string({D.entries.status});
    for e = D.entries(status ~= "done")
        L(end+1) = e.plot + ": " + e.status + " - " + e.message; %#ok<AGROW>
    end
    parts = [parts; page(L, D.name, d)]; %#ok<AGROW>
    for e = D.entries(status == "done")
        if isempty(e.pages)
            error('writePdfReport:NoPages', ...
                'Plot %s of %s holds no PDF pages: start the report with Format "pdf" or "both".', e.plot, D.name);
        end
        parts = [parts; e.pages(:)]; %#ok<AGROW>
    end
end
mergePages(parts, file);

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


function removeFolder(folder)
if isfolder(folder)
    try
        rmdir(folder, 's');
    catch
    end
end
end
