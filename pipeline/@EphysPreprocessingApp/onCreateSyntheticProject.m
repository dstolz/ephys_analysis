function onCreateSyntheticProject(obj)
%onCreateSyntheticProject  File > Create synthetic test project...
%   Asks for a parent folder, a size and a recording format (Intan RHX or
%   an Open Ephys GUI session in the Binary, Open Ephys or NWB format),
%   writes <parent>/synthetic_ephys with makeSyntheticProject (four
%   recordings with Epsych2 sessions, ground-truth sorted output and a
%   pipeline config), then opens that config and scans it
%   (createSyntheticProject). An existing
%   synthetic_ephys folder is replaced only after confirmation, and only
%   when it was written by this tool.
if ~obj.confirmDiscard(); return; end
start = obj.RootPathField.Value;
if isempty(start) || ~isfolder(start); start = pwd; end
parent = uigetdir(start, "Folder in which to create the synthetic test project (a synthetic_ephys subfolder)");
figure(obj.Fig);
if isequal(parent, 0); return; end
root = fullfile(parent, 'synthetic_ephys');

sel = uiconfirm(obj.Fig, ...
    "Write four synthetic recordings (spiking units, LFP, artifacts, six digital lines, accelerometer; the format is chosen next) " + ...
    "with their Epsych2 sessions and ground-truth sorted output into" + newline + root + newline + newline + ...
    "Standard: 30 kHz, 16 channels, 12 trials per session (about 250 MB)." + newline + ...
    "Small: 20 kHz, 8 channels, 6 trials per session (about 40 MB).", ...
    "Create synthetic test project", "Options", {'Standard', 'Small', 'Cancel'}, ...
    "DefaultOption", 1, "CancelOption", 3);
switch sel
    case 'Standard', preset = "standard";
    case 'Small',    preset = "small";
    otherwise,       return
end
sel = uiconfirm(obj.Fig, ...
    "Recording format of the synthetic sessions:" + newline + ...
    "Intan RHX: *.rhd files (A-000.., named digital lines)." + newline + ...
    "Open Ephys: a GUI session folder with Record Node 101 (CH1.., TTL1..TTL6 named by the config's Signals.LineNames).", ...
    "Create synthetic test project", "Options", {'Intan RHX', 'Open Ephys', 'Cancel'}, ...
    "DefaultOption", 1, "CancelOption", 3);
switch sel
    case 'Intan RHX'
        format = "traditional";
    case 'Open Ephys'
        % uiconfirm takes at most four options, so the Open Ephys record
        % format is a second question
        sel = uiconfirm(obj.Fig, ...
            "Open Ephys record format:" + newline + ...
            "Binary: continuous.dat and TTL event arrays." + newline + ...
            "Open Ephys format: one .continuous file per channel plus .events files." + newline + ...
            "NWB: a single NWB 2 (HDF5) file per experiment.", ...
            "Create synthetic test project", "Options", {'Binary', 'Open Ephys format', 'NWB', 'Cancel'}, ...
            "DefaultOption", 1, "CancelOption", 4);
        switch sel
            case 'Binary',            format = "openephys-binary";
            case 'Open Ephys format', format = "openephys-legacy";
            case 'NWB',               format = "openephys-nwb";
            otherwise,                return
        end
    otherwise
        return
end

overwrite = false;
if isfolder(root) && numel(dir(root)) > 2
    if ~isfile(fullfile(root, 'synthetic_pipeline.json'))
        uialert(obj.Fig, root + newline + "exists, is not empty and was not written by this tool. Pick another folder or remove it yourself.", ...
            "Create synthetic test project");
        return
    end
    sel = uiconfirm(obj.Fig, root + newline + "already holds a synthetic project. Replace it?", ...
        "Create synthetic test project", "Options", {'Replace', 'Cancel'}, "DefaultOption", 2, "CancelOption", 2);
    if ~strcmp(sel, 'Replace'); return; end
    overwrite = true;
end

obj.createSyntheticProject(root, Preset=preset, Overwrite=overwrite, Generator=struct('Format', format));
end
