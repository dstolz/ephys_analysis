function test_EphysDataset()
%test_EphysDataset  Verification suite for the Intan -> Kilosort4 backend.
%   Builds synthetic *.rhd fixtures (valid magic + header + known data blocks),
%   then exercises parseIntanHeader, refreshMetadata, readData, toBin,
%   matrixToBin, filterContinuous, detectArtifacts, detectSpikes,
%   EphysProject discovery and runKilosort(DryRun=true). Section 10 builds split-format
%   fixtures (info.rhd + flat .dat files) for the one-file-per-signal and
%   one-file-per-channel layouts and checks metadata, readData and a byte-correct
%   toBin for both; section 14 streams detectSpikes over a whole (split) recording
%   and requires it to match the single-block result exactly. Sections 15-16
%   cover the JSON helpers, the v2 manifest (manual artifacts, sorting and
%   behavior associations), EphysProject.refresh / relative keys, and the
%   ArtifactConfig pre-detection filter. No real Intan files or Kilosort4
%   install are required.
%
%   Usage:  test_EphysDataset
%
%   The fixtures live in a temp folder which is deleted on completion.

here = fileparts(mfilename('fullpath'));
addpath(here);                          % @EphysDataset / @EphysProject
addpath(fileparts(here));               % matrix2kilosort.m (ephys/)

root = fullfile(tempdir, sprintf('IntanDS_test_%s', datestr(now,'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's'));

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

nProg = 0;
    function progTick(~, ~, ~)
        nProg = nProg + 1;
    end
    function id = errorIdOf(fcn)
        id = '';
        try
            fcn();
        catch ME
            id = ME.identifier;
        end
    end
    function cancelAfterTwo(~, ~, ~)
        nProg = nProg + 1;
        if nProg >= 2
            error('test:Cancel', 'cancelled by the test');
        end
    end

rng(42);

% ---- Build a dataset folder with two chronological files ----------------
dsFolder = fullfile(root, 'A1_260101_120000');   % <SubjectID>_<yyMMdd>_<HHmmss>: labels sorted units
mkdir(dsFolder);
numAmp = 4; blocksPerFile = 2; spb = 128;
samplesPerFile = blocksPerFile * spb;
Fs = 30000;

% Known raw amplifier values [numAmp x totalSamples] across both files
totalSamples = 2 * samplesPerFile;
ampRaw = uint16(randi([0 65535], numAmp, totalSamples));

% Digital line: high during samples 50..70 of file 1
digRaw = zeros(1, totalSamples);
digRaw(50:70) = 1;   % native_order 0 -> bit 0

f1 = fullfile(dsFolder, 'rec_001.rhd');
f2 = fullfile(dsFolder, 'rec_002.rhd');
writeSyntheticRHD(f1, ampRaw(:,1:samplesPerFile),            digRaw(1:samplesPerFile),            Fs, spb);
writeSyntheticRHD(f2, ampRaw(:,samplesPerFile+1:end),        digRaw(samplesPerFile+1:end),        Fs, spb);
% Force chronological datenum order (f1 older than f2)
java.io.File(f1).setLastModified(int64(1.0e12));
java.io.File(f2).setLastModified(int64(1.0e12 + 60000));

fprintf('\n== 1-2. refreshMetadata + header-only parse (via PerFile) ==\n');
ds = EphysDataset(dsFolder);   % AutoMetadata=true -> parseIntanHeader per file
check(ds.NumFiles == 2, 'discovered 2 files');
check(ds.Files(1) == "rec_001.rhd", 'chronological sort (file 1)');
check(ds.NumChannels == numAmp, 'NumChannels');
check(ds.Fs == Fs, 'Fs');
check(abs(ds.Duration - totalSamples/Fs) < 1e-9, 'Duration = sum of recordTime');
check(ds.NumSamples == totalSamples, 'NumSamples (dependent)');
% Header-only parse output surfaced through PerFile
pf = ds.PerFile(1);
check(pf.numAmplifierChannels == numAmp, 'PerFile amplifier channel count');
check(pf.numDataBlocks == blocksPerFile, 'PerFile whole data block count');
check(pf.numAmplifierSamples == samplesPerFile, 'PerFile amplifier sample count');
check(~pf.partialBlock, 'no partial block flagged');
% headerBytes must equal filesize - nBlocks*bytesPerBlock (parser stopped at data offset)
s = dir(f1);
check(pf.headerBytes == s.bytes - pf.numDataBlocks*pf.bytesPerBlock, ...
    'headerBytes at data offset (no amplifier matrix read)');

fprintf('\n== 3. readData (concat + events) ==\n');
data = ds.readData();
check(isequal(size(data.amplifier), [totalSamples numAmp]), 'amplifier [nSamples x nChan]');
expectedUV = 0.195 * (double(ampRaw) - 32768);   % [numAmp x totalSamples]
check(all(abs(data.amplifier - expectedUV.') < 1e-6, 'all'), 'amplifier microvolts match');
check(numel(fieldnames(data.events)) == 1, 'one dig-in event field');
evName = fieldnames(data.events); ev = data.events.(evName{1});
check(size(ev,1) == 1, 'one event interval detected');
check(abs(ev(1,1) - 50/Fs) < 1e-9, 'event onset (1-based sample 50, intan2matlab convention)');

fprintf('\n== 4. toBin streaming vs matrix2kilosort byte-identical ==\n');
ds.OutputDir = fullfile(root, 'out_stream');
info = ds.toBin();
check(info.nChan == numAmp && info.nSamples == totalSamples, 'toBin nChan/nSamples');
check(info.nBytes == numAmp * totalSamples * 2, 'byte invariant nBytes = nChan*nSamples*2');

% In-memory write of the same data via matrixToBin
ds2 = EphysDataset(dsFolder);
ds2.OutputDir = fullfile(root, 'out_mem');
info2 = ds2.matrixToBin(data.amplifier);   % uses Scale=1/0.195, Dtype int16
b1 = readBin(info.filename);
b2 = readBin(info2.filename);
check(isequal(b1, b2), 'streaming toBin == matrix2kilosort (byte-identical)');

fprintf('\n== 5. round-trip bin -> microvolts ==\n');
raw = reshape(typecast(b1, 'int16'), numAmp, totalSamples);  % [nChan x nSamples]
backUV = 0.195 * double(raw);                                % undo scale (offset 0)
check(all(abs(backUV.' - expectedUV.') < 0.2, 'all'), 'round-trip within rounding (<0.2 uV)');

fprintf('\n== 6. filterContinuous + detectArtifacts ==\n');
t = (0:totalSamples-1).'/Fs;
sig = 100*sin(2*pi*10*t) + 500;          % 10 Hz + big DC offset, single chan
hp = ds.filterContinuous(sig, Type="highpass", Cutoff=300, Fs=Fs);
check(abs(mean(hp)) < 1, 'highpass removes DC offset');

X = 5*randn(totalSamples, numAmp);
X(100:105, :) = X(100:105, :) + 2000;    % multi-channel transient
[mask, intervals] = ds.detectArtifacts(X, Method="microvolts", Threshold=1500, MinChannels=2);
check(all(mask(100:105)), 'artifact mask covers transient');
check(size(intervals,1) >= 1 && intervals(1,1) <= 100/Fs, 'artifact interval onset');
% Intervals are half-open on the 0-based sample clock: rows a..b -> [a-1, b)/Fs.
Xs = zeros(1000, 2); Xs(101, :) = 5000; Xs(301:310, :) = 5000;
[m1, iv1] = ds.detectArtifacts(Xs, Method="microvolts", Threshold=1500, MinChannels=2, Fs=Fs);
check(isequal(iv1, [100 101; 300 310] / Fs) && isequal(ds.manualArtifactMask(1000, 0, Fs, iv1), m1), ...
    'intervals are [first, last+1)/Fs (a one-sample artifact is one sample long) and mask back to the flagged samples');
check(isequal(find(ds.manualArtifactMask(1000, 200, Fs, iv1 + 200 / Fs)).', [101 301:310]), ...
    'the mask of a later block (sample offset) finds the same rows');
Xb = ds.blankArtifacts(X, mask, Fill="zero");
check(all(all(Xb(mask,:) == 0)), 'blankArtifacts zeroes flagged rows');

fprintf('\n== 7. EphysProject discovery ==\n');
% nested tree: 2 real dataset folders + 1 empty decoy
mkdir(fullfile(root, 'proj', 'mouse1', 'sess1'));
mkdir(fullfile(root, 'proj', 'mouse2', 'sess1'));
mkdir(fullfile(root, 'proj', 'empty_decoy'));
writeSyntheticRHD(fullfile(root,'proj','mouse1','sess1','a.rhd'), ampRaw(:,1:spb), digRaw(1:spb), Fs, spb);
writeSyntheticRHD(fullfile(root,'proj','mouse2','sess1','b.rhd'), ampRaw(:,1:spb), digRaw(1:spb), Fs, spb);
P = EphysProject(fullfile(root,'proj'));
check(P.NumDatasets == 2 && P.Recursive, 'discover finds exactly 2 dataset folders (decoy ignored)');
T = P.gatherMetadata();
check(height(T) == 2 && all(T.NumChannels == numAmp), 'gatherMetadata table');
% Recursive=false: the root and the folders directly in it, nothing deeper
flat = fullfile(root, 'flat');
mkdir(fullfile(flat, 'sessA', 'old'));
mkdir(fullfile(flat, 'grp', 'sessB'));
writeSyntheticRHD(fullfile(flat,'top.rhd'), ampRaw(:,1:spb), digRaw(1:spb), Fs, spb);
writeSyntheticRHD(fullfile(flat,'sessA','a.rhd'), ampRaw(:,1:spb), digRaw(1:spb), Fs, spb);
writeSyntheticRHD(fullfile(flat,'sessA','old','a.rhd'), ampRaw(:,1:spb), digRaw(1:spb), Fs, spb);
writeSyntheticRHD(fullfile(flat,'grp','sessB','b.rhd'), ampRaw(:,1:spb), digRaw(1:spb), Fs, spb);
Pdeep = EphysProject(flat);
check(isequal(sort(Pdeep.datasetKeys()), ["." "grp/sessB" "sessA" "sessA/old"]), ...
    'a recursive scan finds the root and every nested recording');
Pflat = EphysProject(flat, Recursive=false);
check(~Pflat.Recursive && isequal(sort(Pflat.datasetKeys()), ["." "sessA"]), ...
    'Recursive=false finds only the root and the folders directly in it');
ws = warning('off', 'EphysProject:NoData');
Pnone = EphysProject(fullfile(root, 'proj'), Recursive=false);
warning(ws);
check(Pnone.NumDatasets == 0, 'Recursive=false does not reach recordings two levels down');

fprintf('\n== 8. runKilosort(DryRun=true) ==\n');
% Minimal valid probe json
probeFile = fullfile(root, 'probe.json');
probe = struct('chanMap', 0:numAmp-1, 'xc', zeros(1,numAmp), 'yc', (0:numAmp-1)*20, ...
    'kcoords', zeros(1,numAmp), 'n_chan', numAmp);
fid = fopen(probeFile,'w'); fwrite(fid, jsonencode(probe), 'char'); fclose(fid);

ds.ProbeFile = probeFile;
ds.PythonExe = "C:\miniconda3\python.exe";
res = ds.runKilosort(DryRun=true);
check(isfile(res.settingsPath), 'settings.json written');
check(isfile(res.scriptPath), 'run_ks4.py written');
sett = jsondecode(fileread(res.settingsPath));
check(sett.n_chan_bin == numAmp, 'settings n_chan_bin');
check(sett.fs == Fs, 'settings fs');
check(contains(res.command, '"C:\miniconda3\python.exe"'), 'command quotes python path');
check(contains(res.command, '"'+string(res.scriptPath)+'"') || contains(res.command, res.scriptPath), ...
    'command references script');

fprintf('\n== 8b. explicit artifact intervals (native engine) ==\n');
ds.ManualArtifacts = [0.001 0.002];
siDry = fullfile(root, 'si_dry');
rsi = ds.runSpikeInterface(DryRun=true, ResultsDir=siDry, ArtifactIntervals=zeros(0, 2));
sic = jsondecode(fileread(rsi.settingsPath));
check(~sic.preprocessing.silence_periods.enabled, 'an explicit empty ArtifactIntervals silences nothing');
rsi = ds.runSpikeInterface(DryRun=true, ResultsDir=siDry);
sic = jsondecode(fileread(rsi.settingsPath));
check(sic.preprocessing.silence_periods.enabled, 'the default ArtifactIntervals falls back to the dataset''s periods');
binX = fullfile(root, 'blank_test.bin');
infoB = ds.toBin(BinFile=binX, ArtifactIntervals=[0 0.001], WriteMeta=false);
fid = fopen(binX, 'r'); B = fread(fid, [infoB.nChan Inf], 'int16=>double'); fclose(fid);
nZ = round(0.001 * Fs);       % samples 0 .. round(t1*Fs)-1: half-open, as SpikeInterface silences
check(all(B(:, 1:nZ) == 0, 'all') && any(B(:, nZ+1:end) ~= 0, 'all') && infoB.nManualBlanked == nZ, ...
    'toBin blanks exactly the listed intervals, not the manual periods');
check(strcmp(errorIdOf(@() ds.runKilosort(ArtifactIntervals=[0 ds.NumSamples / ds.Fs])), ...
    'EphysDataset:runKilosort:MostlySilenced'), 'runKilosort refuses to blank most of the recording');
[share, covered] = EphysDataset.silencedFraction([0 1; 0.5 2; 3 10], 4);
check(abs(covered - 3) < 1e-12 && abs(share - 0.75) < 1e-12, 'silencedFraction clips and unions the intervals');
ds.ManualArtifacts = zeros(0, 2);

fprintf('\n== 9. DatasetTracker integration (ds / project) ==\n');
% ds.OutputDir = out_stream (section 4); section 8 wrote a dry-run kilosort4/
% there (settings + script, but no spike output yet).
dt = ds.tracker();
check(isa(dt, 'DatasetTracker'), 'ds.tracker() returns a DatasetTracker');
check(dt.NumBinFiles == 1, 'tracker sees the streamed .bin');
check(dt.BinFiles(1).NChanBin == numAmp, 'tracker reads .bin sidecar (n_chan_bin)');
check(dt.NumKilosortRuns >= 1, 'tracker sees the kilosort4 run folder');
check(~dt.hasKilosort, 'no results yet (dry run wrote no spike_clusters.npy)');

% Simulate a completed sort (existence is all the tracker checks), re-snapshot.
ksDir = fullfile(char(ds.outputFolder()), 'kilosort4');
fclose(fopen(fullfile(ksDir, 'spike_clusters.npy'), 'w'));
fid = fopen(fullfile(ksDir, 'cluster_KSLabel.tsv'), 'w');
fprintf(fid, 'cluster_id\tKSLabel\n0\tgood\n1\tmua\n'); fclose(fid);
dt2 = ds.tracker();
check(dt2.hasKilosort, 'hasKilosort true after results appear');
run = dt2.latestKilosortRun();
check(~isempty(run) && run.HasResults && run.NumUnits == 2, ...
    'latestKilosortRun reports results + cluster count');

% Project-level wrappers + the new gatherMetadata column.
dtp = P.tracker(1);
check(isa(dtp, 'DatasetTracker'), 'P.tracker(idx) returns a DatasetTracker');
T2 = P.gatherMetadata();
check(any(strcmp('HasKilosort', T2.Properties.VariableNames)), ...
    'gatherMetadata exposes a HasKilosort column');
check(islogical(T2.HasKilosort) && ~any(T2.HasKilosort), ...
    'project datasets (no sorts) -> HasKilosort all false');

fprintf('\n== 10. split formats (one-file-per-signal / one-file-per-channel) ==\n');
% Known int16 amplifier codes; microvolts = 0.195 * int16 (no 32768 offset).
nSampSplit = 300;
ampI16   = int16(randi([-30000 30000], numAmp, nSampSplit));
expSigUV = 0.195 * double(ampI16).';            % [nSampSplit x numAmp]
digSplit = zeros(1, nSampSplit); digSplit(50:70) = 1;   % bit-0 line high 50..70

% --- one-file-per-signal: info.rhd + amplifier.dat (+ time/digitalin) --------
sigFolder = fullfile(root, 'split_signal');
mkdir(sigFolder);
writeInfoRHD(fullfile(sigFolder, 'info.rhd'), numAmp, Fs);
writeDat(fullfile(sigFolder, 'amplifier.dat'), ampI16, 'int16');      % channel-major/sample
writeDat(fullfile(sigFolder, 'time.dat'), int32(0:nSampSplit-1), 'int32');
writeDat(fullfile(sigFolder, 'digitalin.dat'), uint16(digSplit), 'uint16');

dsig = EphysDataset(sigFolder);
check(dsig.RecordingFormat == "one-file-per-signal", 'detect one-file-per-signal');
check(dsig.NumChannels == numAmp, 'signal: NumChannels from info.rhd');
check(dsig.Fs == Fs, 'signal: Fs from info.rhd');
check(dsig.NumSamples == nSampSplit, 'signal: NumSamples from amplifier.dat size');
check(abs(dsig.Duration - nSampSplit/Fs) < 1e-9, 'signal: Duration');
dats = dsig.readData();
check(isequal(size(dats.amplifier), [nSampSplit numAmp]), 'signal: amplifier [nSamples x nChan]');
check(all(abs(dats.amplifier - expSigUV) < 1e-9, 'all'), 'signal: amplifier microvolts (0.195*int16)');
check(numel(fieldnames(dats.events)) == 1, 'signal: one dig-in event field');
evN = fieldnames(dats.events); evSig = dats.events.(evN{1});
check(size(evSig,1) == 1 && abs(evSig(1,1) - 50/Fs) < 1e-9, 'signal: event onset (sample 50)');
dsig.OutputDir = fullfile(root, 'out_split_signal');
isig = dsig.toBin();
check(isig.nChan == numAmp && isig.nSamples == nSampSplit, 'signal: toBin nChan/nSamples');
rawSig = reshape(typecast(readBin(isig.filename), 'int16'), numAmp, nSampSplit);
check(max(abs(double(rawSig) - double(ampI16)), [], 'all') <= 1, 'signal: .bin int16 == source int16');

% --- aux (accelerometer) inputs: one-file-per-signal + auxiliary.dat ---------
numAux = 3;
auxU16 = uint16(randi([0 65535], numAux, nSampSplit));   % RHX: full rate
expAuxV = 37.4e-6 * double(auxU16).';                    % [nSampSplit x numAux]
auxFolder = fullfile(root, 'split_signal_aux');
mkdir(auxFolder);
writeInfoRHD(fullfile(auxFolder, 'info.rhd'), numAmp, Fs, numAux);
writeDat(fullfile(auxFolder, 'amplifier.dat'), ampI16, 'int16');
writeDat(fullfile(auxFolder, 'time.dat'), int32(0:nSampSplit-1), 'int32');
writeDat(fullfile(auxFolder, 'digitalin.dat'), uint16(digSplit), 'uint16');
writeDat(fullfile(auxFolder, 'auxiliary.dat'), auxU16, 'uint16');
daux = EphysDataset(auxFolder);
check(daux.NumChannels == numAmp, 'aux: aux channels are not amplifier channels');
dataux = daux.readData(IncludeAux=true);
check(isequal(size(dataux.aux), [nSampSplit numAux]) && max(abs(dataux.aux - expAuxV), [], 'all') < 1e-9 ...
    && dataux.auxFs == Fs, 'aux: auxiliary.dat read as volts at the rate its size implies');
check(isequal(dataux.auxNames, ["accel1" "accel2" "accel3"]) && dataux.auxNativeNames(1) == "A-AUX1", ...
    'aux: aux channel names from info.rhd');
[Ya, ~, ia] = daux.deriveSignals(dataTypeOut="AUX");
check(isa(Ya.AUX, 'single') && max(abs(double(Ya.AUX) - expAuxV), [], 'all') < 1e-6 && isempty(Ya.LFP) ...
    && ia.AUX.Fs == Fs && ia.AUX.units == "volts" && isequal(ia.AUX.labels, {'accel1'; 'accel2'; 'accel3'}) ...
    && numel(ia.labels) == numAmp, 'deriveSignals "AUX": Y.AUX volts + info.AUX (Fs, labels, units)');
lastwarn('');
[Yn, ~, in_] = dsig.deriveSignals(dataTypeOut="AUX");
[~, wid] = lastwarn();
check(isempty(Yn.AUX) && ~isfield(in_, 'AUX') && strcmp(wid, 'EphysDataset:deriveSignals:NoAux'), ...
    'deriveSignals "AUX" without aux inputs: empty, no info.AUX, NoAux warning');
if license('test', 'Signal_Toolbox')
    daux.OutputDir = fullfile(root, 'out_split_aux');
    oa = daux.toMat(SeparateFiles=true, SignalOptions=struct('dataTypeOut', ["LFP" "AUX"], 'LFP_Fs', 1000));
    check(numel(oa.file) == 2 && endsWith(oa.file(2), "_AUX.mat") && isequal(oa.types, ["LFP" "AUX"]), ...
        'toMat SeparateFiles writes an _AUX file');
    cxa = daux.exportChronux();
    Ca = load(cxa.file);
    check(isequal(sort(cxa.signals), ["AUX" "LFP"]) && isequal(size(Ca.AUX.data), [nSampSplit numAux]) ...
        && Ca.AUX.params.Fs == Fs && Ca.AUX.info.units == "volts" && Ca.AUX.labels(1) == "accel1", ...
        'exportChronux: AUX struct in volts with aux labels');
    fta = daux.exportFieldTrip(Validate=false);
    Fa = load(fta.file);
    check(isfield(Fa, 'data_AUX') && isequal(Fa.data_AUX.label, {'accel1'; 'accel2'; 'accel3'}) ...
        && isequal(Fa.data_AUX.hdr.chanunit, repmat({'V'}, numAux, 1)), 'exportFieldTrip: data_AUX with aux labels, unit V');
    dsig.OutputDir = fullfile(root, 'out_split_noaux');
    on = dsig.toMat(SeparateFiles=true, SignalOptions=struct('dataTypeOut', ["LFP" "AUX"], 'LFP_Fs', 1000));
    check(isscalar(on.file) && endsWith(on.file, "_LFP.mat") && on.types == "LFP" ...
        && ~isfile(EphysDataset.signalFiles(fullfile(dsig.OutputDir, dsig.Name + "_extract.mat"), "AUX")), ...
        'toMat SeparateFiles: no _AUX file for a recording without aux');
    check(isequal(EphysDataset.recordedSignalFiles([on.file, replace(on.file, "_LFP.mat", "_AUX.mat")]), on.file), ...
        'recordedSignalFiles drops the unwritten _AUX file');
    dsig.OutputDir = "";
else
    fprintf('  (aux toMat / export checks skipped: no Signal Processing Toolbox)\n');
end

% --- one-file-per-channel: info.rhd + amp-A-00x.dat (+ time/board-DIN) -------
chanFolder = fullfile(root, 'split_channel');
mkdir(chanFolder);
writeInfoRHD(fullfile(chanFolder, 'info.rhd'), numAmp, Fs);
for c = 1:numAmp
    writeDat(fullfile(chanFolder, sprintf('amp-A-%03d.dat', c-1)), ampI16(c,:), 'int16');
end
writeDat(fullfile(chanFolder, 'time.dat'), int32(0:nSampSplit-1), 'int32');
writeDat(fullfile(chanFolder, 'board-DIN-00.dat'), uint16(digSplit), 'uint16');

dchan = EphysDataset(chanFolder);
check(dchan.RecordingFormat == "one-file-per-channel", 'detect one-file-per-channel');
check(dchan.NumChannels == numAmp, 'channel: NumChannels');
check(dchan.NumSamples == nSampSplit, 'channel: NumSamples from amp-A-000.dat size');
datc = dchan.readData();
check(all(abs(datc.amplifier - expSigUV) < 1e-9, 'all'), 'channel: amplifier microvolts');
check(numel(fieldnames(datc.events)) == 1, 'channel: one dig-in event field');
evcN = fieldnames(datc.events); evChan = datc.events.(evcN{1});
check(size(evChan,1) == 1 && abs(evChan(1,1) - 50/Fs) < 1e-9, 'channel: event onset (sample 50)');
dchan.OutputDir = fullfile(root, 'out_split_channel');
ic = dchan.toBin();
rawChan = reshape(typecast(readBin(ic.filename), 'int16'), numAmp, nSampSplit);
check(max(abs(double(rawChan) - double(ampI16)), [], 'all') <= 1, 'channel: .bin int16 == source int16');

% Split toBin must match the in-memory matrixToBin on the same microvolts.
dsig2 = EphysDataset(sigFolder); dsig2.OutputDir = fullfile(root, 'out_split_mem');
imem = dsig2.matrixToBin(expSigUV);
check(isequal(readBin(isig.filename), readBin(imem.filename)), ...
    'signal: streaming toBin == matrix2kilosort (byte-identical)');

fprintf('\n== 11. artifactIntervals (manual merge + auto streaming) ==\n');
dsi = EphysDataset(dsFolder);
% Manual-only: two overlapping periods merge into one; auto disabled by default.
dsi.ManualArtifacts = [0.001 0.003; 0.0025 0.004];
ivm = dsi.artifactIntervals();
check(size(ivm,1) == 1, 'artifactIntervals merges overlapping manual periods');
check(abs(ivm(1,1) - 0.001) < 1e-9 && abs(ivm(1,2) - 0.004) < 1e-9, ...
    'merged manual interval spans the union');
% IncludeAuto=false ignores ArtifactConfig even when Enabled.
dsi.ArtifactConfig.Enabled = true;
ivf = dsi.artifactIntervals(IncludeAuto=false);
check(size(ivf,1) == 1, 'IncludeAuto=false returns manual periods only');
% Auto detection streams the recording; a low microvolts threshold flags the
% random fixture broadly, exercising the offset accumulation + merge path.
dsi.ArtifactConfig.Method = "microvolts";
dsi.ArtifactConfig.Threshold = 3000;
dsi.ArtifactConfig.MinChannels = 1;
iva = dsi.artifactIntervals();
check(size(iva,2) == 2 && ~isempty(iva), 'artifactIntervals (auto) returns intervals');
check(all(iva(:,2) >= iva(:,1)), 'auto intervals are well-formed');
check(max(iva(:,2)) <= dsi.Duration + 1e-6, 'auto intervals lie within the recording');
% The same intervals come back from the process pool (or from the serial
% fall-back when no pool can be used); MaxWorkers=1 is serial and says so.
ivaP = dsi.artifactIntervals(UseParallel=true);
check(isequal(ivaP, iva), 'artifactIntervals(UseParallel=true) == serial (traditional files)');
lastwarn('');
ivaS = dsi.artifactIntervals(UseParallel=true, MaxWorkers=1);
[~, wid] = lastwarn;
check(isequal(ivaS, iva) && strcmp(wid, 'EphysDataset:artifactIntervals:SerialFallback'), ...
    'MaxWorkers=1 falls back to serial with a warning');

fprintf('\n== 12. runSpikeInterface(DryRun=true) ==\n');
dsr = EphysDataset(dsFolder);
dsr.OutputDir = fullfile(root, 'out_si');
dsr.ProbeFile = probeFile;                 % from section 8
dsr.PythonExe = "C:\envs\kilosort\python.exe";
dsr.ExcludeChannels = 2;                    % 1-based .bin row -> 0-based idx 1
dsr.ManualArtifacts = [0.0005 0.001];
resSI = dsr.runSpikeInterface(DryRun=true);
check(isfile(resSI.settingsPath), 'si_config.json written');
check(isfile(resSI.scriptPath), 'run_si_ks4.py written');
cfgSI = jsondecode(fileread(resSI.settingsPath));
check(cfgSI.n_chan == numAmp, 'config n_chan');
check(abs(cfgSI.fs - Fs) < 1e-9, 'config fs');
check(strcmp(char(cfgSI.recording_format), 'traditional'), 'config recording_format');
check(numel(cfgSI.files) == 2, 'config lists both rhd files');
check(isequal(cfgSI.exclude_channels(:).', 1), 'exclude_channels 0-based (2 -> 1)');
check(cfgSI.preprocessing.detect_bad_channels.enabled, 'detect_bad_channels on by default');
check(cfgSI.preprocessing.silence_periods.enabled, 'silence enabled with a manual period');
check(~cfgSI.preprocessing.filter.enabled, 'SI bandpass off by default');
check(contains(resSI.command, 'run_si_ks4.py'), 'command references the script');
check(endsWith(char(resSI.resultsDir), 'kilosort4'), 'results dir is the kilosort4 run folder');

fprintf('\n== 13. detectSpikes (voltage thresholding) ==\n');
FsSpk = ds.Fs;                      % 30000
rng(7);
noiseSD = 5;                                    % uV white noise
Xs = noiseSD * randn(2*FsSpk, 2);               % 2 s, 2 channels
% Spike template: sharp negative trough (sigma 1.5 samples) + slower positive
% lobe. Element 11 (tw == 0) is the trough, 291.9 uV deep.
tw   = (-10:20).';
tmpl = -300*exp(-0.5*(tw/1.5).^2) + 60*exp(-0.5*((tw-8)/4).^2);
spkIdx = round((0.1:0.05:1.9).' * FsSpk);       % 37 troughs, 50 ms apart
Xs = injectSpikes(Xs, spkIdx,      1, tmpl, 11);
Xs = injectSpikes(Xs, spkIdx(1:10), 2, tmpl, 11);

% Threshold=8 robust SDs keeps false crossings of the 5 uV noise out of the
% exact-index checks (4 SDs over 60000 samples would let a couple through).
[tsS, wfS, infoS] = ds.detectSpikes(Xs, Filter=false, Threshold=8);
check(iscell(tsS) && numel(tsS) == 2, 'detectSpikes returns {1 x nChan} timestamps');
check(isequal(infoS.count, [numel(spkIdx) 10]), 'per-channel spike counts');
check(isequal(infoS.index{1}, spkIdx), 'trough-aligned sample indices exact (ch 1)');
check(max(abs(tsS{1} - (spkIdx-1)/FsSpk)) < 1e-12, 'timestamps = (row-1)/Fs');
check(abs(infoS.threshold(1) - 8*noiseSD) < 0.05*8*noiseSD, 'MAD threshold ~ 8 robust SDs');
check(all(infoS.amplitude{1} < -250), 'amplitudes are the signed trough values');

% Waveforms (requested by asking for a second output)
check(isequal(size(wfS{1}), [numel(spkIdx) 61]), 'waveform matrix [nSpikes x nWin]');
check(abs(infoS.waveformTimeMs(1) + 0.5) < 1e-12 && ...
      abs(infoS.waveformTimeMs(end) - 1.5) < 1e-12, 'default window spans -0.5 to 1.5 ms');
zc = find(infoS.waveformTimeMs == 0);
check(isscalar(zc) && max(abs(wfS{1}(:,zc) - infoS.amplitude{1})) < 1e-12, ...
    'waveforms centered on the aligned sample');
[~, wmin] = min(wfS{1}, [], 2);
check(all(wmin == zc), 'every waveform troughs at the center column');

% Default threshold (4 robust SDs) still finds every injected trough
[~, ~, info4] = ds.detectSpikes(Xs, Filter=false);
check(all(arrayfun(@(k) min(abs(info4.index{1} - k)), spkIdx) == 0), ...
    'default 4-SD MAD threshold finds every injected trough');

% Default band-pass path
[~, ~, infoF] = ds.detectSpikes(Xs, Threshold=8);
check(infoF.filterApplied && isequal(infoF.band, [500 5000]), 'default band 500-5000 Hz');
check(all(arrayfun(@(k) min(abs(infoF.index{1} - k)), spkIdx) <= 3), ...
    'band-pass detection within 3 samples of each true trough');

% Polarity / alignment
[~, ~, infoP] = ds.detectSpikes(-Xs, Filter=false, Threshold=8, ...
    Polarity="positive", Align="peak");
check(isequal(infoP.index{1}, spkIdx), 'positive polarity + peak alignment (inverted signal)');
[~, ~, infoB] = ds.detectSpikes(Xs, Filter=false, Threshold=8, ...
    Polarity="both", Align="extremum");
check(isequal(infoB.index{1}, spkIdx), 'polarity "both" + extremum alignment');
[~, ~, infoN] = ds.detectSpikes(Xs, Filter=false, Threshold=8, Align="none");
check(isequal(infoN.count, infoS.count) && ...
      all(infoN.index{1} <= spkIdx & infoN.index{1} >= spkIdx-3), ...
    'Align="none" timestamps the first threshold crossing');

% Minimum detection period: two troughs 0.5 ms (15 samples) apart
twP   = (-6:6).';
tmplP = -300*exp(-0.5*(twP/1.5).^2);
Xp = injectSpikes(noiseSD*randn(3000,1), [1000; 1015], 1, tmplP, 7);
[~, ~, iMin1] = ds.detectSpikes(Xp, Filter=false, Threshold=8, ...
    AlignWindowMs=0.2, MinPeriodMs=1);
check(isequal(iMin1.index{1}, 1000), 'MinPeriodMs=1 keeps only the first of two troughs 0.5 ms apart');
check(abs(iMin1.minPeriodMs - 1) < 1e-12 && iMin1.minPeriodSamples == 30, ...
    'min period reported in ms and samples');
[~, ~, iMin2] = ds.detectSpikes(Xp, Filter=false, Threshold=8, ...
    AlignWindowMs=0.2, MinPeriodMs=0.2);
check(isequal(iMin2.index{1}, [1000; 1015]), 'MinPeriodMs=0.2 keeps both troughs');

% Edge handling: an extra trough at sample 5, whose window runs off the start
Xe = injectSpikes(Xs, 5, 1, tmplP, 7);
tsE1          = ds.detectSpikes(Xe, Filter=false, Threshold=8, EdgeHandling="drop");
[tsE2, wfE2]  = ds.detectSpikes(Xe, Filter=false, Threshold=8, EdgeHandling="drop");
[tsE3, wfE3]  = ds.detectSpikes(Xe, Filter=false, Threshold=8, EdgeHandling="nan");
check(numel(tsE1{1}) == numel(spkIdx)+1, 'timestamps-only call keeps the edge spike');
check(numel(tsE2{1}) == numel(spkIdx) && size(wfE2{1},1) == numel(tsE2{1}), ...
    'EdgeHandling="drop" drops the edge spike from ts and wf together');
check(numel(tsE3{1}) == numel(spkIdx)+1 && all(isnan(wfE3{1}(1,1:10))), ...
    'EdgeHandling="nan" keeps the spike and pads the truncated window');

% TimeOffset
tsO = ds.detectSpikes(Xs, Filter=false, Threshold=8, TimeOffset=10);
check(max(abs(tsO{1} - (tsS{1} + 10))) < 1e-12, 'TimeOffset shifts every timestamp');

% Other threshold methods
[~, ~, iAbs] = ds.detectSpikes(Xs, Filter=false, ThresholdMethod="absolute", Threshold=100);
check(iAbs.threshold(1) == 100 && isnan(iAbs.noise(1)), 'absolute threshold in microvolts');
check(isequal(iAbs.index{1}, spkIdx), 'absolute threshold detects the injected troughs');
[~, ~, iStd] = ds.detectSpikes(Xs, Filter=false, ThresholdMethod="std");
check(iStd.noise(1) > infoS.noise(1), 'STD noise estimate inflated by spikes (MAD is robust)');
[~, ~, iPct] = ds.detectSpikes(Xs, Filter=false, ThresholdMethod="percentile", Threshold=99.9);
check(iPct.threshold(1) > 0 && iPct.count(1) > 0, 'percentile threshold detects spikes');

% Input / option guards
errId = '';
try
    ds.detectSpikes(randn(1,64), Filter=false);
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'EphysDataset:detectSpikes:RowVector'), 'row-vector input rejected');

errId = '';
try
    ds.detectSpikes(Xs, Filter=false, ThresholdMethod="absolute");
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'EphysDataset:detectSpikes:NoThreshold'), 'absolute method requires a Threshold');

errId = '';
try
    ds.detectSpikes(Xs, Band=[500 FsSpk]);
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'EphysDataset:detectSpikes:BandAboveNyquist'), 'band above Nyquist rejected');

fprintf('\n== 14. detectSpikes over a whole recording (streaming) ==\n');
% One-file-per-signal fixture with known troughs, detected chunk by chunk. The
% streamed result must match detecting on the whole recording in one block.
spkFolder = fullfile(root, 'A2_260101_130000');
mkdir(spkFolder);
nChanSpk = 2;
nSampRec = 12000;                                % 0.4 s at 30 kHz
rng(11);
XuV  = 5 * randn(nSampRec, nChanSpk);            % microvolts
twR   = (-10:20).';
tmplR = -300*exp(-0.5*(twR/1.5).^2) + 60*exp(-0.5*((twR-8)/4).^2);
% Troughs: near the very start, straddling the 2000-sample chunk boundaries
% (1990 / 4010 / 7999), and running past the end of the recording (11960).
recIdx = [6; 500; 1990; 2060; 4010; 6000; 7999; 9000; 10000; 11960];
XuV = injectSpikes(XuV, recIdx,      1, tmplR, 11);
XuV = injectSpikes(XuV, recIdx(1:4), 2, tmplR, 11);
ampI16spk = int16(round(XuV.' / 0.195));         % [nChan x nSamp] stored codes
writeInfoRHD(fullfile(spkFolder, 'info.rhd'), nChanSpk, Fs);
writeDat(fullfile(spkFolder, 'amplifier.dat'), ampI16spk, 'int16');
writeDat(fullfile(spkFolder, 'time.dat'), int32(0:nSampRec-1), 'int32');
writeDat(fullfile(spkFolder, 'digitalin.dat'), uint16(zeros(1,nSampRec)), 'uint16');

dsSpk = EphysDataset(spkFolder);
datRec = dsSpk.readData();
Xrec   = datRec.amplifier;                       % the same microvolts, in one block

% Reference: the whole recording detected as a single block.
absArgs = {'Filter', false, 'ThresholdMethod', "absolute", 'Threshold', 100};
[tsBlk, wfBlk, iBlk] = dsSpk.detectSpikes(Xrec, absArgs{:});
check(isequal(iBlk.index{1}, recIdx), 'block reference finds every injected trough');

% Streamed over 6 chunks of 2000 samples.
[tsStr, wfStr, iStr] = dsSpk.detectSpikes('MaxChunkSamples', 2000, absArgs{:});
check(numel(iStr.chunks) == 6 && isequal([iStr.chunks.sampleOffset], 0:2000:10000), ...
    'recording streamed in 6 chunks with contiguous sample offsets');
check(iStr.source == "recording" && iStr.thresholdScope == "chunk", ...
    'info flags whole-recording mode and per-chunk thresholds');
check(isequal(size(iStr.threshold), [6 nChanSpk]), 'threshold reported per chunk x channel');
check(iStr.nSamples == nSampRec && abs(iStr.durationSec - nSampRec/Fs) < 1e-12, ...
    'nSamples / durationSec cover the whole recording');
check(isequal(iStr.index{1}, recIdx) && isequal(iStr.index{2}, recIdx(1:4)), ...
    'streamed indices are recording-global and exact, across chunk boundaries');
check(isequal(iStr.index, iBlk.index) && isequal(iStr.count, iBlk.count), ...
    'streamed detection == single-block detection (indices and counts)');
check(max(abs(tsStr{1} - (recIdx-1)/Fs)) < 1e-12, 'timestamps = (index-1)/Fs');
check(isequal(tsStr, tsBlk), 'streamed timestamps == single-block timestamps');
check(isequaln(wfStr{1}, wfBlk{1}) && isequaln(wfStr{2}, wfBlk{2}), ...
    'streamed waveforms == single-block waveforms (NaN padding included)');
% Chunk boundaries must not truncate a waveform; only the recording edges do.
bnd = find(recIdx == 1990);
check(all(isfinite(wfStr{1}(bnd,:))), 'waveform straddling a chunk boundary is complete');
check(any(isnan(wfStr{1}(1,:))) && any(isnan(wfStr{1}(end,:))), ...
    'waveforms past the start/end of the recording are NaN-padded');
check(isequal(iStr.nEdgeWindows, iBlk.nEdgeWindows), ...
    'edge-window count matches the single-block result');

% A subset/reorder of channels applies to every chunk.
[~, ~, iCh] = dsSpk.detectSpikes('MaxChunkSamples', 2000, 'ChannelOrder', 2, absArgs{:});
check(iCh.nChan == 1 && isequal(iCh.index{1}, recIdx(1:4)), ...
    'ChannelOrder subsets the channels detected on');

% Default (band-pass + MAD) path over the recording.
[~, ~, iDef] = dsSpk.detectSpikes(MaxChunkSamples=2000, Threshold=8);
check(all(arrayfun(@(k) min(abs(iDef.index{1} - k)), recIdx) <= 3), ...
    'band-pass streaming detects every injected trough within 3 samples');
check(iDef.edgePadSamples >= round(0.010*Fs), 'edge padding at least EdgePadMs');

% Progress reporting runs once per chunk.
nProg = 0;
dsSpk.detectSpikes('MaxChunkSamples', 2000, absArgs{:}, 'ProgressFcn', @progTick);
check(nProg == 6, 'ProgressFcn called once per chunk');

% UseParallel must give exactly the serial result (or fall back to serial with
% a warning where no pool is available).
[tsPar, wfPar, iPar] = dsSpk.detectSpikes('MaxChunkSamples', 2000, absArgs{:}, ...
    'UseParallel', true);
check(isequal(tsPar, tsStr) && isequaln(wfPar, wfStr), ...
    'UseParallel timestamps and waveforms == serial (split format)');
check(isequaln(iPar, iStr), 'UseParallel info == serial (split format)');
[~, ~, iParDef] = dsSpk.detectSpikes(MaxChunkSamples=2000, Threshold=8, UseParallel=true);
check(isequaln(iParDef, iDef), 'UseParallel == serial with band-pass + MAD thresholds');
[~, wfSerT, iSerT] = ds.detectSpikes(Filter=false, ThresholdMethod="percentile", ...
    Threshold=99, Waveforms=true);
[~, wfParT, iParT] = ds.detectSpikes(Filter=false, ThresholdMethod="percentile", ...
    Threshold=99, Waveforms=true, UseParallel=true);
check(isequaln(iParT, iSerT) && isequaln(wfParT, wfSerT) && numel(iParT.chunks) == 2, ...
    'UseParallel == serial across traditional *.rhd files');

% MaxWorkers caps the chunks in flight without changing the result; 1 means
% serial (with the fall-back warning), whether or not a pool is available.
[~, ~, iPar2] = dsSpk.detectSpikes('MaxChunkSamples', 2000, absArgs{:}, 'UseParallel', true, 'MaxWorkers', 2);
check(isequaln(iPar2, iStr), 'MaxWorkers=2 gives the serial result');
lastwarn('');
[~, ~, iOne] = dsSpk.detectSpikes('MaxChunkSamples', 2000, absArgs{:}, 'UseParallel', true, 'MaxWorkers', 1);
[~, wid] = lastwarn;
check(strcmp(wid, 'EphysDataset:detectSpikes:SerialFallback') && isequaln(iOne, iStr), ...
    'MaxWorkers=1 falls back to serial with a warning and the same result');
nProg = 0;
dsSpk.detectSpikes('MaxChunkSamples', 2000, absArgs{:}, 'ProgressFcn', @progTick, 'UseParallel', true);
check(nProg == 6, 'ProgressFcn is called once per chunk in parallel mode too');
% A worker error surfaces with the identifier the serial path raises, and a
% ProgressFcn that throws (the pipeline's cancel) stops the loop and leaves no
% future queued or running on the pool.
check(strcmp(errorIdOf(@() dsSpk.detectSpikes('MaxChunkSamples', 2000, absArgs{:}, 'ChannelOrder', 99, 'UseParallel', true)), ...
    errorIdOf(@() dsSpk.detectSpikes('MaxChunkSamples', 2000, absArgs{:}, 'ChannelOrder', 99))), ...
    'a worker error carries the serial error identifier');
nProg = 0;
check(strcmp(errorIdOf(@() dsSpk.detectSpikes('MaxChunkSamples', 2000, absArgs{:}, 'UseParallel', true, ...
    'ProgressFcn', @cancelAfterTwo)), 'test:Cancel'), 'a throwing ProgressFcn aborts a parallel run');
pl = gcp('nocreate');
if ~isempty(pl)
    tq = tic;
    while toc(tq) < 10 && (~isempty(pl.FevalQueue.QueuedFutures) || ~isempty(pl.FevalQueue.RunningFutures))
        pause(0.1);
    end
    check(isempty(pl.FevalQueue.QueuedFutures) && isempty(pl.FevalQueue.RunningFutures), ...
        'cancelling leaves no future queued or running on the pool');
end
% artifactIntervals / analyzeArtifacts over the same six split chunks give the
% same intervals and summary from the pool.
dsSpk.ArtifactConfig.Enabled = true;
dsSpk.ArtifactConfig.Method = "microvolts";
dsSpk.ArtifactConfig.Threshold = 100;
dsSpk.ArtifactConfig.MinChannels = 1;
ivSer = dsSpk.artifactIntervals(MaxChunkSamples=2000);
ivPar = dsSpk.artifactIntervals(MaxChunkSamples=2000, UseParallel=true);
check(~isempty(ivSer) && isequal(ivSer, ivPar), 'artifactIntervals over 6 split chunks: parallel == serial');
smSer = dsSpk.analyzeArtifacts(MaxChunkSamples=2000);
smPar = dsSpk.analyzeArtifacts(MaxChunkSamples=2000, UseParallel=true);
check(isequaln(smSer, smPar) && smSer.nSamples == nSampRec && numel(smSer.files) == 6, ...
    'analyzeArtifacts over 6 split chunks: parallel == serial, MaxChunkSamples honoured');
check(size(smSer.intervals, 1) == smSer.nIntervals && all(smSer.intervals(:, 2) > smSer.intervals(:, 1)) ...
    && isequal(mergeTouching(smSer.intervals), ivSer), ...
    'analyzeArtifacts returns every detected interval, recording-relative; artifactIntervals joins those that touch across chunks');
dsSpk.ArtifactConfig.Enabled = false;

% Guards
errId = '';
try
    ds.detectSpikes(Xs, Filter=false, ChannelOrder=1);
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'EphysDataset:detectSpikes:BlockOption'), ...
    'streaming-only options rejected for a data block');

errId = '';
try
    dsSpk.detectSpikes(Fs=30000);
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'EphysDataset:detectSpikes:FsNotAllowed'), ...
    'Fs cannot be overridden over a whole recording');

errId = '';
try
    EphysDataset().detectSpikes();
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'EphysDataset:detectSpikes:NoData'), ...
    'no data block and no recording folder is an error');

fprintf('\n== 15. JSON helpers, manifest v2, sorting/behavior association ==\n');
% writeJsonFile / readJsonFile
jf = fullfile(root, 'json_test.json');
js = struct('a', Inf, 'b', NaN, 'c', [1 -Inf 3], 'd', "x", 'e', struct('f', 2));
writeJsonFile(jf, js, NonFinite="string");
jr = readJsonFile(jf);
check(strcmp(jr.a, 'Inf') && strcmp(jr.b, 'NaN') && iscell(jr.c) && strcmp(jr.c{2}, '-Inf') ...
    && jr.c{1} == 1 && strcmp(jr.d, 'x') && jr.e.f == 2, ...
    'writeJsonFile(NonFinite="string") writes Inf/-Inf/NaN as strings');
check(isempty(dir(fullfile(root, '~*.partial'))), 'writeJsonFile leaves no partial file behind');
writeJsonFile(jf, struct('a', NaN, 'b', 3));
jr = readJsonFile(jf);
check(isempty(jr.a) && jr.b == 3, 'default NonFinite="null" writes NaN as null');
check(isempty(readJsonFile(fullfile(root, 'nope.json'), ErrorOnFail=false)), ...
    'readJsonFile(ErrorOnFail=false) returns [] for a missing file');
errId = '';
try
    readJsonFile(fullfile(root, 'nope.json'));
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'readJsonFile:NotFound'), 'readJsonFile errors on a missing file by default');

% Manifest v2 round trip on a copy of the two-file dataset.
mdsDir = fullfile(root, 'mds');
mkdir(mdsDir);
copyfile(fullfile(dsFolder, '*.rhd'), mdsDir);
sortDir = fullfile(root, 'phy_manual');
mkdir(sortDir);
fidp = fopen(fullfile(sortDir, 'params.py'), 'w'); fprintf(fidp, 'sample_rate = %g\n', Fs); fclose(fidp);
fidp = fopen(fullfile(sortDir, 'spike_clusters.npy'), 'w'); fwrite(fidp, 0); fclose(fidp);
fidp = fopen(fullfile(sortDir, 'cluster_group.tsv'), 'w');
fprintf(fidp, 'cluster_id\tgroup\n0\tgood\n1\tmua\n'); fclose(fidp);
behFile = fullfile(root, 'beh_session.mat');
Data = struct('TrialIndex', {1, 2}); Info = struct('Subject', 'subjA'); %#ok<NASGU>
save(behFile, 'Data', 'Info');

dsm = EphysDataset(mdsDir);
dsm.ProbeFile = probeFile;
dsm.ExcludeChannels = [2 3];
dsm.ManualArtifacts = [0.001 0.002; 0.005 0.006];
dsm.SortingDir = sortDir;
dsm.BehaviorFile = behFile;
dsm.writeManifest();
m = readJsonFile(dsm.manifestFile());
check(strcmp(m.schema, 'intan-dataset-manifest/2'), 'manifest schema is v2');
check(isequal(size(m.manual_artifacts), [2 2]), 'manifest stores manual_artifacts');
check(strcmp(m.sorting.source, 'manual') && m.sorting.curated && m.sorting.num_units == 2 ...
    && strcmp(m.sorting.results_dir, sortDir), 'manifest sorting block (manual, curated, 2 units)');
check(strcmp(m.behavior.file, behFile), 'manifest behavior file');

ds2 = EphysDataset(mdsDir);
tf2 = ds2.applyManifest();
check(tf2 && isequal(ds2.ExcludeChannels, [2 3]) && ds2.ProbeFile == string(probeFile), ...
    'applyManifest restores probe + exclusions');
check(isequal(ds2.ManualArtifacts, [0.001 0.002; 0.005 0.006]), 'applyManifest restores manual artifacts');
check(ds2.SortingDir == string(sortDir) && strcmp(ds2.sortingResultsDir(), sortDir) ...
    && ds2.hasKilosortResults() && ds2.hasPhyOutput(), ...
    'applyManifest restores a manual sorting dir; accessors follow it');
check(ds2.BehaviorFile == string(behFile), 'applyManifest restores the behavior file');

dsm.ManualArtifacts = [0.003 0.004];
dsm.writeManifest();
ds3 = EphysDataset(mdsDir);
ds3.applyManifest();
check(isequal(ds3.ManualArtifacts, [0.003 0.004]), 'a single manual period survives the jsondecode collapse');
ds3.SortingDir = "";
check(strcmp(ds3.sortingResultsDir(), ds3.kilosortResultsDir()) && ~ds3.hasKilosortResults(), ...
    'sortingResultsDir falls back to kilosortResultsDir when SortingDir is empty');
s3 = ds3.sortingStruct();
check(strcmp(s3.source, 'auto') && s3.results_dir == "" && isnan(s3.num_units), ...
    'sortingStruct reports auto / no results when nothing is sorted');

% Auto-discovered sorting is reported without pinning it.
autoDir = fullfile(ds3.kilosortDir(), 'si', 'sorter_output');
mkdir(autoDir);
copyfile(fullfile(sortDir, 'params.py'), autoDir);
copyfile(fullfile(sortDir, 'spike_clusters.npy'), autoDir);
fidp = fopen(fullfile(autoDir, 'cluster_KSLabel.tsv'), 'w');
fprintf(fidp, 'cluster_id\tKSLabel\n0\tgood\n'); fclose(fidp);
s3 = ds3.sortingStruct();
check(strcmp(s3.source, 'auto') && strcmp(s3.results_dir, autoDir) && ~s3.curated && s3.num_units == 1, ...
    'sortingStruct reports an auto-discovered, uncurated run');
ds3.writeManifest();
ds3b = EphysDataset(mdsDir);
ds3b.applyManifest();
check(ds3b.SortingDir == "", 'an auto sorting association is not pinned on restore');

% v1 manifests still yield probe + exclusions.
m1 = struct('schema', "intan-dataset-manifest/1", 'probe', struct('file', probeFile), ...
    'exclude_channels', "4");
writeJsonFile(dsm.manifestFile(), m1);
ds4 = EphysDataset(mdsDir);
tf4 = ds4.applyManifest();
check(tf4 && isequal(ds4.ExcludeChannels, 4) && isempty(ds4.ManualArtifacts) && ds4.SortingDir == "", ...
    'v1 manifest: probe + exclusions restored, nothing else');
writeJsonFile(dsm.manifestFile(), struct('schema', "something/9", 'exclude_channels', "5"));
ds5 = EphysDataset(mdsDir);
ws = warning('off', 'EphysDataset:applyManifest:Schema');
tf5 = ds5.applyManifest();
warning(ws);
check(~tf5 && isempty(ds5.ExcludeChannels), 'a manifest with an unknown schema is ignored');

% EphysProject.refresh + relative keys (tree from section 7).
Pm = EphysProject(fullfile(root, 'proj'));
i1 = Pm.findByKey("mouse1/sess1");
check(i1 > 0 && Pm.findByKey("mouse2/sess1") > 0 && Pm.findByKey("nope") == 0, 'findByKey');
check(isequal(sort(Pm.datasetKeys()), ["mouse1/sess1" "mouse2/sess1"]), ...
    'datasetKeys are root-relative with forward slashes');
check(Pm.findByKey("mouse1\sess1\") == i1, 'findByKey normalizes backslashes / trailing slash');
Pm.Datasets(i1).ManualArtifacts = [0.001 0.002];
Pm.Datasets(i1).writeManifest();
Pr = EphysProject(fullfile(root, 'proj'));
rep = Pr.refresh();
check(height(rep) == 2 && all(rep.Metadata) && all(rep.Manifest), 'EphysProject.refresh report');
j1 = Pr.findByKey("mouse1/sess1");
check(isequal(Pr.Datasets(j1).ManualArtifacts, [0.001 0.002]) && ~isnan(Pr.Datasets(j1).Fs), ...
    'refresh parses headers and restores manifest state');
rep2 = Pr.refresh(CancelFcn=@() true);
check(all(rep2.Message == "cancelled"), 'refresh honours CancelFcn');

% refresh associates the one Epsych2 file in a recording folder (the Copy tab puts it there).
k1 = Pr.findByKey("mouse1/sess1");
k2 = Pr.findByKey("mouse2/sess1");
f1 = Pr.Datasets(k1).Folder;
f2 = Pr.Datasets(k2).Folder;
check(Pr.Datasets(k1).BehaviorFile == "" && Pr.Datasets(k2).BehaviorFile == "", ...
    'no behavior file before one is put in the recording folders');
Data = struct('TrialIndex', {1, 2}); Info = struct('Subject', 'subjA');
save(fullfile(f1, 'subjA_260101T100000.mat'), 'Data', 'Info');
save(fullfile(f2, 'subjA_260102T100000.mat'), 'Data', 'Info');
save(fullfile(f2, 'subjA_260102T110000.mat'), 'Data', 'Info');
behavior = struct('nTrials', 2);
save(fullfile(f1, 'sess1_behavior.mat'), 'behavior');   % an output, not an Epsych2 session
Pb = EphysProject(fullfile(root, 'proj'));
Pb.refresh();
b1 = Pb.Datasets(Pb.findByKey("mouse1/sess1"));
b2 = Pb.Datasets(Pb.findByKey("mouse2/sess1"));
check(b1.BehaviorFile == string(fullfile(f1, 'subjA_260101T100000.mat')), ...
    'refresh associates the one Epsych2 file in the recording folder');
mb = readJsonFile(b1.manifestFile());
check(strcmp(mb.behavior.file, fullfile(f1, 'subjA_260101T100000.mat')), 'that association is written to the manifest');
check(b2.BehaviorFile == "", 'two Epsych2 files in the folder: nothing is associated');
b2.BehaviorFile = string(behFile);
b2.writeManifest();
Pc = EphysProject(fullfile(root, 'proj'));
Pc.refresh();
check(Pc.Datasets(Pc.findByKey("mouse2/sess1")).BehaviorFile == string(behFile), ...
    'an existing association is kept');
Pd = EphysProject(fullfile(root, 'proj'));
Pd.refresh(ApplyManifest=false, WriteManifest=false);
check(Pd.Datasets(Pd.findByKey("mouse1/sess1")).BehaviorFile == "", ...
    'ApplyManifest=false leaves behavior unassociated');
delete(fullfile(f1, '*.mat'));
delete(fullfile(f2, '*.mat'));

fprintf('\n== 16. ArtifactConfig pre-detection filter ==\n');
% A slow 5 Hz, 4000 uV oscillation trips the absolute-microvolts detector
% on broadband data but vanishes after the configured 300 Hz high-pass.
fdir = fullfile(root, 'filt_ds');
mkdir(fdir);
Fsf = 20000; nf = 128 * 200;          % v2 files use 128 samples per block
tt = (0:nf-1) / Fsf;
sig = 4000 * sin(2 * pi * 5 * tt);
rawf = uint16(round(repmat(sig, 4, 1) / 0.195) + 32768);
writeSyntheticRHD(fullfile(fdir, 'f.rhd'), rawf, zeros(1, nf), Fsf, 128);
dsf = EphysDataset(fdir);
dsf.ArtifactConfig.Enabled = true;
dsf.ArtifactConfig.Method = "microvolts";
dsf.ArtifactConfig.Threshold = 3000;
dsf.ArtifactConfig.MinChannels = 1;
ivB = dsf.artifactIntervals();
check(~isempty(ivB), 'broadband: the slow oscillation trips the microvolts detector');
dsf.ArtifactConfig.Filter = true;
dsf.ArtifactConfig.FilterCutoff = 300;
ivH = dsf.artifactIntervals();
check(isempty(ivH), 'ArtifactConfig.Filter=true is honoured by artifactIntervals');
ivO = dsf.artifactIntervals(Filter=false);
check(~isempty(ivO), 'a per-call Filter=false overrides the config');
sumH = dsf.analyzeArtifacts();
check(sumH.nBlanked == 0, 'analyzeArtifacts honours the config filter');
sumB = dsf.analyzeArtifacts(Filter=false);
check(sumB.nBlanked > 0, 'analyzeArtifacts per-call override');
lastwarn('');
check(isequal(dsf.artifactIntervals(UseParallel=true), ivH) && isempty(lastwarn), ...
    'UseParallel on a single-chunk recording runs serially without a warning');
cfgN = EphysDataset.normalizeArtifactConfig(struct('Threshold', 5));
check(cfgN.Filter == false && cfgN.FilterType == "highpass" && cfgN.FilterCutoff == 300 ...
    && cfgN.FilterOrder == 4 && cfgN.Threshold == 5, 'normalizeArtifactConfig fills the filter fields');

fprintf('\n== 17. readPhyUnits / readSortedUnits (sorted units loader) ==\n');
% Legacy-engine layout: phy files directly in kilosort4/, channel_map.npy
% reversed so sorted channel k is recording channel 5-k.
phyFs = 30000;
legDir = fullfile(root, 'phy_legacy', 'kilosort4');
makePhyFixture(legDir, phyFs, ChannelMap=[3 2 1 0], Legacy=true);
[U, ui] = EphysDataset.readPhyUnits(legDir);
check(isequal(U.unitId, [0; 1]) && isequal(U.group, ["good"; "mua"]) && U.groupSource == "phy" && U.curated, ...
    'noise cluster dropped by default; phy labels win over KSLabel');
check(isequal(U.times{1}, double(int64([300; 600; 30000])) / phyFs) && isequal(U.samples{1}, int64([300; 600; 30000])), ...
    'times are samples / params.py sample_rate');
check(U.fs == phyFs && U.nSpikes(1) == 3 && U.nSpikes(2) == 2, 'fs and per-unit counts');
check(isequal(U.ksChannel, [2; 4]) && isequal(U.channel, [3; 1]), ...
    'peak channel from templates; recording channel via channel_map.npy (legacy engine)');
check(U.channelMapSource == "channel_map.npy" && U.engine == "legacy", 'legacy engine detected');
check(numel(U.templateWaveform{1}) == 8 && isempty(U.templateFull) && numel(U.templateTimeMs) == 8, ...
    'peak-channel template waveform, no full templates by default');
check(abs(U.templateWaveform{1}(3) - (-50 * 1.5)) < 1e-9, 'template scaled by the unit median amplitude');
check(isequal(U.amplitude, [1.5; 2]) && isnan(U.contamPct(1)), 'amplitude from amplitudes.npy; contam NaN when absent');
check(numel(ui.spikeSamples) == 6 && isequal(ui.spikeUnitIdx(:).', [1 1 2 2 1 0]), ...
    'info carries per-spike arrays; dropped clusters map to 0');
Ua = EphysDataset.readPhyUnits(legDir, IncludeNoise=true, FullTemplates=true);
check(isequal(Ua.unitId, [0; 1; 2]) && isequal(size(Ua.templateFull), [8 4 3]), 'IncludeNoise + FullTemplates');
Ug = EphysDataset.readPhyUnits(legDir, Groups="mua");
check(isequal(Ug.unitId, 1), 'Groups filter');
Um = EphysDataset.readPhyUnits(legDir, ChannelMap=[10 20 30 40]);
check(isequal(Um.channel, [20; 40]) && Um.channelMapSource == "manual", 'ChannelMap override');
check(strcmp(EphysDataset.resolvePhyDir(fullfile(root, 'phy_legacy')), legDir), 'resolvePhyDir finds kilosort4/ below a dataset folder');
Ur = EphysDataset.readPhyUnits(fullfile(root, 'phy_legacy'));
check(isequal(Ur.unitId, U.unitId), 'readPhyUnits accepts the folder above the results');
errId = '';
try
    EphysDataset.readPhyUnits(legDir, Groups="nothing");
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'EphysDataset:readPhyUnits:NoGroupMatch'), 'unmatched Groups errors');
errId = '';
try
    EphysDataset.readPhyUnits(fullfile(root, 'proj'));
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'EphysDataset:readPhyUnits:NoOutput'), 'a folder without phy output errors');

% No params.py: fallback rate with a warning, error without one.
noFsDir = fullfile(root, 'phy_nofs');
makePhyFixture(noFsDir, phyFs, ChannelMap=[0 1 2 3], Legacy=true);
delete(fullfile(noFsDir, 'params.py'));
errId = '';
try
    EphysDataset.readPhyUnits(noFsDir);
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'EphysDataset:readPhyUnits:NoSampleRate'), 'no params.py and no fallback is an error');
lastwarn('');
ws = warning('off', 'EphysDataset:readPhyUnits:FsFallback');
Uf = EphysDataset.readPhyUnits(noFsDir, FsFallback=20000);
warning(ws);
check(Uf.fs == 20000 && abs(Uf.times{1}(1) - 300 / 20000) < 1e-12, 'FsFallback is used when params.py is missing');

% SpikeInterface layout: probe-site order, one bad channel removed, so the
% 3 sorted channels map back to recording channels through the probe.
siRun = fullfile(root, 'phy_si', 'kilosort4');
siDir = fullfile(siRun, 'si', 'sorter_output');
makePhyFixture(siDir, phyFs, ChannelMap=[0 1 2], NChan=3, Legacy=false);
siProbe = fullfile(root, 'si_probe.json');
writeJsonFile(siProbe, struct('chanMap', [3 0 2 1], 'xc', zeros(1, 4), 'yc', (0:3) * 20, ...
    'kcoords', zeros(1, 4), 'n_chan', 4));
writeJsonFile(fullfile(siRun, 'si_config.json'), struct('schema', "intan-si-ks4/1", ...
    'probe', siProbe, 'n_chan', 4, 'exclude_channels', []));
writeJsonFile(fullfile(siRun, 'ks4_status.json'), struct('state', "done", 'bad_channels', {{'2'}}));
Us = EphysDataset.readPhyUnits(siDir);
% channel numbers 0..3 (default); sites in probe order: 3, 0, 2, 1 -> drop 2 -> [4 1 2]
check(Us.engine == "spikeinterface" && Us.channelMapSource == "probe" && isequal(Us.channelMap, [4; 1; 2]), ...
    'SpikeInterface run maps sorted channels back through the probe minus bad channels');
check(isequal(Us.ksChannel, [2; 3]) && isequal(Us.channel, [1; 2]), 'unit recording channels follow that map');
wsI = warning('off', 'EphysDataset:readPhyUnits:ChannelMapFallback');
Us2 = EphysDataset.readPhyUnits(siDir, ChannelNumbers=[3 2 1 0]);
warning(wsI);
% number -> position: 3->1 2->2 1->3 0->4; chanMap [3 0 2 1] -> [1 4 2 3]; drop number 2 (position 2)
check(Us2.channelMapSource == "probe" && isequal(Us2.channelMap, [1; 4; 3]), ...
    'channels are matched by channel number, as run_si_ks4.py names them');

% Instance wrapper: dataset defaults + SortingDir association.
dsu = EphysDataset(dsFolder);
dsu.SortingDir = legDir;
[Ud, ~] = dsu.readSortedUnits(Groups=["good" "mua"]);
check(isequal(Ud.unitId, [0; 1]) && Ud.resultsDir == string(legDir), 'readSortedUnits reads from SortingDir');
dsu.SortingDir = "";
errId = '';
try
    dsu.readSortedUnits();
catch ME
    errId = ME.identifier;
end
check(startsWith(errId, 'EphysDataset:readPhyUnits:No'), 'readSortedUnits errors when nothing is sorted');
dsu.SortingDir = noFsDir;
ws = warning('off', 'EphysDataset:readPhyUnits:FsFallback');
Un = dsu.readSortedUnits();
warning(ws);
check(Un.fs == dsu.Fs, 'readSortedUnits falls back to the recording rate');

% writeNPY round trips N-D arrays in C order.
npyF = fullfile(root, 'nd.npy');
A = reshape(single(1:24), [2 3 4]);
writeNPY(npyF, A);
[B, shp] = readNPY(npyF);
check(isequal(B, A) && isa(B, 'single') && isequal(shp, [2 3 4]), 'writeNPY/readNPY N-D round trip');
writeNPY(npyF, int64([5 6 7]));
check(isequal(readNPY(npyF), int64([5; 6; 7])), 'writeNPY 1-D round trip');

fprintf('\n== 18. spikesToMat (detected + sorted, artifact rejection) ==\n');
spkOut = fullfile(root, 'spikes_out');
dsSpk.OutputDir = spkOut;
dopt = struct('Filter', false, 'ThresholdMethod', "absolute", 'Threshold', 100);
o1 = dsSpk.spikesToMat(DetectOptions=dopt);
check(isfile(o1.file) && endsWith(o1.file, '_spikes.mat') && startsWith(o1.file, spkOut), ...
    'spikesToMat default file <outputFolder>/<Name>_spikes.mat');
M = load(o1.file);
check(all(isfield(M, {'detected', 'units', 'conversion'})) && ~isfield(M, 'behavior'), ...
    'file holds detected / units / conversion (behavior has its own file)');
check(isequal(M.detected.info.index{1}, recIdx) && isempty(M.units) && isempty(M.detected.wf), ...
    'detected indices match detectSpikes; no units and no waveforms by default');
check(isequal(M.detected.channels, [1 2]) && isequal(M.detected.channelNames, ["amp0" "amp1"]), ...
    'detected channels + names');
check(isequal(o1.nDetected, [10 4]) && isequal(o1.nRejectedArtifact, [0 0]) && o1.nUnits == 0, 'out counts');
[~, wfN, ~] = dsSpk.detectSpikes(absArgs{:}, 'Waveforms', false);
check(isempty(wfN) || all(cellfun(@isempty, wfN)), 'Waveforms=false suppresses extraction even with three outputs');

% Events inside a manual artifact period are rejected (indices 4010, 6000).
dsSpk.ManualArtifacts = [4000 6100] / Fs;
o2 = dsSpk.spikesToMat(DetectOptions=dopt, Overwrite=true, Channels=1);
M2 = load(o2.file);
check(isequal(o2.nRejectedArtifact, 2) && numel(M2.detected.ts{1}) == 8 ...
    && ~any(M2.detected.ts{1} >= 4000/Fs & M2.detected.ts{1} <= 6100/Fs), ...
    'events inside a manual artifact period are rejected');
check(numel(M2.detected.info.index{1}) == 8 && M2.detected.info.count(1) == 8, ...
    'info arrays are filtered consistently');
check(isequal(size(M2.detected.detection.artifactIntervals), [1 2]), 'artifact intervals are recorded');
dsSpk.ManualArtifacts = [4009 5999] / Fs;   % the two events' samples: start inside, end outside
o2b = dsSpk.spikesToMat(DetectOptions=dopt, Overwrite=true, Channels=1);
check(isequal(o2b.nRejectedArtifact, 1), 'a period rejects the event on its first sample but not the one on its end (half-open)');
dsSpk.ManualArtifacts = [4000 6100] / Fs;
o3 = dsSpk.spikesToMat(DetectOptions=dopt, Overwrite=true, Channels=1, RejectArtifacts=false);
check(isequal(o3.nDetected, 10), 'RejectArtifacts=false keeps every event');
o3b = dsSpk.spikesToMat(DetectOptions=dopt, Overwrite=true, Channels=1, ArtifactIntervals=[0 0.0001]);
check(isequal(o3b.nRejectedArtifact, 0) && isequal(o3b.nDetected, 10), 'explicit ArtifactIntervals override the manual periods');
dopt2 = dopt; dopt2.Waveforms = true;
o4 = dsSpk.spikesToMat(DetectOptions=dopt2, Overwrite=true, Channels=1);
M4 = load(o4.file);
check(iscell(M4.detected.wf) && size(M4.detected.wf{1}, 1) == 8, 'waveforms saved on request, rows filtered too');
errId = '';
try
    dsSpk.spikesToMat(DetectOptions=dopt);
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'EphysDataset:spikesToMat:Exists'), 'an existing file is not overwritten by default');
errId = '';
try
    dsSpk.spikesToMat(DetectOptions=struct('ChannelOrder', 1), Overwrite=true);
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'EphysDataset:spikesToMat:DetectOption'), 'ChannelOrder inside DetectOptions is rejected');

% Sorted units and both sources.
dsSpk.SortingDir = legDir;
o5 = dsSpk.spikesToMat(Source="sorted", Overwrite=true);
M5 = load(o5.file);
check(isempty(M5.detected) && isequal(M5.units.unitId, [0; 1]) && o5.nUnits == 2, ...
    'Source="sorted" writes the units only');
check(isequal(M5.units.label, ["su000_A2_260101T1300"; "mua001_A2_260101T1300"]) && isequal(M5.units.class, ["su"; "mua"]) ...
    && all(M5.units.subject == "A2") && isdatetime(M5.units.recordingStart) ...
    && all(M5.units.recordingStart == datetime(2026, 1, 1, 13, 0, 0)) && all(M5.units.datasetKey == EphysProject.normalizeKey(spkFolder)), ...
    'saved units carry their labels and the recording they came from');
o6 = dsSpk.spikesToMat(Source="both", DetectOptions=dopt, Overwrite=true, Groups="good");
M6 = load(o6.file);
check(~isempty(M6.detected) && isequal(M6.units.unitId, 0) && ~isfield(M6, 'behavior') ...
    && M6.conversion.source == "both", 'Source="both" + Groups; no behavior variable');
check(isempty(dir(fullfile(spkOut, '~*.partial.mat'))), 'no partial file is left behind');
dsSpk.ManualArtifacts = zeros(0, 2);

% toMat leaves behavior to its own file (needs the Signal Processing Toolbox).
if license('test', 'Signal_Toolbox')
    oM = dsSpk.toMat(File=fullfile(spkOut, 'x_extract.mat'), ...
        SignalOptions=struct('dataTypeOut', "LFP", 'LFP_Fs', 1000));
    MM = load(oM.file);
    check(~isfield(MM, 'behavior') && isfield(MM, 'Y') && isfield(MM, 'events') && isfield(MM, 'info'), ...
        'toMat saves Y / events / info and no behavior variable');
else
    fprintf('  (toMat variables check skipped: no Signal Processing Toolbox)\n');
end

fprintf('\n== 19. acquisition readers: registry, BinaryReader, discovery ==\n');
check(isa(ds.Reader, 'IntanReader') && ds.Reader.Kind == "intan" && ds.RecordingFormat == "traditional", ...
    'EphysDataset picks IntanReader for a *.rhd folder');
check(isa(dsig.Reader, 'IntanReader') && dsig.supportsRandomAccess() && ~ds.supportsRandomAccess(), ...
    'random access only for the split layouts');
check(isequal(sort(EphysReader.readerClasses()), sort(["IntanReader" "BinaryReader" "OpenEphysReader"])), 'built-in reader registry');
check(isempty(EphysReader.forFolder(fullfile(root, 'proj', 'empty_decoy'))), 'no reader claims an empty folder');
check(strcmp(DatasetTracker.classifyJson(struct('schema', "ephys-recording/1")), 'recording-descriptor'), ...
    'classifyJson recognises a recording descriptor');

% A universal recording built from the traditional dataset: toBin + descriptor.
binDir = fullfile(root, 'universal_rec');
mkdir(binDir);
dsb = EphysDataset(dsFolder);
dsb.OutputDir = binDir;
infoB = dsb.toBin();                        % int16 = round(uV / 0.195), no offset
src = ds.readData();
Xsrc = src.amplifier;
BinaryReader.writeDescriptor(binDir, struct( ...
    'name', "universal", 'data_file', string([char(dsb.Name) '.bin']), 'dtype', "int16", ...
    'n_chan', numAmp, 'fs', Fs, 'gain_to_uV', 0.195, 'offset', 0, ...
    'channel_names', {cellstr(ds.ChannelNames)}, 'native_names', {cellstr(ds.NativeNames)}, ...
    'dig_in_names', {{'din0'}}, 'events', src.events, 'acq_date', "2026-01-02 03:04:05"));
check(isfile(fullfile(binDir, 'recording.json')) && isfile(infoB.filename), 'descriptor + binary written');

dsu = EphysDataset(binDir);
check(isa(dsu.Reader, 'BinaryReader') && dsu.RecordingFormat == "binary" && dsu.Name == "universal_rec" ...
    && dsu.Reader.Name == "universal", 'BinaryReader claims a recording.json folder (dataset name = folder leaf)');
check(dsu.Fs == Fs && dsu.NumChannels == numAmp && dsu.NumSamples == totalSamples ...
    && isequal(dsu.ChannelNames, ds.ChannelNames) && isequal(dsu.NativeNames, ds.NativeNames), ...
    'binary metadata from the descriptor + file size');
check(dsu.AcqDate == datetime(2026, 1, 2, 3, 4, 5), 'acq_date parsed');
du = dsu.readData();
check(isequal(size(du.amplifier), size(Xsrc)) && max(abs(du.amplifier(:) - Xsrc(:))) < 1e-9, ...
    'readData microvolts round-trip through the universal binary');
check(isequal(du.events.din0, src.events.din0) && isequal(du.channelNames, ds.ChannelNames) ...
    && abs(du.t(2) - 1/Fs) < 1e-12, 'events, names and t from the descriptor');
du1 = dsu.readData(KeepChannels=[3 1], Precision="single");
check(isa(du1.amplifier, 'single') && isequal(du1.channelOrder, [3 1]) ...
    && isequal(du1.channelNames, ds.ChannelNames([3 1])), 'KeepChannels / Precision honoured');
planU = dsu.streamPlan(MaxChunkSamples=100);
check(numel(planU) == ceil(totalSamples / 100) && planU(1).kind == "window" && planU(2).sampleOffset == 100, ...
    'binary streamPlan windows');
Xw = dsu.readChunkUV(planU(2));
check(isequal(size(Xw), [100 numAmp]) && max(abs(Xw(:) - reshape(Xsrc(101:200, :), [], 1))) < 1e-9, 'readChunkUV window');
check(dsu.supportsRandomAccess() && max(abs(reshape(dsu.readWindowUV(5, 3) - Xsrc(6:8, :), [], 1))) < 1e-9, 'readWindowUV');
check(isequal(size(dsu.readWindowUV(totalSamples, 10)), [0 numAmp]), 'readWindowUV past the end is empty');
check(EphysDataset.detectFormat(binDir) == "binary" && EphysDataset.detectFormat(dsFolder) == "traditional" ...
    && EphysDataset.detectFormat(fullfile(root, 'proj', 'empty_decoy')) == "unknown", 'detectFormat via the registry');

% Discovery through the registry.
fAll = EphysReader.findAllRecordingFolders(root, true);
check(any(fAll == string(binDir)) && any(fAll == string(dsFolder)), 'findAllRecordingFolders finds both kinds');
dtU = DatasetTracker(binDir);
check(dtU.NumRecordings == 1 && dtU.Recordings(1).Format == "binary" && dtU.Recordings(1).Reader == "binary" ...
    && dtU.Recordings(1).NumFiles == 1, 'DatasetTracker inventories a binary recording');
Pu = EphysProject(binDir);
check(Pu.NumDatasets == 1 && Pu.Datasets(1).RecordingFormat == "binary", 'EphysProject discovers a binary recording');

% Processing on the universal format gives the same answers as on the source.
dsu.ArtifactConfig.Enabled = true;
dsu.ArtifactConfig.Method = "microvolts";
dsu.ArtifactConfig.Threshold = 3000;
dsu.ArtifactConfig.MinChannels = 1;
dsu.ManualArtifacts = dsi.ManualArtifacts;   % section 11's manual periods are part of iva
ivU = dsu.artifactIntervals();
% The chunking differs (two *.rhd files vs one window), so runs that touch a
% file boundary may split differently; compare the flagged duration instead.
check(abs(sum(diff(ivU, 1, 2)) - sum(diff(iva, 1, 2))) <= 4 / Fs && abs(size(ivU, 1) - size(iva, 1)) <= 2, ...
    'artifactIntervals flag the same span on the universal format');
tsS = ds.detectSpikes(absArgs{:});
tsU = dsu.detectSpikes(absArgs{:});
check(isequal(tsS, tsU), 'detectSpikes identical on the universal format');
dsu.writeManifest();
mU = readJsonFile(dsu.manifestFile());
check(strcmp(mU.reader, 'binary') && strcmp(mU.recording_format, 'binary'), 'manifest records the reader');
spU = dsu.Reader.siRecordingSpec();
check(spU.reader == "binary" && spU.gain_to_uV == 0.195 && spU.n_chan == numAmp && spU.dtype == "int16", ...
    'siRecordingSpec carries dtype / gain / offset');
dsu.ProbeFile = probeFile;
dsu.PythonExe = "C:\envs\kilosort\python.exe";
rU = dsu.runSpikeInterface(DryRun=true);
cU = readJsonFile(rU.settingsPath);
check(strcmp(cU.recording.reader, 'binary') && strcmp(cU.recording.dtype, 'int16') && cU.recording.n_chan == numAmp, ...
    'si_config.json carries the recording spec');
spI = ds.Reader.siRecordingSpec();
check(spI.reader == "intan" && iscell(spI.files) && numel(spI.files) == 2, 'Intan siRecordingSpec lists the files');

% Digital input from a per-sample uint16 file instead of the events map.
writeDat(fullfile(binDir, 'digitalin.dat'), uint16(digRaw), 'uint16');
BinaryReader.writeDescriptor(binDir, struct('data_file', string([char(dsb.Name) '.bin']), 'dtype', "int16", ...
    'n_chan', numAmp, 'fs', Fs, 'gain_to_uV', 0.195, 'dig_in_names', {{'din0'}}, 'dig_in_file', "digitalin.dat"));
dsu2 = EphysDataset(binDir);
du2 = dsu2.readData();
check(isequal(du2.events.din0, src.events.din0) && dsu2.Name == "universal_rec", ...
    'events from dig_in_file; name defaults to the folder leaf');
errId = '';
try
    BinaryReader.writeDescriptor(binDir, struct('data_file', "nope.bin", 'dtype', "int16", 'n_chan', 1, 'fs', 1));
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'BinaryReader:NoDataFile'), 'writeDescriptor refuses a missing data file');
writeJsonFile(fullfile(root, 'bad_rec', 'recording.json'), struct('schema', "ephys-recording/1", 'dtype', "int16"));
ws = warning('off', 'EphysReader:ReaderFailed');
check(isempty(EphysReader.forFolder(fullfile(root, 'bad_rec'))), 'an invalid descriptor is reported, not claimed');
warning(ws);

fprintf('\n== 20. exportChronux / exportFieldTrip / behavior ==\n');
% A toMat-shaped extract built in memory (no Signal Processing Toolbox needed).
nX = 256;
Sx = struct();
Sx.Y = struct('LFP', single(Xsrc(1:nX, :)), 'MUA', single([]), 'SPIKE', single([]));
Sx.events = src.events;
Sx.info = struct('LFP', struct('Fs', Fs), 'labels', ds.ChannelNames, 'origFs', Fs);
expOut = fullfile(root, 'export_out');
dsx = EphysDataset(dsFolder);
dsx.OutputDir = expOut;
dsx.SortingDir = legDir;
dsx.BehaviorFile = behFile;
check(dsx.hasKilosortResults(), 'export fixture dataset has sorted units');

% behavior helpers on the minimal section-15 session file
[bt, bi, bm] = dsx.readBehavior();
check(height(bt) == 2 && strcmp(bi.Subject, 'subjA') && bm.subject == "subjA" && isnat(bm.startTime), ...
    'readBehavior loads the associated Epsych2 file');
bs = dsx.behaviorStruct();
check(isstruct(bs) && bs.nTrials == 2 && bs.file == string(behFile), 'behaviorStruct packs trials + info + meta');
dsx.writeManifest();
mx = readJsonFile(dsx.manifestFile());
check(strcmp(mx.behavior.subject, 'subjA') && mx.behavior.n_trials == 2, 'manifest behavior block carries subject / n_trials');
oB = dsx.behaviorToMat();
B = load(oB.file);
check(oB.file == string(fullfile(expOut, dsx.Name + "_behavior.mat")) && B.behavior.nTrials == 2 ...
    && B.conversion.behaviorFile == string(behFile) && isequal(sort(string(fieldnames(B))), ["behavior"; "conversion"]), ...
    'behaviorToMat writes <Name>_behavior.mat with behavior + conversion');
errId = '';
try
    dsx.behaviorToMat();
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'EphysDataset:behaviorToMat:Exists'), 'behaviorToMat does not overwrite by default');
dsx.BehaviorFile = "";
check(isempty(dsx.behaviorStruct()), 'behaviorStruct is [] without an associated file');
errId = '';
try
    dsx.behaviorToMat(Overwrite=true);
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'EphysDataset:behaviorToMat:NoFile'), 'behaviorToMat errors without an associated session');
errId = '';
try
    dsx.readBehavior();
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'EphysDataset:readBehavior:NoFile'), 'readBehavior errors without a file');
dsx.BehaviorFile = behFile;

% detected spikes for the exports
dsx.spikesToMat(DetectOptions=struct('Filter', false, 'ThresholdMethod', "absolute", 'Threshold', 100));

oC = dsx.exportChronux(Extract=Sx);
check(endsWith(oC.file, '_chronux.mat') && isfile(oC.file), 'exportChronux writes <Name>_chronux.mat');
C = load(oC.file);
check(all(isfield(C, {'LFP', 'sp', 'spDetected', 'units', 'detected', 'events', 'export'})) ...
    && ~isfield(C, 'MUA') && ~isfield(C, 'behavior'), 'chronux file variables (only signals present, no behavior)');
check(isa(C.LFP.data, 'double') && isequal(size(C.LFP.data), [nX numAmp]) ...
    && isequal(C.LFP.data, double(single(Xsrc(1:nX, :)))) ...
    && C.LFP.params.Fs == Fs && C.LFP.t(1) == 0 && abs(C.LFP.t(2) - 1/Fs) < 1e-12 ...
    && isequal(C.LFP.labels, ds.ChannelNames), 'LFP data / params / t / labels through ChronuxDataset.continuous');
check(numel(C.sp) == 2 && isequal(fieldnames(C.sp), {'times'}) && isequal(C.units.unitId, [0; 1]) ...
    && isequal(C.units.label, ["su000_A1_260101T1200"; "mua001_A1_260101T1200"]) ...
    && isequal(C.sp(1).times, C.units.times{1}), 'sp is the toPointProcess form of the sorted units');
check(numel(C.spDetected) == numAmp && ~isempty(C.detected) && isequal(C.spDetected(1).times, C.detected.ts{1}(:)), ...
    'spDetected from the spikes file');
check(isequal(C.events.din0, src.events.din0) && C.export.tool == "EphysDataset.exportChronux", ...
    'events and provenance');
oC2 = dsx.exportChronux(Extract=Sx, Units=false, Detected=false, Overwrite=true, ...
    File=fullfile(expOut, 'c2.mat'));
C2 = load(oC2.file);
check(isempty(C2.sp) && isempty(C2.units) && isempty(C2.spDetected) && oC2.nUnits == 0, ...
    'Units / Detected = false leave those empty');
errId = '';
try
    dsx.exportChronux(Extract=Sx);
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'EphysDataset:exportChronux:Exists'), 'existing chronux file is not overwritten by default');
errId = '';
try
    dsx.exportChronux(Extract=Sx, Signals="MUA", Overwrite=true);
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'EphysDataset:exportChronux:SignalMissing'), 'asking for a signal the extract lacks errors');
errId = '';
try
    dsx.exportChronux(Overwrite=true);
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'EphysDataset:exportChronux:NoExtract'), 'no extract file -> clear error');

oF = dsx.exportFieldTrip(Extract=Sx);
check(endsWith(oF.file, '_fieldtrip.mat') && isfile(oF.file), 'exportFieldTrip writes <Name>_fieldtrip.mat');
F = load(oF.file);
check(all(isfield(F, {'data_LFP', 'spike', 'spikeDetected', 'event', 'export'})) && ~isfield(F, 'data_MUA') ...
    && ~isfield(F, 'behavior'), 'fieldtrip file variables (no behavior)');
check(isequal(size(F.data_LFP.trial{1}), [numAmp nX]) && isequal(F.data_LFP.label, cellstr(ds.ChannelNames(:))) ...
    && F.data_LFP.fsample == Fs && F.data_LFP.hdr.TimeStampPerSample == 1, 'data_LFP is a FieldTrip raw structure');
check(numel(F.data_LFP.cfg.event) == size(src.events.din0, 1) && F.data_LFP.cfg.event(1).sample == round(src.events.din0(1, 1) * Fs), ...
    'each data struct carries its events at its own rate in cfg.event');
check(isequal(F.spike.label, {'su000_A1_260101T1200', 'mua001_A1_260101T1200'}) && isequal(F.spike.timestamp{1}, [300 600 30000]) && F.spike.hdr.Fs == 30000 ...
    && isequal(F.spike.hdr.orig.shank, [0; 0]) && isfield(F.spike.hdr.orig, 'notes') && isfield(F.spike.hdr.orig, 'y'), ...
    'spike structure from the sorted units');
check(numel(F.spikeDetected.label) == numAmp && F.spikeDetected.hdr.Fs == Fs, 'spikeDetected from the spikes file');
check(numel(F.event) == size(src.events.din0, 1) && F.export.eventFs == Fs, ...
    'event at the recording rate; provenance');
check(isempty(dir(fullfile(expOut, '~*.partial.mat'))), 'no partial files left by the exporters');

% Extract from the file written by toMat (needs the Signal Processing Toolbox).
if license('test', 'Signal_Toolbox')
    oM = dsx.toMat(SignalOptions=struct('dataTypeOut', ["LFP" "MUA"], 'LFP_Fs', 1000, 'MUA_Fs', 2000));
    oF2 = dsx.exportFieldTrip(Overwrite=true);
    F2 = load(oF2.file);
    check(isfile(oM.file) && isequal(sort(oF2.signals), ["LFP" "MUA"]) && isfield(F2, 'data_MUA') ...
        && F2.data_MUA.hdr.TimeStampPerSample == Fs / 2000, 'default Extract is the toMat file; origFs sets TimeStampPerSample');
else
    fprintf('  (toMat-based export check skipped: no Signal Processing Toolbox)\n');
end

fprintf('\n== 21. channelLayout (the recording channels on the probe) ==\n');
lay = fullfile(root, 'layout'); mkdir(lay);
rng(7);
writeSyntheticRHD(fullfile(lay, 'lay.rhd'), uint16(randi([0 65535], 5, spb)), zeros(1, spb), Fs, spb, ...
    AmpNames=["c5" "c2" "c7" "c0" "c9"], AmpNative=["A-005" "A-002" "A-007" "A-000" "A-009"]);
dl = EphysDataset(lay);
L0 = dl.channelLayout();
check(isequal(dl.ChannelNumbers, [5 2 7 0 9]) && ~L0.hasProbe && isequal(L0.order, 1:5) && all(isnan(L0.shank)), ...
    'without a probe no channel is placed and the order is the recording''s');
layProbe = fullfile(lay, 'probe.json');
writeJsonFile(layProbe, struct('chanMap', [0; 2; 5; 7], 'xc', zeros(4, 1), 'yc', [0; 10; 20; 30], 'kcoords', [1; 1; 2; 2]));
dl.ProbeFile = layProbe;
L = dl.channelLayout();
check(L.hasProbe && isequaln(L.shank, [2 1 2 1 NaN]) && isequaln(L.y, [20 10 30 0 NaN]) ...
    && isequal(L.order, [2 4 3 1 5]) && isequal(L.shanks, [1 2]), ...
    'chanMap values are hardware numbers: by shank, top down, the channel off the probe last');
writeJsonFile(layProbe, struct('chanMap', [0; 2; 5; 7], 'xc', [0; 10; 0; 10], 'yc', zeros(4, 1)));
L = dl.channelLayout();
check(isequaln(L.shank, [1 1 1 1 NaN]) && isequal(L.order, [1 4 2 3 5]), ...
    'without kcoords every site is on shank 1; a row runs left to right');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysDataset:Failures', '%d checks failed.', nFail);
end
end


% =========================================================================
function out = mergeTouching(iv)
% Sorted half-open intervals joined where they overlap or touch (artifactIntervals' rule).
out = zeros(0, 2);
for r = 1:size(iv, 1)
    if ~isempty(out) && iv(r, 1) <= out(end, 2)
        out(end, 2) = max(out(end, 2), iv(r, 2));
    else
        out(end+1, :) = iv(r, :); %#ok<AGROW>
    end
end
end


function bytes = readBin(ffn)
fid = fopen(ffn, 'r', 'ieee-le');
bytes = fread(fid, inf, '*uint8');
fclose(fid);
end
