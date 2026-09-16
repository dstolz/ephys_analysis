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

rng(42);

% ---- Build a dataset folder with two chronological files ----------------
dsFolder = fullfile(root, 'subjA_day1');
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
check(P.NumDatasets == 2, 'discover finds exactly 2 dataset folders (decoy ignored)');
T = P.gatherMetadata();
check(height(T) == 2 && all(T.NumChannels == numAmp), 'gatherMetadata table');

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
spkFolder = fullfile(root, 'split_spikes');
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
cfgN = EphysDataset.normalizeArtifactConfig(struct('Threshold', 5));
check(cfgN.Filter == false && cfgN.FilterType == "highpass" && cfgN.FilterCutoff == 300 ...
    && cfgN.FilterOrder == 4 && cfgN.Threshold == 5, 'normalizeArtifactConfig fills the filter fields');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysDataset:Failures', '%d checks failed.', nFail);
end
end


% =========================================================================
function writeSyntheticRHD(ffn, ampRaw, digRaw, Fs, spb)
%writeSyntheticRHD  Write a minimal valid v2.0 RHD2000 file.
%   ampRaw [numAmp x nSamples] uint16 raw codes; digRaw [1 x nSamples] (bit 0).
%   numAmp amplifier channels, 1 dig-in line, no aux/adc/supply/temp/dig-out.
%   nSamples must be a multiple of spb.

numAmp = size(ampRaw,1);
nSamples = size(ampRaw,2);
nBlocks = nSamples / spb;
assert(mod(nSamples, spb) == 0, 'nSamples must be a multiple of spb');

fid = fopen(ffn, 'w', 'ieee-le');
assert(fid >= 0, 'cannot open %s', ffn);

% --- Header ---
fwrite(fid, hex2dec('c6912702'), 'uint32');   % magic
fwrite(fid, 2, 'int16');                       % main version (>1 => 128 spb, int32 ts)
fwrite(fid, 0, 'int16');                       % secondary version
fwrite(fid, Fs, 'single');                     % sample_rate
fwrite(fid, 1, 'int16');                        % dsp_enabled
fwrite(fid, [1 1 7500], 'single');              % actual dsp cutoff, lower, upper bw
fwrite(fid, [1 1 7500], 'single');              % desired dsp cutoff, lower, upper bw
fwrite(fid, 0, 'int16');                        % notch_filter_mode
fwrite(fid, [1000 1000], 'single');             % desired/actual impedance test freq
writeQString(fid, '');                          % note1
writeQString(fid, '');                          % note2
writeQString(fid, '');                          % note3
fwrite(fid, 0, 'int16');                        % num_temp_sensor_channels (v1.1+/v>1)
fwrite(fid, 0, 'int16');                        % board_mode (v1.3+/v>1)
writeQString(fid, '');                          % reference_channel (v>1)

% One signal group holding numAmp amplifier channels + 1 dig-in
fwrite(fid, 1, 'int16');                        % number_of_signal_groups
writeQString(fid, 'PortA');                     % group name
writeQString(fid, 'A');                         % group prefix
fwrite(fid, 1, 'int16');                        % group enabled
fwrite(fid, numAmp + 1, 'int16');               % group num channels
fwrite(fid, numAmp, 'int16');                   % group num amp channels

for c = 1:numAmp
    writeChannel(fid, sprintf('A-%03d', c-1), sprintf('amp%d', c-1), c-1, 0); % signal_type 0
end
% dig-in line, native_order 0
writeChannel(fid, 'DIN-00', 'din0', 0, 4);      % signal_type 4

% --- Data blocks (channel-major amplifier per block, matching the reader) ---
for blk = 1:nBlocks
    cols = (blk-1)*spb + (1:spb);
    fwrite(fid, cols - 1, 'int32');             % timestamps (int32 for v>1)
    % amplifier: fread reads [spb, numAmp] column-major => write channel-major
    ampBlock = ampRaw(:, cols).';               % [spb x numAmp]
    fwrite(fid, ampBlock, 'uint16');            % column-major => ch1 spb samples, ch2...
    % dig-in raw uint16 (bit 0 carries the line)
    fwrite(fid, digRaw(cols), 'uint16');
end

fclose(fid);
end


function writeChannel(fid, nativeName, customName, nativeOrder, signalType)
writeQString(fid, nativeName);
writeQString(fid, customName);
fwrite(fid, nativeOrder, 'int16');   % native_order
fwrite(fid, 0, 'int16');             % custom_order
fwrite(fid, signalType, 'int16');    % signal_type
fwrite(fid, 1, 'int16');             % channel_enabled
fwrite(fid, 0, 'int16');             % chip_channel
fwrite(fid, 0, 'int16');             % board_stream
fwrite(fid, 0, 'int16');             % voltage_trigger_mode
fwrite(fid, 0, 'int16');             % voltage_threshold
fwrite(fid, 0, 'int16');             % digital_trigger_channel
fwrite(fid, 0, 'int16');             % digital_edge_polarity
fwrite(fid, 0, 'single');            % electrode_impedance_magnitude
fwrite(fid, 0, 'single');            % electrode_impedance_phase
end


function writeQString(fid, str)
% Qt QString: uint32 length in BYTES, then uint16 per char.
fwrite(fid, numel(str) * 2, 'uint32');
for i = 1:numel(str)
    fwrite(fid, double(str(i)), 'uint16');
end
end


function writeInfoRHD(ffn, numAmp, Fs)
%writeInfoRHD  Write a header-only v2.0 info.rhd (no data blocks) for the split
%   formats. Declares numAmp amplifier channels (native names A-000..A-00N, so
%   amp-A-00x.dat filenames line up) plus one bit-0 dig-in line; no aux/adc.

fid = fopen(ffn, 'w', 'ieee-le');
assert(fid >= 0, 'cannot open %s', ffn);

fwrite(fid, hex2dec('c6912702'), 'uint32');   % magic
fwrite(fid, 2, 'int16');                       % main version (>1)
fwrite(fid, 0, 'int16');                       % secondary version
fwrite(fid, Fs, 'single');                     % sample_rate
fwrite(fid, 1, 'int16');                        % dsp_enabled
fwrite(fid, [1 1 7500], 'single');              % actual dsp cutoff, lower, upper bw
fwrite(fid, [1 1 7500], 'single');              % desired dsp cutoff, lower, upper bw
fwrite(fid, 0, 'int16');                        % notch_filter_mode
fwrite(fid, [1000 1000], 'single');             % desired/actual impedance test freq
writeQString(fid, '');                          % note1
writeQString(fid, '');                          % note2
writeQString(fid, '');                          % note3
fwrite(fid, 0, 'int16');                        % num_temp_sensor_channels
fwrite(fid, 0, 'int16');                        % board_mode
writeQString(fid, '');                          % reference_channel (v>1)

fwrite(fid, 1, 'int16');                        % number_of_signal_groups
writeQString(fid, 'PortA');                     % group name
writeQString(fid, 'A');                         % group prefix
fwrite(fid, 1, 'int16');                        % group enabled
fwrite(fid, numAmp + 1, 'int16');               % group num channels
fwrite(fid, numAmp, 'int16');                   % group num amp channels
for c = 1:numAmp
    writeChannel(fid, sprintf('A-%03d', c-1), sprintf('amp%d', c-1), c-1, 0);
end
writeChannel(fid, 'DIN-00', 'din0', 0, 4);      % dig-in, native_order 0

fclose(fid);   % header only - no data blocks follow
end


function writeDat(ffn, data, prec)
%writeDat  Write a flat little-endian binary .dat file (split-format data file).
fid = fopen(ffn, 'w', 'ieee-le');
assert(fid >= 0, 'cannot open %s', ffn);
fwrite(fid, data, prec);
fclose(fid);
end


function bytes = readBin(ffn)
fid = fopen(ffn, 'r', 'ieee-le');
bytes = fread(fid, inf, '*uint8');
fclose(fid);
end


% =========================================================================
function X = injectSpikes(X, idx, chan, tmpl, peakPos)
%injectSpikes  Add tmpl to column chan of X, tmpl(peakPos) landing on each idx.
%   Samples of the template that fall outside X are clipped.
n = size(X, 1);
m = numel(tmpl);
for k = 1:numel(idx)
    rows = idx(k) - peakPos + (1:m).';
    ok = rows >= 1 & rows <= n;
    X(rows(ok), chan) = X(rows(ok), chan) + tmpl(ok);
end
end
