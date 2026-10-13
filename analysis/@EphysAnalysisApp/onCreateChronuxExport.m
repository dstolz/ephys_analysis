function out = onCreateChronuxExport(obj, opts)
%onCreateChronuxExport  Write the active dataset's Chronux file from its extract, sorted units and detections.
%   OUT = onCreateChronuxExport(obj, Name=Value) runs the dataset's
%   EphysDataset.exportChronux -- what the pipeline's Export step writes
%   -- reading the extract file(s) DatasetOutputs found, the sorted units
%   (with their quality metrics) and the threshold detections when there
%   are any, and writes <Name>_chronux.mat (-v7.3) into the dataset's
%   output folder; when that folder cannot be written (a read-only
%   share), or Where is "cache", into the local cache
%   (<ChronuxCacheFolder>/<dataset key>/; picked with a dialog when not
%   set). An existing file is replaced. When the dataset's hand-picked
%   sort is not there now, it asks whether to write the file without
%   units. OUT: what exportChronux returned ([] when nothing was written).
%
%   Options
%     Where         "auto" (default) | "cache"
%     WithoutUnits  [] (default: ask when the sort is missing) | true
%                   (no units) | false (units when there are any, no question)
arguments
    obj (1,1) EphysAnalysisApp
    opts.Where (1,1) string {mustBeMember(opts.Where, ["auto" "cache"])} = "auto"
    opts.WithoutUnits = []
end
out = [];
k = obj.ActiveIdx;
if isempty(obj.Runner) || k < 1 || ismember(obj.ChronuxState, ["computing" "creating"]); return; end
outs = obj.Runner.Outputs(k);
name = obj.Runner.Names(k);
if ~outs.has("extract")
    obj.setChronuxState("failed", Message=name + " has no extract: run the pipeline's Signals step first.");
    return
end
ds = exportDataset(outs);
units = ~isequal(opts.WithoutUnits, true);
if ds.sortingMissing()
    if isempty(opts.WithoutUnits)
        pick = uiconfirm(obj.Fig, "The sort picked for " + name + " (" + ds.SortingDir + ") is not there now. " + ...
            "Write the Chronux file without sorted units?", "Sort missing", ...
            "Options", ["Create without units" "Cancel"], "DefaultOption", 2, "CancelOption", 2);
        if pick ~= "Create without units"; return; end
    end
    units = false;   % the sort is not there: nothing to read
end
folder = string(ds.outputFolder());
if opts.Where == "cache" || ~canWriteFolder(folder)
    if obj.ChronuxCacheFolder == ""
        obj.onChronuxCacheFolder("");
        if obj.ChronuxCacheFolder == ""
            obj.setChronuxState("idle", Message="The output folder of " + name + " cannot be written: pick a local cache folder.");
            return
        end
    end
    file = chronuxCachePath(obj.ChronuxCacheFolder, obj.Runner.Keys(k), ds.Name);
else
    file = string(fullfile(folder, ds.Name + "_chronux.mat"));
end
d = fileparts(file);
if ~isfolder(d)
    [ok, msg] = mkdir(d);
    if ~ok
        obj.setChronuxState("failed", Message="Cannot create " + d + ": " + string(msg));
        return
    end
end
args = {'File', file, 'Extract', outs.ExtractFiles, 'Overwrite', true, 'MatVersion', "-v7.3"};
if outs.has("spikes")
    args = [args {'Detected', string(outs.SpikesFile)}];
else
    args = [args {'Detected', false}];
end
if ~units; args = [args {'Units', false}]; end
obj.ChronuxResult = [];
obj.setChronuxState("creating", Message="Writing " + file + " ...");
try
    out = ds.exportChronux(args{:});
catch ME
    if ~isvalid(obj) || ~isvalid(obj.Fig); return; end
    obj.setChronuxState("failed", Message="Creating the Chronux file failed: " + string(ME.message));
    obj.log("Chronux: creating " + file + " failed: " + string(ME.message));
    return
end
outs.refresh();
obj.ChronuxIndex = [];
obj.ChronuxFile = "";
msg = sprintf("Wrote %s (%.0f MB, %.1f s): %s; %d sorted unit(s), %d detection channel(s).", file, ...
    out.bytes / 2^20, out.seconds, strjoin(out.signals, ", "), out.nUnits, out.nDetectedChannels);
obj.log("Chronux: " + msg);
obj.setChronuxState("idle", Message=msg);
obj.refreshChronuxTab();
end


function ds = exportDataset(outs)
%exportDataset  The dataset to export: the project's, else one made of the output folder with its sort.
ds = outs.Dataset;
if ~isempty(ds); return; end
ds = EphysDataset(outs.Folder, AutoMetadata=false, Name=outs.Name);
if outs.has("sorting")
    ds.SortingDir = string(outs.SortingDir);
end
end
