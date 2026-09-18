function openSource(obj, source, opts)
%openSource  Open what the app was launched with: a config, a project root or an output folder.
%   SOURCE ending in .json is an analysis config (openConfigFile). A folder
%   holding <Name>_manifest.json or <Name>_extract*.mat files is one
%   dataset's output folder: a new config in "folders" mode. Any other
%   folder is a pipeline project root: a new config in "project" mode with
%   OutputRoot. Either way the datasets are scanned.
arguments
    obj (1,1) EphysAnalysisApp
    source (1,1) string
    opts.OutputRoot (1,1) string = ""
end
if endsWith(lower(source), ".json")
    if ~isfile(source)
        uialert(obj.Fig, "No such config: " + source, "Open");
        return
    end
    obj.openConfigFile(source);
    return
end
if ~isfolder(source)
    uialert(obj.Fig, "Not a folder or an analysis config: " + source, "Open");
    return
end
source = regexprep(source, '[\\/]+$', '');
[~, leaf] = fileparts(source);
cfg = EphysAnalysisConfig();
cfg.Name = string(leaf) + " quick look";
isOutputs = ~isempty(dir(fullfile(source, '*_manifest.json'))) || ~isempty(dir(fullfile(source, '*_extract*.mat')));
if isOutputs
    cfg.Source.Mode = "folders";
    cfg.Source.Folders = source;
else
    cfg.Source.Mode = "project";
    cfg.Source.Root = source;
    cfg.Source.OutputRoot = opts.OutputRoot;
end
obj.SelectedPlot = 0;
obj.applyConfig(cfg, MarkSaved=true);
obj.onScan();
end
