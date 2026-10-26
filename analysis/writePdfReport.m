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
%   writePdfReport(..., ProgressFcn=F) calls F(done, total, message)
%   before each page it draws ("Writing the report: page 3/12") and before
%   the pages are joined.
%
%   Errors: writePdfReport:NoPages, writePdfReport:Merge.
%
%   See also writeHtmlReport, newAnalysisReport, reportPdfPage, exportFigure.

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
    parts = [parts; page(L, D.name + starWord(D), d)]; %#ok<AGROW>
    for e = D.entries(status == "done")
        if isempty(e.pages)
            error('writePdfReport:NoPages', ...
                'Figure %s of %s holds no PDF pages: start the report with Format "pdf" or "both".', e.plot, D.name);
        end
        parts = [parts; e.pages(:)]; %#ok<AGROW>
    end
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
