function report = refresh(obj, opts)
%refresh  Parse headers and restore/refresh each dataset's manifest.
%   P.refresh() runs, for every dataset in the project (or Datasets=):
%     1. refreshMetadata()  - header-only metadata (Fs, channels, duration)
%     2. applyManifest()    - restore probe, exclusions, tags, manual artifacts,
%                             sorting and behavior associations from disk
%                             (as recorded, also while their files are not
%                             there); then associateFolderBehavior() - a
%                             dataset with no behavior file takes the one
%                             Epsych2 session file in its own folder (where
%                             the Copy tab puts it)
%     3. writeManifest()    - rewrite the manifest with the fresh metadata;
%                             a dataset that had no manifest (a scan finds
%                             it for the first time) first takes NewTags
%   A dataset without its recording (EphysDataset.hasRecording false: a
%   folder of pipeline outputs) takes its metadata from those outputs, and
%   nothing is written to its folder, which is often a backup.
%   A manifest that is there but cannot be read (not JSON, or an unknown
%   schema) is neither applied nor rewritten: applyManifest warns, and the
%   report says so. This is what the GUI's Scan does and what scripts /
%   EphysPipeline call, so headless runs and the app agree on the state of
%   each dataset.
%
%   Options
%     Datasets       indices into Datasets to refresh (default: all)
%     ApplyManifest  logical (default true)
%     WriteManifest  logical (default true)
%     Force          logical (default false)  re-parse headers even if cached
%     ProgressFcn    ProgressFcn(i, n, name) called before each dataset
%     CancelFcn      returns true to stop early (remaining datasets untouched)
%     NewTags        tags given to each dataset whose first manifest this
%                    refresh writes (default none; Project.NewDatasetTags
%                    with Project.AutoTag). Lenient, like a manifest's
%                    tags: entries that are no valid tag, and those past
%                    TagSet.MaxTags, are left out with a warning
%                    (EphysProject:refresh:NewTags). Added to the tags the
%                    dataset holds, unless that would pass TagSet.MaxTags.
%
%   Returns a table (Dataset, Key, Metadata, Manifest, New, Message), one
%   row per dataset refreshed: Metadata / Manifest are logical success
%   flags, New is true for a dataset that had no manifest and has one now
%   (it took NewTags); failures warn and are recorded here instead of
%   interrupting the loop.
%   Tags a manifest holds that are not valid are dropped by applyManifest
%   (warning EphysDataset:applyManifest:Tags); the warning's text goes into
%   that row's Message, and the row's Manifest flag stays true.
%
%   See also EphysDataset.refreshMetadata, EphysDataset.applyManifest,
%   EphysDataset.associateFolderBehavior, EphysDataset.writeManifest.

arguments
    obj (1,1) EphysProject
    opts.Datasets (1,:) double = 1:obj.NumDatasets
    opts.ApplyManifest (1,1) logical = true
    opts.WriteManifest (1,1) logical = true
    opts.Force (1,1) logical = false
    opts.ProgressFcn = []
    opts.CancelFcn = []
    opts.NewTags = {}
end

idx = opts.Datasets;
n = numel(idx);
names = strings(n, 1);
keys  = strings(n, 1);
okMeta = false(n, 1);
okMan  = false(n, 1);
isNew  = false(n, 1);
msg    = strings(n, 1);
newTags = newDatasetTags(opts.NewTags);

for i = 1:n
    d = obj.Datasets(idx(i));
    names(i) = d.Name;
    keys(i)  = obj.datasetKey(idx(i));
    if ~isempty(opts.CancelFcn) && opts.CancelFcn()
        msg(i:end) = "canceled";
        break
    end
    if ~isempty(opts.ProgressFcn)
        opts.ProgressFcn(i, n, d.Name);
    end
    first = ~isfile(d.manifestFile());   % before this refresh writes one

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
        unread = "";   % why a manifest that is there was not read
        if opts.ApplyManifest
            lastwarn("");
            [~, unread] = d.applyManifest();
            % Tags dropped as invalid are reported with the row, so the Scan
            % alert names them; the manifest itself still counts as read.
            [wmsg, wid] = lastwarn();
            if wid == "EphysDataset:applyManifest:Tags"
                if msg(i) ~= ""; msg(i) = msg(i) + "; "; end
                msg(i) = msg(i) + string(wmsg);
            end
            % A recorded session is kept, also while its file is not there.
            % A folder of outputs alone holds no session: its .mat files are not opened.
            if d.BehaviorFile == "" && d.hasRecording()
                d.associateFolderBehavior();
            end
        end
        if unread ~= ""
            if msg(i) ~= ""; msg(i) = msg(i) + "; "; end
            msg(i) = msg(i) + "manifest not read (" + unread + "), left as it is";
        else
            if opts.WriteManifest && d.hasRecording()
                if first && ~isempty(newTags)
                    t = TagSet.union(d.Tags, newTags);
                    if TagSet.checkCount(t); d.Tags = t; end
                end
                isNew(i) = d.writeManifest() && first;
            end
            okMan(i) = true;
        end
    catch ME
        if msg(i) ~= ""; msg(i) = msg(i) + "; "; end
        msg(i) = msg(i) + "manifest: " + string(ME.message);
        warning('EphysProject:refresh:Manifest', ...
            'Manifest update failed for %s: %s', d.Name, ME.message);
    end
end

report = table(names, keys, okMeta, okMan, isNew, msg, ...
    'VariableNames', {'Dataset', 'Key', 'Metadata', 'Manifest', 'New', 'Message'});
end


function t = newDatasetTags(in)
%newDatasetTags  The NewTags option as a valid set: what is no tag, and what is past MaxTags, left out with a warning.
[t, bad] = TagSet.parse(in);
if numel(t) > TagSet.MaxTags
    bad = [bad, t(TagSet.MaxTags+1:end)];
    t = t(1:TagSet.MaxTags);
end
if ~isempty(bad)
    warning('EphysProject:refresh:NewTags', ...
        'Tags for new datasets: %d left out as invalid or over the limit of %d (%s).', ...
        numel(bad), TagSet.MaxTags, strjoin(string(bad), ", "));
end
end
