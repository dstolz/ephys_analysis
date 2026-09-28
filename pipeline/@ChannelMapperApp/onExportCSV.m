function onExportCSV(obj)
%onExportCSV  Write the result table to a .csv file.
txt = obj.copyText("csv");
if txt == ""
    obj.setStatus('Nothing to write: choose a package and a headstage.', true);
    return
end
[f, p] = uiputfile({'*.csv', 'CSV (*.csv)'}, 'Export the channel map as CSV', 'channel_map.csv');
figure(obj.Fig);
if isequal(f, 0)
    return
end
file = fullfile(p, f);
fid = fopen(file, 'w', 'n', 'UTF-8');
if fid < 0
    obj.setStatus("Cannot write " + file, true);
    return
end
fwrite(fid, char(txt), 'char');
fclose(fid);
obj.setStatus("Wrote " + file, false);
end
