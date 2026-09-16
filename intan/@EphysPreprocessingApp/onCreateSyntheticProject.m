function onCreateSyntheticProject(obj)
%onCreateSyntheticProject  File > Create synthetic test project...
%   Asks for a parent folder and a size, writes <parent>/synthetic_ephys
%   with makeSyntheticProject (four recordings with Epsych2 sessions,
%   ground-truth sorted output and a pipeline config), then opens that
%   config and scans it (createSyntheticProject). An existing
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
    "Write four synthetic recordings (Intan RHX layout, spiking units, LFP, artifacts, six digital lines, accelerometer) " + ...
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

obj.createSyntheticProject(root, Preset=preset, Overwrite=overwrite);
end
