function onExportKS4(obj)
%onExportKS4  Export button: confirm problems, choose the file, write it.
%   Starts in the parent's probe folder (pipeline/probes standalone). The
%   file dialog asks before replacing a file.
R = obj.Result;
if isempty(R)
    obj.setStatus('Choose a package and a headstage first.', true);
    return
end
if all(isnan(R.Table.X))
    uialert(obj.Fig, 'The probe file needs site positions: choose a probe design in panel 1 first.', 'No probe design');
    return
end
if ~isempty(R.Problems)
    answer = uiconfirm(obj.Fig, sprintf('The chain has %d problem(s), the first:\n\n%s\n\nExport anyway? Sites that reach no recorded channel are left out.', ...
        numel(R.Problems), R.Problems(1)), 'Export with problems', ...
        'Options', {'Export anyway', 'Cancel'}, 'DefaultOption', 2, 'CancelOption', 2);
    if answer ~= "Export anyway"
        return
    end
end
folder = "";
if ~isempty(obj.App) && isvalid(obj.App)
    folder = string(obj.App.ProbeFolderField.Value);
    if folder == "" || ~isfolder(folder)
        folder = string(obj.App.defaultProbeFolder());
    end
end
if folder == "" || ~isfolder(folder)
    folder = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'probes');
end
parts = strings(0, 1);
if obj.ProbeId ~= ""
    parts(end + 1) = extractAfter(obj.ProbeId, "/");
end
parts(end + 1) = extractAfter(obj.PackageId, "/");
parts(end + 1) = extractAfter(obj.HeadstageId, "/");
name = HardwareBank.safeName(strjoin(parts, "_")) + ".json";
[f, p] = uiputfile({'*.json', 'Kilosort4 probe (*.json)'}, 'Export Kilosort4 probe', char(fullfile(folder, name)));
figure(obj.Fig);
if isequal(f, 0)
    return
end
if endsWith(string(f), ChannelMap.SidecarSuffix, 'IgnoreCase', true) || endsWith(string(f), ".ks4.json", 'IgnoreCase', true)
    uialert(obj.Fig, 'That name is kept for a probe''s sidecar files; choose a plain <name>.json.', 'Export');
    return
end
try
    obj.exportKS4(fullfile(p, f));
catch ME
    obj.setStatus("Export failed: " + ME.message, true);
    uialert(obj.Fig, ME.message, 'Export failed');
end
end
