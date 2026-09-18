function T = planLocalCleanup(datasets, opts)
%planLocalCleanup  List the local files of datasets and which of them a clean up would remove.
%   T = planLocalCleanup(DATASETS) looks at every file in each dataset's
%   recording folder, output folder and sorted-output folder and returns one
%   row per file saying whether runLocalCleanup would remove it or keep it,
%   and why. Nothing is changed on disk: this is the preview.
%
%   What can be removed (Remove option; all three by default)
%     "raw"          the raw recording files that the Copy tab copied into the
%                    session folder (the Intan files listed in its
%                    session_manifest.json). A file is removed only when its
%                    source, as recorded in that manifest, still exists and has
%                    the same size as the local file, so the recording can be
%                    copied back. A recording that was not copied by the Copy
%                    tab has no known source and is always kept.
%     "sorter_copy"  Kilosort4's filtered copy of the recording (recording.dat,
%                    temp_wh.dat) under the dataset's kilosort4 folder or its
%                    sorted-output folder. The sorted units do not need it;
%                    phy's trace view does.
%     "bin"          <Name>.bin and its <Name>.json sidecar written by toBin: the
%                    flat binary the native Kilosort engine sorts (never a raw
%                    recording file). As above, only phy's trace view needs it.
%
%   Everything else is kept: the pipeline outputs (extract, spikes, behavior,
%   Chronux, FieldTrip, events and artifact files), the sorted output, the
%   dataset and copy manifests, the Epsych2 session file and any other file.
%   Removing the raw recording means the pipeline can no longer read the
%   dataset (Signals, Sorting, Spikes, Visualize, Scan) until it is copied
%   back; the outputs already written are unaffected.
%
%   Options
%     Remove  (1,:) string, a subset of ["raw" "sorter_copy" "bin"]
%             (default all three). Files of the other kinds are kept.
%
%   T has one row per file:
%     Dataset    dataset Name
%     Folder     the dataset's recording folder (where the clean-up record goes)
%     Action     "remove" | "keep"
%     Category   "raw" | "sorter_copy" | "bin" | "epsych" | "copy_record" |
%                "manifest" | "sorting" | "output" | "other"
%     What       what the file is, in words
%     File       full path
%     Bytes      its size now
%     Source     for a raw file copied by the Copy tab, its source ("" otherwise)
%     Reason     why it is removed or kept
%
%   See also runLocalCleanup, copySessions, EphysDataset.

arguments
    datasets EphysDataset
    opts.Remove (1,:) string {mustBeMember(opts.Remove, ["raw" "sorter_copy" "bin"])} = ["raw" "sorter_copy" "bin"]
end

T = emptyPlan();
for d = datasets(:).'
    T = [T; planDataset(d, opts.Remove)]; %#ok<AGROW>
end
end


function T = planDataset(d, remove)
folder = string(d.Folder);
outDir = string(d.outputFolder());
ksDir  = string(d.kilosortDir());
sortDir = string(d.sortingResultsDir());
name = string(d.Name);

files = listFiles(unique([folder outDir ksDir sortDir], 'stable'));
n = numel(files);
T = emptyPlan();
if n == 0; return; end

copied = copyRecord(folder);
rawNames = rawRecordingNames(d);

rows = cell(n, 1);
for k = 1:n
    f = files(k);
    r = struct('Dataset', name, 'Folder', folder, 'Action', "keep", 'Category', "other", ...
        'What', "Other file", 'File', f.path, 'Bytes', f.bytes, 'Source', "", 'Reason', "");
    [p, base, ext] = fileparts(f.path);
    leaf = base + ext;
    inFolder = samePath(p, folder);
    key = lower(f.path);

    if isKey(copied.raw, key)
        src = copied.raw(key);
        r.Category = "raw"; r.What = "Raw recording"; r.Source = src;
        if ~any(remove == "raw")
            r.Reason = "Raw recording files are not selected for removal.";
        else
            s = dir(src);
            if ~isscalar(s) || s.isdir
                r.Reason = "Not found at its source " + src + " (the source may be offline), so there would be no copy left.";
            elseif s.bytes ~= f.bytes
                r.Reason = sprintf("Its source %s is %s, the local file %s: they differ.", src, sizeText(s.bytes), sizeText(f.bytes));
            else
                r.Action = "remove";
                r.Reason = "A copy of the same size is at " + src + ".";
            end
        end
    elseif inFolder && (any(lower(leaf) == lower(rawNames)) || any(lower(ext) == [".rhd" ".rhs" ".dat"]))
        r.Category = "raw"; r.What = "Raw recording";
        r.Reason = "Not copied by the Copy tab (no session_manifest.json lists it), so no source copy is known.";
    elseif any(lower(leaf) == ["recording.dat" "temp_wh.dat"]) && (under(p, ksDir) || under(p, sortDir))
        r.Category = "sorter_copy"; r.What = "Kilosort4's filtered copy of the recording";
        if any(remove == "sorter_copy")
            r.Action = "remove";
            r.Reason = "The sorted units do not need it; phy's trace view does.";
        else
            r.Reason = "Kilosort4's copy of the recording is not selected for removal.";
        end
    elseif samePath(p, outDir) && any(lower(leaf) == lower(name + [".bin" ".json"])) && isfile(fullfile(outDir, name + ".bin"))
        r.Category = "bin"; r.What = "Sorting input .bin (toBin)";
        if any(remove == "bin")
            r.Action = "remove";
            r.Reason = "The flat binary the native Kilosort engine sorted; the sorted units do not need it, phy's trace view does.";
        else
            r.Reason = "The sorting input .bin is not selected for removal.";
        end
    elseif inFolder && any(lower(leaf) == ["session_manifest.json" "session_copy_robocopy.log"])
        r.Category = "copy_record"; r.What = "Copy record (where the raw files came from)";
    elseif inFolder && any(lower(leaf) == lower(copied.epsych))
        r.Category = "epsych"; r.What = "Epsych2 session";
    elseif lower(leaf) == lower(name + "_manifest.json") || lower(leaf) == lower(name + "_cleanup.json")
        r.Category = "manifest"; r.What = "Dataset manifest";
        if endsWith(lower(leaf), "_cleanup.json"); r.What = "Clean-up record"; end
    elseif under(p, ksDir) || under(p, sortDir)
        r.Category = "sorting"; r.What = "Sorted output / sorting run file";
    elseif startsWith(lower(leaf), lower(name) + "_")
        r.Category = "output"; r.What = outputWhat(lower(extractAfter(leaf, strlength(name) + 1)));
    end
    rows{k} = r;
end
T = struct2table(vertcat(rows{:}), 'AsArray', true);
T = sortrows(T, {'Action', 'Bytes'}, {'descend', 'descend'});   % "remove" before "keep", largest first
end


function w = outputWhat(rest)
%outputWhat  Words for a <Name>_<rest> pipeline output.
if startsWith(rest, "extract");       w = "Signals output (extract)";
elseif startsWith(rest, "spikes");    w = "Spikes output";
elseif startsWith(rest, "behavior");  w = "Behavior output";
elseif startsWith(rest, "events");    w = "Digital events cache";
elseif startsWith(rest, "artifacts"); w = "Artifact cache";
elseif startsWith(rest, "chronux");   w = "Chronux export";
elseif startsWith(rest, "fieldtrip"); w = "FieldTrip export";
else;                                 w = "Pipeline output";
end
end


function c = copyRecord(folder)
%copyRecord  The raw files (local path -> source) and Epsych2 file names from session_manifest.json.
c = struct('raw', containers.Map('KeyType', 'char', 'ValueType', 'any'), 'epsych', strings(1, 0));
m = readJsonFile(fullfile(folder, "session_manifest.json"), ErrorOnFail=false);
if ~isstruct(m); return; end
if isfield(m, 'intan') && isfield(m.intan, 'files')
    recs = m.intan.files;
    if iscell(recs); recs = [recs{:}]; end
    for rec = recs(:).'
        if ~isfield(rec, 'relativePath') || ~isfield(rec, 'source'); continue; end
        local = string(fullfile(folder, string(rec.relativePath)));
        c.raw(char(lower(local))) = string(rec.source);
    end
end
if isfield(m, 'epsych') && isfield(m.epsych, 'destFile') && string(m.epsych.destFile) ~= ""
    [~, b, e] = fileparts(string(m.epsych.destFile));
    c.epsych = b + e;
end
end


function names = rawRecordingNames(d)
%rawRecordingNames  File names the dataset's reader counts as its recording.
names = string(d.Files);
names = names(:).';
if isempty(names); names = strings(1, 0); end
end


function files = listFiles(roots)
%listFiles  Every file under ROOTS (recursive), each once.
files = struct('path', {}, 'bytes', {});
seen = strings(0, 1);
for root = roots
    if root == "" || ~isfolder(root); continue; end
    D = dir(fullfile(root, "**", "*"));
    D = D(~[D.isdir]);
    for k = 1:numel(D)
        p = string(fullfile(D(k).folder, D(k).name));
        if any(seen == lower(p)); continue; end
        seen(end+1, 1) = lower(p); %#ok<AGROW>
        files(end+1) = struct('path', p, 'bytes', D(k).bytes); %#ok<AGROW>
    end
end
end


function tf = samePath(a, b)
tf = b ~= "" && strcmpi(stripSep(a), stripSep(b));
end


function tf = under(p, root)
%under  True when folder P is ROOT or inside it.
tf = false;
if root == ""; return; end
p = stripSep(p); root = stripSep(root);
tf = strcmpi(p, root) || startsWith(lower(p), lower(root) + filesep);
end


function s = stripSep(s)
s = string(s);
s = strip(strrep(s, "/", filesep), 'right', filesep);
end


function s = sizeText(bytes)
if bytes >= 1024^3;     s = sprintf("%.2f GB", bytes / 1024^3);
elseif bytes >= 1024^2; s = sprintf("%.1f MB", bytes / 1024^2);
else;                   s = sprintf("%d bytes", bytes);
end
end


function T = emptyPlan()
T = table(strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), ...
    strings(0, 1), zeros(0, 1), strings(0, 1), strings(0, 1), ...
    'VariableNames', {'Dataset', 'Folder', 'Action', 'Category', 'What', 'File', 'Bytes', 'Source', 'Reason'});
end
