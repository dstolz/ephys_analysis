function file = writeHtmlReport(report, file, opts)
%writeHtmlReport  Write a report as one self-contained HTML file.
%   FILE = writeHtmlReport(REPORT, FILE) writes the report built with
%   newAnalysisReport / addReportDataset / addReportFigure: a title, a table
%   of contents, then one section per dataset with its summary tables
%   (IncludeSummary) and every plot -- its pages embedded as PNG
%   (data:image/png;base64) or inline SVG, its caption, the parameters it
%   was drawn with (IncludeParameters, folded) and links to its exported
%   files -- and the config JSON at the end (IncludeConfig, folded). No
%   file beside it is needed; opening it needs only a browser.
%
%   Options: EmbedFormat ("png" | "svg"; default the report's), Dpi (PNG
%   resolution; default the report's). The images a plot was added with
%   (addReportFigure) are used as they are; a plot added without them is
%   drawn again from its result, as is one that kept its result (a "pdf" /
%   "both" report) when EmbedFormat or Dpi is given here. Every link to an
%   exported file is relative to FILE's folder (a file:// URL on another
%   drive) and percent-encoded.
%
%   See also writePdfReport, newAnalysisReport, EphysAnalysisRunner.run.

arguments
    report (1,1) struct
    file (1,1) string
    opts.EmbedFormat (1,1) string = ""
    opts.Dpi (1,1) double = NaN
end

redraw = opts.EmbedFormat ~= "" || isfinite(opts.Dpi);
if opts.EmbedFormat ~= ""; report.options.EmbedFormat = opts.EmbedFormat; end
if isfinite(opts.Dpi); report.options.Dpi = opts.Dpi; end
folder = fileparts(file);
if strlength(folder) > 0 && ~isfolder(folder); mkdir(folder); end

L = strings(0, 1);
L(end+1) = "<!DOCTYPE html><html><head><meta charset=""utf-8"">";
L(end+1) = "<title>" + htmlEscape(report.title) + "</title><style>" + css() + "</style></head><body>";
L(end+1) = "<h1>" + htmlEscape(report.title) + "</h1>";
nPlots = sum(arrayfun(@(d) numel(d.entries), report.datasets));
L(end+1) = "<p class=""meta"">Generated <span class=""created"">" + htmlEscape(report.created) + "</span> &middot; " ...
    + numel(report.datasets) + " dataset(s), " + nPlots + " plot(s)</p>";

% --- contents ----------------------------------------------------------------------
L(end+1) = "<nav><h2>Contents</h2><ol>";
for d = 1:numel(report.datasets)
    D = report.datasets(d);
    L(end+1) = "<li><a href=""#ds" + d + """>" + htmlEscape(D.name) + "</a><ul>"; %#ok<AGROW>
    for k = 1:numel(D.entries)
        e = D.entries(k);
        L(end+1) = "<li><a href=""#ds" + d + "-" + k + """>" + htmlEscape(e.plot) + "</a>" ...
            + ternary(e.status ~= "done", " <span class=""bad"">(" + htmlEscape(e.status) + ")</span>", "") + "</li>"; %#ok<AGROW>
    end
    L(end+1) = "</ul></li>"; %#ok<AGROW>
end
if report.options.IncludeConfig; L(end+1) = "<li><a href=""#config"">Config</a></li>"; end
L(end+1) = "</ol></nav>";

% --- datasets ------------------------------------------------------------------------
for d = 1:numel(report.datasets)
    D = report.datasets(d);
    L(end+1) = "<section id=""ds" + d + """><h2>" + htmlEscape(D.name) + "</h2>"; %#ok<AGROW>
    if ~isempty(D.summary)
        S = D.summary;
        L(end+1) = "<div class=""tables"">"; %#ok<AGROW>
        L(end+1) = "<div><h4>Recording</h4>" + htmlTable(S.recording, "kv") + "</div>"; %#ok<AGROW>
        if height(S.lines) > 0; L(end+1) = "<div><h4>Digital lines</h4>" + htmlTable(S.lines) + "</div>"; end %#ok<AGROW>
        if height(S.trials) > 0; L(end+1) = "<div><h4>Trials</h4>" + htmlTable(S.trials) + "</div>"; end %#ok<AGROW>
        if height(S.units) > 0; L(end+1) = "<div><h4>Units</h4>" + htmlTable(S.units) + "</div>"; end %#ok<AGROW>
        if height(S.topRates) > 0; L(end+1) = "<div><h4>Highest rates</h4>" + htmlTable(S.topRates) + "</div>"; end %#ok<AGROW>
        L(end+1) = "</div>"; %#ok<AGROW>
    end
    for k = 1:numel(D.entries)
        e = D.entries(k);
        head = e.plot;
        if e.title ~= ""; head = head + ": " + e.title; end
        L(end+1) = "<article id=""ds" + d + "-" + k + """><h3>" + htmlEscape(head) + ...
            " <span class=""kind"">" + htmlEscape(e.kind) + "</span></h3>"; %#ok<AGROW>
        if e.status ~= "done"
            L(end+1) = "<p class=""bad"">" + htmlEscape(e.status) + ": " + htmlEscape(e.message) + "</p></article>"; %#ok<AGROW>
            continue
        end
        images = e.images;
        if ~isempty(e.R) && (isempty(images) || redraw)
            images = reportImages(e.R, e.spec, report);
        end
        for p = 1:numel(images)
            im = images{p};
            if im.format == "svg"
                L(end+1) = "<div class=""fig"">" + svgText(im.data, "d" + d + "p" + k + "i" + p + "_") + "</div>"; %#ok<AGROW>
            else
                L(end+1) = "<div class=""fig""><img alt=""" + htmlEscape(im.title) + """ src=""data:image/png;base64," ...
                    + im.data + """></div>"; %#ok<AGROW>
            end
        end
        L(end+1) = "<p class=""cap"">" + htmlEscape(e.caption) + "</p>"; %#ok<AGROW>
        if ~isempty(e.files)
            links = arrayfun(@(f) "<a href=""" + htmlEscape(relativePath(folder, f)) + """>" + htmlEscape(fileName(f)) + "</a>", e.files);
            L(end+1) = "<p class=""files"">Files: " + strjoin(links, ", ") + "</p>"; %#ok<AGROW>
        end
        if report.options.IncludeParameters
            L(end+1) = "<details><summary>Parameters</summary><pre>" + ...
                htmlEscape(jsonencode(specForJson(e.spec), 'PrettyPrint', true)) + "</pre></details>"; %#ok<AGROW>
        end
        L(end+1) = "</article>"; %#ok<AGROW>
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
    ".kind{font-size:11px;font-weight:normal;padding:1px 7px;border-radius:9px;background:#eaeef2;color:#57606a}"
    ".fig img,.fig svg{max-width:100%;height:auto;display:block;margin:4px 0}"
    ".cap{color:#1f2328;font-size:12px;margin:6px 0}"
    ".files{font-size:11px;color:#57606a;margin:4px 0}"
    ".bad{color:#cf222e}"
    ".tables{display:flex;flex-wrap:wrap;gap:12px;align-items:flex-start}"
    ".tables>div{background:#fff;border:1px solid #d0d7de;border-radius:8px;padding:8px 10px}"
    "table{border-collapse:collapse;font-size:12px}"
    "th,td{border-bottom:1px solid #eaeef2;padding:2px 8px;text-align:left;vertical-align:top}"
    "th{color:#57606a;font-weight:600}"
    "table.kv td:first-child{color:#57606a}"
    "details{margin:6px 0} summary{cursor:pointer;color:#57606a;font-size:12px}"
    "pre{background:#f6f8fa;border:1px solid #d0d7de;border-radius:6px;padding:8px;overflow:auto;font-size:11px;max-height:480px}"
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


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
