function [stamp, sorted] = outputsStamp(out)
%outputsStamp  Text that changes when a dataset's outputs change: the names, sizes and times of its files.
%   STAMP = outputsStamp(OUT) for a DatasetOutputs is one line per file,
%   "<kind> <name> <bytes> <modified>", sorted and joined by newlines, of
%     - the files refresh found (OUT.Candidates, kept in memory) of the
%       kinds extract (the signal files), spikes, behavior
%       (<Name>_behavior.mat), manifest and artifacts, plus the names of
%       the spikes and extract files in effect (a pinned path too);
%     - the files of the sorting folder (OUT.SortingDir) that a new sort
%       or phy curation rewrites: params.py, spike_times.npy,
%       spike_clusters.npy, spike_templates.npy, channel_map.npy,
%       channel_positions.npy, channel_shanks.npy and every cluster_*.tsv
%       (cluster_group.tsv, cluster_info.tsv, cluster_KSLabel.tsv, ...).
%   Only file names go in, not their folders, so the stamp stays the same
%   when the outputs are copied or moved with their times (robocopy,
%   OutputTransfer). DatasetRuns keeps the stamp with each result (run's
%   StampFcn): a result whose stamp differs is computed again, and a
%   dataset kept as skipped is tried again. The pipeline rewrites the
%   manifest after each output, so any step run again changes the stamp;
%   so does a tag edit, which is written to the manifest too.
%
%   [STAMP, SORTED] = outputsStamp(OUT) also says whether the sorting
%   folder holds params.py: OUT.has("sorting"), from the same listing.
%
%   I/O: the candidates cost nothing (OUT is refreshed first only when it
%   never has been). The sorting folder costs finding it (OUT.SortingDir:
%   nothing when the dataset names its sort folder, else the checks
%   OUT.has("sorting") makes too) and one listing of it (two when it is a
%   run folder holding kilosort4\, as EphysDataset.resolvePhyDir reads
%   it), which replaces the params.py checks of has("sorting").
%
%   Not seen: a change after OUT was refreshed to a file of the first list
%   (refresh, or scan again), a file outside the outputs (the probe map's
%   .json edited in place; processing the dataset again with a new map
%   rewrites the manifest, which is seen), and a file rewritten with the
%   same size and modification time.
%
%   See also DatasetRuns, DatasetOutputs, epochMatrix, DatasetBrowser.

arguments
    out (1,1) DatasetOutputs
end

if isnat(out.LastRefreshed) && out.Name ~= ""
    out.refresh();
end
C = out.Candidates;
C = C(ismember(C.Kind, ["extract" "spikes" "behavior" "manifest" "artifacts"]), :);
lines = C.Kind + " " + leafName(C.File) + " " + compose("%.0f", C.Bytes) + " " + timeText(C.Modified);
lines = reshape(lines, [], 1);
lines(end+1, 1) = "spikes in effect: " + strjoin(leafName(out.SpikesFile), ", ");
lines(end+1, 1) = "extract in effect: " + strjoin(leafName(out.ExtractFiles), ", ");

sorted = false;
d = out.SortingDir;
if ~isempty(d) && d(1) ~= ""
    d = d(1);
    L = listFolder(d);
    names = string({L.name});
    if ~any(~[L.isdir] & lower(names) == "params.py") && any([L.isdir] & lower(names) == "kilosort4")
        L = listFolder(fullfile(d, "kilosort4"));   % a run folder: the phy output is in kilosort4\
    end
    F = L(~[L.isdir]);
    names = string({F.name});
    low = lower(names);
    sorted = any(low == "params.py");
    keep = ismember(low, ["params.py" "spike_times.npy" "spike_clusters.npy" "spike_templates.npy" ...
        "channel_map.npy" "channel_positions.npy" "channel_shanks.npy"]) ...
        | (startsWith(low, "cluster_") & endsWith(low, ".tsv"));
    F = F(keep);
    if ~isempty(F)
        when = datetime([F.datenum], 'ConvertFrom', 'datenum');
        lines = [lines; reshape("sorting " + string({F.name}) + " " + compose("%.0f", [F.bytes]) + " " + ...
            timeText(when), [], 1)];
    end
end
stamp = strjoin(sort(lines), newline);
end


function L = listFolder(d)
%listFolder  dir of folder D without . and .. (empty when it is not there).
L = dir(d);
L = L(~ismember({L.name}, {'.', '..'}));
end


function n = leafName(f)
%leafName  File names without their folders, in F's shape.
f = string(f);
n = f;
for k = 1:numel(f)
    [~, nm, ext] = fileparts(f(k));
    n(k) = nm + ext;
end
end


function s = timeText(t)
s = string(t, 'yyyy-MM-dd''T''HH:mm:ss.SSS');
s(ismissing(s)) = "NaT";
end
