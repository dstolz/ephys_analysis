function test_TDTReader()
%test_TDTReader  Verification suite for the TDT Synapse block reader.
%   Writes small TDT blocks with the synthetic writer (writeTDTBlock: TSQ,
%   TEV, Tbk and SEV files as Synapse lays them out) and checks: discovery
%   (block folders, a tank scanned recursively, SEV-only blocks), metadata
%   (rate, channels, channel numbers, start time, the stream chosen),
%   exact samples from TEV chunks and SEV files (windows, stream plans,
%   readData), the gain (float streams in volts, integer streams need
%   GainToMicrovolts), the epocs as TDT's readers return them (buddy
%   offsets, onset-only stores, a secondary epoc, a strobe high at the
%   start, iCon values 3 / 4, disabled stores) and their rows on the
%   stream grid (epocs outside the stream, a stream that starts late, gaps
%   between chunks), line naming through EphysDataset, and the
%   Acquisition.TDT options in the config.
%
%   Usage:  test_TDTReader

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

root = fullfile(tempdir, sprintf('TDT_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
cleanup = onCleanup(@() rmdirQuiet(root));
warnIds = ["EphysReader:ReaderFailed" "EphysDataset:refreshMetadata:NoFiles" "EphysProject:refresh:Metadata"];
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

Fs = 24414.0625;                       % 195312.5 / 8, TDT's usual rate
npts = 256; nChunks = 40; n = npts * nChunks;
rng(11);
X = single(randn(n, 4) * 1e-4);        % volts, as Synapse stores float streams
L = int16(round(randn(n / 8, 2) * 300));
R = single(randn(n, 3) * 1e-4);
t0 = datetime(2026, 1, 1, 12, 0, 0.25);
start = posixtime(datetime(t0, 'TimeZone', 'local'));
sec = @(s) s / Fs;                     % a sample index (0-based) as seconds

epoc = @(name, on, val, off, offName) struct('Name', name, 'Onset', sec(on(:)), 'Value', val(:), ...
    'Offset', sec(off(:)), 'OffName', offName);

spec = struct();
spec.Name = 'Subj1-260101-120000';
spec.StartTime = start;
spec.Streams = [streamSpec('Wav1', Fs, X, Npts=npts), streamSpec('LFP1', Fs / 8, L, Npts=32), ...
    streamSpec('RSn1', Fs, R, Sev=true, Rate=2, Decimate=1)];
spec.Epocs = [epoc('Tick', [0 4000 8000], [0 1 2], [], ''), ...
    epoc('Freq', [1000 3000 5000 7000], [1000 2000 4000 8000], [1500 3500 5500 7500], 'Fre/'), ...
    epoc('Levl', [1000 3000 5000 7000], [10 20 30 40], [], ''), ...
    epoc('PC0_', 2000, 1, [200 2600], 'PC0/'), ...
    epoc('Late', 12000, 5, [], '')];
spec.Notes = struct('StoreName', {'Wav1', 'LFP1', 'RSn1', 'Tick', 'Freq', 'Levl', 'PC0_', 'Late'}, ...
    'HeadName', {'Wav1', 'LFP1', 'RSn1', 'Tick', 'Freq', 'Levl|Freq', 'PC0_', 'Late'}, ...
    'Enabled', {'1', '1', '1', '1', '1', '1', '1', '1'}, ...
    'SampleFreq', {'24414.0625', '3051.7578125', '24414.0625', '0', '0', '0', '0', '0'});
tank = fullfile(root, 'Tank1');
blk = fullfile(tank, spec.Name);
writeTDTBlock(blk, spec);

%% ---- 1. discovery and metadata ------------------------------------------------------
fprintf('\n== 1. discovery, metadata ==\n');
r = EphysReader.forFolder(string(blk));
check(isa(r, 'TDTReader') && TDTReader.claims(blk) && ~TDTReader.claims(tank), ...
    'the block folder is claimed by TDTReader, the tank folder is not');
found = TDTReader.findRecordingFolders(string(root), true);
check(isscalar(found) && endsWith(found, filesep + string(spec.Name)) ...
    && isempty(TDTReader.findRecordingFolders(string(tank), false)), ...
    'a recursive scan finds the block; a non-recursive scan of the tank does not reach it');
ds = EphysDataset(blk);
check(ds.RecordingFormat == "tdt" && ds.NumFiles == 1 && all(ismember(spec.Name + [".tsq" ".tev" ".Tbk"], ds.Files)) ...
    && sum(endsWith(ds.Files, ".sev")) == 3, 'files: TSQ, TEV, Tbk and the SEV files');
check(ds.Fs == Fs && ds.NumChannels == 4 && ds.NumSamples == n && ds.Reader.Stream.name == "Wav1" ...
    && ds.Reader.Stream.storage == "tev", 'the stream with the most channels (Wav1, TEV) is the amplifier');
check(isequal(ds.ChannelNames, "Ch" + (1:4)) && isequal(ds.ChannelNumbers, 0:3) ...
    && isequal(ds.NativeNames, ds.ChannelNames), 'channels Ch1.. numbered 0..');
check(abs(seconds(ds.AcqDate - t0)) < 1e-3 && abs(ds.Duration - n / Fs) < 1e-12, ...
    'start time from the TSQ start mark (UTC -> local); duration');
check(isequal(ds.DigInNames, ["Tick" "Freq" "Levl" "PC0_" "Late"]) && isequal(ds.DigInNativeNames, ds.DigInNames), ...
    'one line per epoc onset store, in order of appearance');
S = ds.Reader.Streams;
check(isequal(string({S.name}), ["Wav1" "LFP1" "RSn1"]) && isequal([S.nSamples], [n n/8 n]) ...
    && isequal(string([S.storage]), ["tev" "tev" "sev"]), 'every stream is listed (TEV and SEV)');

%% ---- 2. samples --------------------------------------------------------------------------
fprintf('\n== 2. samples ==\n');
Y = ds.readWindowUV(0, n, Reference=false);
check(isequal(Y, double(X) * 1e6), 'every TEV sample reads back exactly, in microvolts (V * 1e6)');
check(isequal(ds.readWindowUV(1000, 777, Reference=false), Y(1001:1777, :)), 'a window across chunk boundaries');
check(isequal(ds.readWindowUV(n - 5, 20, Reference=false), Y(n-4:n, :)), 'a window past the end is cut at the last row');
pl = ds.streamPlan(MaxChunkSamples=3000);
Z = cell2mat(arrayfun(@(c) ds.readChunkUV(c, Reference=false), pl.', 'UniformOutput', false));
check(isequal([pl.sampleOffset], [0 3000 6000]) && isequal(Z, Y), 'the stream plan covers every row once');
d = ds.readData(KeepChannels=[4 2], Precision="single");
check(isa(d.amplifier, 'single') && isequal(d.amplifier, single(Y(:, [4 2]))) && isequal(d.channelNames, ["Ch4" "Ch2"]) ...
    && d.units == "microvolts" && isequal(d.fileSampleCounts, n) && isempty(d.boardADC) && isempty(d.aux), ...
    'readData: kept channels, single precision');

%% ---- 3. epocs ----------------------------------------------------------------------------
fprintf('\n== 3. epocs ==\n');
E = ds.digitalEvents(Cache=false);
rows = @(ln) round(E.events.(ln) * Fs);
check(isequal(rows("Freq"), [1001 1500; 3001 3500; 5001 5500; 7001 7500]), ...
    'strobe epocs: first row at the onset to the last row before the offset (t = row/Fs)');
check(isequal(rows("Levl"), rows("Freq")), 'a secondary epoc (HeadName Levl|Freq) takes its primary''s offsets');
check(isequal(rows("Tick"), [1 4000; 4001 8000; 8001 n]), 'an onset-only store runs to the next onset, the last to the end');
check(isequal(rows("PC0_"), [1 200; 2001 2600]), 'a strobe high at the block start begins at row 1 (TDT adds an onset at 0)');
check(isempty(E.events.Late) && E.nSamples == n && E.Fs == Fs, 'an epoc after the last row is left out of the lines');
P = ds.Reader.readEpocs();
f = P(strcmp({P.name}, 'Freq'));
check(isequal(f.value, [1000; 2000; 4000; 8000]) && max(abs(f.onset - sec([1000; 3000; 5000; 7000]))) < 3e-6 ...
    && f.buddy == "Fre/" && isequal(round(f.interval * Fs), rows("Freq")), ...
    'readEpocs: values, onsets (s from the block start), intervals as the events');
lt = P(strcmp({P.name}, 'Late'));
tk = P(strcmp({P.name}, 'Tick'));
check(all(isnan(lt.interval)) && lt.value == 5 && isinf(tk.offset(end)) && isequal(tk.value, [0; 1; 2]), ...
    'readEpocs keeps the epocs the lines leave out (NaN interval) and TDT''s Inf offsets');

%% ---- 4. streams: SEV, integer, choice ----------------------------------------------------
fprintf('\n== 4. stream choice, SEV, gain ==\n');
dR = EphysDataset(blk, ReaderOptions=struct('TDT', struct('Stream', "RSn1")));
check(dR.Reader.Stream.storage == "sev" && dR.NumChannels == 3 && dR.NumSamples == n ...
    && isequal(dR.readWindowUV(0, n, Reference=false), double(R) * 1e6) ...
    && isequal(dR.readWindowUV(333, 1000, Reference=false), double(R(334:1333, :)) * 1e6), ...
    'Acquisition.TDT.Stream picks a SEV stream; its samples read back exactly');
check(strcmp(errorId(@() EphysDataset(blk, ReaderOptions=struct('TDT', struct('Stream', "LFP1")))), 'TDTReader:NeedGain'), ...
    'an integer stream needs Acquisition.TDT.GainToMicrovolts');
dL = EphysDataset(blk, ReaderOptions=struct('TDT', struct('Stream', "LFP1", 'GainToMicrovolts', 0.5)));
EL = dL.digitalEvents(Cache=false);
check(dL.Fs == Fs / 8 && isequal(dL.readWindowUV(0, n / 8, Reference=false), double(L) * 0.5) ...
    && isequal(round(EL.events.Freq * dL.Fs), [126 188; 376 438; 626 688; 876 938]), ...
    'an int16 stream at Fs/8: samples * GainToMicrovolts; epocs on its own grid');
check(strcmp(errorId(@() EphysDataset(blk, ReaderOptions=struct('TDT', struct('Stream', "nope")))), 'TDTReader:NoStream'), ...
    'an absent stream is an error');
check(strcmp(errorId(@() TDTReader(string(blk), struct('TDT', struct('GainToMicrovolts', -1)))), 'TDTReader:BadGain'), ...
    'a negative gain is an error');
tie = spec; tie.Name = 'Tie-260101-120000';
tie.Streams = [streamSpec('Wav1', Fs, X, Npts=npts), streamSpec('Wav2', Fs / 2, X(1:n/2, :), Npts=npts)];
tie.Notes = struct([]);
writeTDTBlock(fullfile(tank, tie.Name), tie);
dT = EphysDataset(fullfile(tank, tie.Name), AutoMetadata=false);
check(lastWarningId(@() dT.refreshMetadata()) == "TDTReader:SeveralStreams" && dT.Reader.Stream.name == "Wav1", ...
    'streams with as many channels: the highest rate, with a warning');

%% ---- 5. time: a late stream start, gaps between chunks -----------------------------------
fprintf('\n== 5. stream start, gaps ==\n');
late = spec; late.Name = 'Late-260101-120000';
late.Streams = streamSpec('Wav1', Fs, X, Npts=npts, T0=sec(512));
late.Epocs = [epoc('Freq', [1000 300], [1 2], [1600 400], 'Fre/')];
late.Notes = struct([]);
writeTDTBlock(fullfile(tank, late.Name), late);
dLt = EphysDataset(fullfile(tank, late.Name));
El = dLt.digitalEvents(Cache=false);
check(abs(dLt.Reader.StreamStart - sec(512)) < 3e-6 && isequal(round(El.events.Freq * Fs), [489 1088]), ...
    'a stream that starts late: epocs are placed from its first sample; one that ends before it is left out');
gap = spec; gap.Name = 'Gap-260101-120000';
ct = sec((0:nChunks - 1).' * npts); ct(21:end) = ct(21:end) + 0.1;
gap.Streams = streamSpec('Wav1', Fs, X, Npts=npts, ChunkTimes=ct);
inGap = ct(20) + sec(npts) + 0.05;
gap.Epocs = [struct('Name', 'Freq', 'Onset', [ct(21) + sec(10); inGap], 'Value', [1; 2], ...
    'Offset', [ct(21) + sec(20); inGap + sec(3)], 'OffName', 'Fre/')];
gap.Notes = struct([]);
writeTDTBlock(fullfile(tank, gap.Name), gap);
dG = EphysDataset(fullfile(tank, gap.Name), AutoMetadata=false);
check(lastWarningId(@() dG.refreshMetadata()) == "TDTReader:Gaps" && dG.NumSamples == n, ...
    'a gap between chunks warns; rows are the stored samples');
EG = dG.digitalEvents(Cache=false);
check(isequal(round(EG.events.Freq * Fs), [20 * npts + 1, 20 * npts + 1; 20 * npts + 11, 20 * npts + 20]), ...
    'epocs are placed by their chunk''s time; one inside the gap moves to the next stored row');

%% ---- 6. the Tbk, iCon, stop mark, SEV-only blocks ----------------------------------------
fprintf('\n== 6. Tbk, iCon, stop mark, SEV only ==\n');
odd = spec; odd.Name = 'Odd-260101-120000';
odd.StopMark = false;
odd.Epocs = [epoc('iCn1', [100 200 300 400], [3 4 3 4], [], ''), epoc('Tick', [0 4000], [0 1], [], '')];
odd.Notes = struct('StoreName', {'Tick', 'LFP1'}, 'HeadName', {'Tick', 'LFP1'}, 'Enabled', {'2', '2'});
writeTDTBlock(fullfile(tank, odd.Name), odd);
dO = EphysDataset(fullfile(tank, odd.Name), AutoMetadata=false);
check(lastWarningId(@() dO.refreshMetadata()) == "TDTReader:NoStopMark", 'a block without a stop mark warns');
EO = dO.digitalEvents(Cache=false);
PO = dO.Reader.readEpocs();
check(isequal(dO.DigInNames, "iCn1") && isequal(string({dO.Reader.Streams.name}), ["Wav1" "RSn1"]), ...
    'TSQ stores the .Tbk disables (Enabled = 2) are not read');
check(isequal(round(EO.events.iCn1 * Fs), [101 200; 301 400]) && isequal(PO.value, [1; 1]) && PO.icon, ...
    'iCon epocs: value-3 events are onsets, value-4 events offsets (as TDT''s readers)');
sevOnly = fullfile(tank, 'SevOnly-260101-120000');
mkdir(sevOnly);
so = spec; so.Name = 'SevOnly-260101-120000';
so.Streams = streamSpec('RSn1', Fs, R, Sev=true, Rate=2, Decimate=1);
so.Epocs = struct([]); so.Notes = struct([]);
tmp = fullfile(root, 'sevtmp');
writeTDTBlock(tmp, so);
movefile(fullfile(tmp, '*.sev'), sevOnly);
dS = EphysDataset(sevOnly);
check(TDTReader.claims(sevOnly) && dS.NumSamples == n && isempty(dS.DigInNames) && isnat(dS.AcqDate) ...
    && isequal(dS.readWindowUV(0, 50, Reference=false), double(R(1:50, :)) * 1e6), ...
    'a block of SEV files without a TSQ: samples, no lines, no start time');

%% ---- 7. EphysDataset / EphysProject / config ---------------------------------------------
fprintf('\n== 7. dataset, project, config ==\n');
ds.OutputDir = fullfile(root, 'out');
tc = ds.TrialConfig; tc.LineNames = "Freq=Stim"; ds.TrialConfig = tc;
E1 = ds.digitalEvents();
E2 = ds.digitalEvents();
check(E1.source == "read" && E2.source == "cache" && isfield(E2.events, 'Stim') && ~isfield(E2.events, 'Freq') ...
    && isequal(round(E2.events.Stim * Fs), rows("Freq")), 'LineNames renames an epoc line; the events are cached');
data = ds.readData(KeepChannels=1, LineNames="Tick=Clock");
check(isfield(data.events, 'Clock') && isequal(data.digInNames, ["Clock" "Freq" "Levl" "PC0_" "Late"]), ...
    'readData names the epoc lines too');
Pj = EphysProject(string(root));
check(any([Pj.Datasets.Name] == spec.Name) && all(arrayfun(@(x) x.Reader.Kind == "tdt", Pj.Datasets)), ...
    'a project scan finds the blocks of a tank');
[v, ~, ok] = parseNameTokens(spec.Name, TDTReader.DefaultNamePattern);
check(ok && isequal(v, ["Subj1" "260101" "120000"]), 'the default name pattern parses Synapse block names');
cfg = EphysPipelineConfig();
check(isfield(cfg.Acquisition, 'TDT') && cfg.Acquisition.TDT.Stream == "" && isnan(cfg.Acquisition.TDT.GainToMicrovolts), ...
    'the config has Acquisition.TDT (Stream "", GainToMicrovolts NaN)');
cfg.Acquisition.TDT.GainToMicrovolts = 0;
iss = cfg.validate(CheckPaths=false);
check(any(iss.Field == "TDT.GainToMicrovolts" & iss.Severity == "error"), 'validate: a gain that is not positive');
A = EphysPipelineConfig.normalizeSection("Acquisition", struct('TDT', struct('GainToMicrovolts', "NaN", 'Stream', 'Wav1')));
check(isnan(A.TDT.GainToMicrovolts) && A.TDT.Stream == "Wav1" && isfield(A, 'OpenEphys'), ...
    'normalizeSection fills and coerces Acquisition.TDT');

%% ---- 8. trials from the epocs --------------------------------------------------------------
fprintf('\n== 8. trials from the epocs ==\n');
tc = ds.TrialConfig; tc.LineNames = string.empty(1, 0); tc.TrialLine = "InTrial"; ds.TrialConfig = tc;
check(ds.behaviorSource() == "", 'a trial line that is not an epoc store: no trials');
tc.TrialLine = "Freq"; ds.TrialConfig = tc;
[src, store] = ds.behaviorSource();
check(src == "epocs" && store == "Freq", 'no Epsych2 session and the trial line is an epoc store: the epocs give the trials');
[Tt, info, meta] = ds.readBehavior();
nan4 = NaN(4, 1);
check(isequal(string(Tt.Properties.VariableNames), ["TrialIndex" "Freq" "Levl" "PC0_" "Late"]) ...
    && isequal(Tt.TrialIndex, (1:4).') && isequal(Tt.Freq, [1000; 2000; 4000; 8000]) && isequal(Tt.Levl, [10; 20; 30; 40]) ...
    && isequaln(Tt.PC0_, nan4) && isequaln(Tt.Late, nan4), ...
    'one trial per epoc; each other store''s value at the trial onset (NaN when none is active); no Tick');
check(isequal(string(info.WriteParams), ["Freq" "Levl" "PC0_" "Late"]) && info.TrialStore == "Freq" ...
    && meta.file == "" && meta.responseCodeField == "" && meta.nTrials == 4, ...
    'info lists the parameters (WriteParams); no session file, no response codes');
P = ds.pairTrials(Warn=false);
check(P.source == "epocs" && P.status == "approved" && P.autoApproved && ~P.countMismatch && P.nPaired == 4 ...
    && isequal(round(P.onset * Fs), [1001; 3001; 5001; 7001]) && isequal(round(P.offset * Fs), [1500; 3500; 5500; 7500]), ...
    'the epoc trials pair one to one with their own line, approved');
ds.setTrialPairing(P, P.status, Auto=P.autoApproved);
b = ds.behaviorStruct(Pairing=P);
check(b.file == "" && b.nTrials == 4 && b.pairing.source == "epocs" && all(ismember(["TrialOnset" "Levl"], ...
    string(b.trials.Properties.VariableNames))), 'behaviorStruct: the epoc trials with the pairing columns');
bo = ds.behaviorToMat(File=fullfile(root, 'beh', ds.Name + "_behavior.mat"), Pairing=P);
Bb = load(bo.file);
check(bo.nTrials == 4 && bo.paired && isequal(Bb.behavior.trials.Levl, [10; 20; 30; 40]), 'behaviorToMat writes them');
tc.LineNames = "Freq=Stim"; tc.TrialLine = "Stim"; ds.TrialConfig = tc;
[src, store] = ds.behaviorSource();
Tn = ds.readBehavior();
check(src == "epocs" && store == "Freq" && isequal(Tn.Stim, Tt.Freq), 'a renamed line: the trial line and the columns use the final names');
ds.BehaviorFile = fullfile(root, 'no_such_session.mat');
check(ds.behaviorSource() == "epsych2", 'an associated Epsych2 session wins over the epocs');
ds.BehaviorFile = "";
proj8 = fullfile(root, 'proj8');
mkdir(proj8);
copyfile(blk, fullfile(proj8, spec.Name));
cfg8 = EphysPipelineConfig();
cfg8.Project.Root = proj8;
cfg8.Project.OutputRoot = fullfile(root, 'pout');
cfg8.Behavior.Enabled = true;
cfg8.Behavior.Search = false;
cfg8.Behavior.TrialLine = "Freq";
pipe8 = EphysPipeline(cfg8);
pipe8.LogFcn = [];
pipe8.checkBehavior();
R8 = pipe8.Results;
d8 = pipe8.Project.Datasets(1);
Bp = load(pipe8.outputPathFor("behavior", d8));
check(any(R8.Step == "behavior:pairing" & R8.Status == "auto-approved") && any(R8.Step == "behavior:file" & R8.Status == "done") ...
    && isequal(Bp.behavior.trials.Levl, [10; 20; 30; 40]) && d8.TrialPairing.status == "approved", ...
    'the behavior step pairs and writes the epoc trials of a block without a session');

%% ---- 9. synthetic TDT recordings and project -------------------------------------------
fprintf('\n== 9. synthetic TDT recordings and project ==\n');
Fs9 = 12207.03125;   % 195312.5 / 16
T9 = makeSyntheticRecording(fullfile(root, 'syn', 'SYN-01', 'SYN-01-260102-120000'), Format="tdt", ...
    Subject="SYN-01", Scenario="spurious", Fs=Fs9, NumChannels=4, NumTrials=5, FileSeconds=4, ...
    SortedOutput=false, Artifacts=false, Seed=3);
d9 = EphysDataset(T9.folder);
check(d9.Reader.Kind == "tdt" && d9.Fs == Fs9 && d9.NumSamples == T9.nSamples && d9.NumChannels == 4 ...
    && isequal(d9.ChannelNames, T9.channelNames) && mod(T9.nSamples, 256) == 0 ...
    && abs(seconds(d9.AcqDate - T9.acqTime)) < 1e-3, ...
    'makeSyntheticRecording "tdt": a block the reader reads (rate, samples, channels, start)');
E9 = d9.digitalEvents(Relabel=false);
ok9 = numel(T9.lineNames) == numel(fieldnames(T9.events));
for ln = T9.lineNames
    kv = split(ln, "=");
    got = zeros(0, 2);   % a line never active writes no epocs, so the block has no store for it
    if isfield(E9.events, kv(1)); got = E9.events.(kv(1)); end
    ok9 = ok9 && isequal(reshape(round(got * Fs9), [], 2), reshape(round(T9.events.(kv(2)) * Fs9), [], 2));
end
check(ok9 && startsWith(T9.lineNames(1), "PC0_="), 'each line reads back at the rows it was written (store PCn_ = its name; a line never active has none)');
tc = d9.TrialConfig; tc.LineNames = T9.lineNames; tc.TrialLine = T9.trialLine; d9.TrialConfig = tc;
d9.BehaviorFile = T9.behaviorFile;
P9 = d9.pairTrials(Cuts=T9.expectedCuts, Warn=false);
ok9 = ~isnan(T9.trials.Onset);
check(P9.source == "epsych2" && P9.nPaired == nnz(ok9) && ~P9.countMismatch ...
    && isequal(round(P9.onset(~isnan(P9.onset)) * Fs9), round(T9.trials.Onset(ok9) * Fs9)), ...
    'with its Epsych2 session and the expected cuts, the trials pair at the written onsets');
d9.BehaviorFile = "";
[src, store] = d9.behaviorSource();
T9e = d9.readBehavior();
k9 = find(endsWith(T9.lineNames, "=" + T9.trialLine), 1);
check(src == "epocs" && store == extractBefore(T9.lineNames(k9), "=") && height(T9e) == T9.nIntervals, ...
    'without the session, the trial line''s epocs give the trials, one per interval');

S9 = makeSyntheticProject(fullfile(root, 'synproj'), Format="tdt", Preset="small", Scenarios="clean", ...
    SortedOutput=false, Artifacts=false);
cfg9 = EphysPipelineConfig.load(S9.configFile);
check(S9.format == "tdt" && cfg9.Project.NamePattern == TDTReader.DefaultNamePattern ...
    && isequal(cfg9.Signals.LineNames, S9.datasets(1).lineNames) && ~cfg9.Signals.AUX ...
    && S9.datasets(1).Fs == 195312.5 / 16, 'makeSyntheticProject "tdt": the config names the epoc stores, no AUX, a TDT rate');
pipe9 = EphysPipeline(cfg9);
pipe9.LogFcn = [];
pipe9.checkBehavior();
d9p = pipe9.Project.Datasets(1);
P9p = d9p.pairTrials(Warn=false);
check(pipe9.Project.NumDatasets == 1 && d9p.Reader.Kind == "tdt" && P9p.source == "epsych2" ...
    && ~P9p.countMismatch && P9p.nPaired == S9.datasets(1).nTrials ...
    && any(pipe9.Results.Step == "behavior:pairing" & pipe9.Results.Status ~= "error"), ...
    'the pipeline finds the block, its session, and pairs every trial');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_TDTReader:Failed', '%d checks failed.', nFail);
end
end


function s = streamSpec(name, fs, data, opts)
%streamSpec  One element of writeTDTBlock's Streams.
arguments
    name
    fs
    data
    opts.Npts = 256
    opts.Sev = false
    opts.T0 = 0
    opts.ChunkTimes = []
    opts.Rate = []
    opts.Decimate = []
end
s = struct('Name', name, 'Fs', fs, 'Data', data, 'Npts', opts.Npts, 'Sev', opts.Sev, 'T0', opts.T0, ...
    'ChunkTimes', opts.ChunkTimes, 'Rate', opts.Rate, 'Decimate', opts.Decimate, 'Channels', []);
end


function rmdirQuiet(p)
try
    if isfolder(p); rmdir(p, 's'); end
catch
end
end
