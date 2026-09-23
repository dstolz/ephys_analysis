function T = planLocalCleanup(datasets, opts)
%planLocalCleanup  List the local files of datasets and which of them a clean up would remove.
%   T = planLocalCleanup(DATASETS) looks at every file in each dataset's
%   recording folder, output folder and sorted-output folder and returns one
%   row per file saying whether runLocalCleanup would remove it or keep it,
%   and why. Nothing is changed on disk: this is the preview.
%
%   What can be removed (Remove option; the first three by default)
%   To free space, keeping every output:
%     "raw"          the raw recording files that the Copy tab copied into the
%                    session folder (the recording files listed in its
%                    session_manifest.json). A file is removed only when its
%                    source, as recorded in that manifest, still exists and has
%                    the same size as the local file, so the recording can be
%                    copied back. A recording that was not copied by the Copy
%                    tab has no known source and is always kept. An Open
%                    Ephys recording that is one dataset of several in its
%                    session (a part folder) shares the session's files:
%                    they are not listed with it and never removed.
%     "sorter_copy"  Kilosort4's filtered copy of the recording (temp_wh.dat)
%                    under the dataset's kilosort4 folder or its
%                    sorted-output folder. The sorted units do not need it;
%                    phy's trace view does.
%     "bin"          the .bin toBin writes (the dataset's BinFile: <Name>.bin,
%                    or <Name>_ks4.bin when the recording's own data file is
%                    <Name>.bin) and its .json sidecar: the flat binary
%                    Kilosort4 sorts (never a raw recording file). As above,
%                    only phy's trace view needs it.
%   Everything one preprocessing step wrote (the step names of
%   EphysPipelineConfig.StepNames), to run the step again or drop it:
%     "sorting"      the dataset's kilosort4 folder (kilosortDir: the sorted
%                    units with their phy curation and unit notes, the run
%                    files and logs, Kilosort4's copy of the recording) and the
%                    .bin + .json of toBin. A sorted-output folder associated
%                    by hand (SortingDir, outside kilosort4) was not written by
%                    the step and is kept.
%     "signals"      the derived-signal .mat files (toMat)
%     "spikes"       the spikes .mat (spikesToMat)
%     "behavior"     <Name>_behavior.mat (behaviorToMat) and the digital
%                    events cache <Name>_events.mat (trial pairing)
%     "artifacts"    the artifact-interval cache <Name>_artifacts.json
%     "export"       the Chronux, FieldTrip and epochs .mat files
%   A .mat output is recognised by the variables it holds (DatasetOutputs),
%   so outputs with configured suffixes are found too, else by its default
%   name (<Name>_extract*, <Name>_spikes*, ...). Unfinished outputs that a
%   failed write left (~<name>.partial.mat) go with their step. The probe
%   step writes no file, and what the dataset manifest records (probe,
%   exclusions, trial pairing, a hand-picked sorted-output folder) stays.
%   Files another recording wrote are always kept: a .mat whose provenance
%   names another dataset or recording folder (DatasetOutputs.Foreign), and
%   the .bin and kilosort4 folder when the .bin's sidecar names another
%   recording folder (two recordings with the same name share
%   <OutputRoot>/<Name>).
%
%   Everything else is kept: the outputs of the steps not selected, the
%   dataset and copy manifests, the clean-up record, the Epsych2 session
%   file and any other file. Removing the raw recording means the pipeline
%   can no longer read the dataset (Signals, Sorting, Spikes, Visualize,
%   Scan) until it is copied back; the outputs already written are
%   unaffected.
%
%   Options
%     Remove      (1,:) string, a subset of ["raw" "sorter_copy" "bin"
%                 "sorting" "signals" "spikes" "behavior" "artifacts"
%                 "export"] (default ["raw" "sorter_copy" "bin"]). Files of
%                 the other kinds are kept.
%     SearchDirs  (1,:) string, more folders holding step outputs (the
%                 config's Signals / Spikes / Export OutputDir). The
%                 datasets' outputs found there are listed too; their other
%                 files are not.
%
%   T has one row per file:
%     Dataset    dataset Name
%     Folder     the dataset's recording folder (where the clean-up record goes)
%     Action     "remove" | "keep"
%     Category   "raw" | "sorter_copy" | "bin" | "epsych" | "copy_record" |
%                "manifest" | "sorting" | "output" | "other"
%     Step       the preprocessing step that wrote the file ("" for none)
%     What       what the file is, in words
%     File       full path
%     Bytes      its size now
%     Source     for a raw file copied by the Copy tab, its source ("" otherwise)
%     Reason     why it is removed or kept
%     Root       the folder the file lies under: the dataset's recording or
%                output folder, or the search folder it was found in.
%                runLocalCleanup moves a file to <Destination>/<Key>/<its path
%                below Root> and removes the folders it empties below Root.
%     Key        the dataset's DatasetKey (its folder below the project
%                root), else its Name
%
%   See also runLocalCleanup, copySessions, EphysDataset, DatasetOutputs.

arguments
    datasets EphysDataset
    opts.Remove (1,:) string {mustBeMember(opts.Remove, ["raw" "sorter_copy" "bin" ...
        "sorting" "signals" "spikes" "behavior" "artifacts" "export"])} = ["raw" "sorter_copy" "bin"]
    opts.SearchDirs (1,:) string = string.empty(1, 0)
end

searchDirs = opts.SearchDirs(strlength(strtrim(opts.SearchDirs)) > 0);
T = emptyPlan();
for d = datasets(:).'
    T = [T; planDataset(d, opts.Remove, searchDirs)]; %#ok<AGROW>
end
end


function T = planDataset(d, remove, searchDirs)
folder = string(d.Folder);
outDir = string(d.outputFolder());
ksDir  = string(d.kilosortDir());
sortDir = string(d.sortingResultsDir());
name = string(d.Name);
key = string(d.DatasetKey);
if key == ""; key = name; end

[outputKind, found, foreign] = datasetOutputs(d, searchDirs);
files = addFiles(listFiles(unique([folder outDir ksDir sortDir], 'stable')), found);
n = numel(files);
T = emptyPlan();
if n == 0; return; end

copied = copyRecord(folder);
rawNames = rawRecordingNames(d);
roots = [folder outDir searchDirs];
[~, binStem] = fileparts(d.BinFile);    % <Name>, or <Name>_ks4 beside a recording file <Name>.bin
otherSort = sortSource(d);              % the recording folder another dataset's .bin and sort came from

rows = cell(n, 1);
for k = 1:n
    f = files(k);
    r = struct('Dataset', name, 'Folder', folder, 'Action', "keep", 'Category', "other", 'Step', "", ...
        'What', "Other file", 'File', f.path, 'Bytes', f.bytes, 'Source', "", 'Reason', "", ...
        'Root', "", 'Key', key);
    [p, base, ext] = fileparts(f.path);
    leaf = base + ext;
    r.Root = rootOf(p, roots, sortDir);
    inFolder = samePath(p, folder);
    fileKey = lower(f.path);
    rel = "";   % the path below the recording folder, as the reader lists its files
    if under(p, folder)
        rel = lower(replace(extractAfter(f.path, strlength(stripSep(folder)) + 1), "\", "/"));
    end

    if isKey(copied.raw, fileKey)
        src = copied.raw(fileKey);
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
    elseif (inFolder && any(lower(ext) == [".rhd" ".rhs" ".dat"])) || any(rel == rawNames)
        r.Category = "raw"; r.What = "Raw recording";
        r.Reason = "Not copied by the Copy tab (no session_manifest.json lists it), so no source copy is known.";
    elseif isKey(foreign, char(fileKey))
        r.Category = "output"; r.What = "Another dataset's output";
        r.Reason = "Its provenance names another dataset or recording folder, so it is not this dataset's to remove.";
    elseif otherSort ~= "" && (under(p, ksDir) || (samePath(p, outDir) ...
            && any(lower(leaf) == lower(binStem + [".bin" ".json"]))))
        r.Category = "sorting"; r.What = "Another recording's sort or .bin";
        r.Reason = "Written for " + otherSort + ", which shares this output folder (the same name), so it is kept.";
    elseif lower(leaf) == "temp_wh.dat" && (under(p, ksDir) || under(p, sortDir))
        r.Category = "sorter_copy"; r.What = "Kilosort4's filtered copy of the recording";
        if under(p, ksDir); r.Step = "sorting"; end
        if any(remove == "sorter_copy")
            r.Action = "remove";
            r.Reason = "The sorted units do not need it; phy's trace view does.";
        elseif r.Step ~= "" && any(remove == r.Step)
            r = removeWithStep(r);
        else
            r.Reason = "Kilosort4's copy of the recording is not selected for removal.";
        end
    elseif samePath(p, outDir) && any(lower(leaf) == lower(binStem + [".bin" ".json"])) ...
            && (isfile(d.BinFile) || isBinSidecar(f.path))
        r.Category = "bin"; r.What = "Sorting input .bin (toBin)"; r.Step = "sorting";
        if any(remove == "bin")
            r.Action = "remove";
            r.Reason = "The flat binary Kilosort4 sorted; the sorted units do not need it, phy's trace view does.";
        elseif any(remove == r.Step)
            r = removeWithStep(r);
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
    elseif under(p, ksDir)
        r.Category = "sorting"; r.What = "Sorted output / sorting run file"; r.Step = "sorting";
        if any(remove == r.Step); r = removeWithStep(r); end
    elseif under(p, sortDir)
        r.Category = "sorting"; r.What = "Sorted output associated by hand";
        if any(remove == "sorting")
            r.Reason = "A sorted-output folder chosen by hand (SortingDir), not written by the Sorting step: it is kept.";
        end
    else
        kind = "";
        if isKey(outputKind, char(fileKey)); kind = outputKind(char(fileKey)); end
        partial = startsWith(lower(leaf), "~" + lower(name) + "_") && endsWith(lower(leaf), ".partial.mat");
        if kind == "" && (partial || startsWith(lower(leaf), lower(name) + "_"))
            kind = "other";
            if partial || any(lower(ext) == [".mat" ".json"])
                byName = nameKind(lower(extractAfter(leaf, strlength(name) + 1 + partial)));
                if byName ~= ""; kind = byName; end
            end
        end
        if kind ~= ""
            [r.What, r.Step] = outputWhat(kind);
            r.Category = "output";
            if partial; r.What = "Unfinished " + lower(extractBefore(r.What, 2)) + extractAfter(r.What, 1) + " (a failed write)"; end
            if r.Step ~= "" && any(remove == r.Step); r = removeWithStep(r); end
        end
    end
    rows{k} = r;
end
T = struct2table(vertcat(rows{:}), 'AsArray', true);
T = sortrows(T, {'Action', 'Bytes'}, {'descend', 'descend'});   % "remove" before "keep", largest first
end


function r = removeWithStep(r)
r.Action = "remove";
r.Reason = "Written by the " + stepTitle(r.Step) + " step, whose output is selected for removal.";
end


function t = stepTitle(step)
t = upper(extractBefore(step, 2)) + extractAfter(step, 1);
end


function [what, step] = outputWhat(kind)
%outputWhat  Words for an output of KIND (a DatasetOutputs kind, or "events") and the step that writes it.
switch kind
    case "extract";   what = "Signals output (extract)"; step = "signals";
    case "spikes";    what = "Spikes output";            step = "spikes";
    case "behavior";  what = "Behavior output";          step = "behavior";
    case "events";    what = "Digital events cache";     step = "behavior";
    case "artifacts"; what = "Artifact cache";           step = "artifacts";
    case "chronux";   what = "Chronux export";           step = "export";
    case "fieldtrip"; what = "FieldTrip export";         step = "export";
    case "epochs";    what = "Epochs export";            step = "export";
    otherwise;        what = "Pipeline output";          step = "";
end
end


function kind = nameKind(rest)
%nameKind  The output kind a <Name>_<rest> file's default name gives ("" = none).
kind = "";
for k = ["extract" "spikes" "behavior" "events" "artifacts" "chronux" "fieldtrip" "epochs"]
    if startsWith(rest, k); kind = k; return; end
end
end


function [kind, found, foreign] = datasetOutputs(d, searchDirs)
%datasetOutputs  The dataset's outputs found by DatasetOutputs (file -> kind), their
%   files, and the files it skipped as another dataset's (a set of lower-case paths).
kind = containers.Map('KeyType', 'char', 'ValueType', 'any');
foreign = containers.Map('KeyType', 'char', 'ValueType', 'logical');
found = struct('path', {}, 'bytes', {});
ws = warning('off');   % a .mat it cannot read is not classified; no need to say so here
restoreWarnings = onCleanup(@() warning(ws));
try
    O = DatasetOutputs(d, SearchDirs=searchDirs);
catch
    return
end
C = O.Candidates;
for k = 1:height(C)
    kind(char(lower(C.File(k)))) = C.Kind(k);
    found(end+1) = struct('path', C.File(k), 'bytes', C.Bytes(k)); %#ok<AGROW>
end
for f = O.Foreign.'
    foreign(char(lower(f))) = true;
end
end


function tf = isBinSidecar(file)
%isBinSidecar  True for toBin's JSON sidecar (it names the .bin and its channel count).
m = readJsonFile(file, ErrorOnFail=false);
tf = isstruct(m) && isfield(m, 'n_chan_bin') && isfield(m, 'bin_file');
end


function folder = sortSource(d)
%sortSource  The recording folder the .bin in D's output folder came from, when
%   it is another recording's ("" otherwise): its toBin sidecar records it. Two
%   recordings with the same name share <OutputRoot>/<Name>, and whichever
%   sorted last wrote the .bin and the kilosort4 folder there.
folder = "";
[p, stem] = fileparts(d.BinFile);
m = readJsonFile(fullfile(p, stem + ".json"), ErrorOnFail=false);
if isstruct(m) && isfield(m, 'n_chan_bin') && isfield(m, 'source_folder') ...
        && strlength(string(m.source_folder)) > 0 && ~d.isOwnSource(string(m.source_folder))
    folder = string(m.source_folder);
end
end


function root = rootOf(p, roots, sortDir)
%rootOf  The deepest of ROOTS holding folder P, else SORTDIR, else P itself.
root = "";
for c = roots
    if under(p, c) && strlength(stripSep(c)) > strlength(root)
        root = stripSep(c);
    end
end
if root == "" && under(p, sortDir); root = stripSep(sortDir); end
if root == ""; root = stripSep(p); end
end


function c = copyRecord(folder)
%copyRecord  The raw files (local path -> source) and Epsych2 file names from session_manifest.json.
c = struct('raw', containers.Map('KeyType', 'char', 'ValueType', 'any'), 'epsych', strings(1, 0));
m = readJsonFile(fullfile(folder, "session_manifest.json"), ErrorOnFail=false);
if ~isstruct(m); return; end
if isfield(m, 'recording') && isfield(m.recording, 'files')
    recs = m.recording.files;
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
%rawRecordingNames  Files the dataset's reader counts as its recording, relative
%   to its folder, lower case with "/" separators (Open Ephys lists paths
%   below the session folder).
names = lower(replace(string(d.Files), "\", "/"));
names = names(:).';
if isempty(names); names = strings(1, 0); end
end


function files = listFiles(roots)
%listFiles  Every file under ROOTS (recursive), each once.
files = struct('path', {}, 'bytes', {});
for root = roots
    if root == "" || ~isfolder(root); continue; end
    D = dir(fullfile(root, "**", "*"));
    D = D(~[D.isdir]);
    for k = 1:numel(D)
        files(end+1) = struct('path', string(fullfile(D(k).folder, D(k).name)), 'bytes', D(k).bytes); %#ok<AGROW>
    end
end
files = addFiles(struct('path', {}, 'bytes', {}), files);
end


function files = addFiles(files, more)
%addFiles  FILES plus those of MORE not in it yet (paths compared without case).
seen = strings(1, 0);
if ~isempty(files); seen = lower([files.path]); end
for f = more(:).'
    if any(seen == lower(f.path)); continue; end
    seen(end+1) = lower(f.path); %#ok<AGROW>
    files(end+1) = f; %#ok<AGROW>
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
T = table(strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), ...
    strings(0, 1), zeros(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), ...
    'VariableNames', {'Dataset', 'Folder', 'Action', 'Category', 'Step', 'What', 'File', 'Bytes', ...
    'Source', 'Reason', 'Root', 'Key'});
end
