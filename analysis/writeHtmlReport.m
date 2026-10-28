function file = writeHtmlReport(report, file, opts)
%writeHtmlReport  Write a report as one self-contained HTML file.
%   FILE = writeHtmlReport(REPORT, FILE) writes the report built with
%   newAnalysisReport / addReportDataset / addReportFigure: a title, a table
%   of contents, then one section per dataset (and per addReportSection
%   section, such as "Across sessions") with its summary tables
%   (IncludeSummary: every table of the summary struct, under its label --
%   recording "Recording" (field / value rows, always shown), lines
%   "Digital lines", trials, units, topRates "Highest rates", sessions
%   "Sessions", any other by its name -- when it has rows) and every figure
%   -- its pages embedded as PNG
%   (data:image/png;base64) or inline SVG, its caption, the parameters it
%   was drawn with (IncludeParameters, folded) and links to its exported
%   files -- and the config JSON at the end (IncludeConfig, folded). A starred
%   dataset (its starred field: DatasetFavorites) has a ★ after its name,
%   in the contents and over its section. No file beside it is needed;
%   opening it needs only a browser.
%
%   The images are those each figure was added with (addReportFigure: made
%   from its pages as they were drawn, at the report's Dpi in its
%   EmbedFormat); nothing is drawn here. Every link to an exported file is
%   relative to FILE's folder (a file:// URL on another drive) and
%   percent-encoded.
%
%   Report.Order (REPORT.options.Order) sets the order within a section:
%   "figure" (the default) a figure at a time, all its observations'
%   pages together; "unit" an observation at a time (reportGroups): under
%   a heading per unit, channel or the dataset, each figure's pages of it,
%   in the figures' order -- the caption under each, the figure's file
%   links and parameters at its first appearance -- and the contents list
%   the observations. A figure not drawn, or one added without its pages'
%   observations (a session figure), follows the groups whole.
%
%   writeHtmlReport(..., ProgressFcn=F) calls F(done, total, message)
%   before each dataset's (or section's) part ("Writing the report: section
%   3/12"): a report of many figures embeds many images.
%
%   See also writePdfReport, newAnalysisReport, EphysAnalysisRunner.run.

arguments
    report (1,1) struct
    file (1,1) string
    opts.ProgressFcn = []
end

folder = fileparts(file);
if strlength(folder) > 0 && ~isfolder(folder); mkdir(folder); end

L = strings(0, 1);
L(end+1) = "<!DOCTYPE html><html><head><meta charset=""utf-8"">";
L(end+1) = "<title>" + htmlEscape(report.title) + "</title><style>" + css() + "</style></head><body>";
L(end+1) = "<h1>" + htmlEscape(report.title) + "</h1>";
nPlots = sum(arrayfun(@(d) numel(d.entries), report.datasets));
isSection = arrayfun(@(d) isfield(d, 'kind') && d.kind == "section", report.datasets);
counts = numel(report.datasets) - nnz(isSection) + " dataset(s), ";
if any(isSection); counts = counts + nnz(isSection) + " section(s), "; end
L(end+1) = "<p class=""meta"">Generated <span class=""created"">" + htmlEscape(report.created) + "</span> &middot; " ...
    + counts + nPlots + " figure(s)</p>";
if isfield(report, 'provenance') && isstruct(report.provenance)
    p = report.provenance;
    L(end+1) = "<p class=""meta provenance"">ephys_analysis " + htmlEscape(p.code) + " &middot; MATLAB " ...
        + htmlEscape(p.matlab) + " &middot; " + htmlEscape(p.host) + "</p>";
end

byUnit = isfield(report.options, 'Order') && report.options.Order == "unit";
perSheet = 1;
if isfield(report.options, 'FiguresPerPage'); perSheet = max(1, round(report.options.FiguresPerPage)); end

% --- contents ----------------------------------------------------------------------
L(end+1) = "<nav><h2>Contents</h2><ol>";
for d = 1:numel(report.datasets)
    D = report.datasets(d);
    L(end+1) = "<li><a href=""#ds" + d + """>" + htmlEscape(D.name) + "</a>" + starMark(D) + "<ul>"; %#ok<AGROW>
    rest = 1:numel(D.entries);
    if byUnit
        [G, rest] = reportGroups(D);
        for g = 1:numel(G)
            L(end+1) = "<li><a href=""#ds" + d + "-o" + g + """>" + htmlEscape(G(g).label) + "</a> (" ...
                + numel(G(g).entry) + ")</li>"; %#ok<AGROW>
        end
    end
    for k = rest
        e = D.entries(k);
        L(end+1) = "<li><a href=""#ds" + d + "-" + k + """>" + htmlEscape(e.plot) + "</a>" ...
            + ternary(e.status ~= "done", " <span class=""bad"">(" + htmlEscape(e.status) + ")</span>", "") + "</li>"; %#ok<AGROW>
    end
    L(end+1) = "</ul></li>"; %#ok<AGROW>
end
if report.options.IncludeConfig; L(end+1) = "<li><a href=""#config"">Config</a></li>"; end
L(end+1) = "</ol></nav>";

% --- datasets ------------------------------------------------------------------------
nSections = numel(report.datasets);
for d = 1:nSections
    if ~isempty(opts.ProgressFcn)
        opts.ProgressFcn(d - 1, nSections, sprintf("Writing the report: section %d/%d", d, nSections));
    end
    D = report.datasets(d);
    L(end+1) = "<section id=""ds" + d + """><h2>" + htmlEscape(D.name) + starMark(D) + tagsMark(D) + "</h2>"; %#ok<AGROW>
    if ~isempty(D.summary)
        S = D.summary;
        L(end+1) = "<div class=""tables"">"; %#ok<AGROW>
        for f = string(fieldnames(S)).'
            T = S.(f);
            if f == "recording"   % always shown, as field / value rows
                L(end+1) = "<div><h4>" + htmlEscape(summaryLabel(f)) + "</h4>" + htmlTable(T, "kv") + "</div>"; %#ok<AGROW>
            elseif istable(T) && height(T) > 0
                L(end+1) = "<div><h4>" + htmlEscape(summaryLabel(f)) + "</h4>" + htmlTable(T) + "</div>"; %#ok<AGROW>
            end
        end
        L(end+1) = "</div>"; %#ok<AGROW>
    end
    rest = 1:numel(D.entries);
    if byUnit
        [G, rest] = reportGroups(D);
        seen = false(1, numel(D.entries));   % a figure's files and parameters at its first appearance
        for g = 1:numel(G)
            L(end+1) = "<div class=""obs"" id=""ds" + d + "-o" + g + """><h3 class=""obs"">" + htmlEscape(G(g).label) + "</h3>"; %#ok<AGROW>
            nq = numel(G(g).entry);
            arts = cell(1, nq);
            sizes = zeros(nq, 2);   % each article's pages, one under the other
            for q = 1:nq
                k = G(g).entry(q);
                arts{q} = reshape(articleLines(D.entries(k), "ds" + d + "-o" + g + "-" + k, "d" + d + "p" + k, G(g).pages{q}, ...
                    ~seen(k), folder, report, ternary(nq == 1, perSheet, 1)), [], 1);   % one figure: its pages tiled
                seen(k) = true;
                z = pageSizes(D.entries(k), G(g).pages{q}, report);
                sizes(q, :) = [max(z(:, 1)) sum(z(:, 2))];
            end
            if perSheet > 1 && nq > 1
                a = tileLines(arts, sizes, perSheet, report.options);
            else
                a = vertcat(arts{:});
            end
            L(end+1:end+numel(a)) = a; %#ok<AGROW>
            L(end+1) = "</div>"; %#ok<AGROW>
        end
    end
    for k = rest
        e = D.entries(k);
        a = articleLines(e, "ds" + d + "-" + k, "d" + d + "p" + k, 1:numel(e.images), true, folder, report, perSheet);
        L(end+1:end+numel(a)) = a; %#ok<AGROW>
    end
    L(end+1) = "</section>"; %#ok<AGROW>
end
if report.options.IncludeConfig
    L(end+1) = "<section id=""config""><h2>Config</h2><details><summary>The analysis config (JSON)</summary><pre class=""config"">" ...
        + htmlEscape(jsonencode(specForJson(report.config), 'PrettyPrint', true)) + "</pre></details></section>";
end
L(end+1) = "</body></html>";

fid = fopen(file, 'w', 'n', 'UTF-8');
if fid < 0
    error('writeHtmlReport:CannotWrite', 'Cannot open %s for writing.', file);
end
fwrite(fid, char(strjoin(L, newline)), 'char');
fclose(fid);
end


function L = articleLines(e, id, svgId, pages, full, folder, report, perSheet)
%articleLines  One figure entry E as an <article> of id ID: its PAGES (indices into its images), the caption and,
%   FULL, its file links and parameters; an entry not drawn says why. SVGID prefixes its inline SVGs' ids. With
%   PERSHEET above 1 its pages are tiles, up to PERSHEET side by side (tileLines).
L = strings(0, 1);
head = e.plot;
if e.title ~= ""; head = head + ": " + e.title; end
L(end+1) = "<article id=""" + id + """><h3>" + htmlEscape(head) + ...
    " <span class=""kind"">" + htmlEscape(e.kind) + "</span></h3>";
if e.status ~= "done"
    L(end+1) = "<p class=""bad"">" + htmlEscape(e.status) + ": " + htmlEscape(e.message) + "</p></article>";
    return
end
figs = cell(1, numel(pages));
for q = 1:numel(pages)
    p = pages(q);
    im = e.images{p};
    if im.format == "svg"
        figs{q} = "<div class=""fig"">" + svgText(im.data, svgId + "i" + p + "_") + "</div>";
    else
        figs{q} = "<div class=""fig""><img alt=""" + htmlEscape(im.title) + """ src=""data:image/png;base64," ...
            + im.data + """></div>";
    end
end
if perSheet > 1 && numel(pages) > 1
    t = tileLines(figs, pageSizes(e, pages, report), perSheet, report.options);
    L(end+1:end+numel(t)) = t;
else
    L(end+1:end+numel(figs)) = [figs{:}];
end
L(end+1) = "<p class=""cap"">" + htmlEscape(e.caption) + "</p>";
if full && ~isempty(e.files)
    links = arrayfun(@(f) "<a href=""" + htmlEscape(relativePath(folder, f)) + """>" + htmlEscape(fileName(f)) + "</a>", e.files);
    L(end+1) = "<p class=""files"">Files: " + strjoin(links, ", ") + "</p>";
end
if full && report.options.IncludeParameters
    L(end+1) = "<details><summary>Parameters</summary><pre>" + ...
        htmlEscape(jsonencode(specForJson(e.spec), 'PrettyPrint', true)) + "</pre></details>";
end
L(end+1) = "</article>";
end


function L = tileLines(items, sizes, perSheet, P)
%tileLines  ITEMS (a cell, each the HTML lines of a page's <div> or of an <article>) as tiles: up to PERSHEET a
%   sheet (reportSheets, one block), each sheet's rows as reportPageLayout lays out the items' SIZES (n x 2 cm)
%   on P.PageSize / P.PageOrientation, each tile as wide, in % of the row, as its page there.
L = strings(0, 1);
for sh = reportSheets(numel(items), perSheet)
    idx = sh{1};
    lay = reportPageLayout(sizes(idx, :), PageSize=P.PageSize, Orientation=P.PageOrientation);
    gap = 100 * 0.5 / lay.contentCm(1);   % reportPageLayout's GapCm
    L(end+1) = "<div class=""sheet"">"; %#ok<AGROW>
    for r = 1:lay.rows
        L(end+1) = "<div class=""tilerow"" style=""column-gap:" + sprintf("%.2f", gap) + "%"">"; %#ok<AGROW>
        for q = reshape(find(lay.row == r), 1, [])
            t = reshape(string(items{idx(q)}), [], 1);
            L(end+1) = "<div class=""tile"" style=""width:" + sprintf("%.2f", 100 * lay.pos(q, 3) / lay.contentCm(1)) + "%"">"; %#ok<AGROW>
            L(end+1:end+numel(t)) = t; %#ok<AGROW>
            L(end+1) = "</div>"; %#ok<AGROW>
        end
        L(end+1) = "</div>"; %#ok<AGROW>
    end
    L(end+1) = "</div>"; %#ok<AGROW>
end
end


function z = pageSizes(e, pages, report)
%pageSizes  The [width height] cm of entry E's PAGES as drawn (reportImage's sizeCm), else the Export size.
z = zeros(numel(pages), 2);
fallback = [18 12];
if isfield(report, 'export') && isfield(report.export, 'FigureSizeCm') && numel(report.export.FigureSizeCm) == 2
    fallback = double(reshape(report.export.FigureSizeCm, 1, 2));
end
for q = 1:numel(pages)
    z(q, :) = fallback;
    p = pages(q);
    if p <= numel(e.images) && isstruct(e.images{p}) && isfield(e.images{p}, 'sizeCm') && numel(e.images{p}.sizeCm) == 2 ...
            && all(e.images{p}.sizeCm > 0)
        z(q, :) = double(reshape(e.images{p}.sizeCm, 1, 2));
    end
end
end


function s = css()
s = join([ ...
    "body{font:13px/1.45 'Segoe UI',system-ui,sans-serif;color:#1f2328;background:#f4f5f7;margin:0 auto;padding:12px 20px 40px;max-width:1200px}"
    "h1{font-size:20px;margin:4px 0}"
    "h2{font-size:16px;margin:24px 0 8px;padding-bottom:4px;border-bottom:1px solid #d0d7de}"
    "h3{font-size:14px;margin:0 0 6px}"
    "h4{font-size:12px;margin:0 0 4px;color:#57606a}"
    ".meta{color:#57606a;margin:0 0 12px}"
    "nav{background:#fff;border:1px solid #d0d7de;border-radius:8px;padding:4px 16px}"
    "nav ol{margin:4px 0 8px;padding-left:20px} nav ul{margin:0;padding-left:18px;columns:3}"
    "a{color:#0969da;text-decoration:none} a:hover{text-decoration:underline}"
    "section{margin-bottom:12px}"
    "article{background:#fff;border:1px solid #d0d7de;border-radius:8px;padding:10px 14px;margin:12px 0}"
    "h3.obs{font-size:15px;margin:18px 0 0;padding:4px 10px;border-left:4px solid #0969da;background:#fff;border-radius:4px}"
    ".kind{font-size:11px;font-weight:normal;padding:1px 7px;border-radius:9px;background:#eaeef2;color:#57606a}"
    ".fig img,.fig svg{max-width:100%;height:auto;display:block;margin:4px 0}"
    % Report.FiguresPerPage: tiles side by side, each as wide as its page on the sheet
    ".tilerow{display:flex;justify-content:center;align-items:flex-start;margin:6px 0}"
    ".tile{box-sizing:border-box;flex:none;min-width:0}"
    ".tile>article{margin:0}"
    ".tile img,.tile svg{width:100%}"
    ".cap{color:#1f2328;font-size:12px;margin:6px 0}"
    ".files{font-size:11px;color:#57606a;margin:4px 0}"
    ".bad{color:#cf222e}"
    ".star{color:#bf8700}"
    ".tags{font-size:11px;font-weight:normal;color:#57606a}"
    ".tables{display:flex;flex-wrap:wrap;gap:12px;align-items:flex-start}"
    ".tables>div{background:#fff;border:1px solid #d0d7de;border-radius:8px;padding:8px 10px}"
    "table{border-collapse:collapse;font-size:12px}"
    "th,td{border-bottom:1px solid #eaeef2;padding:2px 8px;text-align:left;vertical-align:top}"
    "th{color:#57606a;font-weight:600}"
    "table.kv td:first-child{color:#57606a}"
    "details{margin:6px 0} summary{cursor:pointer;color:#57606a;font-size:12px}"
    "pre{background:#f6f8fa;border:1px solid #d0d7de;border-radius:6px;padding:8px;overflow:auto;font-size:11px;max-height:480px}"
    % printed (or saved as PDF): no page break inside a table or a figure, nor right after a heading
    "@media print{body{background:#fff;max-width:none;padding:0}"
    "h2,h3,h4{break-after:avoid}.tables>div,.fig,.sheet,table,tr{break-inside:avoid}"
    ".fig img{max-height:25cm;width:auto;max-width:100%}}"
    ], "");
end


function s = specForJson(s)
%specForJson  A struct jsonencode can write (tables, results and handles dropped).
if isstruct(s)
    for k = 1:numel(s)
        for f = string(fieldnames(s)).'
            v = s(k).(f);
            if istable(v) || isa(v, 'handle') || isa(v, 'function_handle')
                s(k).(f) = "[" + class(v) + "]";
            else
                s(k).(f) = specForJson(v);
            end
        end
    end
elseif isnumeric(s)
    if any(~isfinite(s(:)))
        c = num2cell(s);
        for i = 1:numel(c)
            if isnan(c{i}); c{i} = "NaN"; elseif isinf(c{i}); c{i} = string(sign(c{i}) * Inf); end
        end
        if isscalar(c); s = c{1}; else; s = c; end
    end
end
end


function n = fileName(f)
[~, a, b] = fileparts(f);
n = a + b;
end


function s = summaryLabel(f)
%summaryLabel  The heading of a summary table: a known field's label, else its name.
switch f
    case "recording", s = "Recording";
    case "lines",     s = "Digital lines";
    case "trials",    s = "Trials";
    case "units",     s = "Units";
    case "topRates",  s = "Highest rates";
    case "sessions",  s = "Sessions";
    otherwise,        s = f;
end
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end


function s = starMark(D)
%starMark  " ★" after a starred dataset's name (its starred field), else "".
s = "";
if D.starred; s = " <span class=""star"" title=""starred"">&#9733;</span>"; end
end


function s = tagsMark(D)
%tagsMark  " <span>draft, pilot</span>" after a dataset's name (its tags field), else "".
s = "";
if ~isempty(D.tags)
    s = " <span class=""tags"" title=""tags"">" + htmlEscape(TagSet.toText(D.tags, TagSet.DisplayDelimiter)) + "</span>";
end
end
