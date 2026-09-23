function openSource(obj, source, opts)
%openSource  Open what the app was launched with: a config, a project root or an output folder.
%   SOURCE ending in .json is an analysis config (openConfigFile). A folder
%   holding <Name>_manifest.json or <Name>_extract*.mat files is one
%   dataset's output folder: a new config in "folders" mode. Any other
%   folder is a pipeline project root: a new config in "project" mode with
%   OutputRoot, NamePattern and Recordings ("" = the defaults); Datasets
%   (root-relative keys, as EphysProject.datasetKey) makes its selection
%   those datasets (Selection "list": the scan lists every dataset but
%   ticks only these to run, the first of them active), and one dataset
%   names the config. Either way the datasets are scanned.
arguments
    obj (1,1) EphysAnalysisApp
    source (1,1) string
    opts.OutputRoot (1,1) string = ""
    opts.NamePattern (1,1) string = ""
    opts.Recordings (1,1) string = ""
    opts.Datasets (1,:) string = string.empty(1,0)
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
    if opts.NamePattern ~= ""; cfg.Source.NamePattern = opts.NamePattern; end
    if opts.Recordings ~= ""; cfg.Source.Recordings = opts.Recordings; end
    if ~isempty(opts.Datasets)
        cfg.Source.Selection = "list";
        cfg.Source.Datasets = EphysProject.normalizeKey(opts.Datasets);
        if isscalar(opts.Datasets)
            [~, leaf] = fileparts(opts.Datasets);
            cfg.Name = string(leaf) + " quick look";
        end
    end
end
obj.SelectedPlot = 0;
obj.applyConfig(cfg, MarkSaved=true);
obj.onScan();
end
