function file = writePdfReport(report, file, opts)
%writePdfReport  Write a report as one multi-page PDF.
%   FILE = writePdfReport(REPORT, FILE) writes a title page (the report's
%   title, when it was made, its datasets and plots), then for each dataset
%   a summary page (IncludeSummary) and every plot drawn again with
%   renderPlot as vector pages (every page of a paged grid), appended with
%   exportgraphics(..., Append=true). No Report Generator is needed. Plots
%   that failed are listed on their dataset's summary page. A report built
%   for HTML only keeps no results to draw: build it with Format "pdf" or
%   "both".
%
%   Options: Dpi (only used for the raster parts exportgraphics may embed).
%
%   See also writeHtmlReport, newAnalysisReport, exportFigure.

arguments
    report (1,1) struct
    file (1,1) string
    opts.Dpi (1,1) double = NaN %#ok<INUSA>
end

folder = fileparts(file);
if strlength(folder) > 0 && ~isfolder(folder); mkdir(folder); end
if isfile(file); delete(file); end
first = true;
ws = warning('off', 'MATLAB:print:ContentTypeImageSuggested');
restore = onCleanup(@() warning(ws));

lines = [report.title; ""; "Generated " + report.created; ""];
for d = 1:numel(report.datasets)
    D = report.datasets(d);
    lines(end+1) = sprintf("%d. %s (%d plot(s))", d, D.name, numel(D.entries)); %#ok<AGROW>
end
page(lines, report.title);

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
    page(L, D.name);
    for e = D.entries(status == "done")
        if isempty(e.R)
            error('writePdfReport:NoResult', ...
                'Plot %s of %s holds no result to draw: build the report with Format "pdf" or "both".', e.plot, D.name);
        end
        for p = 1:plotPageCount(e.R, e.spec)
            fig = newExportFigure(report.export);
            closer = onCleanup(@() close(fig));
            renderPlot(e.R, e.spec, fig, Page=p);
            exportgraphics(fig, file, 'ContentType', 'vector', 'Append', ~first);
            first = false;
            clear closer
        end
    end
end

    function page(txt, heading)
        fig = newExportFigure(report.export);
        c = onCleanup(@() close(fig));
        ax = axes(fig, 'Position', [0.06 0.05 0.9 0.9], 'Visible', 'off');
        text(ax, 0, 1, heading, 'FontSize', 14, 'FontWeight', 'bold', 'VerticalAlignment', 'top', 'Interpreter', 'none');
        body = txt;
        if ~isempty(body) && body(1) == heading; body = body(2:end); end
        text(ax, 0, 0.92, strjoin(body, newline), 'FontName', 'FixedWidth', 'FontSize', 7, ...
            'VerticalAlignment', 'top', 'Interpreter', 'none');
        xlim(ax, [0 1]); ylim(ax, [0 1]);
        exportgraphics(fig, file, 'ContentType', 'vector', 'Append', ~first);
        first = false;
    end
end


function L = tableLines(T)
%tableLines  A table as plain text lines.
txt = formattedDisplayText(T, 'SuppressMarkup', true);
L = splitlines(string(txt));
L = L(strlength(strtrim(L)) > 0);
end
