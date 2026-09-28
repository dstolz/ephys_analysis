function onImportProbe(obj)
%onImportProbe  Copy an external probe .json into the probe folder.
%   The probe's Kilosort4 parameter file (<probe>.ks4.json) and its
%   channel-map sidecar (<probe>.chanmap.json, ChannelMapperApp) come along
%   when they are next to it.

[f, p] = uigetfile({'*.json', 'Kilosort4 probe (*.json)'}, "Select a probe .json to import");
figure(obj.Fig);
if isequal(f, 0); return; end
src = fullfile(p, f);

folder = string(obj.ProbeFolderField.Value);
if folder == "" || ~isfolder(folder)
    folder = string(obj.defaultProbeFolder());
end
if ~isfolder(folder); mkdir(folder); end

dst = fullfile(folder, f);
if isfile(dst)
    sel = uiconfirm(obj.Fig, sprintf("%s already exists in the probe folder. Overwrite?", f), ...
        "Import probe", "Options", {'Overwrite','Cancel'}, "DefaultOption", 2);
    if sel ~= "Overwrite"; return; end
end

[ok, msg] = copyfile(src, dst);
if ok && isfile(EphysPipelineConfig.ks4ParamsFile(src))
    [ok, msg] = copyfile(EphysPipelineConfig.ks4ParamsFile(src), EphysPipelineConfig.ks4ParamsFile(dst), 'f');
end
if ok && isfile(ChannelMap.sidecarFile(src))
    [ok, msg] = copyfile(ChannelMap.sidecarFile(src), ChannelMap.sidecarFile(dst), 'f');
end
if ~ok
    uialert(obj.Fig, "Copy failed: " + string(msg), "Import probe");
    return
end
obj.refreshProbeList();
row = find(obj.ProbePaths == string(dst), 1);
if ~isempty(row)
    obj.selectProbeRow(row);
end
end
