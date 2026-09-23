function test_DeriveSignals()
%test_DeriveSignals  Derived signals (EphysDataset.deriveSignals) and their options.
%   Builds universal-binary recordings (recording.json + float32 .bin in
%   microvolts) on a two-shank synthetic probe, plus two makeSyntheticRecording
%   datasets, then checks:
%     1. EphysPipelineConfig.signalOptions maps the bad list and the
%        "interpolate" exclusions (recording channels) to columns of the kept
%        data; a channel that is not kept drops out
%     2. badChannels are columns: checked before the read (BadChannels
%        error), never widening the output; a bad column becomes the
%        inverse-distance mean of the nearest good sites on its own shank and
%        every other column is untouched; the channel remap (in place for a
%        permutation) equals plain indexing
%     3. without a usable probe layout: a BadChannelGeometry warning and the
%        fillmissing makima fallback; the probeFile option (the pipeline's
%        default probe) gives the geometry instead; automatic detection
%     4. MUA / SPIKE filtered in double (filterContinuous): finite for low
%        bands, no low-frequency leak, the interior as with second-order
%        sections, and equal (as LFP) to whole-matrix references, also in
%        the 8-column blocks of a 64-channel recording
%     5. non-integer sample rates resample; info.<type>.Fs and importOptions
%        report the rate produced; info.<type>.nSamples, no time vectors
%     6. digital-line naming and polarity default to the dataset's
%        TrialConfig, also through ChronuxDataset; explicit options win;
%        intan2matlab's ProbeFile
%   Needs the Signal Processing Toolbox (and zscore for automatic detection).
%
%   Usage:  test_DeriveSignals

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

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

if ~license('test', 'Signal_Toolbox')
    fprintf('  (skipped: no Signal Processing Toolbox)\n');
    return
end

root = fullfile(tempdir, sprintf('DeriveSignals_test_%s', char(datetime('now', 'Format', 'yyyyMMdd_HHmmssSSS'))));
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's'));

% --- fixture: 16 channels on two shanks of 8 sites (25 um pitch, 200 um apart) ---
Fs = 30000;
nSamp = 3 * Fs;
nChan = 16;
probe = makeSyntheticProbe(nChan);
probeFile = fullfile(root, 'probe16.json');
writeJsonFile(probeFile, probe);
t = (0:nSamp-1).' / Fs;
common = 200 * sin(2*pi*7*t) + 30 * sin(2*pi*60*t + 1) + 20 * sin(2*pi*1200*t);
perUm  = 1.5 * sin(2*pi*11*t + 0.5) + 0.2 * sin(2*pi*2200*t + 2);
perShank = 80 * sin(2*pi*3*t + 2) + 10 * sin(2*pi*800*t);
Xclean = common + perUm * probe.yc + perShank * probe.kcoords;   % linear in depth on each shank
rng(3);
Xdirty = Xclean;
Xdirty(:, 12) = 20000 * randn(nSamp, 1);                        % broken site: channel 12 (shank 2, y = 75 um)
cleanDir = writeRecording(root, "clean", Xclean, Fs);
dirtyDir = writeRecording(root, "dirty", Xdirty, Fs);
dsC = EphysDataset(cleanDir, ProbeFile=probeFile);
dsD = EphysDataset(dirtyDir, ProbeFile=probeFile);
two = ["LFP" "SPIKE"];

fprintf('\n== 1. signalOptions: bad channels are recording channels ==\n');
G = EphysPipelineConfig.defaults("Signals");
G.KeepChannels = "9-16";
G.ExcludeHandling = "interpolate";
so = EphysPipelineConfig.signalOptions(G, ExcludeChannels=12);
check(isequal(so.keepAmpChannels, 9:16) && isequal(so.badChannels, 4), ...
    '"interpolate": excluded channel 12 of the kept 9-16 is column 4');
so = EphysPipelineConfig.signalOptions(G, ExcludeChannels=3);
check(~isfield(so, 'badChannels'), 'an excluded channel that is not kept is left out (no column to overwrite)');
G.BadMode = "manual"; G.BadList = "12";
so = EphysPipelineConfig.signalOptions(G);
check(isequal(so.badChannels, 4), 'the manual bad list is recording channels: 12 -> column 4');
G.BadList = "12, 3";
so = EphysPipelineConfig.signalOptions(G, ExcludeChannels=16);
check(isequal(so.badChannels, [4 8]), 'manual list and exclusions are unioned as columns; channel 3 is not kept');
G.KeepChannels = "9-16, 12";
so = EphysPipelineConfig.signalOptions(G);
check(isequal(so.badChannels, [4 9]), 'a channel kept twice is bad in both of its columns');
G.KeepChannels = "";
so = EphysPipelineConfig.signalOptions(G);
check(isequal(so.badChannels, [3 12]), 'without a keep list the columns are the channels');
G.KeepChannels = "1-8"; G.BadList = "12";
so = EphysPipelineConfig.signalOptions(G);
check(~isfield(so, 'badChannels'), 'a bad list with no kept channel sets no bad channels');

fprintf('\n== 2. badChannels are columns, interpolated from the probe ==\n');
msgs = strings(0, 1);
    function logProgress(~, ~, m)
        msgs(end+1, 1) = string(m);
    end
errId = '';
try
    dsD.deriveSignals(dataTypeOut="LFP", keepAmpChannels=9:16, badChannels=12, ProgressFcn=@logProgress);
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'EphysDataset:deriveSignals:BadChannels') && ~any(startsWith(msgs, "Reading")), ...
    'a bad column beyond the kept columns is an error, raised before the read (no widening)');
ids = strings(1, 0);
for b = {2.5, 0, [-1 2]}
    try
        dsD.deriveSignals(dataTypeOut="LFP", badChannels=b{1});
        ids(end+1) = ""; %#ok<AGROW>
    catch ME
        ids(end+1) = string(ME.identifier); %#ok<AGROW>
    end
end
check(all(ids == "EphysDataset:deriveSignals:BadChannels"), 'non-integer, zero and mixed-sign badChannels are refused');
check(strcmp(errorId(@() dsD.deriveSignals(dataTypeOut="LFP", keepAmpChannels=[3 4], badChannels=[1 2])), ...
    'EphysDataset:deriveSignals:BadChannels'), 'badChannels covering every column are refused');

Y0 = dsD.deriveSignals(dataTypeOut=two, keepAmpChannels=9:16);
Yc = dsC.deriveSignals(dataTypeOut=two, keepAmpChannels=9:16);
msgs = strings(0, 1);
[Y1, ~, I1] = dsD.deriveSignals(dataTypeOut=two, keepAmpChannels=9:16, badChannels=4, ProgressFcn=@logProgress);
check(isequal(size(Y1.LFP), size(Y0.LFP)) && size(Y1.LFP, 2) == 8 && size(Y1.SPIKE, 2) == 8 ...
    && numel(I1.labels) == 8 && strcmp(I1.labels{4}, 'ch12'), 'the output keeps the 8 kept columns and labels');
others = [1:3 5:8];
check(isequal(Y1.LFP(:, others), Y0.LFP(:, others)) && isequal(Y1.SPIKE(:, others), Y0.SPIKE(:, others)), ...
    'every other column is untouched');
relL = max(abs(Y1.LFP(:, 4) - Yc.LFP(:, 4))) / max(abs(Yc.LFP(:, 4)));
relS = max(abs(Y1.SPIKE(:, 4) - Yc.SPIKE(:, 4))) / max(abs(Yc.SPIKE(:, 4)));
check(relL < 1e-4 && relS < 1e-4, sprintf(['the broken site is rebuilt from its shank neighbours ' ...
    '(max error %.1g of the LFP peak, %.1g of the SPIKE peak)'], relL, relS));
B1 = I1.badChannels;
d1 = hypot(8, 25); d2 = 50;
w1 = (1/d1) / (2/d1 + 2/d2);
check(isequal(B1.columns, 4) && isequal(B1.channels, 12) && isequal(B1.method, "geometry") ...
    && isequal(find(B1.weights).', [2 3 5 6]) && abs(sum(B1.weights) - 1) < 1e-12 ...
    && abs(B1.weights(3) - w1) < 1e-12 && abs(B1.weights(2) - (1/d2) / (2/d1 + 2/d2)) < 1e-12, ...
    'info.badChannels: the 4 nearest sites (26 and 50 um), weights 1/distance summing to 1');
check(isequal(I1.importOptions.badChannels, 4) && any(msgs == "Interpolating bad channels (probe geometry)"), ...
    'importOptions.badChannels and the progress message');
[~, ~, I2] = dsD.deriveSignals(dataTypeOut="LFP", badChannels=[8 9]);
W2 = I2.badChannels.weights;
check(isequal(find(W2(:, 1)).', 4:7) && isequal(find(W2(:, 2)).', 10:13) && all(I2.badChannels.method == "geometry"), ...
    'the two shank-edge channels 8 | 9 each take only sites of their own shank');

% channel remap: a permutation (applied in place) and a subset with repeats
Yb = dsD.deriveSignals(dataTypeOut=two, badChannels=12);
perm = [5 1 2 3 4 16:-1:6];
[Yr, ~, Ir] = dsD.deriveSignals(dataTypeOut=two, badChannels=12, channelRemap=perm);
check(isequal(Yr.LFP, Yb.LFP(:, perm)) && isequal(Yr.SPIKE, Yb.SPIKE(:, perm)) ...
    && isequal(string(Ir.labels).', "ch" + perm), 'a permutation remap equals plain indexing (labels too)');
Yr2 = dsD.deriveSignals(dataTypeOut=two, badChannels=12, channelRemap=[3 3 1]);
check(isequal(Yr2.LFP, Yb.LFP(:, [3 3 1])) && isequal(Yr2.SPIKE, Yb.SPIKE(:, [3 3 1])), ...
    'a remap with repeats and omissions equals plain indexing');

% the pipeline path: config -> signalOptions -> deriveSignals
G = EphysPipelineConfig.defaults("Signals");
G.KeepChannels = "9-16"; G.ExcludeHandling = "interpolate";
args = namedargs2cell(EphysPipelineConfig.signalOptions(G, ExcludeChannels=12));
[Yp, ~, Ip] = dsD.deriveSignals(args{:});
check(size(Yp.LFP, 2) == 8 && isequal(Ip.badChannels.channels, 12) && isequal(Yp.LFP, Y1.LFP), ...
    'config KeepChannels 9-16 + interpolated exclusion 12 rebuilds column 4 only');

fprintf('\n== 3. fallback to neighbouring columns; automatic detection ==\n');
dsN = EphysDataset(dirtyDir);   % no probe
Yn0 = dsN.deriveSignals(dataTypeOut="LFP");
lastwarn('');
ws = warning('off', 'EphysDataset:deriveSignals:BadChannelGeometry');
[Yn, ~, In] = dsN.deriveSignals(dataTypeOut="LFP", badChannels=12);
warning(ws);
[~, wid] = lastwarn();
ref = Yn0.LFP;
ref(:, 12) = NaN;
ref = fillmissing(ref, 'makima', 2);
check(strcmp(wid, 'EphysDataset:deriveSignals:BadChannelGeometry') && isequal(In.badChannels.method, "columns") ...
    && ~any(In.badChannels.weights) && isequal(Yn.LFP, ref), ...
    'no probe: a warning and fillmissing makima across the columns');
[Yg, ~, Ig] = dsN.deriveSignals(dataTypeOut="LFP", badChannels=12, probeFile=probeFile);
Yg0 = dsD.deriveSignals(dataTypeOut="LFP", badChannels=12);
check(isequal(Ig.badChannels.method, "geometry") && isequal(Yg.LFP, Yg0.LFP) && Ig.importOptions.probeFile == string(probeFile), ...
    'probeFile places the channels of a dataset without a probe (the pipeline''s default probe)');
probe12 = fullfile(root, 'probe12.json');
makeSyntheticProbe(12, File=probe12);                       % channels 13-16 are not on this probe
dsP = EphysDataset(dirtyDir, ProbeFile=probe12);
lastwarn('');
ws = warning('off', 'EphysDataset:deriveSignals:BadChannelGeometry');
[Ym, ~, Im] = dsP.deriveSignals(dataTypeOut="LFP", badChannels=[3 14]);
warning(ws);
[~, wid] = lastwarn();
ref = Yn0.LFP;
ref(:, [3 14]) = NaN;
ref = fillmissing(ref, 'makima', 2);
check(strcmp(wid, 'EphysDataset:deriveSignals:BadChannelGeometry') && isequal(Im.badChannels.method, ["geometry" "columns"]) ...
    && isequal(Ym.LFP(:, 14), ref(:, 14)) && ~isequal(Ym.LFP(:, 3), ref(:, 3)), ...
    'a channel off the probe falls back to the columns, the other still uses the geometry');
[~, ~, Io2] = dsP.deriveSignals(dataTypeOut="LFP", badChannels=[3 14], probeFile=probeFile);
check(isequal(Io2.badChannels.method, ["geometry" "geometry"]), 'probeFile wins over the dataset''s own probe');
if exist('zscore', 'file')
    [Ya, ~, Ia] = dsD.deriveSignals(dataTypeOut="LFP", badChannels=-3);
    Yca = dsC.deriveSignals(dataTypeOut="LFP");
    relA = max(abs(Ya.LFP(:, 12) - Yca.LFP(:, 12))) / max(abs(Yca.LFP(:, 12)));
    check(isequal(Ia.importOptions.badChannels, 12) && isequal(Ia.badChannels.method, "geometry") && relA < 1e-4, ...
        'automatic detection flags the broken channel, which is then rebuilt from the probe');
else
    fprintf('  (automatic detection skipped: no zscore)\n');
end

fprintf('\n== 4. MUA / SPIKE filters in double ==\n');
t4 = (0:4*Fs-1).' / Fs;
theta = 500 * sin(2*pi*8*t4);
rng(5);
thetaDir = writeRecording(root, "theta", [theta, theta + 20 * randn(numel(t4), 1)], Fs);
dsT = EphysDataset(thetaDir);
[Yt, ~, It] = dsT.deriveSignals(dataTypeOut=["MUA" "SPIKE"], SPIKE_bpLoHi=[150 5000], MUA_bpLoHi=[150 5000]);
inner = round(0.5*Fs):round(3.5*Fs);
leak = max(abs(double(Yt.SPIKE(inner, 1))));
check(leak < 1e-3, sprintf('SPIKE [150 5000] Hz: a 500 uV theta leaks %.2g uV (the single-precision filter: 0.4-2 uV)', leak));
Yl = dsT.deriveSignals(dataTypeOut=["MUA" "SPIKE"], SPIKE_bpLoHi=[100 3000], MUA_bpLoHi=[100 3000]);
check(all(isfinite(Yl.SPIKE), 'all') && all(isfinite(Yl.MUA), 'all') && any(Yl.SPIKE(:, 2)), ...
    'SPIKE / MUA [100 3000] Hz stay finite (single precision [b,a] gave NaN)');
X = dsT.readData(Precision="single").amplifier;
[Yd, ~, Id] = dsT.deriveSignals(dataTypeOut=["LFP" "MUA" "SPIKE"]);
band = @(x, fs) dsT.filterContinuous(x, 'Type', "bandpass", 'Cutoff', [300 5000], 'Order', 4, 'Fs', fs);
check(isequal(Yd.SPIKE, band(X, Fs)) && isequal(Yd.MUA, single(movmean(resample(abs(band(double(X), Fs)), 1, 15), 2))) ...
    && isequal(Yd.LFP, resample(X, 1, 30)), ...
    'SPIKE / MUA / LFP channel by channel equal the whole-matrix references (filterContinuous in double)');
fS = sosOf(4, [300 5000] / (Fs/2));
refSOS = filtfilt(fS.sos, fS.g, double(X));
dev = max(abs(double(Yd.SPIKE(inner, :)) - refSOS(inner, :)), [], 'all');
check(dev < 1e-3, sprintf('SPIKE interior matches double second-order sections within %.2g uV', dev));
Yd2 = dsT.deriveSignals(dataTypeOut="SPIKE", SPIKE_Fs=20000);
check(isequal(Yd2.SPIKE, single(band(resample(double(X), 2, 3), 20000))), ...
    'SPIKE_Fs = 20000: resampled then filtered in double');
check(It.SPIKE.Fs == Fs && Id.MUA.Fs == 2000 && Id.LFP.Fs == 1000, 'SPIKE_Fs = Inf keeps the recording rate');
rng(9);
wideDir = writeRecording(root, "wide", 50 * randn(Fs, 64), Fs);   % 64 channels: blocks of 8
dsW = EphysDataset(wideDir);
XW = dsW.readData(Precision="single").amplifier;
YW = dsW.deriveSignals(dataTypeOut=["LFP" "MUA" "SPIKE"]);
check(isequal(YW.SPIKE, band(XW, Fs)) && isequal(YW.MUA, single(movmean(resample(abs(band(double(XW), Fs)), 1, 15), 2))) ...
    && isequal(YW.LFP, resample(XW, 1, 30)), '64 channels, 8-column blocks: the same as the whole-matrix references');

fprintf('\n== 5. non-integer sample rates; nSamples ==\n');
fsT = 24414.0625;
nT = 48828;
tT = (0:nT-1).' / fsT;
tdtDir = writeRecording(root, "tdt", [100 * sin(2*pi*7*tT), 50 * cos(2*pi*13*tT), 20 * randn(nT, 1)], fsT);
dsR = EphysDataset(tdtDir);
[Yq, ~, Iq] = dsR.deriveSignals(dataTypeOut=["LFP" "MUA" "SPIKE"], SPIKE_Fs=20000);
check(Iq.LFP.Fs == 1000 && Iq.MUA.Fs == 2000 && Iq.SPIKE.Fs == 20000 && Iq.origFs == fsT ...
    && size(Yq.LFP, 1) == ceil(nT * 128 / 3125) && size(Yq.MUA, 1) == ceil(nT * 256 / 3125) ...
    && size(Yq.SPIKE, 1) == ceil(nT * 512 / 625), '24414.0625 Hz -> 1000 / 2000 / 20000 Hz exactly (128/3125, ...)');
check(Iq.importOptions.LFP_Fs == 1000 && Iq.importOptions.SPIKE_Fs == 20000 ...
    && all(isfinite(Yq.LFP), 'all') && all(isfinite(Yq.MUA), 'all') && all(isfinite(Yq.SPIKE), 'all'), ...
    'importOptions hold the rates produced; every sample finite');
k = (200:size(Yq.LFP, 1) - 200).';
errLFP = max(abs(double(Yq.LFP(k, 1)) - 100 * sin(2*pi*7*(k-1)/1000)));
check(errLFP < 0.5, sprintf('LFP row k is at (k-1)/Fs (7 Hz sine within %.2g uV)', errLFP));
check(Iq.LFP.nSamples == size(Yq.LFP, 1) && Iq.MUA.nSamples == size(Yq.MUA, 1) ...
    && Iq.SPIKE.nSamples == size(Yq.SPIKE, 1) && ~isfield(Iq.LFP, 'time') && ~isfield(Iq.MUA, 'time') ...
    && ~isfield(Iq.SPIKE, 'time'), 'info.<type>.nSamples replaces the time vectors');
odd = writeRecording(root, "odd", 10 * randn(3 * 30000, 2), 30000.0012345);
dsO = EphysDataset(odd);
[Yo, ~, Io] = dsO.deriveSignals(dataTypeOut="LFP");
check(Io.LFP.Fs == dsO.Fs / 30 && Io.LFP.Fs ~= 1000 && Io.importOptions.LFP_Fs == Io.LFP.Fs ...
    && size(Yo.LFP, 1) == ceil(3 * 30000 / 30), ...
    sprintf('a ratio beyond 2^18 is approximated and the rate produced reported (%.8f Hz)', Io.LFP.Fs));
dsH = EphysDataset(writeRecording(root, "half", 10 * randn(60001, 2), 30000.5));
[Yh, ~, Ih] = dsH.deriveSignals(dataTypeOut="LFP");
check(Ih.LFP.Fs == 1000 && size(Yh.LFP, 1) == 2000, '30000.5 Hz -> 1000 Hz (2000/60001)');
check(strcmp(errorId(@() dsT.deriveSignals(dataTypeOut="LFP", LFP_Fs=1e-3)), 'EphysDataset:deriveSignals:ResampleRatio'), ...
    'a ratio no factor up to 2^18 can reach is an error');

fprintf('\n== 6. line naming and polarity from TrialConfig ==\n');
T = makeSyntheticRecording(fullfile(root, 'SYN-01_260101_120000'), Format="binary", InvertedLines="InTrial", ...
    NumChannels=4, NumTrials=4, Fs=20000, SortedOutput=false, Artifacts=false, WriteManifest=false);
truth = T.events.InTrial;
dsL = EphysDataset(T.folder);
dsL.TrialConfig.InvertedLines = "InTrial";
[~, evL, IL] = dsL.deriveSignals();
check(sameIntervals(evL.InTrial, truth) && isequal(IL.invertedLines, "InTrial") ...
    && isequal(IL.importOptions.invertedLines, "InTrial"), ...
    'TrialConfig.InvertedLines applies by default: InTrial holds the trials, written active-low');
cx = ChronuxDataset(dsL, Signal="LFP");
cx.loadSignal();
check(sameIntervals(cx.Events.InTrial, truth), 'ChronuxDataset(ds, Signal="LFP") sees the trials too');
[~, evE, IE] = dsL.deriveSignals(invertedLines=string.empty(1, 0));
check(~sameIntervals(evE.InTrial, truth) && isempty(IE.invertedLines), ...
    'an explicit invertedLines (none) wins over TrialConfig');
dsL.TrialConfig.LineNames = "InTrial=Trial";
dsL.TrialConfig.InvertedLines = "Trial";
[~, evN, IN] = dsL.deriveSignals();
check(isfield(evN, 'Trial') && ~isfield(evN, 'InTrial') && sameIntervals(evN.Trial, truth) ...
    && isequal(IN.importOptions.lineNames, "InTrial=Trial"), 'TrialConfig.LineNames names the line');
dsC.TrialConfig.LabelField = "native";
[~, ~, Inat] = dsC.deriveSignals();
[~, ~, Icus] = dsC.deriveSignals(labelField="custom");
check(strcmp(Inat.labels{1}, 'A-000') && Inat.importOptions.labelField == "native" && strcmp(Icus.labels{1}, 'ch1'), ...
    'TrialConfig.LabelField labels the channels; an explicit labelField wins');
T2 = makeSyntheticRecording(fullfile(root, 'SYN-02_260101_120000'), Format="one-file-per-signal", ...
    NumChannels=4, NumTrials=4, Fs=20000, SortedOutput=false, Artifacts=false, WriteManifest=false);
probe4 = fullfile(root, 'probe4.json');
makeSyntheticProbe(4, File=probe4);
[Yi, ~, Ii] = intan2matlab(T2.folder, dataTypeOut=["LFP" "AUX"], badChannels=2, ProbeFile=probe4, ...
    ProgressFcn=@(varargin) []);
check(isequal(Ii.badChannels.method, "geometry") && ~isfield(Ii.importOptions, 'ProbeFile'), ...
    'intan2matlab ProbeFile: the bad channel is interpolated from the probe');
check(Ii.AUX.nSamples == size(Yi.AUX, 1) && ~isfield(Ii.AUX, 'time') && Ii.LFP.nSamples == size(Yi.LFP, 1), ...
    'info.AUX.nSamples too');
dsA = EphysDataset(T2.folder);   % no probe
lastwarn('');
[~, ~, Iaux] = dsA.deriveSignals(dataTypeOut="AUX", badChannels=2);
[~, wid] = lastwarn();
check(~strcmp(wid, 'EphysDataset:deriveSignals:BadChannelGeometry') && isempty(Iaux.badChannels.columns), ...
    'AUX alone: bad channels have nothing to interpolate (no geometry warning)');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_DeriveSignals:Failures', '%d checks failed.', nFail);
end
end


function folder = writeRecording(root, name, X, Fs)
%writeRecording  A universal-binary recording: float32 microvolts, gain 1,
%   custom names ch1.., native names A-000...
folder = fullfile(root, name);
mkdir(folder);
fid = fopen(fullfile(folder, name + ".bin"), 'w', 'ieee-le');
fwrite(fid, single(X.'), 'single');
fclose(fid);
nCh = size(X, 2);
spec = struct('data_file', name + ".bin", 'dtype', "float32", 'n_chan', nCh, 'fs', Fs, ...
    'gain_to_uV', 1, 'offset', 0);
spec.channel_names = cellstr("ch" + (1:nCh));
spec.native_names = cellstr("A-" + compose("%03d", 0:nCh-1));
BinaryReader.writeDescriptor(folder, spec);
end


function f = sosOf(n, Wn)
%sosOf  A BUTTER bandpass as second-order sections, as deriveSignals designs it.
[z, p, k] = butter(n, Wn, 'bandpass');
[f.sos, f.g] = zp2sos(z, p, k);
end


function tf = sameIntervals(a, b)
tf = isequal(size(a), size(b)) && (isempty(a) || max(abs(a(:) - b(:))) < 1e-9);
end


function id = errorId(fcn)
id = '';
try
    fcn();
catch ME
    id = ME.identifier;
end
end
