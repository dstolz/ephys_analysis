function onOpenReport(obj)
%onOpenReport  Open the last run's report (the HTML one when there is one).
f = obj.LastReportFiles;
if isempty(f); return; end
html = f(endsWith(f, ".html"));
if ~isempty(html); f = html(1); else; f = f(1); end
if endsWith(f, ".html")
    web("file:///" + replace(f, "\", "/"), '-browser');
elseif ispc
    winopen(f);
else
    web("file:///" + f, '-browser');
end
obj.setStatus("Opened " + f);
end
