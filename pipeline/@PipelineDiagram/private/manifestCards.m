function [C, E] = manifestCards(m, defaultProbe)
%manifestCards  What PipelineDiagram.manifest draws of a decoded manifest M.
%   [C, E] = manifestCards(M, DEFAULTPROBE) returns a card per box and an edge
%   per read. Each card holds its place on the grid and what each level of
%   detail adds:
%     steps        title, badge (whether it ran, whether its file is still there)
%     outputs      lines, warn, pills: the result in short, and the files written
%     settings     key: the few settings that decide the result, [name value]
%     parameters   all: every value the manifest holds about it, [name value];
%                  a row ["#" label] starts a group
%   An edge is on when the record of the step that reads says it read it.
%
%   The grid, five columns wide. Each row reads only from those above it, and
%   a column keeps a line of work together (the .bin over its sort):
%     0  Behavior session     Raw recording            Probe map
%     1  Behavior             Artifacts
%     2       Signals                      Sorting .bin    Spikes
%     3                                    Sort
%     4                  NWB export
%
%   See also PipelineDiagram.manifest, ManifestText, gridPlace.

P = ManifestText.field(m, 'processing', struct());
C = [sessionCard(m), recordingCard(m), probeCard(m, defaultProbe), behaviorCard(m, P), ...
    artifactsCard(m, P), signalsCard(P), binCard(m, P), spikesCard(P), sortCard(m, P), exportCard(P)];
E = edgeList(m, P);
end


% =========================================================================
% the cards
% =========================================================================

function c = sessionCard(m)
b = ManifestText.field(m, 'behavior', struct());
f = ManifestText.text(ManifestText.field(b, 'file', ""));
c = card("epsych", 0, 0, "in", "Behavior session");
c = fileBadge(c, f, "file");
if c.badge == "written"; c.badge = ""; end   % an input, nothing wrote it
if f == ""
    c.badge = "none";
    c.dim = true;
    return
end
c.lines = fileName(f);
c.lines(end+1) = joinParts([fieldText(b, 'subject'), fieldText(b, 'n_trials', " trials")]);
c.key = [kv("Started", fieldText(b, 'start_time')); kv("Subject", fieldText(b, 'subject'))];
if isfield(b, 'pairing'); b = rmfield(b, 'pairing'); end   % drawn on the Behavior box
c.all = flatRows(b, "");
end


function c = recordingCard(m)
md = ManifestText.field(m, 'metadata', struct());
c = card("rec", 0, 2, "src", "Raw recording");
c = fileBadge(c, ManifestText.text(ManifestText.field(m, 'folder', "")), "folder");
if c.badge == "written"; c.badge = ""; end
c.lines = ManifestText.text(ManifestText.field(m, 'name', ""));
fs = ManifestText.number(ManifestText.field(md, 'fs', NaN));
parts = [fieldText(md, 'num_channels', " ch"), ternaryText(isnan(fs), "", sprintf("%g kHz", fs / 1000))];
dur = ManifestText.number(ManifestText.field(md, 'duration_s', NaN));
if ~isnan(dur)
    parts(end+1) = string(duration(0, 0, dur, 'Format', 'hh:mm:ss'));
end
if any(parts ~= ""); c.lines(end+1) = joinParts(parts); end
tags = TagSet.toText(tagsOf(m), TagSet.DisplayDelimiter);
if tags ~= ""; c.lines(end+1) = "tags: " + tags; end
c.key = [kv("Format", fieldText(m, 'recording_format')); kv("Reader", fieldText(m, 'reader')); ...
    kv("Acquired", fieldText(md, 'acq_date')); kv("Files", fieldText(md, 'num_files')); ...
    kv("Manifest updated", fieldText(m, 'updated'))];

c.all = flatRows(rmfieldIf(m, ["metadata" "probe" "exclude_channels" "reference_exclude" "bad_channels" ...
    "manual_artifacts" "artifact_adjustments" "artifacts" "bin" "processing" "kilosort" "sorting" "behavior"]), "");
c.all = [["#" "recording"]; flatRows(md, ""); c.all];
end


function c = probeCard(m, defaultProbe)
pr = ManifestText.field(m, 'probe', struct());
f = ManifestText.text(ManifestText.field(pr, 'file', ""));
c = card("probemap", 0, 4, "in", "Probe map");
if f ~= ""
    c = fileBadge(c, f, "file");
    if c.badge == "written"; c.badge = ""; end
    c.lines = fileName(f);
    c.lines(end+1) = joinParts([fieldText(pr, 'num_channels', " ch"), fieldText(pr, 'num_shanks', " shank(s)")]);
elseif defaultProbe ~= ""
    % The default is used, never assigned (EphysPipeline.probeFor).
    c = fileBadge(c, defaultProbe, "file");
    c.badge = ternaryText(c.badge == "written", "default", c.badge);
    c.lines = fileName(defaultProbe);
else
    c.badge = "none";
    c.dim = true;
end
ex = ManifestText.text(ManifestText.field(m, 'exclude_channels', ""));
re = ManifestText.text(ManifestText.field(m, 'reference_exclude.channels', ""));
bad = ManifestText.text(ManifestText.field(m, 'bad_channels.channels', ""));
counts = [countOf(ex, "excluded"), countOf(re, "left out of the reference"), countOf(bad, "bad")];
if any(counts ~= ""); c.lines(end+1) = joinParts(counts); end
c.key = [kv("Excluded", ex); kv("Left out of the reference", re); kv("Bad channels", bad); ...
    kv("Depth (µm)", fieldText(pr, 'depth_um'))];
c.all = groupRows("probe", pr);
c.all = [c.all; kv("exclude_channels", ex, true)];
c.all = [c.all; groupRows("reference_exclude", ManifestText.field(m, 'reference_exclude', struct()))];
c.all = [c.all; groupRows("bad_channels", ManifestText.field(m, 'bad_channels', struct()))];
end


function c = behaviorCard(m, P)
r = ManifestText.field(P, 'behavior', []);
c = card("behavior", 1, 0, "step", "Behavior");
c = recordBadge(c, r, "file");
pa = ManifestText.field(m, 'behavior.pairing', []);
if isstruct(pa) && isscalar(pa)
    % The pairing is in the manifest before any file is written from it.
    st = ManifestText.text(ManifestText.field(pa, 'status', ""));
    c.dim = false;
    if c.badge == "not run"; c.badge = "paired"; c.badgeClass = ""; end
    how = ternaryText(isequal(ManifestText.field(pa, 'auto_approved', false), true), ", automatically", "");
    c.pills = pill("Trial pairing", [st + how, ManifestText.text(ManifestText.field(pa, 'summary', ""))]);
    if st ~= "approved"; c.warn(end+1) = "trial pairing " + st + ": review it on the Trials tab"; end
    c.key = [kv("Trial line", fieldText(pa, 'trial_line')); ...
        kv("Cut trials [start end]", ManifestText.value(reshape(ManifestText.field(pa, 'cut_trials', []), 1, []))); ...
        kv("Cut intervals [start end]", ManifestText.value(reshape(ManifestText.field(pa, 'cut_intervals', []), 1, [])))];
    c.all = groupRows("pairing", pa);
end
if isRecord(r)
    n = fieldText(r, 'n_trials', " trials");
    c.pills = [c.pills, filePill("Behavior file", r, "file", n)];
    c.lines = writtenLine(r);
    c.key = [c.key; kv("Derived events", ManifestText.value(ManifestText.field(r, 'derived_events', [])))];
    fail = ManifestText.field(r, 'derived_failed', []);
    if ~isempty(fail); c.warn(end+1) = sprintf("%d derived event(s) could not be made", numel(string(fail))); end
    c.all = [recordRows(r); c.all];
end
end


function c = artifactsCard(m, P)
r = ManifestText.field(P, 'artifacts', []);
a = ManifestText.field(m, 'artifacts', struct());
ma = countRows(ManifestText.field(m, 'manual_artifacts', []), 2);
aa = countRows(ManifestText.field(m, 'artifact_adjustments', []), 4);
c = card("artifacts", 1, 2, "step", "Artifacts");
c = recordBadge(c, r, "file");
if ~isRecord(r) && ma > 0
    c.badge = "manual only";
    c.badgeClass = "";
    c.dim = false;
end
nd = ManifestText.number(ManifestText.field(a, 'detected', NaN));
if isnan(nd); nd = ManifestText.number(ManifestText.field(r, 'detected', NaN)); end
ds = ManifestText.number(ManifestText.field(a, 'detected_s', NaN));
if isnan(ds); ds = ManifestText.number(ManifestText.field(r, 'detected_s', NaN)); end
parts = strings(1, 0);
if ~isnan(nd); parts(end+1) = sprintf("%g detected", nd) + ternaryText(isnan(ds), "", sprintf(" (%.3g s)", ds)); end
parts(end+1) = sprintf("%d manual", ma);
if aa > 0; parts(end+1) = sprintf("%d moved by hand", aa); end
if ~c.dim
    c.pills = pill("Artifact periods", joinParts(parts), "link");
    c.pills.dim = false;
end
if isRecord(r)
    c.lines = writtenLine(r);
    o = ManifestText.field(r, 'options', struct());
    c.key = [kv("Method", fieldText(o, 'Method')); kv("Threshold", fieldText(o, 'Threshold')); ...
        kv("Min channels", fieldText(o, 'MinChannels')); kv("Pad (ms)", fieldText(o, 'PadMs')); ...
        kv("Merge gap (ms)", fieldText(o, 'MergeGapMs')); ...
        kv("Reference", ManifestText.reference(ManifestText.field(r, 'reference', struct()))); ...
        kv("Channels", fieldText(r, 'channels'))];
end
hd = ManifestText.field(a, 'handling', []);
if isstruct(hd) && isscalar(hd)
    for s = ["sorting" "spikes" "signals"]
        t = ManifestText.text(ManifestText.field(hd, s + ".treatment", ""));
        per = ManifestText.text(ManifestText.field(hd, s + ".periods", ""));
        if per ~= ""; t = t + " (" + per + ")"; end
        c.key = [c.key; kv("Handling: " + s, t)];
    end
end
if isRecord(r); c.all = recordRows(r); end
c.all = [c.all; groupRows("manifest", rmfieldIf(a, "file"))];
c.all = [c.all; kv("manual_artifacts", ManifestText.value(ManifestText.field(m, 'manual_artifacts', [])), true)];
c.all = [c.all; kv("artifact_adjustments", ManifestText.value(ManifestText.field(m, 'artifact_adjustments', [])), true)];
end


function c = signalsCard(P)
r = ManifestText.field(P, 'signals', []);
c = card("signals", 2, 1, "step", "Signals");
c = recordBadge(c, r, "files");
if ~isRecord(r); return; end
c.lines = writtenLine(r);
c.pills = filePill("Signal files", r, "files");
o = ManifestText.field(r, 'options', struct());
types = ManifestText.value(ManifestText.field(r, 'types', []));
c.key = [kv("Types", types); ...
    kv("Reference", ManifestText.reference(ManifestText.field(r, 'reference', struct()))); ...
    kv("Original rate (Hz)", fieldText(r, 'orig_fs'))];
for t = ["LFP" "MUA" "SPIKE"]
    if contains(types, t)
        c.key = [c.key; kv(t + " rate (Hz)", fieldText(o, t + "_Fs")); kv(t + " band (Hz)", fieldText(o, t + "_bpLoHi"))];
    end
end
c.key = [c.key; kv("LFP notch (Hz)", fieldText(o, 'LFP_NotchHz')); ...
    kv("LFP filter", fieldText(r, 'lfp_filter')); ...
    kv("Periods erased", fieldText(r, 'artifacts.periods')); ...
    kv("Erased (s)", fieldText(r, 'artifacts.erased_s')); ...
    kv("Bad channels", fieldText(r, 'bad_channels.channels'))];
c.all = recordRows(r);
end


function c = binCard(m, P)
r = ManifestText.field(P, 'bin', []);
c = card("bin", 2, 3, "step", "Sorting .bin");
c = recordBadge(c, r, "file");
if ~isRecord(r)
    % A .bin there without a record: written before the records, or by hand.
    f = ManifestText.text(ManifestText.field(m, 'bin.file', ""));
    if f ~= "" && isfile(f)
        c.badge = "on disk";
        c.dim = false;
        c.pills = pill(".bin", fileName(f));
    end
    return
end
c.lines = writtenLine(r);
c.pills = filePill(".bin", r, "file");
o = ManifestText.field(r, 'options', struct());
c.key = [kv("Reference", ManifestText.reference(ManifestText.field(r, 'reference', struct()))); ...
    kv("Filter", fieldText(r, 'filter')); kv("Data type", fieldText(o, 'Dtype')); kv("Scale", fieldText(o, 'Scale')); ...
    kv("Artifact fill", fieldText(r, 'artifacts.fill')); kv("Erased (s)", fieldText(r, 'artifacts.erased_s')); ...
    kv("Noise band (Hz)", fieldText(o, 'NoiseBandHz')); kv("Samples clipped", fieldText(r, 'n_clipped'))];
c.all = recordRows(r);
end


function c = spikesCard(P)
r = ManifestText.field(P, 'spikes', []);
c = card("spikes", 2, 4, "step", "Spikes");
c = recordBadge(c, r, "file");
if ~isRecord(r); return; end
c.lines = writtenLine(r);
c.pills = filePill("Spikes file", r, "file", fieldText(r, 'artifacts.rejected', " events rejected"));
o = ManifestText.field(r, 'options', struct());
c.key = [kv("Method", fieldText(o, 'ThresholdMethod')); kv("Threshold", fieldText(r, 'threshold_input')); ...
    kv("Polarity", fieldText(o, 'Polarity')); kv("Band (Hz)", fieldText(o, 'Band')); ...
    kv("Min period (ms)", fieldText(o, 'MinPeriodMs')); kv("Align", fieldText(o, 'Align')); ...
    kv("Artifacts", fieldText(r, 'artifacts.mode')); ...
    kv("Reference", ManifestText.reference(ManifestText.field(r, 'reference', struct()))); ...
    kv("Coincidence", fieldText(r, 'coincidence.mode')); kv("Channels", fieldText(r, 'channels'))];
c.all = recordRows(r);
end


function c = sortCard(m, P)
r = ManifestText.field(P, 'sorting', []);
so = ManifestText.field(m, 'sorting', struct());
ks = ManifestText.field(m, 'kilosort', struct());
c = card("sorting", 3, 3, "step", "Sort");
dir_ = ManifestText.text(ManifestText.field(so, 'results_dir', ""));
has = isequal(ManifestText.field(so, 'exists', false), true) && dir_ ~= "";
if isRecord(r)
    c = recordBadge(c, r, "results_dir");
    if ~has
        % Set up without results yet: a dry run, or a sort still running.
        st = ManifestText.text(ManifestText.field(ks, 'state', ""));
        c.badge = ternaryText(st == "", "no results", st);
        c.badgeClass = "warn";
    end
elseif has
    c.badge = "imported";   % sorted output with no record of how it was made
else
    c.badge = "not run";
    c.dim = true;
end
if has
    c.pills = pill("Sorted units", [fileName(dir_), fieldText(so, 'num_units', " units")]);
    c.pills(2) = pill("Curated in phy", ternaryText(isequal(ManifestText.field(so, 'curated', false), true), "yes", "no"));
end
if isRecord(r)
    c.lines = writtenLine(r);
    o = ManifestText.field(r, 'options', struct());
    [txt, level, why] = ManifestText.sortReference(r);
    if level == "warn"; c.warn(end+1) = "reference: " + why; end
    c.key = [kv("Sorter", fieldText(r, 'sorter')); kv("Reference", txt); ...
        kv("Excluded channels", fieldText(r, 'exclude_channels'))];
    for k = ["Th_universal" "Th_learned" "nblocks" "batch_size" "whitening_range" "dminx" "do_CAR"]
        c.key = [c.key; kv(k, fieldText(o, k))];
    end
    c.all = recordRows(r);
end
c.all = [c.all; groupRows("sorting", so); groupRows("kilosort", ks)];
end


function c = exportCard(P)
r = ManifestText.field(P, 'nwb', []);
c = card("export", 4, 2, "step", "NWB export");
c = recordBadge(c, r, "file");
if ~isRecord(r); return; end
c.lines = writtenLine(r);
c.pills = filePill("NWB file", r, "file");
o = ManifestText.field(r, 'options', struct());
sig = fieldText(o, 'Signals');
c.key = [kv("Signals", ternaryText(sig == "", "all", sig)); kv("Events", fieldText(o, 'Events')); ...
    kv("Trials", fieldText(o, 'Trials')); kv("Unit groups", fieldText(o, 'Groups')); ...
    kv("Probe", fileName(ManifestText.text(ManifestText.field(r, 'probe_file', ""))))];
c.all = recordRows(r);
end


% =========================================================================
% the arrows
% =========================================================================

function E = edgeList(m, P)
%edgeList  Every read the pipeline can make, on when the reader's record says
%   it did. Listed left to right as they reach the top of the box they enter.
%   LANE routes an arrow that skips a row as in PipelineDiagram.overview: NaN
%   drops it straight onto its target, a number runs it down that lane (grid
%   units: column k's center, or k + 0.5 for the gap right of column k).
beh = ManifestText.field(P, 'behavior', []);
sig = ManifestText.field(P, 'signals', []);
bin = ManifestText.field(P, 'bin', []);
spk = ManifestText.field(P, 'spikes', []);
srt = ManifestText.field(P, 'sorting', []);
nwb = ManifestText.field(P, 'nwb', []);
pairing = isstruct(ManifestText.field(m, 'behavior.pairing', []));
erased = ManifestText.number(ManifestText.field(sig, 'artifacts.periods', 0));
xf = ManifestText.field(beh, 'extract_files', []);
binIn = ManifestText.number(ManifestText.field(bin, 'artifacts.listed', 0)) ...
    + ManifestText.number(ManifestText.field(bin, 'artifacts.detected', 0));
spkMode = ManifestText.text(ManifestText.field(spk, 'artifacts.mode', ""));
coinc = ManifestText.text(ManifestText.field(spk, 'coincidence.probe', ""));
srtProbe = ManifestText.text(ManifestText.field(srt, 'probe_file', ""));
nwbProbe = ManifestText.text(ManifestText.field(nwb, 'probe_file', ""));
nwbUnits = ManifestText.text(ManifestText.field(nwb, 'sources.sortingDir', ""));
nwbXtr = ManifestText.text(ManifestText.field(nwb, 'sources.extractFile', ""));

E = [ ...
    edge("epsych", "behavior", ManifestText.text(ManifestText.field(m, 'behavior.file', "")) ~= "", "the session's trials"), ...
    edge("rec", "behavior", pairing, "the trial line, to pair the trials"), ...
    edge("rec", "artifacts", true, "the recording, read for artifacts"), ...
    edge("behavior", "signals", ~isempty(xf), "the derived events, written into the extract"), ...
    edge("rec", "signals", isRecord(sig), "the recording"), ...
    edge("artifacts", "signals", erased > 0, "the periods, erased before any filter"), ...
    edge("artifacts", "bin", binIn > 0, "the periods, filled in the .bin"), ...
    edge("rec", "bin", isRecord(bin), "the recording, written to the .bin"), ...
    edge("artifacts", "spikes", ~ismember(spkMode, ["" "none"]), "the periods: " + spkMode), ...
    edge("rec", "spikes", isRecord(spk), "the recording, for threshold detection"), ...
    edge("probemap", "spikes", coinc ~= "", "the sites, to keep a spike once across neighbors"), ...
    edge("bin", "sorting", ManifestText.text(ManifestText.field(srt, 'bin_file', "")) ~= "", "the .bin"), ...
    edge("probemap", "sorting", srtProbe ~= "", "the channel map", 3.5), ...
    edge("behavior", "export", isRecord(nwb) && isequal(ManifestText.field(nwb, 'options.Trials', false), true) && isRecord(beh), ...
        "the paired trials, the NWB file's trials", 0), ...
    edge("signals", "export", nwbXtr ~= "", "the extract: signals and events"), ...
    edge("sorting", "export", nwbUnits ~= "", "the sorted units"), ...
    edge("probemap", "export", nwbProbe ~= "", "the electrodes' positions", 3.5)];
end


function e = edge(from, to, on, note, lane)
if nargin < 5; lane = NaN; end
e = struct('from', string(from), 'to', string(to), 'on', logical(on), 'note', string(note), ...
    'lane', lane, 'dim', false, 'portX', NaN, 'points', zeros(0, 2));
end


% =========================================================================
% helpers
% =========================================================================

function c = card(id, row, col, kind, title)
c = struct('id', string(id), 'row', row, 'col', col, 'kind', string(kind), 'title', string(title), ...
    'badge', "", 'badgeClass', "", 'dim', false, 'lines', strings(1, 0), 'warn', strings(1, 0), ...
    'pills', {emptyPills()}, 'key', strings(0, 2), 'all', strings(0, 2));
end


function p = pill(title, lines, kind)
%pill  A file a step wrote, or what came of it, hung under its box (gridNodeSVG).
if nargin < 3; kind = "out"; end
lines = string(lines);
p = struct('kind', string(kind), 'title', string(title), 'lines', {lines(lines ~= "")}, ...
    'target', "", 'port', false, 'dim', [], 'x', 0, 'y', 0, 'w', 0, 'h', 0);
end


function p = emptyPills()
p = pill("", "");
p(1) = [];
end


function tf = isRecord(r)
tf = isstruct(r) && isscalar(r);
end


function c = recordBadge(c, r, key)
%recordBadge  Not run without a record; with one, whether its output is on disk now.
if ~isRecord(r)
    c.badge = "not run";
    c.dim = true;
    return
end
paths = strings(1, 0);
if isfield(r, key); paths = string(r.(key)); end
kind = ternaryText(key == "results_dir", "folder", "file");
if isempty(paths) || all(paths == "")
    c.badge = "done";     % no file of its own (a detection not kept in its cache)
else
    c = fileBadge(c, paths, kind);
end
end


function c = fileBadge(c, paths, kind)
%fileBadge  The badge for a path or paths, checked on disk now.
paths = paths(paths ~= "");
if isempty(paths); return; end
if kind == "folder"
    ok = isfolder(paths);
else
    ok = isfile(paths);
end
if all(ok)
    c.badge = "written";
else
    c.badge = ternaryText(numel(ok) > 1, sprintf("%d of %d gone", nnz(~ok), numel(ok)), "file gone");
    c.badgeClass = "bad";
end
end


function p = filePill(title, r, key, extra)
%filePill  The files a record names, by name; their full paths are on the "parameters" level.
if nargin < 4; extra = ""; end
f = reshape(string(ManifestText.field(r, key, strings(1, 0))), 1, []);
p = pill(title, [fileName(f(f ~= "")), extra]);
end


function s = writtenLine(r)
%writtenLine  When a record's output was written, and in which run.
s = strings(1, 0);
t = ManifestText.text(ManifestText.field(r, 'created', ""));
if t ~= ""; s = "written " + t; end
end


function s = fieldText(st, path, unit)
%fieldText  A field's value in words, with UNIT after it; "" when it is not there.
if nargin < 3; unit = ""; end
v = ManifestText.field(st, path, []);
if isempty(v) && ~ischar(v) && ~isstring(v)
    s = "";
    return
end
s = ManifestText.value(v);
if s ~= "" && unit ~= ""; s = s + unit; end
end


function r = kv(name, value, always)
%kv  One [name value] row; none for a value that is empty or null, unless ALWAYS.
if nargin < 3; always = false; end
value = string(value);
if isempty(value); value = ""; end
if ismember(value, ["" "null"]) && ~always
    r = strings(0, 2);
else
    r = [string(name), value];
end
end


function R = groupRows(label, s)
%groupRows  A labeled group of a struct's fields, one row per leaf; nothing if it has none.
R = strings(0, 2);
if isstruct(s) && isscalar(s) && ~isempty(fieldnames(s))
    R = [["#", string(label)]; flatRows(s, "")];
end
end


function R = recordRows(r)
%recordRows  Every value of a processing record: the options as run first,
%   then the record's own fields, then each block it holds under its name.
R = strings(0, 2);
if isfield(r, 'options'); R = groupRows("options", r.options); end
names = string(fieldnames(r)).';
isBlock = arrayfun(@(f) isstruct(r.(f)) && isscalar(r.(f)), names);
own = rmfieldIf(r, ["options", names(isBlock)]);
R = [R; groupRows("this output", own)];
for f = setdiff(names(isBlock), "options", 'stable')
    R = [R; groupRows(f, r.(f))]; %#ok<AGROW>
end
end


function R = flatRows(s, prefix)
%flatRows  One [name value] row per leaf of a struct, dotted names for nested fields.
R = strings(0, 2);
for f = string(fieldnames(s)).'
    v = s.(f);
    name = prefix + f;
    if isstruct(v) && isscalar(v) && ~isempty(fieldnames(v))
        R = [R; flatRows(v, name + ".")]; %#ok<AGROW>
    elseif isstruct(v) && isscalar(v)
        R = [R; name, "{}"]; %#ok<AGROW>
    else
        R = [R; name, leafText(v)]; %#ok<AGROW>
    end
end
end


function t = leafText(v)
%leafText  A value as a row shows it: a run of channels in short, and an
%   array that is data rather than a setting (a pairing's per-trial columns) as its size.
if isnumeric(v) && ~isempty(v)
    if isvector(v) && numel(v) > 4 && all(v == round(v)) && all(v > 0) && all(diff(double(v(:))) > 0)
        t = "[" + EphysDataset.formatChannelList(double(v)) + "]";
        return
    elseif numel(v) > 16 || (~isvector(v) && size(v, 1) > 4)
        t = sprintf("[%s]", strjoin(string(size(v)), "x"));
        return
    end
end
t = ManifestText.value(v);
end


function s = rmfieldIf(s, names)
if ~isstruct(s); s = struct(); return; end
s = rmfield(s, intersect(fieldnames(s), cellstr(names)));
end


function n = countRows(v, nCol)
%countRows  How many periods a list holds: jsondecode collapses one row to a vector.
n = 0;
if isempty(v) || ~isnumeric(v); return; end
if isvector(v) && numel(v) == nCol
    n = 1;
elseif size(v, 2) == nCol
    n = size(v, 1);
end
end


function t = countOf(list, what)
t = "";
chs = EphysDataset.parseChannelList(list);
if ~isempty(chs); t = sprintf("%d %s", numel(chs), what); end
end


function t = tagsOf(m)
try
    t = TagSet.parse(ManifestText.field(m, 'tags', {}));
catch
    t = strings(1, 0);
end
end


function t = joinParts(parts)
parts = parts(parts ~= "");
if isempty(parts)
    t = "";
else
    t = strjoin(parts, ", ");
end
end


function t = fileName(p)
[~, b, e] = fileparts(p);
t = string(b) + string(e);
end


function v = ternaryText(tf, a, b)
if tf; v = string(a); else; v = string(b); end
end
