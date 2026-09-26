function T = makeSyntheticRecording(folder, opts)
%makeSyntheticRecording  Write one synthetic recording with its Epsych2 session (test data).
%   T = makeSyntheticRecording(folder, Name=Value) writes into FOLDER a
%   recording shaped like what the lab acquires with an Intan RHX system
%   while Epsych2 runs a task, with everything the pipeline consumes, and
%   returns the truth of what was written in T:
%
%     amplifier data     what Design describes (default SyntheticDesign.builtIn):
%                        LFP rhythms with a depth profile, 1/f-like and white
%                        noise, line noise, event-locked LFP (by default a
%                        stimulus-evoked potential), spiking units with
%                        realistic waveforms spread over the neighbouring
%                        sites whose rates follow the events, and
%                        (Artifacts) two large artifacts, one of them
%                        saturating the ADC
%     digital inputs     the schedule's lines. The built-in task has the six
%                        lines of the lab's rig, in RHX order: Trough (nose
%                        pokes), Platform, Stim, InTrial (the trial line),
%                        RespWindow, Commutator (never active)
%     aux inputs         three accelerometer channels at Fs/4 (Intan layouts;
%                        Open Ephys formats hold each value for 4 samples)
%     Epsych2 session    <Subject>_<yymmdd>T<HHMMSS>.mat (Data + Info) in the
%                        recording folder, named from its start time as
%                        Epsych2 does
%     sorted output      (SortedOutput) the ground-truth units as Kilosort4 /
%                        phy files under kilosort4/, where runKilosort puts
%                        them, so the Spikes, Export and Review steps have
%                        sorted units without Python
%     manifest           (WriteManifest) with the session and ProbeFile
%                        associated, as after a run
%     <Name>_synthetic.json   the design, the schedule's source and the seed
%
%   The schedule: when the events happen
%     By default the built-in AM-detection task (syntheticTaskSchedule), one
%     trial per InTrial interval, with a Scenario for how the recording
%     relates to the Epsych2 session:
%       "clean"       the recording covers every trial: as many InTrial
%                     intervals as trials
%       "late-start"  the recording started during trial 3: trials 1-2 have no
%                     interval and interval 1 is partial (it begins at sample 1)
%       "early-stop"  the recording stopped during trial N-2: the last interval
%                     is partial (it ends at the last sample) and trials N-1, N
%                     have none
%       "spurious"    a 40 ms pulse on InTrial before the first trial (the line
%                     toggled when the protocol loaded) that is not a trial
%     T.expectedCuts gives the cuts (trials / intervals dropped from the start
%     and the end) after which every remaining trial pairs with a whole
%     interval; see pairEpsychTrials.
%     Session=S (syntheticSessionSchedule) takes a real Epsych2 session
%     instead: the recording gets its lines (as recorded, or rebuilt from the
%     session's parameters) over its length, and a copy of the session is
%     written next to it (Data as saved; Info with this Subject, the new
%     file name and an Info.Synthetic note naming the source). The copy's
%     times move with AcqTime. NumTrials and Scenario do not apply.
%
%   Options
%     Subject        "SYNTH-01"
%     Design         SyntheticDesign: units, event-linked LFP, background
%                    (default SyntheticDesign.builtIn(NumChannels))
%     Session        schedule struct from syntheticSessionSchedule (default:
%                    the built-in task)
%     Scenario       "clean" (default) | "late-start" | "early-stop" | "spurious"
%     NumTrials      12 (at least 4)
%     MaxDuration    Inf: with Session, stop the recording after this many
%                    seconds (lines still on then end at the last sample)
%     Format         "traditional" (default: RHX-style *.rhd files of
%                    FileSeconds each) | "one-file-per-signal" (info.rhd +
%                    *.dat) | "binary" (recording.json + .bin; no aux inputs)
%                    | "openephys-binary" | "openephys-legacy" |
%                    "openephys-nwb" (an Open Ephys GUI session: FOLDER is
%                    the session folder, holding "Record Node 101"; channels
%                    CH1.., lines TTL1.. in the schedule's order, name them
%                    with Signals.LineNames, see T.lineNames; the sample
%                    count is a multiple of 1024) | "tdt" (a TDT Synapse
%                    block: FOLDER is the block folder, holding
%                    <name>.tsq / .tev; stream Wav1 of Ch1.. in float32
%                    volts; each line a strobe epoc store PC0_, PC1_, .. in
%                    the schedule's order, named with Signals.LineNames, see
%                    T.lineNames; no aux inputs; Fs must divide TDT's
%                    195312.5 Hz clock, default 24414.0625; the sample count
%                    is a multiple of 256)
%     Parts          1 (Open Ephys formats): split the session into this many
%                    recordings (recording stopped and restarted, 2 s apart),
%                    each boundary outside the trial line's intervals. T.events is
%                    then what an Open Ephys reader sees: intervals split at
%                    the boundaries, and a line already high when a recording
%                    starts is lost where the format cannot know it (the Open
%                    Ephys format without an edge in that recording; NWB in
%                    a recording without any edge)
%     Fs             30000 (with Session: the source's rate when known;
%                    "tdt": 24414.0625, or the source's when it is a TDT rate)
%     NumChannels    16 (at least 2; with Session: the source's count)
%     FileSeconds    30 (also the size of the chunks generated in memory)
%     AcqTime        nominal start of the recording (default: with Session,
%                    the source recording's start; else 2 min ago). The
%                    built-in session starts 65 s earlier, as in the lab. The
%                    Intan files are named from it as RHX names them and
%                    stamped as RHX leaves them: each data file with the
%                    time it was closed (the end of its data), info.rhd
%                    with the start (T.fileTimesSet says whether the
%                    stamping worked)
%     Seed           1 (the same seed gives the same data in every format)
%     Probe          struct chanMap / xc / yc / kcoords for the site geometry
%                    (default: with Session, its probe file when it has the
%                    sites; else makeSyntheticProbe(NumChannels))
%     ProbeFile      probe .json recorded in the manifest (default: with
%                    Session, its probe file when that gave the sites; else
%                    none, or with WriteProbe the synthetic probe)
%     WriteProbe     false: true writes the synthetic probe (when no probe
%                    file gave the sites) as <Name>_probe.json in FOLDER
%                    and records it in the manifest
%     PreviewOnly    false: true writes nothing and returns, at once, what
%                    would be written: T.model (syntheticModel), T.schedule
%                    and the fields up to trials (the app's Synthetic tab
%                    previews this, so the preview is what Generate writes)
%     SortedOutput   true
%     Artifacts      true
%     InvertedLines  lines written with inverted logic: on = low (default
%                    none; with a Session, the lines its source inverts,
%                    except for the Open Ephys and TDT formats, which cannot)
%     WriteManifest  true
%     ProgressFcn    ProgressFcn(fraction, message)
%
%   T fields: folder, name, subject, scenario ("session" with Session),
%   format, parts (part end rows), lineNames (Open Ephys: "TTL1=Trough",
%   ...), Fs, nSamples, duration, files, acqTime, sessionStart,
%   behaviorFile, channelNames, digInNames, digInOrders, trialLine,
%   invertedLines, events (struct: line -> [k x 2] seconds ON, t = row/Fs,
%   the readers' convention), nTrials, nIntervals, expectedCuts (trials /
%   intervals [start end]; NaN with Session), trials (table: TrialIndex,
%   TrialType, RespCode (NaN when the session has none), Onset, Offset,
%   Interval; NaN outside the recording), units (struct array: id,
%   name, peakChannel, samples (1-based rows), amplitudeUV, widthMs,
%   baselineHz, label, modulation, event, edge, shape, gain, latencyMs,
%   durationMs, jitterMs, parameter, tuning, eventTimes (s: the edges it
%   responds to), starts (s: its responses' starts)), lfp (the resolved LFP
%   components, see syntheticModel), design, source (the schedule's
%   source, "" for the built-in task), designFile, artifacts ([k x 2] s),
%   aux (names, Fs), sortedDir, manifestFile, probeFile (the probe the
%   manifest records, "" for none), probeSource ("given" | "session" |
%   "synthetic": where the sites came from), fileTimesSet, bytes, seed.
%
%   See also makeSyntheticProject, makeSyntheticProbe, SyntheticDesign,
%   syntheticModel, syntheticTaskSchedule, syntheticSessionSchedule,
%   EphysDataset, pairEpsychTrials, readEpsychSession.

arguments
    folder (1,1) string
    opts.Subject (1,1) string = "SYNTH-01"
    opts.Design = []
    opts.Session (1,1) struct = struct()
    opts.Scenario (1,1) string {mustBeMember(opts.Scenario, ["clean" "late-start" "early-stop" "spurious"])} = "clean"
    opts.NumTrials (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(opts.NumTrials, 4)} = 12
    opts.MaxDuration (1,1) double {mustBePositive} = Inf
    opts.Format (1,1) string {mustBeMember(opts.Format, ["traditional" "one-file-per-signal" "binary" ...
        "openephys-binary" "openephys-legacy" "openephys-nwb" "tdt"])} = "traditional"
    opts.Fs (1,1) double = NaN
    opts.NumChannels (1,1) double = NaN
    opts.FileSeconds (1,1) double {mustBePositive} = 30
    opts.AcqTime datetime = NaT
    opts.Seed (1,1) double {mustBeInteger, mustBeInRange(opts.Seed, 0, 4294967295)} = 1
    opts.Probe (1,1) struct = struct()
    opts.ProbeFile (1,1) string = ""
    opts.WriteProbe (1,1) logical = false
    opts.PreviewOnly (1,1) logical = false
    opts.SortedOutput (1,1) logical = true
    opts.Artifacts (1,1) logical = true
    opts.InvertedLines (1,:) string = string.empty(1,0)
    opts.Parts (1,1) double {mustBeInteger, mustBePositive} = 1
    opts.WriteManifest (1,1) logical = true
    opts.ProgressFcn = []
end

rngState = rng;                     % the caller's generator, put back at the end
restoreRng = onCleanup(@() rng(rngState)); %#ok<NASGU>
rng(opts.Seed, 'twister');
fromSession = ~isempty(fieldnames(opts.Session));
S = opts.Session;
if fromSession && ~(isfield(S, 'kind') && S.kind == "session")
    error('makeSyntheticRecording:Session', 'Session must be a schedule from syntheticSessionSchedule.');
end
if ~fromSession && isfinite(opts.MaxDuration)
    error('makeSyntheticRecording:MaxDuration', 'MaxDuration applies with a Session only.');
end
isTDT = opts.Format == "tdt";
tdtRate = @(f) isfinite(f) && f > 0 && abs(195312.5 / f - round(195312.5 / f)) < 1e-9;
Fs = opts.Fs;
if isnan(Fs)
    Fs = 30000;
    if isTDT; Fs = 24414.0625; end
    if fromSession && isfinite(S.Fs) && (~isTDT || tdtRate(S.Fs)); Fs = S.Fs; end
end
if isTDT && ~tdtRate(Fs)
    error('makeSyntheticRecording:TDTRate', ...
        'A TDT block''s rate must divide 195312.5 Hz (e.g. 24414.0625 or 12207.03125); %g does not.', Fs);
end
nCh = opts.NumChannels;
if isnan(nCh)
    nCh = 16;
    if fromSession && isfinite(S.nChannels); nCh = S.nChannels; end
end
if ~(Fs > 0) || ~(nCh >= 2 && nCh == round(nCh))
    error('makeSyntheticRecording:Size', 'Fs must be > 0 and NumChannels a whole number >= 2.');
end
spb  = 128;                 % samples per RHD data block (v2+ files)
uvPerBit = 0.195;           % Intan amplifier resolution
auxVoltsPerBit = 37.4e-6;   % Intan aux-input resolution
fmt = opts.Format;
isOE = startsWith(fmt, "openephys-");
if opts.Parts > 1 && ~isOE
    error('makeSyntheticRecording:Parts', 'Parts applies to the Open Ephys formats only.');
end
if (isOE || isTDT) && ~isempty(opts.InvertedLines)
    error('makeSyntheticRecording:InvertedLines', 'InvertedLines is not supported for the Open Ephys and TDT formats.');
end
if isOE
    spb = 1024;   % whole Open Ephys records: no zero padding at the end of a recording
end
if isTDT
    spb = 256;    % whole TDT stream chunks
end
D = opts.Design;
if isempty(D); D = SyntheticDesign.builtIn(nCh); end
if ~isa(D, 'SyntheticDesign')
    error('makeSyntheticRecording:Design', 'Design must be a SyntheticDesign.');
end

subject = opts.Subject;
folder = string(folder);
[~, leaf] = fileparts(char(folder));
name = string(leaf);

    function tick(frac, msg)
        if ~isempty(opts.ProgressFcn); opts.ProgressFcn(frac, string(msg)); end
    end

% --- the schedule ---------------------------------------------------------------
if fromSession
    scenario = "session";
    acq = opts.AcqTime;
    if isnat(acq); acq = S.acqTime; end
    if isnat(acq); acq = dateshift(datetime('now') - minutes(2), 'start', 'second'); end
    L = min(S.duration, opts.MaxDuration);
    if isfinite(S.nSamples) && Fs == S.Fs && ~isfinite(opts.MaxDuration)
        nSamp = ceil(S.nSamples / spb) * spb;    % as long as the source (padded to whole blocks)
    else
        nSamp = max(spb, ceil(L * Fs / spb) * spb);
    end
    if isfinite(opts.MaxDuration)
        nSamp = max(spb, floor(opts.MaxDuration * Fs / spb) * spb);
        nSamp = min(nSamp, ceil(S.duration * Fs / spb) * spb);
    end
    cuts = struct('trials', [NaN NaN], 'intervals', [NaN NaN]);
    S = alignToRate(S, Fs, nSamp);
else
    S = syntheticTaskSchedule(NumTrials=opts.NumTrials, Scenario=opts.Scenario);
    scenario = opts.Scenario;
    acq = opts.AcqTime;
    if isnat(acq); acq = dateshift(datetime('now') - minutes(2), 'start', 'second'); end
    if scenario == "early-stop"
        nSamp = round(S.duration * Fs / spb) * spb;
    else
        nSamp = ceil(S.duration * Fs / spb) * spb;
    end
    cuts = S.expectedCuts;
end
L = nSamp / Fs;
lineNames = reshape(string(S.lineNames), 1, []);
trialLine = string(S.trialLine);
nLines = numel(lineNames);
if nLines > 16
    error('makeSyntheticRecording:Lines', 'The schedule has %d digital lines; at most 16 can be written.', nLines);
end
bad = setdiff(opts.InvertedLines, lineNames);
if ~isempty(bad)
    error('makeSyntheticRecording:InvertedLines', 'Unknown line(s) in InvertedLines: %s', strjoin(bad, ', '));
end
inverted = opts.InvertedLines;
if fromSession && isempty(inverted) && ~isOE && ~isTDT && isfield(S, 'invertedLines')
    inverted = intersect(reshape(string(S.invertedLines), 1, []), lineNames, 'stable');   % as the source records them
end

% --- the probe --------------------------------------------------------------------
probe = opts.Probe;
probeFile = opts.ProbeFile;                 % the probe the manifest records
probeSource = "given";
if isempty(fieldnames(probe)) && fromSession && S.probeFile ~= "" && isfile(S.probeFile)
    p = readJsonFile(S.probeFile, ErrorOnFail=false);
    if isstruct(p) && isfield(p, 'xc') && isfield(p, 'yc') && numel(p.xc) >= nCh && numel(p.yc) >= nCh
        probe = sitesInChannelOrder(p, nCh);
        probeSource = "session";
        if probeFile == ""; probeFile = S.probeFile; end
    end
end
if isempty(fieldnames(probe))
    probe = makeSyntheticProbe(nCh);
    probeSource = "synthetic";
end
xc = double(probe.xc(:)); yc = double(probe.yc(:));
if numel(xc) < nCh
    error('makeSyntheticRecording:Probe', 'The probe has %d sites but the recording %d channels.', numel(xc), nCh);
end
xc = xc(1:nCh); yc = yc(1:nCh);
kcoords = zeros(nCh, 1);
if isfield(probe, 'kcoords'); kcoords = double(probe.kcoords(:)); kcoords = kcoords(1:nCh); end

% --- channel names (as RHX writes them) ---------------------------------------
ampNames   = "A-" + string(compose('%03d', (0:nCh-1).')).';
auxNames   = ["accelX" "accelY" "accelZ"];
auxNative  = "A-AUX" + string(1:3);
lineNative = "DIGITAL-IN-" + string(compose('%02d', (1:nLines).')).';
lineOrders = 1:nLines;                  % RHX: DIGITAL-IN-01 is bit 1 of the word
if fmt == "binary" || isOE || isTDT
    lineBits = 0:nLines-1;              % recording.json: bit k = dig_in_names(k+1); Open Ephys: TTL k+1; TDT: store k
else
    lineBits = lineOrders;
end
oeLineNames = "TTL" + (1:nLines) + "=" + lineNames;
tdtStores = "PC" + string(cellstr(dec2hex(0:nLines-1))).' + "_";   % PC0_, PC1_, ..., PCF_
tdtLineNames = tdtStores + "=" + lineNames;

% --- the model: lines at Fs, units, LFP, background -------------------------------
M = syntheticModel(S, D, Fs, nSamp, struct('xc', xc, 'yc', yc), Artifacts=opts.Artifacts);
rows = M.rows;
trialRows = M.trialRows;
[~, trialInterval] = ismember(trialRows, rows.(trialLine), 'rows');
trialInterval = double(trialInterval);
trialInterval(isnan(trialRows(:, 1)) | trialInterval == 0) = NaN;
nIntervals = size(rows.(trialLine), 1);
nt = M.nt;
artRows = M.artifacts;
if opts.PreviewOnly
    T = previewResult(M, S, folder, name, subject, scenario, fmt, Fs, nSamp, acq, lineNames, trialLine, ...
        trialRows, trialInterval, nIntervals, cuts, D, probeSource, probeFile, xc, yc, kcoords, opts.Seed);
    return
end
auxBase = [1.65 1.70 2.00]; auxF = [0.9 1.3 0.7]; auxPh = 2 * pi * rand(1, 3);

% --- Open Ephys recordings (parts): boundaries outside the trial line's intervals --
partEnd = nSamp;
if isOE && opts.Parts > 1
    partEnd = zeros(1, opts.Parts);
    tl = rows.(trialLine);
    for k = 1:opts.Parts - 1
        b = round(k * nSamp / opts.Parts / 1024) * 1024;
        while any(tl(:, 1) <= b + 1 & tl(:, 2) >= b) && b + 1024 < nSamp
            b = b + 1024;
        end
        partEnd(k) = b;
    end
    partEnd(end) = nSamp;
    partEnd = unique(partEnd);
end
gapS = 2;                                  % wall-clock pause between recordings
firstSample = 123456;                      % acquisition was running before recording started

% --- write, one segment (= one traditional file) at a time --------------------
if ~isfolder(folder); mkdir(folder); end
nSegSamp = max(spb, round(opts.FileSeconds * Fs / spb) * spb);
nSeg = ceil(nSamp / nSegSamp);
files = strings(1, 0); fileTimes = datetime.empty(1, 0);
fids = struct();
switch fmt
    case "one-file-per-signal"
        writeInfoRHD(fullfile(folder, 'info.rhd'), nCh, Fs, 3, AmpNames=ampNames, AmpNative=ampNames, ...
            DigInNames=lineNames, DigInOrders=lineOrders, DigInNative=lineNative, ...
            AuxNames=auxNames, AuxNative=auxNative, Version=[3 0]);
        fids.amp = fopen(fullfile(folder, 'amplifier.dat'), 'w', 'ieee-le');
        fids.time = fopen(fullfile(folder, 'time.dat'), 'w', 'ieee-le');
        fids.dig = fopen(fullfile(folder, 'digitalin.dat'), 'w', 'ieee-le');
        fids.aux = fopen(fullfile(folder, 'auxiliary.dat'), 'w', 'ieee-le');
        files = ["info.rhd" "amplifier.dat" "time.dat" "digitalin.dat" "auxiliary.dat"];
    case "binary"
        fids.amp = fopen(fullfile(folder, name + ".bin"), 'w', 'ieee-le');
        fids.dig = fopen(fullfile(folder, 'digitalin.dat'), 'w', 'ieee-le');
        files = [name + ".bin", "digitalin.dat"];
end
closer = onCleanup(@() closeAll(fids));
oeW = [];
if isOE
    meta = struct('Fs', Fs, 'NumChannels', nCh, 'AuxCount', 3, 'BitVolts', uvPerBit, 'AuxBitVolts', auxVoltsPerBit);
    switch fmt
        case "openephys-binary", oeW = writeOpenEphysBinary(folder, meta);
        case "openephys-legacy", oeW = writeOpenEphysLegacy(folder, meta);
        case "openephys-nwb",    oeW = writeOpenEphysNWB(folder, meta);
    end
    oePart = 1;
    oeW.begin(1, 1, firstSample, acq);
end
tdtW = [];
if isTDT
    tdtW = writeTDTStream('open', [], char(folder), struct('Name', char(name), 'Fs', Fs, ...
        'NumChannels', nCh, 'StartTime', posixtime(datetime(acq, 'TimeZone', 'local')), ...
        'LineStores', {cellstr(tdtStores)}));
end
if fromSession
    notes = [sprintf("Synthetic recording (seed %d) written by makeSyntheticRecording", opts.Seed), ...
        "Schedule from the Epsych2 session of " + S.source, ""];
else
    notes = [sprintf("Synthetic recording (%s scenario, seed %d) written by makeSyntheticRecording", scenario, opts.Seed), "", ""];
end

for sIdx = 1:nSeg
    s0 = (sIdx - 1) * nSegSamp;
    n  = min(nSegSamp, nSamp - s0);
    tick((sIdx - 1) / (nSeg + 1), sprintf("Writing %s: segment %d of %d", name, sIdx, nSeg));
    t = (s0 + (0:n-1)).' / Fs;
    X = M.signal(s0, n);
    % digital word
    W = zeros(n, 1, 'uint16');
    for k = 1:nLines
        bit = uint16(2^lineBits(k));
        iv = rows.(lineNames(k));
        for i = find(iv(:, 2) >= s0 + 1 & iv(:, 1) <= s0 + n).'
            r1 = max(iv(i, 1), s0 + 1) - s0; r2 = min(iv(i, 2), s0 + n) - s0;
            W(r1:r2) = bitor(W(r1:r2), bit);
        end
        if ismember(lineNames(k), inverted)
            W = bitxor(W, bit);
        end
    end
    % accelerometer at Fs/4: the animal moves between trials
    t4 = t(1:4:end);
    moving = ones(numel(t4), 1);
    tl = rows.(trialLine);
    for i = find(tl(:, 2) >= s0 + 1 & tl(:, 1) <= s0 + n).'
        moving(t4 >= (tl(i, 1) - 1) / Fs & t4 <= tl(i, 2) / Fs) = 0.15;
    end
    V = auxBase + moving .* (0.06 * sin(2 * pi * auxF .* t4 + auxPh) + 0.03 * sin(2 * pi * 3.1 * auxF .* t4)) ...
        + 0.004 * randn(numel(t4), 3);
    auxRaw = uint16(min(max(round(V / auxVoltsPerBit), 0), 65535)).';   % [3 x n/4]

    switch fmt
        case "traditional"
            ampRaw = uint16(min(max(round(X / uvPerBit) + 32768, 0), 65535)).';
            ft = acq + seconds(s0 / Fs);
            fname = subject + "_" + fmtTime(ft, 'yyMMdd_HHmmss') + ".rhd";
            writeSyntheticRHD(fullfile(folder, fname), ampRaw, W, Fs, spb, ...
                AmpNames=ampNames, AmpNative=ampNames, DigInNames=lineNames, DigInOrders=lineOrders, ...
                DigInNative=lineNative, AuxRaw=auxRaw, AuxNames=auxNames, AuxNative=auxNative, ...
                Version=[3 0], FirstTimestamp=s0, Notes=notes);
            files(end+1) = fname; fileTimes(end+1) = ft + seconds(n / Fs); %#ok<AGROW> RHX: closed at its end
        case "one-file-per-signal"
            fwrite(fids.amp, int16(min(max(round(X / uvPerBit), -32768), 32767)).', 'int16');
            fwrite(fids.time, int32(s0 + (0:n-1)), 'int32');
            fwrite(fids.dig, W, 'uint16');
            fwrite(fids.aux, repelem(auxRaw, 1, 4), 'uint16');       % RHX holds each value for 4 samples
        case "binary"
            fwrite(fids.amp, int16(min(max(round(X / uvPerBit), -32768), 32767)).', 'int16');
            fwrite(fids.dig, W, 'uint16');
        case "tdt"
            tdtW = writeTDTStream('append', tdtW, X, W);
        otherwise   % Open Ephys: AUX held for 4 samples, stored as (raw - 32768) * 37.4 uV
            A = repelem((double(auxRaw.') - 32768) * auxVoltsPerBit, 4, 1);
            A = A(1:n, :);
            r = 1;
            while r <= n
                stop = min(n, partEnd(oePart) - s0);
                oeW.append(X(r:stop, :), W(r:stop), A(r:stop, :));
                r = stop + 1;
                if s0 + stop == partEnd(oePart) && oePart < numel(partEnd)
                    oeW.finish();
                    oePart = oePart + 1;
                    b = partEnd(oePart - 1);
                    oeW.begin(1, oePart, firstSample + b + round(gapS * (oePart - 1) * Fs), ...
                        acq + seconds(b / Fs + gapS * (oePart - 1)));
                end
            end
    end
end
delete(closer);
if isOE
    oeW.finish();
    if isfield(oeW, 'closeAll'); oeW.closeAll(); end
end
if isTDT
    writeTDTStream('close', tdtW);
end
switch fmt
    case "traditional"              % RHX: each file closed at its end (the times set above)
    case "one-file-per-signal"      % RHX: info.rhd written at the start, the .dat files closed at the end
        fileTimes = [acq, repmat(acq + seconds(nSamp / Fs), 1, numel(files) - 1)];
    case "binary"
        src = struct('tool', "makeSyntheticRecording", 'scenario', scenario, 'seed', opts.Seed);
        if fromSession; src.session = S.source; end
        BinaryReader.writeDescriptor(folder, struct( ...
            'name', name, 'data_file', name + ".bin", 'dtype', "int16", 'n_chan', nCh, 'fs', Fs, ...
            'n_samples', nSamp, 'gain_to_uV', uvPerBit, 'offset', 0, ...
            'channel_names', {cellstr(ampNames)}, 'native_names', {cellstr(ampNames)}, ...
            'dig_in_names', {cellstr(lineNames)}, 'dig_in_file', "digitalin.dat", ...
            'acq_date', fmtTime(acq, 'yyyy-MM-dd HH:mm:ss'), 'source', src));
        files = ["recording.json", files];
        fileTimes = repmat(acq, 1, numel(files));
    otherwise   % Open Ephys, TDT: start times are in the recording's own files
        Dir = dir(fullfile(folder, '**', '*'));
        Dir = Dir(~[Dir.isdir]);
        files = string(erase(fullfile({Dir.folder}, {Dir.name}), [char(folder) filesep]));
        fileTimes = repmat(acq, 1, numel(files));
end
timesOk = true;
for k = 1:numel(files)
    timesOk = setFileModifiedTime(fullfile(folder, files(k)), fileTimes(k)) && timesOk;
end

% --- the Epsych2 session file ---------------------------------------------------
tick(nSeg / (nSeg + 1), "Writing the Epsych2 session");
if fromSession
    [Data, Info, sessionStart] = sessionCopy(S, acq, subject);
else
    sessionStart = acq - seconds(S.sessionLead);
    Data = S.Data;
    ts = sessionStart + seconds(S.trialEnd);        % session-relative trial ends
    for k = 1:numel(Data); Data(k).computerTimestamp = ts(k); end
end
behFile = fullfile(folder, subject + "_" + fmtTime(sessionStart, 'yyMMdd''T''HHmmss') + ".mat");
if fromSession
    Info.DataFilename = char(behFile);
else
    Info = taskInfo(subject, behFile, sessionStart, scenario, opts.Seed);
end
save(behFile, 'Data', 'Info');
setFileModifiedTime(behFile, sessionStart);

% --- ground-truth sorted output (Kilosort4 / phy files) --------------------------
units = M.units;
nU = numel(units);
ampUV = [units.amplitudeUV];
sortedDir = "";
labels = strings(1, 0);
if opts.SortedOutput
    tick(nSeg / (nSeg + 1), "Writing the ground-truth sorted output");
    sortedDir = fullfile(folder, 'kilosort4');
    if ~isfolder(sortedDir); mkdir(sortedDir); end
    allS = zeros(0, 1); allC = zeros(0, 1); allA = zeros(0, 1);
    for u = 1:nU
        allS = [allS; units(u).samples(:) - 1]; %#ok<AGROW>
        allC = [allC; (u - 1) * ones(numel(units(u).samples), 1)]; %#ok<AGROW>
        allA = [allA; units(u).scales(:)]; %#ok<AGROW>
    end
    nNoise = 25;                                        % a "noise" cluster on the artifacts
    if ~isempty(artRows)
        k = randi(size(artRows, 1), nNoise, 1);
        sN = artRows(k, 1) + floor(rand(nNoise, 1) .* (artRows(k, 2) - artRows(k, 1)));
    else
        sN = randi([nt, nSamp - nt], nNoise, 1);
    end
    allS = [allS; sN - 1]; allC = [allC; nU * ones(nNoise, 1)]; allA = [allA; 3 + rand(nNoise, 1)];
    [allS, order] = sort(allS); allC = allC(order); allA = allA(order);
    writeNPY(fullfile(sortedDir, 'spike_times.npy'), int64(allS));
    writeNPY(fullfile(sortedDir, 'spike_clusters.npy'), int32(allC));
    writeNPY(fullfile(sortedDir, 'spike_templates.npy'), int32(allC));
    writeNPY(fullfile(sortedDir, 'amplitudes.npy'), double(allA));
    T3 = zeros(nU + 1, nt, nCh, 'single');
    for u = 1:nU; T3(u, :, :) = single(units(u).template); end
    T3(nU + 1, :, :) = single(20 * randn(nt, nCh));
    writeNPY(fullfile(sortedDir, 'templates.npy'), T3);
    writeNPY(fullfile(sortedDir, 'channel_map.npy'), int32((0:nCh-1).'));
    writeNPY(fullfile(sortedDir, 'channel_positions.npy'), [xc yc]);
    writeNPY(fullfile(sortedDir, 'channel_shanks.npy'), int32(kcoords));
    fid = fopen(fullfile(sortedDir, 'params.py'), 'w');
    fprintf(fid, 'dat_path = ''temp_wh.dat''\nn_channels_dat = %d\ndtype = ''int16''\noffset = 0\nsample_rate = %.10g\nhp_filtered = True\n', nCh, Fs);
    fclose(fid);
    labels = repmat("mua", 1, nU); labels(ampUV >= 100) = "good";
    fid = fopen(fullfile(sortedDir, 'cluster_KSLabel.tsv'), 'w');
    fprintf(fid, 'cluster_id\tKSLabel\n');
    for u = 1:nU; fprintf(fid, '%d\t%s\n', u - 1, labels(u)); end
    fprintf(fid, '%d\tnoise\n', nU);
    fclose(fid);
    fid = fopen(fullfile(sortedDir, 'cluster_Amplitude.tsv'), 'w');
    fprintf(fid, 'cluster_id\tAmplitude\n');
    for u = 1:nU; fprintf(fid, '%d\t%.1f\n', u - 1, ampUV(u)); end
    fprintf(fid, '%d\t%.1f\n', nU, 30);
    fclose(fid);
    fid = fopen(fullfile(sortedDir, 'cluster_ContamPct.tsv'), 'w');
    fprintf(fid, 'cluster_id\tContamPct\n');
    for u = 1:nU; fprintf(fid, '%d\t%.2f\n', u - 1, 0.2 + 3.8 * rand); end
    fprintf(fid, '%d\t%.2f\n', nU, 60);
    fclose(fid);
    writeJsonFile(fullfile(folder, 'kilosort4', 'ks4_status.json'), struct('state', "done", ...
        'num_units', nU + 1, 'bad_channels', {{}}, 'dropped_params', {{}}, ...
        'source', "synthetic ground truth (makeSyntheticRecording)"));
end

% --- the design, for the record ----------------------------------------------------
source = ""; sourceFile = ""; timing = "task";
if fromSession
    source = S.source; sourceFile = S.behaviorFile;
    if isfield(S, 'timing'); timing = S.timing; end
end
designFile = fullfile(folder, name + "_synthetic.json");
writeJsonFile(designFile, struct('tool', "makeSyntheticRecording", 'seed', opts.Seed, 'Fs', Fs, ...
    'numChannels', nCh, 'schedule', struct('kind', string(S.kind), 'scenario', scenario, 'source', source, ...
    'behaviorFile', sourceFile, 'timing', timing), 'design', D.toStruct()), NonFinite="string");

% --- verify by reading the headers back; write the manifest ----------------------
ds = EphysDataset(folder);
if ds.NumSamples ~= nSamp || ds.NumChannels ~= nCh || ds.Fs ~= Fs
    error('makeSyntheticRecording:Verify', ...
        'The written recording reads back as %d samples, %d channels at %g Hz (expected %d, %d, %g).', ...
        ds.NumSamples, ds.NumChannels, ds.Fs, nSamp, nCh, Fs);
end
manifestFile = "";
if opts.WriteManifest
    ds.BehaviorFile = string(behFile);
    if probeFile == "" && opts.WriteProbe && probeSource == "synthetic"
        probeFile = fullfile(folder, name + "_probe.json");
        writeJsonFile(probeFile, struct('notes', sprintf("Synthetic %d-channel probe of %s (makeSyntheticRecording).", nCh, name), ...
            'chanMap', 0:nCh-1, 'xc', xc.', 'yc', yc.', 'kcoords', kcoords.', 'n_chan', nCh));
    end
    if probeFile ~= "" && isfile(probeFile); ds.ProbeFile = probeFile; end
    ds.writeManifest();
    manifestFile = string(ds.manifestFile());
end
tick(1, "Done");

% --- the truth -------------------------------------------------------------------
events = struct();
for ln = lineNames
    iv = rows.(ln);
    if isOE
        iv = openEphysView(iv, rows, lineNames, partEnd, fmt);
    end
    events.(ln) = iv / Fs;
end
unitTruth = struct('id', {}, 'name', {}, 'peakChannel', {}, 'samples', {}, 'amplitudeUV', {}, ...
    'widthMs', {}, 'baselineHz', {}, 'label', {}, 'modulation', {}, 'event', {}, 'edge', {}, 'shape', {}, ...
    'gain', {}, 'latencyMs', {}, 'durationMs', {}, 'jitterMs', {}, 'parameter', {}, 'tuning', {}, ...
    'eventTimes', {}, 'starts', {});
for u = 1:nU
    q = units(u);
    lbl = "";
    if ~isempty(labels); lbl = labels(u); end
    unitTruth(u) = struct('id', q.id, 'name', q.name, 'peakChannel', q.peakChannel, 'samples', q.samples, ...
        'amplitudeUV', q.amplitudeUV, 'widthMs', q.widthMs, 'baselineHz', q.baselineHz, 'label', lbl, ...
        'modulation', q.modulation, 'event', q.event, 'edge', q.edge, 'shape', q.shape, 'gain', q.gain, ...
        'latencyMs', q.latencyMs, 'durationMs', q.durationMs, 'jitterMs', q.jitterMs, ...
        'parameter', q.parameter, 'tuning', q.tuning, 'eventTimes', q.eventTimes, 'starts', q.starts);
end
N = height(S.trials);
trials = truthTrials(S, trialRows, trialInterval, Fs);
Dir = dir(fullfile(folder, '**', '*'));
auxFs = Fs / 4;
if fmt == "one-file-per-signal"; auxFs = Fs; end
if fmt == "binary" || isTDT; auxFs = NaN; end
auxOffset = 0;
if isOE; auxOffset = -32768 * auxVoltsPerBit; end
lfp = M.lfp;

T = struct();
T.folder        = folder;
T.name          = name;
T.subject       = subject;
T.scenario      = scenario;
T.format        = fmt;
T.parts         = partEnd;
T.lineNames     = string.empty(1, 0);
if isOE; T.lineNames = oeLineNames; end
if isTDT; T.lineNames = tdtLineNames; end
T.Fs            = Fs;
T.nSamples      = nSamp;
T.duration      = L;
T.files         = files;
T.acqTime       = acq;
T.sessionStart  = sessionStart;
T.behaviorFile  = string(behFile);
T.channelNames  = ampNames;
if isOE; T.channelNames = "CH" + (1:nCh); end
if isTDT; T.channelNames = "Ch" + (1:nCh); end
T.digInNames    = lineNames;
T.digInOrders   = lineBits;
T.trialLine     = trialLine;
T.invertedLines = inverted;
T.events        = events;
T.nTrials       = N;
T.nIntervals    = nIntervals;
T.expectedCuts  = cuts;
T.trials        = trials;
T.units         = unitTruth;
T.lfp           = lfp;
T.design        = D;
T.source        = source;
T.designFile    = string(designFile);
T.artifacts     = [artRows(:, 1) - 1, artRows(:, 2)] / Fs;   % [a b) on the continuous clock
T.aux           = struct('names', auxNames, 'Fs', auxFs, 'offset', auxOffset);   % Open Ephys: volts - 1.2255
T.sortedDir     = string(sortedDir);
T.manifestFile  = manifestFile;
T.probeFile     = string(probeFile);
T.probeSource   = probeSource;
T.fileTimesSet  = timesOk;
T.bytes         = sum([Dir(~[Dir.isdir]).bytes]);
T.seed          = opts.Seed;
end


%% ---------------------------------------------------------------------------
function S = alignToRate(S, Fs, nSamp)
%alignToRate  A schedule of recorded lines at the rate and length written.
%   Recorded lines are at t = row/S.Fs. At another rate each edge goes to
%   the sample of its own, round((t - 1/S.Fs)*Fs) + 1, as events map onto
%   any signal. A line still on at the source's last sample stays on to the
%   end when the recording is padded to whole blocks, so a partial interval
%   does not become a complete one.
if ~(isfield(S, 'timing') && S.timing == "recording" && isfinite(S.Fs) && isfinite(S.nSamples)); return; end
if Fs ~= S.Fs
    map = @(t) (round((t - 1 / S.Fs) * Fs) + 1) / Fs;
else
    map = @(t) t;
end
tLast = S.nSamples / S.Fs;           % the source's last row
tEnd = nSamp / Fs;
for ln = reshape(string(fieldnames(S.events)), 1, [])
    iv = S.events.(ln);
    if isempty(iv); continue; end
    open = iv(:, 2) >= tLast - 0.5 / S.Fs;
    iv = map(iv);
    iv(open, 2) = max(iv(open, 2), tEnd);
    S.events.(ln) = iv;
end
open = S.trials.Offset >= tLast - 0.5 / S.Fs;
S.trials.Onset = map(S.trials.Onset);
S.trials.Offset = map(S.trials.Offset);
S.trials.Offset(open) = max(S.trials.Offset(open), tEnd);
end


function trials = truthTrials(S, trialRows, trialInterval, Fs)
%truthTrials  One row per Epsych2 trial: where its trial-line interval was written.
N = height(S.trials);
onset = trialRows(:, 1) / Fs; offset = trialRows(:, 2) / Fs;
trialType = NaN(N, 1); respCode = NaN(N, 1);
if ismember("TrialType", string(S.trials.Properties.VariableNames)); trialType = S.trials.TrialType; end
if ismember("RespCode", string(S.trials.Properties.VariableNames)); respCode = S.trials.RespCode; end
trials = table((1:N).', trialType, respCode, onset, offset, trialInterval, ...
    'VariableNames', {'TrialIndex', 'TrialType', 'RespCode', 'Onset', 'Offset', 'Interval'});
end


function T = previewResult(M, S, folder, name, subject, scenario, fmt, Fs, nSamp, acq, lineNames, trialLine, ...
    trialRows, trialInterval, nIntervals, cuts, D, probeSource, probeFile, xc, yc, kcoords, seed)
%previewResult  What PreviewOnly returns: the model and the schedule, nothing written.
events = struct();
for ln = lineNames
    events.(ln) = M.rows.(ln) / Fs;
end
T = struct();
T.folder       = folder;
T.name         = name;
T.subject      = subject;
T.scenario     = scenario;
T.format       = fmt;
T.Fs           = Fs;
T.nSamples     = nSamp;
T.duration     = nSamp / Fs;
T.acqTime      = acq;
T.digInNames   = lineNames;
T.trialLine    = trialLine;
T.events       = events;
T.nTrials      = height(S.trials);
T.nIntervals   = nIntervals;
T.expectedCuts = cuts;
T.trials       = truthTrials(S, trialRows, trialInterval, Fs);
T.design       = D;
T.probeSource  = probeSource;
T.probeFile    = string(probeFile);
T.probe        = struct('xc', xc, 'yc', yc, 'kcoords', kcoords);
T.bytes        = 2 * nSamp * (M.nCh + 1);      % the amplifier data and the digital word, about
T.seed         = seed;
T.schedule     = S;
T.model        = M;
end


function [Data, Info, sessionStart] = sessionCopy(S, acq, subject)
%sessionCopy  The source session, moved in time with the recording and renamed to SUBJECT.
Data = S.Data;
Info = S.Info;
delta = seconds(0);
if ~isnat(S.acqTime); delta = acq - S.acqTime; end
sessionStart = S.sessionStart;
if isnat(sessionStart)
    sessionStart = acq - seconds(65);
else
    sessionStart = sessionStart + delta;
end
if isstruct(Info)
    if isfield(Info, 'StartTime') && isdatetime(Info.StartTime); Info.StartTime = Info.StartTime + delta; end
    if isfield(Info, 'Subject') && isstruct(Info.Subject)
        if isfield(Info.Subject, 'Name'); Info.Subject.Name = subject; end
        if isfield(Info.Subject, 'ID'); Info.Subject.ID = subject; end
    else
        Info.Subject = subject;
    end
    Info.Synthetic = struct('SourceFile', S.behaviorFile, 'SourceSubject', S.subject, ...
        'Source', S.source, 'Note', "A copy of the source session for a synthetic recording (makeSyntheticRecording).");
end
if isstruct(Data) && isfield(Data, 'computerTimestamp')
    for k = 1:numel(Data)
        if isdatetime(Data(k).computerTimestamp)
            Data(k).computerTimestamp = Data(k).computerTimestamp + delta;
        end
    end
end
end


function Info = taskInfo(subject, behFile, sessionStart, scenario, seed)
%taskInfo  Info of the built-in task's session.
Info = struct();
Info.FormatVersion = 1;
Info.EPsychMeta = struct('Version', "synthetic", 'Note', "written by makeSyntheticRecording");
Info.Subject = struct('Name', subject, 'ID', subject);
Info.BoxID = 1;
Info.isTest = false;
Info.DataFilename = char(behFile);
Info.StartTime = sessionStart;
Info.SelectorClass = 'synthetic';
Info.Protocol = struct('Name', "SyntheticAMDetection", 'Description', ...
    "AM-noise detection: Stim after StimDelay, response window after RespWinDelay; catch trials have Depth 0.");
Info.WriteParams = {'TrialType', 'Depth', 'Rate', 'StimDelay', 'StimDur', 'RespWinDelay', 'RespWinDur', 'ITIDur', 'NoisedBSPL', 'NumPellets'};
Info.TrialTable = [Info.WriteParams; {0, 0.5, 10, 1000, 500, 600, 1300, 2000, 60, 1}; {1, 0, 10, 1000, 500, 600, 1300, 2000, 60, 1}];
Info.WriteParamIdx = cell2struct(num2cell(1:numel(Info.WriteParams)), Info.WriteParams, 2);
Info.Notes = struct('Trial', [], 'Time', [], 'Elapsed', [], 'Subject', subject, 'Text', "");
Info.NotesText = sprintf('Synthetic session (%s scenario, seed %d) written by makeSyntheticRecording.', scenario, seed);
end


function probe = sitesInChannelOrder(p, nCh)
%sitesInChannelOrder  A probe's sites for channels 1..nCh (channel c sits where chanMap is c - 1).
xc = double(p.xc(:)); yc = double(p.yc(:));
kc = zeros(numel(xc), 1);
if isfield(p, 'kcoords') && numel(p.kcoords) == numel(xc); kc = double(p.kcoords(:)); end
cm = (0:numel(xc) - 1).';
if isfield(p, 'chanMap') && numel(p.chanMap) == numel(xc); cm = double(p.chanMap(:)); end
probe = struct('xc', zeros(nCh, 1), 'yc', zeros(nCh, 1), 'kcoords', zeros(nCh, 1));
for c = 1:nCh
    j = find(cm == c - 1, 1);
    if isempty(j); j = min(c, numel(xc)); end
    probe.xc(c) = xc(j); probe.yc(c) = yc(j); probe.kcoords(c) = kc(j);
end
end


function out = openEphysView(iv, rows, lineNames, partEnd, fmt)
%openEphysView  What an Open Ephys reader sees of a line's [on off] rows:
%   intervals split at the recording boundaries; an interval already high
%   when a recording starts (it holds the recording's first row) is lost
%   where the format cannot know it: the Open Ephys format when the line has
%   no edge in that recording, NWB when that recording has no edge at all
%   (Binary records the initial TTL word).
starts = [1, partEnd(1:end-1) + 1];
out = zeros(0, 2);
for p = 1:numel(partEnd)
    s = starts(p); e = partEnd(p);
    in = iv(iv(:, 2) >= s & iv(:, 1) <= e, :);
    in = [max(in(:, 1), s), min(in(:, 2), e)];
    for k = 1:size(in, 1)
        atStart = in(k, 1) == s;
        if atStart && fmt ~= "openephys-binary"
            ownEdge = in(k, 2) < e;
            anyEdge = false;
            for ln = lineNames
                r = rows.(ln);
                anyEdge = anyEdge || any((r(:, 1) > s & r(:, 1) <= e) | (r(:, 2) >= s & r(:, 2) < e));
            end
            if fmt == "openephys-legacy" && ~ownEdge; continue; end
            if fmt == "openephys-nwb" && ~ownEdge && ~anyEdge; continue; end
        end
        out(end+1, :) = in(k, :); %#ok<AGROW>
    end
end
end


function s = fmtTime(t, fmt)
t.Format = fmt;
s = string(t);
end


function closeAll(fids)
for f = string(fieldnames(fids)).'
    try fclose(fids.(f)); catch, end
end
end
