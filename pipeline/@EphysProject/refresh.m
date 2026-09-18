function report = refresh(obj, opts)
%refresh  Parse headers and restore/refresh each dataset's manifest.
%   P.refresh() runs, for every dataset in the project:
%     1. refreshMetadata()  - header-only metadata (Fs, channels, duration)
%     2. applyManifest()    - restore probe, exclusions, manual artifacts,
%                             sorting and behavior associations from disk;
%                             then associateFolderBehavior() - a dataset with
%                             no behavior file takes the one Epsych2 session
%                             file in its own folder (where the Copy tab
%                             puts it)
%     3. writeManifest()    - rewrite the manifest with the fresh metadata
%   This is what the GUI's Scan does and what scripts / EphysPipeline call,
%   so headless runs and the app agree on the state of each dataset.
%
%   Options
%     ApplyManifest  logical (default true)
%     WriteManifest  logical (default true)
%     Force          logical (default false)  re-parse headers even if cached
%     ProgressFcn    ProgressFcn(i, n, name) called before each dataset
%     CancelFcn      returns true to stop early (remaining datasets untouched)
%
%   Returns a table (Dataset, Key, Metadata, Manifest, Message): Metadata /
%   Manifest are logical success flags; failures warn and are recorded here
%   instead of interrupting the loop.
%
%   See also EphysDataset.refreshMetadata, EphysDataset.applyManifest,
%   EphysDataset.associateFolderBehavior, EphysDataset.writeManifest.

arguments
    obj (1,1) EphysProject
    opts.ApplyManifest (1,1) logical = true
    opts.WriteManifest (1,1) logical = true
    opts.Force (1,1) logical = false
    opts.ProgressFcn = []
    opts.CancelFcn = []
end

n = obj.NumDatasets;
names = strings(n, 1);
keys  = strings(n, 1);
okMeta = false(n, 1);
okMan  = false(n, 1);
msg    = strings(n, 1);

for i = 1:n
    d = obj.Datasets(i);
    names(i) = d.Name;
    keys(i)  = obj.datasetKey(i);
    if ~isempty(opts.CancelFcn) && opts.CancelFcn()
        msg(i:end) = "cancelled";
        break
    end
    if ~isempty(opts.ProgressFcn)
        opts.ProgressFcn(i, n, d.Name);
    end

    try
        if opts.Force || isnan(d.Fs) || isempty(d.PerFile)
            d.refreshMetadata();
        end
        okMeta(i) = true;
    catch ME
        msg(i) = "metadata: " + string(ME.message);
        warning('EphysProject:refresh:Metadata', ...
            'Metadata failed for %s: %s', d.Name, ME.message);
    end

    try
        if opts.ApplyManifest
            d.applyManifest();
            d.associateFolderBehavior();
        end
        if opts.WriteManifest
            d.writeManifest();
        end
        okMan(i) = true;
    catch ME
        if msg(i) ~= ""; msg(i) = msg(i) + "; "; end
        msg(i) = msg(i) + "manifest: " + string(ME.message);
        warning('EphysProject:refresh:Manifest', ...
            'Manifest update failed for %s: %s', d.Name, ME.message);
    end
end

report = table(names, keys, okMeta, okMan, msg, ...
    'VariableNames', {'Dataset', 'Key', 'Metadata', 'Manifest', 'Message'});
end
