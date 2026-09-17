function T = makeSyntheticRecording(folder, opts)
%makeSyntheticRecording  Write one synthetic recording with its Epsych2 session (test data).
%   T = makeSyntheticRecording(folder, Name=Value) writes into FOLDER a
%   recording shaped like what the lab acquires with an Intan RHX system
%   while Epsych2 runs an AM-detection task, with everything the pipeline
%   consumes, and returns the truth of what was written in T:
%
%     amplifier data     LFP rhythms with a depth profile, 1/f-like and white
%                        noise, 60 Hz line noise, a stimulus-evoked potential,
%                        spiking units with realistic waveforms spread over the
%                        neighbouring sites and (Artifacts) two large
%                        artifacts, one of them saturating the ADC
%     digital inputs     the six lines of the lab's rig, in RHX order:
%                        Trough (nose pokes), Platform, Stim, InTrial (the
%                        trial line), RespWindow, Commutator (never active)
%     aux inputs         three accelerometer channels at Fs/4 (Intan layouts)
%     Epsych2 session    <Subject>_<yymmdd>T<HHMMSS>.mat (Data + Info) in the
%                        recording folder, named from its start time as
%                        Epsych2 does, one trial per InTrial interval
%     sorted output      (SortedOutput) the ground-truth units as Kilosort4 /
%                        phy files under kilosort4/si/sorter_output, where the
%                        SpikeInterface engine puts them, so the Spikes, Export
%                        and Review steps have sorted units without Python
%     manifest           (WriteManifest) with the session and ProbeFile
%                        associated, as after a run
%
%   Scenarios: how the recording relates to the Epsych2 session
%     "clean"       the recording covers every trial: as many InTrial
%                   intervals as trials
%     "late-start"  the recording started during trial 3: trials 1-2 have no
%                   interval and interval 1 is partial (it begins at sample 1)
%     "early-stop"  the recording stopped during trial N-2: the last interval
%                   is partial (it ends at the last sample) and trials N-1, N
%                   have none
%     "spurious"    a 40 ms pulse on InTrial before the first trial (the line
%                   toggled when the protocol loaded) that is not a trial
%   T.expectedCuts gives the cuts (trials / intervals dropped from the start
%   and the end) after which every remaining trial pairs with a whole
%   interval; see pairEpsychTrials.
%
%   Options
%     Subject        "SYNTH-01"
%     Scenario       "clean" (default) | "late-start" | "early-stop" | "spurious"
%     Format         "traditional" (default: RHX-style *.rhd files of
%                    FileSeconds each) | "one-file-per-signal" (info.rhd +
%                    *.dat) | "binary" (recording.json + .bin; no aux inputs)
%     Fs             30000
%     NumChannels    16 (at least 2)
%     NumTrials      12 (at least 4)
%     FileSeconds    30 (also the size of the chunks generated in memory)
%     AcqTime        nominal start of the recording (default: 2 min ago). The
%                    Epsych2 session starts 65 s earlier, as in the lab. The
%                    data files are stamped with these times so the readers
%                    date the recording correctly (T.fileTimesSet)
%     Seed           1 (the same seed gives the same data in every format)
%     Probe          struct chanMap / xc / yc / kcoords for the site geometry
%                    (default makeSyntheticProbe(NumChannels))
%     ProbeFile      probe .json recorded in the manifest (default none)
%     SortedOutput   true
%     Artifacts      true
%     InvertedLines  lines written with inverted logic: on = low (default none)
%     WriteManifest  true
%     ProgressFcn    ProgressFcn(fraction, message)
%
%   T fields: folder, name, subject, scenario, format, Fs, nSamples,
%   duration, files, acqTime, sessionStart, behaviorFile, channelNames,
%   digInNames, digInOrders, trialLine, invertedLines, events (struct: line
%   -> [k x 2] seconds ON, t = row/Fs, the readers' convention), nTrials,
%   nIntervals, expectedCuts (trials / intervals [start end]), trials (table:
%   TrialIndex, TrialType, RespCode, Onset, Offset, Interval; NaN outside the
%   recording), units (struct array: id, peakChannel, samples (1-based rows),
%   amplitudeUV, label, modulation), artifacts ([k x 2] s), aux (names, Fs),
%   sortedDir, manifestFile, probeFile, fileTimesSet, bytes.
%
%   See also makeSyntheticProject, makeSyntheticProbe, EphysDataset,
%   pairEpsychTrials, readEpsychSession.

arguments
    folder (1,1) string
    opts.Subject (1,1) string = "SYNTH-01"
    opts.Scenario (1,1) string {mustBeMember(opts.Scenario, ["clean" "late-start" "early-stop" "spurious"])} = "clean"
    opts.Format (1,1) string {mustBeMember(opts.Format, ["traditional" "one-file-per-signal" "binary"])} = "traditional"
    opts.Fs (1,1) double {mustBePositive} = 30000
    opts.NumChannels (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(opts.NumChannels, 2)} = 16
    opts.NumTrials (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(opts.NumTrials, 4)} = 12
    opts.FileSeconds (1,1) double {mustBePositive} = 30
    opts.AcqTime datetime = NaT
    opts.Seed (1,1) double = 1
    opts.Probe (1,1) struct = struct()
    opts.ProbeFile (1,1) string = ""
    opts.SortedOutput (1,1) logical = true
    opts.Artifacts (1,1) logical = true
    opts.InvertedLines (1,:) string = string.empty(1,0)
    opts.WriteManifest (1,1) logical = true
    opts.ProgressFcn = []
end

rng(opts.Seed, 'twister');
Fs   = opts.Fs;
nCh  = opts.NumChannels;
N    = opts.NumTrials;
spb  = 128;                 % samples per RHD data block (v2+ files)
uvPerBit = 0.195;           % Intan amplifier resolution
auxVoltsPerBit = 37.4e-6;   % Intan aux-input resolution
preS = 65;                  % Epsych2 started this long before the recording (as in the lab)
scenario = opts.Scenario;
fmt = opts.Format;

acq = opts.AcqTime;
if isnat(acq)
    acq = dateshift(datetime('now') - minutes(2), 'start', 'second');
end
sessionStart = acq - seconds(preS);
subject = opts.Subject;
folder = string(folder);
if ~isfolder(folder); mkdir(folder); end
[~, leaf] = fileparts(char(folder));
name = string(leaf);
probe = opts.Probe;
if isempty(fieldnames(probe)); probe = makeSyntheticProbe(nCh); end
xc = double(probe.xc(:)); yc = double(probe.yc(:));
if numel(xc) < nCh
    error('makeSyntheticRecording:Probe', 'The probe has %d sites but the recording %d channels.', numel(xc), nCh);
end
xc = xc(1:nCh); yc = yc(1:nCh);
kcoords = zeros(nCh, 1);
if isfield(probe, 'kcoords'); kcoords = double(probe.kcoords(:)); kcoords = kcoords(1:nCh); end

    function tick(frac, msg)
        if ~isempty(opts.ProgressFcn); opts.ProgressFcn(frac, string(msg)); end
    end

% --- channel names (as RHX writes them) ---------------------------------------
ampNames   = "A-" + string(compose('%03d', (0:nCh-1).')).';
auxNames   = ["accelX" "accelY" "accelZ"];
auxNative  = "A-AUX" + string(1:3);
lineNames  = ["Trough" "Platform" "Stim" "InTrial" "RespWindow" "Commutator"];
lineNative = "DIGITAL-IN-" + string(compose('%02d', (1:6).')).';
lineOrders = 1:6;                       % RHX: DIGITAL-IN-01 is bit 1 of the word
if fmt == "binary"
    lineBits = 0:5;                     % recording.json: bit k = dig_in_names(k+1)
else
    lineBits = lineOrders;
end
bad = setdiff(opts.InvertedLines, lineNames);
if ~isempty(bad)
    error('makeSyntheticRecording:InvertedLines', 'Unknown line(s) in InvertedLines: %s', strjoin(bad, ', '));
end

% --- the Epsych2 trial schedule (seconds; t = 0 is the recording start) --------
lead = 6; tail = 4;
stimDelayMs = 600 + 300 * randi([0 4], N, 1) + randi([-100 100], N, 1);   % 500 .. 1900 ms
stimDurS = 0.5; rwDelayS = 0.6; rwDurS = 1.3; postS = 0.05;
itiS = 1.5 + rand(N, 1);
isCatch = rand(N, 1) < 0.15;
if ~any(isCatch) && N >= 6; isCatch(min(6, N)) = true; end
onS = zeros(N, 1); stimS = zeros(N, 1); offS = zeros(N, 1);
t = lead;
for k = 1:N
    onS(k)   = t;
    stimS(k) = t + stimDelayMs(k) / 1000;
    offS(k)  = stimS(k) + rwDelayS + rwDurS + postS;
    t = offS(k) + itiS(k);
end
% Responses: epsych-like bit mask (Hit 1, Miss 2, CR 4, FA 8, Reward 32,
% Punish 64, NoResponse 128, Response 256, TrialType0 1024, TrialType1 2048).
responded = false(N, 1); latencyMs = NaN(N, 1); respCode = zeros(N, 1);
for k = 1:N
    if isCatch(k)
        responded(k) = rand < 0.3;
        if responded(k); respCode(k) = 8 + 64 + 256 + 2048; else; respCode(k) = 4 + 128 + 2048; end
    else
        responded(k) = rand < 0.75;
        if responded(k); respCode(k) = 1 + 32 + 256 + 1024; else; respCode(k) = 2 + 128 + 1024; end
    end
    if responded(k); latencyMs(k) = round(150 + 750 * rand); end
end

% Scenario: where the recording starts and stops relative to the session.
shift = 0;
if scenario == "late-start"
    shift = -(onS(3) + 1.2);               % the recording starts 1.2 s into trial 3
end
onS = onS + shift; stimS = stimS + shift; offS = offS + shift;
if scenario == "early-stop"
    L = onS(N-2) + 0.5 * (offS(N-2) - onS(N-2));   % stops in the middle of trial N-2
    nSamp = round(L * Fs / spb) * spb;
else
    L = offS(N) + tail;
    nSamp = ceil(L * Fs / spb) * spb;
end
L = nSamp / Fs;

% --- the digital lines (seconds ON) -------------------------------------------
ivS = struct();
ivS.InTrial    = [onS offS];
ivS.Stim       = [stimS, stimS + stimDurS];
ivS.RespWindow = [stimS + rwDelayS, stimS + rwDelayS + rwDurS];
if scenario == "spurious"
    ivS.InTrial = [onS(1) - 4, onS(1) - 3.96; ivS.InTrial];
end
trough = zeros(0, 2);
for k = 1:N
    if responded(k)
        a = stimS(k) + rwDelayS + latencyMs(k) / 1000;
        dur = min(0.25 + 0.25 * rand, offS(k) - 0.02 - a);
        if dur > 0.05; trough(end+1, :) = [a, a + dur]; end %#ok<AGROW>
    end
    if k < N && itiS(k) > 0.9 && rand < 0.4          % a poke during the inter-trial interval
        a = offS(k) + 0.2 + rand * (itiS(k) - 0.8);
        trough(end+1, :) = [a, a + 0.15 + 0.25 * rand]; %#ok<AGROW>
    end
end
ivS.Trough = sortrows(trough);
platform = zeros(0, 2);
pStart = onS(1) - 3;
for k = 1:N-1
    if itiS(k) >= 1.2 && rand < 0.3                   % the animal steps off during the ITI
        pEnd = offS(k) + 0.3;
        platform(end+1, :) = [pStart, pEnd]; %#ok<AGROW>
        pStart = pEnd + 0.6 + 0.4 * rand;
    end
end
ivS.Platform = [platform; pStart, offS(N) + tail + 10];
ivS.Commutator = zeros(0, 2);

% Seconds -> 1-based rows, clipped to the recording (t_on = first ON row,
% t_off = last ON row; a reader returns [row_on row_off] / Fs).
rows = struct();
for ln = lineNames
    rows.(ln) = toRows(ivS.(ln), Fs, nSamp);
end
trialRows = toRowsKeepAll([onS offS], Fs, nSamp);           % NaN where the trial is outside
[~, trialInterval] = ismember(trialRows, rows.InTrial, 'rows');
trialInterval(isnan(trialRows(:, 1))) = NaN;
trialInterval(trialInterval == 0) = NaN;
nIntervals = size(rows.InTrial, 1);
switch scenario
    case "clean",      cuts = struct('trials', [0 0], 'intervals', [0 0]);
    case "late-start", cuts = struct('trials', [3 0], 'intervals', [1 0]);
    case "early-stop", cuts = struct('trials', [0 3], 'intervals', [0 1]);
    case "spurious",   cuts = struct('trials', [0 0], 'intervals', [1 0]);
end

% --- units: waveform templates, spatial spread, spike times --------------------
nU = max(2, round(nCh / 2));
peakCh = max(1, min(nCh, round(((1:nU) - 0.5) * nCh / nU)));
ampUV  = exp(log(60) + (log(200) - log(60)) * rand(1, nU));
sigMs  = 0.15 + 0.15 * rand(1, nU);
rateHz = 1.5 + 6.5 * rand(1, nU);
modType = repmat("none", 1, nU); gainMod = zeros(1, nU);
modType(2:2:nU) = "driven"; gainMod(2:2:nU) = 1 + 3 * rand(1, numel(2:2:nU));
if nU >= 3; modType(3) = "suppressed"; end
nt = round(0.002 * Fs) + 1;                 % 2 ms template (61 samples at 30 kHz)
p0 = round(nt / 3);                         % the trough sits here
tmsT = ((1:nt) - p0).' / Fs * 1000;
tmpl = cell(1, nU); smp = cell(1, nU); scl = cell(1, nU);
stimRowsS = rows.Stim / Fs;
for u = 1:nU
    w = ampUV(u) * (-exp(-tmsT.^2 / (2 * sigMs(u)^2)) + 0.3 * exp(-(tmsT - 0.6).^2 / (2 * 0.45^2)));
    d = hypot(xc - xc(peakCh(u)), yc - yc(peakCh(u)));
    tmpl{u} = w * exp(-d.^2 / (2 * 40^2)).';                      % [nt x nCh]
    switch modType(u)
        case "driven",     rStim = rateHz(u) * (1 + gainMod(u));
        case "suppressed", rStim = rateHz(u) * 0.3;
        otherwise,         rStim = rateHz(u);
    end
    rMax = max(rateHz(u), rStim);
    tt = zeros(0, 1); tcur = 0;
    while true
        tcur = tcur + 0.002 - log(rand) / rMax;                  % 2 ms refractory + exponential ISI
        if tcur >= L; break; end
        inStim = any(tcur >= stimRowsS(:, 1) & tcur <= stimRowsS(:, 2));
        if inStim; r = rStim; else; r = rateHz(u); end
        if rand < r / rMax; tt(end+1, 1) = tcur; end %#ok<AGROW>
    end
    s = floor(tt * Fs) + 1;
    s = s(s > p0 + 1 & s < nSamp - (nt - p0) - 1);
    smp{u} = s;
    scl{u} = 1 + 0.06 * randn(numel(s), 1);
end

% --- artifacts -----------------------------------------------------------------
artS = zeros(0, 2); artKind = strings(0, 1);
if opts.Artifacts
    artS = [0.22 * L, 0.22 * L + 0.15; 0.63 * L, 0.63 * L + 0.4];
    artKind = ["burst"; "saturate"];
end
artRows = toRows(artS, Fs, nSamp);

% --- background model parameters -----------------------------------------------
gLFP  = (1.2 - 0.8 * (0:nCh-1) / max(nCh - 1, 1));               % depth gradient, 1 x nCh
gEP   = exp(-(((1:nCh) - (nCh + 1) / 2) / max(nCh / 3, 1)).^2);   % evoked potential, mid-depth max
phLine = 0.3 * randn(1, nCh);                                     % 60 Hz phase per channel
alpha = exp(-2 * pi * 4 / Fs);                                    % 4 Hz one-pole low-pass
bS = 1 - alpha; aS = [1 -alpha];
sigSlowIn = 30 * sqrt((1 + alpha) / (1 - alpha));                 % -> ~30 uV RMS out
ziSlow = zeros(1, nCh);
auxBase = [1.65 1.70 2.00]; auxF = [0.9 1.3 0.7]; auxPh = 2 * pi * rand(1, 3);

% --- write, one segment (= one traditional file) at a time --------------------
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

for sIdx = 1:nSeg
    s0 = (sIdx - 1) * nSegSamp;
    n  = min(nSegSamp, nSamp - s0);
    tick((sIdx - 1) / (nSeg + 1), sprintf("Writing %s: segment %d of %d", name, sIdx, nSeg));
    t = (s0 + (0:n-1)).' / Fs;

    % background: LFP rhythms with slow amplitude modulation, depth profile
    lfp = 120 * (1 + 0.4 * sin(2 * pi * 0.07 * t)) .* sin(2 * pi * 1.7 * t + 0.3) ...
        + 60 * (1 + 0.5 * sin(2 * pi * 0.11 * t + 1)) .* sin(2 * pi * 7.3 * t) ...
        + 25 * sin(2 * pi * 12.5 * t + 2);
    X = lfp * gLFP;
    [slow, ziSlow] = filter(bS, aS, sigSlowIn * randn(n, nCh), ziSlow);
    X = X + slow + 9 * randn(n, nCh);
    X = X + 5 * (sin(2 * pi * 60 * t) * cos(phLine) + cos(2 * pi * 60 * t) * sin(phLine)) ...
          + 1.5 * sin(2 * pi * 180 * t) * ones(1, nCh);
    % stimulus-evoked potential
    for k = find(stimRowsS(:, 1) >= t(1) - 0.35 & stimRowsS(:, 1) <= t(end)).'
        tau = t - stimRowsS(k, 1);
        m = tau >= 0 & tau < 0.35;
        X(m, :) = X(m, :) + (-150 * (tau(m) / 0.045) .* exp(1 - tau(m) / 0.045)) * gEP;
    end
    % spikes
    for u = 1:nU
        su = smp{u}; sc = scl{u};
        for j = find(su >= s0 + 1 - (nt - p0) & su <= s0 + n + p0).'
            r = su(j) - p0 + (1:nt).' - s0;
            ok = r >= 1 & r <= n;
            X(r(ok), :) = X(r(ok), :) + sc(j) * tmpl{u}(ok, :);
        end
    end
    % artifacts
    for k = find(artRows(:, 2) >= s0 + 1 & artRows(:, 1) <= s0 + n).'
        r = (max(artRows(k, 1), s0 + 1) : min(artRows(k, 2), s0 + n)) - s0;
        if artKind(k) == "burst"
            X(r, :) = X(r, :) + 1500 * randn(numel(r), nCh);
        else
            X(r, :) = X(r, :) + 7000;
        end
    end
    % digital word
    W = zeros(n, 1, 'uint16');
    for k = 1:numel(lineNames)
        bit = uint16(2^lineBits(k));
        iv = rows.(lineNames(k));
        for i = find(iv(:, 2) >= s0 + 1 & iv(:, 1) <= s0 + n).'
            r1 = max(iv(i, 1), s0 + 1) - s0; r2 = min(iv(i, 2), s0 + n) - s0;
            W(r1:r2) = bitor(W(r1:r2), bit);
        end
        if ismember(lineNames(k), opts.InvertedLines)
            W = bitxor(W, bit);
        end
    end
    % accelerometer at Fs/4: the animal moves between trials
    t4 = t(1:4:end);
    moving = ones(numel(t4), 1);
    for i = find(rows.InTrial(:, 2) >= s0 + 1 & rows.InTrial(:, 1) <= s0 + n).'
        moving(t4 >= (rows.InTrial(i, 1) - 1) / Fs & t4 <= rows.InTrial(i, 2) / Fs) = 0.15;
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
                Version=[3 0], FirstTimestamp=s0, ...
                Notes=[sprintf("Synthetic recording (%s scenario, seed %d) written by makeSyntheticRecording", scenario, opts.Seed), "", ""]);
            files(end+1) = fname; fileTimes(end+1) = ft; %#ok<AGROW>
        case "one-file-per-signal"
            fwrite(fids.amp, int16(min(max(round(X / uvPerBit), -32768), 32767)).', 'int16');
            fwrite(fids.time, int32(s0 + (0:n-1)), 'int32');
            fwrite(fids.dig, W, 'uint16');
            fwrite(fids.aux, repelem(auxRaw, 1, 4), 'uint16');       % RHX holds each value for 4 samples
        case "binary"
            fwrite(fids.amp, int16(min(max(round(X / uvPerBit), -32768), 32767)).', 'int16');
            fwrite(fids.dig, W, 'uint16');
    end
end
delete(closer);
switch fmt
    case "one-file-per-signal"
        fileTimes = repmat(acq, 1, numel(files));
    case "binary"
        BinaryReader.writeDescriptor(folder, struct( ...
            'name', name, 'data_file', name + ".bin", 'dtype', "int16", 'n_chan', nCh, 'fs', Fs, ...
            'n_samples', nSamp, 'gain_to_uV', uvPerBit, 'offset', 0, ...
            'channel_names', {cellstr(ampNames)}, 'native_names', {cellstr(ampNames)}, ...
            'dig_in_names', {cellstr(lineNames)}, 'dig_in_file', "digitalin.dat", ...
            'acq_date', fmtTime(acq, 'yyyy-MM-dd HH:mm:ss'), ...
            'source', struct('tool', "makeSyntheticRecording", 'scenario', scenario, 'seed', opts.Seed)));
        files = ["recording.json", files];
        fileTimes = repmat(acq, 1, numel(files));
end
timesOk = true;
for k = 1:numel(files)
    timesOk = setFileModifiedTime(fullfile(folder, files(k)), fileTimes(k)) && timesOk;
end

% --- the Epsych2 session file ---------------------------------------------------
tick(nSeg / (nSeg + 1), "Writing the Epsych2 session");
behFile = fullfile(folder, subject + "_" + fmtTime(sessionStart, 'yyMMdd''T''HHmmss') + ".mat");
depthList = [0.25 0.5 1];
depth = depthList(randi(3, N, 1)); depth(isCatch) = 0;
ts = sessionStart + seconds(preS + offS - shift);        % session-relative trial ends
ts = ts(:).';
Data = struct( ...
    'TrialType',    num2cell(double(isCatch(:)).'), ...
    'Depth',        num2cell(depth(:).'), ...
    'Rate',         num2cell(10 * ones(1, N)), ...
    'StimDelay',    num2cell(stimDelayMs(:).'), ...
    'StimDur',      num2cell(1000 * stimDurS * ones(1, N)), ...
    'RespWinDelay', num2cell(1000 * rwDelayS * ones(1, N)), ...
    'RespWinDur',   num2cell(1000 * rwDurS * ones(1, N)), ...
    'ITIDur',       num2cell(round(1000 * itiS(:).')), ...
    'NoisedBSPL',   num2cell(60 * ones(1, N)), ...
    'NumPellets',   num2cell(ones(1, N)), ...
    'RespCode',     num2cell(respCode(:).'), ...
    'RespLatency',  num2cell(latencyMs(:).'), ...
    'TrialIndex',   num2cell(1:N), ...
    'TrialID',      num2cell(double(isCatch(:)).' + 1), ...
    'computerTimestamp', num2cell(ts), ...
    'isTest',       num2cell(false(1, N)));
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
Info.NotesText = sprintf('Synthetic session (%s scenario, seed %d) written by makeSyntheticRecording.', scenario, opts.Seed);
save(behFile, 'Data', 'Info');
setFileModifiedTime(behFile, sessionStart);

% --- ground-truth sorted output (Kilosort4 / phy files) --------------------------
sortedDir = "";
if opts.SortedOutput
    tick(nSeg / (nSeg + 1), "Writing the ground-truth sorted output");
    sortedDir = fullfile(folder, 'kilosort4', 'si', 'sorter_output');
    if ~isfolder(sortedDir); mkdir(sortedDir); end
    allS = zeros(0, 1); allC = zeros(0, 1); allA = zeros(0, 1);
    for u = 1:nU
        allS = [allS; smp{u}(:) - 1]; %#ok<AGROW>
        allC = [allC; (u - 1) * ones(numel(smp{u}), 1)]; %#ok<AGROW>
        allA = [allA; scl{u}(:)]; %#ok<AGROW>
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
    for u = 1:nU; T3(u, :, :) = single(tmpl{u}); end
    T3(nU + 1, :, :) = single(20 * randn(nt, nCh));
    writeNPY(fullfile(sortedDir, 'templates.npy'), T3);
    writeNPY(fullfile(sortedDir, 'channel_map.npy'), int32((0:nCh-1).'));
    writeNPY(fullfile(sortedDir, 'channel_positions.npy'), [xc yc]);
    writeNPY(fullfile(sortedDir, 'channel_shanks.npy'), int32(kcoords));
    fid = fopen(fullfile(sortedDir, 'params.py'), 'w');
    fprintf(fid, 'dat_path = ''temp_wh.dat''\nn_channels_dat = %d\ndtype = ''int16''\noffset = 0\nsample_rate = %g\nhp_filtered = True\n', nCh, Fs);
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
else
    labels = strings(1, 0);
end

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
    if opts.ProbeFile ~= "" && isfile(opts.ProbeFile); ds.ProbeFile = opts.ProbeFile; end
    ds.writeManifest();
    manifestFile = string(ds.manifestFile());
end
tick(1, "Done");

% --- the truth -------------------------------------------------------------------
events = struct();
for ln = lineNames
    events.(ln) = rows.(ln) / Fs;
end
units = struct('id', {}, 'peakChannel', {}, 'samples', {}, 'amplitudeUV', {}, 'label', {}, 'modulation', {});
for u = 1:nU
    lbl = "";
    if ~isempty(labels); lbl = labels(u); end
    units(u) = struct('id', u - 1, 'peakChannel', peakCh(u), 'samples', smp{u}, ...
        'amplitudeUV', ampUV(u), 'label', lbl, 'modulation', modType(u));
end
onset = trialRows(:, 1) / Fs; offset = trialRows(:, 2) / Fs;
trials = table((1:N).', double(isCatch), respCode, onset, offset, trialInterval, ...
    'VariableNames', {'TrialIndex', 'TrialType', 'RespCode', 'Onset', 'Offset', 'Interval'});
D = dir(fullfile(folder, '**', '*'));
auxFs = Fs / 4;
if fmt == "one-file-per-signal"; auxFs = Fs; end
if fmt == "binary"; auxFs = NaN; end

T = struct();
T.folder        = folder;
T.name          = name;
T.subject       = subject;
T.scenario      = scenario;
T.format        = fmt;
T.Fs            = Fs;
T.nSamples      = nSamp;
T.duration      = L;
T.files         = files;
T.acqTime       = acq;
T.sessionStart  = sessionStart;
T.behaviorFile  = string(behFile);
T.channelNames  = ampNames;
T.digInNames    = lineNames;
T.digInOrders   = lineBits;
T.trialLine     = "InTrial";
T.invertedLines = opts.InvertedLines;
T.events        = events;
T.nTrials       = N;
T.nIntervals    = nIntervals;
T.expectedCuts  = cuts;
T.trials        = trials;
T.units         = units;
T.artifacts     = artRows / Fs;
T.aux           = struct('names', auxNames, 'Fs', auxFs);
T.sortedDir     = string(sortedDir);
T.manifestFile  = manifestFile;
T.probeFile     = opts.ProbeFile;
T.fileTimesSet  = timesOk;
T.bytes         = sum([D(~[D.isdir]).bytes]);
T.seed          = opts.Seed;
end


%% ---------------------------------------------------------------------------
function rows = toRows(ivS, Fs, nSamp)
%toRows  Seconds ON -> 1-based [row_on row_off], clipped to the recording.
%   Intervals entirely outside the recording are dropped; those crossing an
%   edge are clipped (they become "partial" intervals).
rows = toRowsKeepAll(ivS, Fs, nSamp);
rows = rows(~isnan(rows(:, 1)), :);
if isempty(rows); rows = zeros(0, 2); end
rows = sortrows(rows);
end


function rows = toRowsKeepAll(ivS, Fs, nSamp)
%toRowsKeepAll  As toRows, but intervals outside the recording become NaN rows.
if isempty(ivS); rows = zeros(0, 2); return; end
on  = floor(ivS(:, 1) * Fs) + 1;
off = max(ceil(ivS(:, 2) * Fs), on);
keep = off >= 1 & on <= nSamp;
on  = max(on, 1); off = min(off, nSamp);
rows = [on off];
rows(~keep, :) = NaN;
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
