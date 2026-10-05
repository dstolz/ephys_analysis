function onExportConfigCopy(obj)
%onExportConfigCopy  Write a copy of the working config without changing its file.
%   Refused while a text field does not parse (gatherConfig).
try
    cfg = obj.gatherConfig();
catch ME
    uialert(obj.Fig, string(ME.message), "Export copy");
    return
end
start = char(obj.defaultConfigFolder());
[f, p] = uiputfile({'*.json', 'Pipeline config (*.json)'}, "Export a copy of the config", ...
    fullfile(start, 'pipeline_copy.json'));
figure(obj.Fig);
if isequal(f, 0); return; end
try
    cfg.save(fullfile(p, f));
catch ME
    uialert(obj.Fig, "Could not write the copy:" + newline + string(ME.message), "Export copy");
    return
end
obj.setStatus("Exported a copy to " + string(fullfile(p, f)), "");
end
