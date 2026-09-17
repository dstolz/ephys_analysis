function onExportConfigCopy(obj)
%onExportConfigCopy  Write a copy of the working config without changing its file.
cfg = obj.gatherConfig();
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
