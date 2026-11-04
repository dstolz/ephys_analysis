function openSource(obj, source, opts)
%openSource  Open what the app was launched with: a config, a project root or an output folder.
%   SOURCE ending in .json is an analysis config (openConfigFile), opened
%   as it is. A folder holding <Name>_manifest.json or <Name>_extract*.mat
%   files is one dataset's output folder: a source in "folders" mode. Any
%   other folder is a pipeline project root: a source in "project" mode
%   with OutputRoot, NamePattern and Recordings ("" = the defaults);
%   Datasets (root-relative keys, as EphysProject.datasetKey) makes its
%   selection those datasets (Selection "list": the scan lists every
%   dataset but ticks only these to run, the first of them active).
%
%   For a folder the last config (preference LastConfigFile) opens again,
%   its figures and defaults as they are, with that source in place of its
%   own: the config is then unsaved (the status bar says so; Save writes
%   the new source to its file). With no last config, or one that cannot
%   be read, it is a new "<folder> quick look" config (one dataset of
%   Datasets names it instead). Either way the datasets are scanned.
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
        obj.Splash.alert(obj.Fig, "No such config: " + source, "Open");
        return
    end
    obj.openConfigFile(source);
    return
end
if ~isfolder(source)
    obj.Splash.alert(obj.Fig, "Not a folder or an analysis config: " + source, "Open");
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
[last, file, why] = lastConfig(obj);
if isempty(last)
    obj.SelectedFigure = 0;
    obj.applyConfig(cfg, MarkSaved=true);
    scanOpened(obj);
    if why ~= ""
        obj.log("Open " + source + ": " + why + "; a quick look config instead");
        obj.setStatus(string(obj.StatusBar.Text) + " A quick look config: " + why + ".");
    end
    return
end
saved = last.toStruct();   % what the file holds
switched = ~isequaln(last.Source, cfg.Source);
last.Source = cfg.Source;
obj.SelectedFigure = min(1, numel(last.Figures));
obj.applyConfig(last, MarkSaved=true);
obj.SavedConfigStruct = saved;   % the new source is not in the file: unsaved
obj.addRecentConfig(file);
for w = last.LoadWarnings
    obj.log("Open " + file + ": " + w);
end
scanOpened(obj);
obj.updateTitle();
msg = "Opened the last config " + file + " on " + source;
if switched
    msg = msg + ": its source is switched to that " + ternary(isOutputs, "output folder", "project") + ...
        ", so the config is unsaved (Save writes the new source to the file).";
else
    msg = msg + ".";
end
obj.setStatus(msg + " " + string(obj.StatusBar.Text));
end


function [cfg, file, why] = lastConfig(obj)
%lastConfig  The config of preference LastConfigFile (CFG [] when none, or WHY it could not be read).
cfg = [];
file = "";
why = "";
g = obj.PrefGroup;
if ~AppPrefs.ispref(g, 'LastConfigFile'); return; end
file = string(AppPrefs.getpref(g, 'LastConfigFile'));
if file == ""; return; end
if ~isfile(file)
    why = "the last config " + file + " is gone";
    return
end
try
    ws = warning('off', 'EphysAnalysisConfig:LoadWarnings');
    restore = onCleanup(@() warning(ws)); %#ok<NASGU>
    cfg = EphysAnalysisConfig.load(file);
catch ME
    cfg = [];
    why = "the last config " + file + " could not be read (" + string(ME.message) + ")";
end
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
