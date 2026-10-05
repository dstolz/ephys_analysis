function onSaveFlowChart(obj)
%onSaveFlowChart  Write the Flow tab's chart as a standalone .html file.
start = obj.defaultConfigFolder();
if obj.Config.File ~= ""
    [p, base] = fileparts(obj.Config.File);
    start = fullfile(p, base + "_diagram.html");
end
[f, p] = uiputfile({'*.html', 'HTML page (*.html)'}, "Save the diagram", start);
figure(obj.Fig);
if isequal(f, 0); return; end
file = fullfile(p, f);
html = obj.flowChartHTML();
fid = fopen(file, 'w', 'n', 'UTF-8');
if fid < 0
    obj.setStatus("Could not write " + string(file));
    return
end
fwrite(fid, char(html), 'char');
fclose(fid);
obj.setStatus("Diagram saved to " + string(file));
end
