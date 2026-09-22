function test_OpenEphysReader()
%test_OpenEphysReader  Verification suite for the Open Ephys GUI reader.
%   Writes small Open Ephys sessions with the synthetic writers (Binary, Open
%   Ephys format in the GUI 0.6+ and 0.5 file layouts, NWB 2), laid out as
%   the GUI's record engines write them, and checks: discovery (session
%   folders, never Record Node folders; non-recursive scans), metadata
%   (rate, channels, channel numbers, TTL lines, start time from the
%   Software Time message), exact samples across recordings and dropped-
%   sample gaps, TTL intervals (initial state, lines high across a
%   recording boundary, what each format can know), AUX hold detection,
%   ADC, record node / stream selection, the three recording modes
%   (concatenate, separate part folders, single), line naming (LabelField,
%   LineNames, the events cache) and a synthetic Open Ephys project through
%   EphysPipeline.
%
%   Usage:  test_OpenEphysReader

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

root = fullfile(tempdir, sprintf('OE_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
cleanup = onCleanup(@() rmdirQuiet(root));
warnIds = ["OpenEphysReader:Concatenated" "OpenEphysReader:LineAcrossBoundary" "OpenEphysReader:Gaps" ...
    "OpenEphysReader:EventInGap" "EphysReader:ReaderFailed" "EphysDataset:refreshMetadata:NoFiles" ...
    "EphysProject:refresh:Metadata"];
ws = arrayfun(@(id) warning('off', id), warnIds);
restoreWarn = onCleanup(@() warning(ws)); %#ok<NASGU>

nPass = 0; nFail = 0;
    function check(cond, msg)
        if cond
            nPass = nPass + 1;
            fprintf('  PASS: %s\n', msg);
        else
            nFail = nFail + 1;
            fprintf(2, '  FAIL: %s\n', msg);
        end
    end
    function id = errorId(fcn)
        id = '';
        try
            fcn();
        catch ME
            id = ME.identifier;
        end
    end
    function id = lastWarningId(fcn)
        lastwarn('');
        fcn();
        [~, id] = lastwarn();
    end

Fs = 20000; nCh = 4; uv = 0.195;
rng(7);
n1 = 5000; n2 = 3000;
X1 = randn(n1, nCh) * 60; X2 = randn(n2, nCh) * 60;
% TTL words: line L is bit L-1. Part 1: TTL1 high 1000-1999, TTL4 high from
% 3000 to the end. Part 2: TTL4 still high at its start (no edge of its own),
% TTL1 high 500-800.
W1 = zeros(n1, 1); W1(1000:1999) = 1; W1(3000:end) = bitor(W1(3000:end), 8);
W2 = zeros(n2, 1) + 8; W2(500:800) = 9;
aux1 = repelem(randn(n1 / 4, 3), 4, 1) * 0.05; aux2 = repelem(randn(n2 / 4, 3), 4, 1) * 0.05;
adc1 = repmat(linspace(-1, 1, n1).', 1, 2); adc2 = zeros(n2, 2) + 0.5;
t0 = datetime(2026, 7, 7, 16, 35, 39);
first = 100000;
gapSamples = 40000;                           % acquisition ran 2 s between the recordings

F = struct('Fs', Fs, 'nCh', nCh, 'X1', X1, 'X2', X2, 'W1', W1, 'W2', W2, 'aux1', aux1, 'aux2', aux2, ...
    'adc1', adc1, 'adc2', adc2, 't0', t0, 'first', first, 'gapSamples', gapSamples, 'root', root);
writeSession = @(fmt, name, varargin) writeFixtureSession(F, fmt, name, varargin{:});

%% ---- 1. the three formats: metadata, samples, events, aux ------------------------
fprintf('\n== 1. formats: metadata, samples, TTL, AUX ==\n');
fmts = ["binary" "legacy" "nwb"];
for fmt = fmts
    sess = writeSession(fmt, "S1_2026-07-07_16-35-39_" + fmt, Adc=true);
    ds = EphysDataset(sess);
    pad1 = n1; pad2 = n2;
    if fmt == "legacy"; pad1 = ceil(n1 / 1024) * 1024; pad2 = ceil(n2 / 1024) * 1024; end
    check(ds.RecordingFormat == "openephys-" + fmt && isa(ds.Reader, 'OpenEphysReader') && ds.Fs == Fs ...
        && ds.NumChannels == nCh && ds.NumFiles == 2 && ds.NumSamples == pad1 + pad2, ...
        fmt + ": format, rate, headstage channels, two recordings, stored samples");
    check(isequal(ds.ChannelNames, "CH" + (1:nCh)) && isequal(ds.ChannelNumbers, 0:nCh-1) ...
        && isequal(ds.DigInNames, "TTL" + (1:4)) && isequal(ds.DigInNativeNames, ds.DigInNames), ...
        fmt + ": channels CH1.. numbered 0.., TTL lines up to the highest seen");
    check(abs(seconds(ds.AcqDate - t0)) < 1e-3 && [ds.PerFile.recording] * [1; 1] == 3, ...
        fmt + ": the start time comes from the Software Time message");
    X = ds.readWindowUV(0, pad1 + pad2);
    q = @(x) round(x / uv) * uv;
    check(max(abs(X(1:n1, :) - q(X1)), [], 'all') < 1e-9 && max(abs(X(pad1 + (1:n2), :) - q(X2)), [], 'all') < 1e-9, ...
        fmt + ": every sample reads back exactly, across the recording boundary");
    Xw = ds.readWindowUV(pad1 - 3, 7);
    check(isequal(Xw, X(pad1 - 2 : pad1 + 4, :)), fmt + ": a window straddling the boundary");
    E = ds.digitalEvents(Cache=false);
    rowsOf = @(ln) round(E.events.(ln) * Fs);
    ttl4 = [3000 pad1; pad1 + 1 pad1 + n2];
    if fmt == "legacy"; ttl4 = [3000 pad1]; end   % high at recording 2's start, no edge: not in the format
    check(isequal(rowsOf("TTL1"), [1000 1999; pad1 + 500, pad1 + 800]) && isequal(rowsOf("TTL4"), ttl4) ...
        && isempty(E.events.TTL2) && E.nSamples == pad1 + pad2, ...
        fmt + ": TTL intervals, split at the boundary (initial state per format)");
    d = ds.readData(IncludeAux=true, IncludeADC=true);
    check(d.auxFs == Fs / 4 && size(d.aux, 1) == (pad1 + pad2) / 4 && isequal(d.auxNames, "AUX" + (1:3)) ...
        && max(abs(d.aux(1:n1/4, :) - round(aux1(1:4:end, :) / 37.4e-6) * 37.4e-6), [], 'all') < 1e-9, ...
        fmt + ": AUX held for 4 samples comes back at Fs/4, in volts");
    check(size(d.boardADC, 2) == 2 && max(abs(d.boardADC(1:n1, 1) - round(adc1(:, 1) / 0.00015258789) * 0.00015258789)) < 1e-6, ...
        fmt + ": ADC channels in volts (NWB keeps bit volts as float32)");
    check(isequal(d.fileSampleCounts, [pad1 pad2]) && isequal(d.channelOrder, 1:nCh), fmt + ": per-recording counts");
end
sess05 = writeSession("legacy", "S1_2026-07-07_16-35-39_legacy05", Layout="0.5");
d05 = EphysDataset(sess05);
E05 = d05.digitalEvents(Cache=false);
check(d05.RecordingFormat == "openephys-legacy" && isequal(d05.ChannelNames, "CH" + (1:nCh)) ...
    && isequal(round(E05.events.TTL1 * Fs), [1000 1999; 5620 5920]) && abs(seconds(d05.AcqDate - t0)) < 1e-3, ...
    'GUI 0.4 / 0.5 file names, all_channels.events and the old date_created');
h = OpenEphysReader.parseCreated("07-Jul-2026 16:35:9");
check(h == datetime(2026, 7, 7, 16, 35, 9) && OpenEphysReader.parseCreated("07-Jul-2026 163509") == h, ...
    'date_created with unpadded seconds (GUI 0.6+) and HHmmss (0.4 / 0.5)');

%% ---- 2. gaps in the stored samples ------------------------------------------------
fprintf('\n== 2. dropped samples ==\n');
for fmt = fmts
    g = 300; if fmt == "legacy"; g = 1024; end
    sess = writeSession(fmt, "S1_2026-07-07_16-35-39_gap_" + fmt, Gap=g, OneRecording=true);
    ds = EphysDataset(sess);
    runs = ds.Reader.Parts(1).runs;
    pad = n1; if fmt == "legacy"; pad = ceil(n1 / 1024) * 1024; end
    check(size(runs, 1) == 2 && runs(2, 1) == 2049 && runs(2, 3) - runs(1, 3) == 2048 + g && ds.NumSamples == pad, ...
        fmt + ": a gap is found by binary search; rows are the stored samples");
    E = ds.digitalEvents(Cache=false);
    check(isequal(round(E.events.TTL1 * Fs), [1000 1999]) && isequal(round(E.events.TTL4 * Fs), [3000 pad]), ...
        fmt + ": TTL edges after the gap land on the stored rows");
    X = ds.readWindowUV(0, n1);
    check(max(abs(X - round(X1 / uv) * uv), [], 'all') < 1e-9, fmt + ": samples around the gap read back");
end

%% ---- 3. discovery, record nodes, streams --------------------------------------------
fprintf('\n== 3. discovery, nodes, streams ==\n');
proj = fullfile(root, 'proj');
mkdir(fullfile(proj, 'SUBJ-ID-1219'));
sA = writeSession("binary", "SUBJ-ID-1219_2026-07-07_16-35-39_active", Parent=fullfile(proj, 'SUBJ-ID-1219'));
sB = writeSession("nwb", "SUBJ-ID-1219_2026-07-11_15-37-09_active", Parent=fullfile(proj, 'SUBJ-ID-1219'), OneRecording=true);
P = EphysProject(proj);
keys = P.datasetKeys();
check(P.NumDatasets == 2 && all(startsWith(keys, "SUBJ-ID-1219/SUBJ-ID-1219_")) && ~any(contains(keys, "Record Node")), ...
    'a recursive scan finds the session folders, never Record Node / experiment folders');
check(~OpenEphysReader.claims(fullfile(sA, 'Record Node 101')) && OpenEphysReader.claims(sA), ...
    'a session folder is claimed, its Record Node folder is not');
Pflat = EphysProject(proj, Recursive=false);
check(Pflat.NumDatasets == 0, 'a non-recursive scan does not reach sessions two levels down');
Psub = EphysProject(fullfile(proj, 'SUBJ-ID-1219'), Recursive=false);
check(Psub.NumDatasets == 2, 'a non-recursive scan of the subject folder finds its sessions');
I = P.unitIdentities(NamePattern=OpenEphysReader.DefaultNamePattern);
check(all(I.Status == "ok") && all(I.Subject == "SUBJ-ID-1219") && any(I.LabelSuffix == "SUBJ-ID-1219_260707T1635"), ...
    'the Open Ephys name pattern labels units from the session folder names');
% a second Record Node and a second stream
two = writeSession("binary", "S2_2026-07-07_16-35-39", NodeId=104, OneRecording=true);
writeSession("binary", "S2_2026-07-07_16-35-39", NodeId=102, OneRecording=true);
dTwo = EphysDataset(two, AutoMetadata=false);
check(lastWarningId(@() dTwo.refreshMetadata()) == "OpenEphysReader:SeveralNodes" && dTwo.Reader.Node.id == "102", ...
    'several Record Nodes: the lowest id, with a warning');
dTwo.ReaderOptions = struct('OpenEphys', struct('RecordNode', "104"));
dTwo.refreshMetadata();
check(dTwo.Reader.Node.id == "104" && dTwo.NumSamples == n1, 'Acquisition.OpenEphys.RecordNode picks the node');
dTwo.ReaderOptions = struct('OpenEphys', struct('RecordNode', "7"));
check(strcmp(errorId(@() dTwo.refreshMetadata()), 'OpenEphysReader:NoNode') || isempty(dTwo.Reader), ...
    'an absent Record Node is an error');
ob = fullfile(two, 'Record Node 104', 'experiment1', 'recording1', 'structure.oebin');
J = readJsonFile(ob);
c2 = J.continuous(1); c2.folder_name = 'NI-DAQmx-110.PXI-6255/'; c2.stream_name = 'PXI-6255';
c2.channels = c2.channels(end-2:end);   % AUX only: no headstage channels
c2.num_channels = 3;
J.continuous = [J.continuous(1); c2];
writeJsonFile(ob, J);
dTwo.ReaderOptions = struct('OpenEphys', struct('RecordNode', "104"));
dTwo.refreshMetadata();
check(dTwo.Reader.Stream.name == "Rhythm Data", 'the stream with headstage channels is read');
dTwo.ReaderOptions = struct('OpenEphys', struct('RecordNode', "104", 'Stream', "nope"));
check(strcmp(errorId(@() dTwo.refreshMetadata()), 'OpenEphysReader:NoStream') || isempty(dTwo.Reader), ...
    'an absent stream is an error');

%% ---- 4. recording modes -------------------------------------------------------------
fprintf('\n== 4. recording modes ==\n');
single = struct('OpenEphys', struct('Recordings', "single"));
separate = struct('OpenEphys', struct('Recordings', "separate"));
dS = EphysDataset(sA, AutoMetadata=false, ReaderOptions=single);
check(strcmp(errorId(@() dS.refreshMetadata()), 'OpenEphysReader:MultipleRecordings'), ...
    'single: a session with two recordings is refused');
Psingle = EphysProject(proj, ReaderOptions=single);
rep = Psingle.refresh();
check(sum(rep.Metadata) == 1 && any(contains(rep.Message, "MultipleRecordings") | contains(rep.Message, "holds 2 recordings")), ...
    'single: the project refresh reports that session and reads the others');
Psep = EphysProject(proj, ReaderOptions=separate);
names = [Psep.Datasets.Name];
check(Psep.NumDatasets == 3 && all(ismember(["SUBJ-ID-1219_2026-07-07_16-35-39_active" "SUBJ-ID-1219_2026-07-07_16-35-42_active" ...
    "SUBJ-ID-1219_2026-07-11_15-37-09_active"], names)), ...
    'separate: one dataset per recording, part folders named from each recording''s start');
pf = fullfile(sA, "SUBJ-ID-1219_2026-07-07_16-35-42_active", OpenEphysReader.PartFile);
pj = readJsonFile(pf);
check(isfile(pf) && string(pj.schema) == OpenEphysReader.PartSchema && pj.recording == 2 && string(pj.record_node) == "101", ...
    'separate: the part folder records node, experiment and recording');
d2 = Psep.dataset("SUBJ-ID-1219_2026-07-07_16-35-42_active");
d2.refreshMetadata();
X = d2.readWindowUV(0, n2);
E2 = d2.digitalEvents(Cache=false);
check(d2.NumSamples == n2 && max(abs(X - round(X2 / uv) * uv), [], 'all') < 1e-9 && abs(seconds(d2.AcqDate - (t0 + seconds(3)))) < 1e-3 ...
    && isequal(round(E2.events.TTL1 * Fs), [500 800]), 'separate: a part folder reads its own recording and start');
check(all(startsWith(d2.Files, "..")) && isfile(fullfile(d2.Folder, d2.Files(1))), ...
    'separate: part files are listed relative to the part folder');
Pcat = EphysProject(proj);
check(Pcat.NumDatasets == 2, 'concatenate ignores the part folders the separate scan created');
names = OpenEphysReader.partNames("S_2026-07-07_16-35-39", struct('start', {t0, t0}, 'experiment', {1, 1}, 'recording', {1, 2}));
check(isequal(names, ["S_2026-07-07_16-35-39_exp1_rec1" "S_2026-07-07_16-35-39_exp1_rec2"]), ...
    'separate: recordings starting in the same second get _exp<E>_rec<R>');
names = OpenEphysReader.partNames("session", struct('start', {t0, NaT}, 'experiment', {1, 2}, 'recording', {1, 1}));
check(isequal(names, ["session_exp1_rec1" "session_exp2_rec1"]), 'separate: a name without a GUI timestamp gets _exp<E>_rec<R>');

%% ---- 5. line names ---------------------------------------------------------------------
fprintf('\n== 5. line names ==\n');
d = Pcat.dataset("SUBJ-ID-1219_2026-07-07_16-35-39_active");
d.OutputDir = fullfile(root, 'out');
tc = d.TrialConfig; tc.LineNames = ["TTL4=InTrial" "ttl1 = Trough"]; d.TrialConfig = tc;
E = d.digitalEvents();
check(E.source == "read" && isequal(E.digInNames, ["Trough" "TTL2" "TTL3" "InTrial"]) && isfield(E.events, 'InTrial') ...
    && ~isfield(E.events, 'TTL4') && isequal(E.digInDefaultNames, "TTL" + (1:4)), ...
    'LineNames renames lines (native names matched without case)');
tc.LineNames = "TTL4=Trial"; d.TrialConfig = tc;
E = d.digitalEvents();
check(E.source == "cache" && isfield(E.events, 'Trial'), 'renaming a line reuses the cached events');
data = d.readData(KeepChannels=1, LineNames="TTL2=X");
check(isequal(data.digInNames, ["TTL1" "X" "TTL3" "TTL4"]) && isfield(data.events, 'X'), 'readData names lines too');
check(strcmp(errorId(@() d.readData(KeepChannels=1, LineNames=["TTL1=A" "TTL2=A"])), 'EphysDataset:LineNames') ...
    && strcmp(errorId(@() d.readData(KeepChannels=1, LineNames="TTL1=TTL2")), 'EphysDataset:relabelEvents:Duplicate'), ...
    'duplicate names are errors');
cfg = EphysPipelineConfig();
cfg.Behavior.Enabled = true;
cfg.Signals.LineNames = ["TTL4=InTrial" "bad"];
iss = cfg.validate(CheckPaths=false);
check(any(iss.Field == "LineNames" & iss.Severity == "error"), 'validate: a line name without "=" is an error');
cfg.Signals.LineNames = "TTL4=In Trial";
iss = cfg.validate(CheckPaths=false);
check(any(iss.Field == "LineNames"), 'validate: a name that is not an identifier is an error');
cfg.Signals.LineNames = "TTL4=InTrial";
cfg.Acquisition.OpenEphys.Recordings = "sometimes";
cfg.Acquisition.OpenEphys.RecordNode = "node";
iss = cfg.validate(CheckPaths=false);
check(any(iss.Field == "OpenEphys.Recordings") && any(iss.Field == "OpenEphys.RecordNode") && ~any(iss.Field == "LineNames"), ...
    'validate: Acquisition options');
Ei = EphysDataset.relabelEvents(struct('events', struct('DIGITAL_IN_04', [1 2]), 'digInNames', "InTrial", ...
    'digInNativeNames', "DIGITAL-IN-04"), "native", "DIGITAL-IN-04=Trial");
Ec = EphysDataset.relabelEvents(struct('events', struct('DIGITAL_IN_04', [1 2]), 'digInNames', "InTrial", ...
    'digInNativeNames', "DIGITAL-IN-04"), "custom");
check(isfield(Ei.events, 'Trial') && isfield(Ec.events, 'InTrial') && Ec.digInDefaultNames == "InTrial", ...
    'Intan lines: custom names by default, LineNames by native name');

%% ---- 6. a synthetic Open Ephys project through EphysPipeline -----------------------------
fprintf('\n== 6. synthetic Open Ephys project + EphysPipeline ==\n');
hasSP = license('test', 'Signal_Toolbox') > 0;
sp = fullfile(root, 'synth');
S = makeSyntheticProject(sp, Preset="small", Fs=Fs, NumChannels=nCh, NumTrials=6, FileSeconds=8, Seed=3, ...
    Format="openephys-binary", Parts=2, Scenarios=["clean" "late-start"]);
cfg = EphysPipelineConfig.load(S.configFile);
check(cfg.Project.NamePattern == OpenEphysReader.DefaultNamePattern && any(cfg.Signals.LineNames == "TTL4=InTrial"), ...
    'the generated config names the TTL lines and matches Open Ephys folders');
cfg.Signals.Enabled = hasSP;
cfg.Export.Enabled = hasSP;
cfg.Spikes.Filter = hasSP;
pipe = EphysPipeline(cfg);
pipe.LogFcn = [];
R = pipe.run();
T1 = S.datasets(1);
d1 = pipe.Project.dataset(T1.name);
check(pipe.Project.NumDatasets == 2 && d1.NumFiles == 2 && d1.NumSamples == T1.nSamples, ...
    'the project scans (two recordings per session, concatenated)');
check(any(R.Step == "behavior:pairing" & R.Status == "needs review") && any(R.Step == "spikes" & R.Status == "done"), ...
    'behavior pairing and spikes run on Open Ephys data');
P1 = d1.pairTrials(Warn=false);
check(~P1.countMismatch && P1.nPaired == 6 && isequal(round(P1.onset * Fs), round(T1.trials.Onset * Fs)), ...
    'clean: trials pair with the TTL4=InTrial intervals');
if hasSP
    outS = pipe.outputPathFor("signals", d1);
    check(all(R.Status(R.Step == "signals") == "done") && all(isfile(outS)) && any(contains(outS, "_AUX")), ...
        'signals written, AUX included');
    A = load(outS(contains(outS, "_AUX")));
    check(A.info.AUX.Fs == Fs / 4 && isfield(A.events, 'InTrial'), 'AUX at Fs/4; events named by LineNames');
end
U = d1.readSortedUnits();
check(numel(U.unitId) == numel(T1.units) && all(U.channelNumber == U.channel - 1) && all(U.channelName == "CH" + U.channel), ...
    'sorted units carry the Open Ephys channel names and numbers');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_OpenEphysReader:Failed', '%d checks failed.', nFail);
end
end


function sess = writeFixtureSession(F, fmt, name, opts)
%writeFixtureSession  Two recordings (experiment 1, recordings 1 and 2) of fixture F.
arguments
    F (1,1) struct
    fmt (1,1) string
    name (1,1) string
    opts.Layout (1,1) string = "0.6"
    opts.NodeId (1,1) double = 101
    opts.Parent (1,1) string = ""
    opts.Adc (1,1) logical = false
    opts.Gap (1,1) double = 0     % samples dropped inside recording 1 (after row 2048)
    opts.OneRecording (1,1) logical = false
end
parent = opts.Parent;
if parent == ""; parent = F.root; end
sess = fullfile(parent, name);
meta = struct('Fs', F.Fs, 'NumChannels', F.nCh, 'NodeId', opts.NodeId, 'AdcCount', 2 * opts.Adc, 'Layout', opts.Layout);
switch fmt
    case "binary", Wr = writeOpenEphysBinary(sess, meta);
    case "legacy", Wr = writeOpenEphysLegacy(sess, meta);
    case "nwb",    Wr = writeOpenEphysNWB(sess, meta);
end
adcA = []; adcB = [];
if opts.Adc; adcA = F.adc1; adcB = F.adc2; end
n1 = size(F.X1, 1);
Wr.begin(1, 1, F.first, F.t0);
if opts.Gap > 0
    Wr.append(F.X1(1:2048, :), F.W1(1:2048), F.aux1(1:2048, :), rowsOf(adcA, 1:2048));
    Wr.skip(opts.Gap);
    Wr.append(F.X1(2049:end, :), F.W1(2049:end), F.aux1(2049:end, :), rowsOf(adcA, 2049:n1));
else
    Wr.append(F.X1, F.W1, F.aux1, adcA);
end
Wr.finish();
if ~opts.OneRecording
    Wr.begin(1, 2, F.first + n1 + opts.Gap + F.gapSamples, F.t0 + seconds(3));
    Wr.append(F.X2, F.W2, F.aux2, adcB);
    Wr.finish();
end
if isfield(Wr, 'closeAll'); Wr.closeAll(); end
end


function r = rowsOf(A, idx)
r = [];
if ~isempty(A); r = A(idx, :); end
end


function rmdirQuiet(p)
try
    if isfolder(p); rmdir(p, 's'); end
catch
end
end
