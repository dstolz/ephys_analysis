function onOpenFlowChartInBrowser(obj)
%onOpenFlowChartInBrowser  Write the Flow tab's chart to a temp file and open it in the default browser.
file = [tempname, '.html'];
html = obj.flowChartHTML();
fid = fopen(file, 'w', 'n', 'UTF-8');
if fid < 0
    obj.setStatus("Could not write " + string(file));
    return
end
fwrite(fid, char(html), 'char');
fclose(fid);
web("file:///" + string(file), '-browser');
obj.setStatus("Diagram opened in browser.");
end
