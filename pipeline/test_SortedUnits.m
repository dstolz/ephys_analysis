function test_SortedUnits()
%test_SortedUnits  Verification suite for reading sorted units and preparing sorts.
%   Covers readPhyUnits' .tsv tables (phy's cluster_group.tsv against
%   Kilosort4's copy of cluster_KSLabel.tsv, CRLF, quoted and blank cells),
%   its template units (whitened / bin / uV, unwhitening with the transpose
%   of whitening_mat_inv.npy, Kilosort4's scale and invert_sign), its
%   per-unit grouping against a plain reference, channelLayout (probe chanMap
%   values are .bin rows), runKilosort(DryRun=true) leaving an existing
%   run's files alone and readPhyWaveforms (the spikes' windows in the
%   sorted .bin: alignment, channels, units, reference, high-pass, a moved
%   .bin, Kilosort4's preprocessed copy). Uses phy fixtures and tiny
%   synthetic Intan recordings; no Python or Kilosort4 is needed, and of the
%   toolboxes only the Signal Processing Toolbox (the high-pass).
%
%   Usage:  test_SortedUnits
%
%   The fixtures live in a temp folder which is deleted on completion.
%
%   See also EphysDataset.readPhyUnits, EphysDataset.channelLayout,
%   EphysDataset.runKilosort, EphysDataset.readPhyWaveforms.

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

root = fullfile(tempdir, sprintf('SortedUnits_test_%s', ...
    datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's'));
warnState = warning('off', 'EphysDataset:readPhyUnits:OtherGroup');
restoreWarn = onCleanup(@() warning(warnState));

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
    function id = errorId(fn)
        id = '';
        try
            fn();
        catch ME
            id = ME.identifier;
        end
    end
    function writeText(file, txt)
        fid = fopen(file, 'w');
        fwrite(fid, txt, 'char');
        fclose(fid);
    end

fs = 30000;
tab = sprintf('\t');
crlf = sprintf('\r\n');

%% ---- 1. label and side tables ----------------------------------------------------
fprintf('\n== 1. label and side tables (.tsv) ==\n');
d1 = fullfile(root, 'phy1');
makePhyFixture(d1, fs);
U = EphysDataset.readPhyUnits(d1, IncludeNoise=true);
check(U.groupSource == "phy" && U.curated && endsWith(U.labelFile, "cluster_group.tsv") ...
    && isequal(U.group, ["good"; "mua"; "noise"]), 'phy''s cluster_group.tsv (header "group"): curated, its labels win');
d2 = fullfile(root, 'phy2');
makePhyFixture(d2, fs, PhyCurated=false);
U = EphysDataset.readPhyUnits(d2, IncludeNoise=true);
check(U.groupSource == "kilosort" && ~U.curated && endsWith(U.labelFile, "cluster_group.tsv") ...
    && isequal(U.group, ["mua"; "good"; "good"]), ...
    'Kilosort4''s copy of cluster_KSLabel.tsv (header "KSLabel") is not curation');
writeText(fullfile(d2, 'cluster_group.tsv'), ['cluster_id' tab 'group' crlf '0' tab '"good"' crlf ...
    '1' tab crlf '2' tab ' Noise ' crlf crlf]);
writeText(fullfile(d2, 'cluster_Amplitude.tsv'), ['cluster_id' tab 'Amplitude' crlf '0' tab '12.5' crlf ...
    '1' tab 'nan' crlf '2' tab crlf]);
writeText(fullfile(d2, 'cluster_ContamPct.tsv'), ['cluster_id' tab 'ContamPct' newline '2' tab '3.5' newline]);
U = EphysDataset.readPhyUnits(d2, IncludeNoise=true);
check(U.groupSource == "phy" && isequal(U.group, ["good"; "unsorted"; "noise"]), ...
    'CRLF lines, a quoted cell, a blank cell (unsorted), spaces and a blank line');
check(isequal(U.amplitude, [12.5; 2; 1]) && isequaln(U.contamPct, [NaN; NaN; 3.5]), ...
    'cluster_Amplitude.tsv, with nan / blank falling back to the median amplitudes.npy; ContamPct by id');
writeText(fullfile(d2, 'cluster_group.tsv'), ['cluster_id' tab 'group' newline '1' tab '"odd ""x"""' newline]);
U = EphysDataset.readPhyUnits(d2, IncludeNoise=true);
check(isequal(U.group, ["unsorted"; "odd ""x"""; "unsorted"]), 'a doubled quote inside a quoted cell');
writeText(fullfile(d2, 'cluster_group.tsv'), ['cluster_id' tab 'group' newline]);
U = EphysDataset.readPhyUnits(d2, IncludeNoise=true);
check(U.groupSource == "kilosort" && endsWith(U.labelFile, "cluster_KSLabel.tsv") && isequal(U.group, ["mua"; "good"; "good"]), ...
    'a header-only cluster_group.tsv falls through to cluster_KSLabel.tsv');

%% ---- 2. template units -------------------------------------------------------------
fprintf('\n== 2. template units and unwhitening ==\n');
T = zeros(3, 8, 4);                      % makePhyFixture's templates (whitened)
T(1, 3, 2) = -50; T(1, 5, 2) = 20;
T(2, 3, 4) = -80; T(2, 6, 4) = 30;
T(3, 4, 1) = -10;
U = EphysDataset.readPhyUnits(d1, IncludeNoise=true, FullTemplates=true);
check(U.templateUnits == "whitened" && isequal(U.templateFull, permute(T, [2 3 1])) ...
    && U.templateWaveform{1}(3) == -50, ...
    'no whitening_mat_inv.npy: the templates as Kilosort4 stores them, not scaled by the amplitudes');
Winv = [1 0.5 0 0; 0 1 0 0; 0.25 0 2 0; 0 0 0.5 1];   % not symmetric, exact in single
expect = @(u, f) reshape(T(u, :, :), 8, 4) * Winv.' * f;
d3 = fullfile(root, 'phy3');
makePhyFixture(d3, fs, WhiteningInv=Winv);
U = EphysDataset.readPhyUnits(d3, IncludeNoise=true, FullTemplates=true);
ok = U.templateUnits == "bin";
for u = 1:3
    ok = ok && max(abs(U.templateFull(:, :, u) - expect(u, 1)), [], 'all') < 1e-9;
end
check(ok, 'whitening_mat_inv.npy: unwhitened as WF * Winv.'' (the .bin''s units without bin_scale)');
wrong = reshape(T(1, :, :), 8, 4) * Winv;
check(max(abs(U.templateFull(:, :, 1) - wrong), [], 'all') > 1, 'and not as WF * Winv (W is not symmetric)');
p2p = max(expect(1, 1)) - min(expect(1, 1));
[~, pk] = max(p2p);
check(U.ksChannel(1) == pk && isequal(U.templateWaveform{1}, U.templateFull(:, pk, 1)), ...
    'the peak channel and waveform come from the unwhitened template');
d4 = fullfile(root, 'phy4');
makePhyFixture(d4, fs, WhiteningInv=Winv, BinScale=1 / 0.195);
U = EphysDataset.readPhyUnits(d4, IncludeNoise=true, FullTemplates=true);
check(U.templateUnits == "uV" && max(abs(U.templateFull(:, :, 2) - expect(2, 0.195)), [], 'all') < 1e-9, ...
    'bin_scale in settings.json: microvolts');
s = readJsonFile(fullfile(d4, 'settings.json'));
s.scale = 2; s.invert_sign = true;
writeJsonFile(fullfile(d4, 'settings.json'), s);
U = EphysDataset.readPhyUnits(d4, IncludeNoise=true, FullTemplates=true);
check(U.templateUnits == "uV" && max(abs(U.templateFull(:, :, 2) - expect(2, -0.195 / 2)), [], 'all') < 1e-9, ...
    'Kilosort4''s own scale and invert_sign are undone');
U = EphysDataset.readPhyUnits(d4, Templates=false);
check(U.templateUnits == "" && all(cellfun(@isempty, U.templateWaveform)), 'Templates=false: no template, no units');

%% ---- 3. grouping ---------------------------------------------------------------------
fprintf('\n== 3. per-unit grouping against a plain reference ==\n');
rng(5);
d5 = fullfile(root, 'phy5');
makePhyFixture(d5, fs);
nSp = 4000; ids = [0 3 4 9 10 11 25 40];
clu = ids(randi(numel(ids), nSp, 1)).';
smp = int64(randperm(10 * nSp, nSp)).';                    % not in time order
tpl = clu; swap = rand(nSp, 1) < 0.3; tpl(swap) = randi([0 2], nnz(swap), 1);
amp = rand(nSp, 1) * 10;
writeNPY(fullfile(d5, 'spike_times.npy'), smp);
writeNPY(fullfile(d5, 'spike_clusters.npy'), int32(clu));
writeNPY(fullfile(d5, 'spike_templates.npy'), int32(tpl));
writeNPY(fullfile(d5, 'amplitudes.npy'), amp);
Tr = randn(41, 8, 4);
writeNPY(fullfile(d5, 'templates.npy'), single(Tr));
Tr = double(single(Tr));
writeText(fullfile(d5, 'cluster_group.tsv'), ['cluster_id' tab 'group' newline '3' tab 'noise' newline ...
    '9' tab 'good' newline '25' tab 'noise' newline]);
delete(fullfile(d5, 'cluster_KSLabel.tsv'));
[U, I] = EphysDataset.readPhyUnits(d5);
kept = ids(~ismember(ids, [3 25]));
ok = isequal(U.unitId, kept(:)) && isequal(I.spikeSamples, smp) && isequal(I.spikeClusters, clu);
refIdx = zeros(nSp, 1);
for k = 1:numel(kept)
    sel = clu == kept(k);
    refIdx(sel) = k;
    s = sort(smp(sel));
    t = mode(tpl(sel)) + 1;
    if t > size(Tr, 1); t = min(kept(k) + 1, size(Tr, 1)); end
    w = reshape(Tr(t, :, :), 8, 4);
    [~, pk] = max(max(w) - min(w));
    ok = ok && isequal(U.samples{k}, s) && isequal(U.times{k}, double(s) / fs) && U.nSpikes(k) == nnz(sel) ...
        && U.amplitude(k) == median(amp(sel)) && U.ksChannel(k) == pk && isequal(U.templateWaveform{k}, w(:, pk));
end
check(ok, 'samples (sorted), times, counts, median amplitude and the mode template of each unit');
check(isequal(I.spikeUnitIdx, refIdx), 'info.spikeUnitIdx: the row of each spike''s unit, 0 when dropped (noise)');
U = EphysDataset.readPhyUnits(d5, Groups="good");
check(isequal(U.unitId, 9) && isequal(U.samples{1}, sort(smp(clu == 9))), 'Groups keeps one unit''s spikes');

%% ---- 4. channelLayout ----------------------------------------------------------------
fprintf('\n== 4. channelLayout: chanMap values are .bin rows ==\n');
spb = 128;
lay = fullfile(root, 'layout'); mkdir(lay);
writeSyntheticRHD(fullfile(lay, 'lay.rhd'), uint16(randi([0 65535], 5, spb)), zeros(1, spb), fs, spb, ...
    AmpNames=["c5" "c2" "c7" "c0" "c9"], AmpNative=["A-005" "A-002" "A-007" "A-000" "A-009"]);
dl = EphysDataset(lay);
layProbe = fullfile(lay, 'probe.json');
writeJsonFile(layProbe, struct('chanMap', [3; 0; 1; 2], 'xc', zeros(4, 1), 'yc', [0; 10; 20; 30], 'kcoords', [1; 1; 2; 2]));
dl.ProbeFile = layProbe;
L = dl.channelLayout();
check(isequal(dl.ChannelNumbers, [5 2 7 0 9]) && L.hasProbe && isequaln(L.shank, [1 2 2 1 NaN]) ...
    && isequaln(L.y, [10 20 30 0 NaN]) && isequal(L.order, [1 4 3 2 5]) && isequal(L.shanks, [1 2]), ...
    'channel c sits at chanMap value c - 1 whatever its hardware number; by shank, top down, off the probe last');
writeJsonFile(layProbe, struct('chanMap', [5; 7], 'xc', [0; 0], 'yc', [0; 10]));
L = dl.channelLayout();
check(~L.hasProbe && isequal(L.order, 1:5), 'a probe whose chanMap names no .bin row places no channel');

%% ---- 5. runKilosort(DryRun=true) -------------------------------------------------------
fprintf('\n== 5. runKilosort(DryRun=true) leaves an existing run alone ==\n');
rec = fullfile(root, 'rec'); mkdir(rec);
writeSyntheticRHD(fullfile(rec, 'rec.rhd'), uint16(32768 + randi([-200 200], 4, 4 * spb)), zeros(1, 4 * spb), fs, spb);
probe = fullfile(root, 'probe.json');
writeJsonFile(probe, struct('chanMap', 0:3, 'xc', zeros(1, 4), 'yc', (0:3) * 20, 'kcoords', zeros(1, 4), 'n_chan', 4));
ds = EphysDataset(rec);
ds.OutputDir = fullfile(root, 'out');
ds.ProbeFile = probe;
ds.PythonExe = "C:\no\python.exe";
res = ds.runKilosort(Launch=false);
st = readJsonFile(res.settingsPath);
check(strcmp(res.runDir, res.resultsDir) && endsWith(string(res.resultsDir), "kilosort4") && st.bin_scale == ds.Scale, ...
    'a run writes its files into the results folder; settings.json records the .bin''s scale (bin_scale)');
writeText(res.settingsPath, [fileread(res.settingsPath) newline]);            % mark the existing run's files
writeText(res.scriptPath, [fileread(res.scriptPath) '# existing run' newline]);
before = {fileread(res.settingsPath), fileread(res.scriptPath)};
dry = ds.runKilosort(DryRun=true, ExcludeChannels=2);
sd = readJsonFile(dry.settingsPath);
check(strcmp(dry.runDir, fullfile(res.resultsDir, 'dryrun')) && startsWith(string(dry.settingsPath), dry.runDir) ...
    && startsWith(string(dry.scriptPath), dry.runDir) && startsWith(string(dry.probeFile), dry.runDir) ...
    && strcmp(dry.resultsDir, res.resultsDir), ...
    'a dry run writes settings.json, run_ks4.py and the derived probe into <results>\dryrun');
check(isequal(before, {fileread(res.settingsPath), fileread(res.scriptPath)}), ...
    'the existing run''s settings.json and run_ks4.py are untouched');
check(strcmp(sd.results_dir, strrep(res.resultsDir, '\', '/')) && strcmp(sd.probe, strrep(dry.probeFile, '\', '/')) ...
    && sd.bin_scale == ds.Scale && contains(dry.command, dry.settingsPath), ...
    'its settings.json names the results folder as the real run''s would, and the derived probe');
check(strcmp(errorId(@() ds.launchSorting(dry)), 'EphysDataset:launchSorting:DryRun'), 'a dry run cannot be launched');
binX = fullfile(root, 'other.bin');
ds.toBin(BinFile=binX, Scale=7);
dryX = ds.runKilosort(DryRun=true, BinFile=binX);
check(readJsonFile(dryX.settingsPath).bin_scale == 7, 'a given .bin: bin_scale from its sidecar');
delete(fullfile(root, 'other.json'));
dryX = ds.runKilosort(DryRun=true, BinFile=binX);
check(~isfield(readJsonFile(dryX.settingsPath), 'bin_scale'), 'a given .bin without a sidecar: no bin_scale');

%% ---- 6. readPhyWaveforms -----------------------------------------------------------------
fprintf('\n== 6. spike waveforms from the sorted .bin (readPhyWaveforms) ==\n');
d6 = fullfile(root, 'phy6');
makePhyFixture(d6, fs, ChannelMap=[4 0 2], NChan=3, SettingsJson=true, BinScale=2);   % templates: nt 8
nBin = 5; nSampB = 3000; binRows = [5 1 3];
rng(7);
tB = (0:nSampB - 1) / fs;
B = round(randn(nBin, nSampB) * 20 + 500 * sin(2 * pi * 5 * tB + (1:nBin).'));     % noise + a slow drift
spk = [1 100 700 1500 2990 2995];                     % 0-based; the first and last windows leave the file
for r = 1:nBin
    B(r, spk + 1) = B(r, spk + 1) - 300 * r;          % a trough on the spike's sample
    B(r, spk + 2) = B(r, spk + 2) + 100 * r;
end
fid = fopen(fullfile(d6, 'rec.bin'), 'w', 'ieee-le'); fwrite(fid, int16(B), 'int16'); fclose(fid);
writeParams = @(datPath, extra) writeText(fullfile(d6, 'params.py'), sprintf( ...
    ['dat_path = %s\nn_channels_dat = %d\noffset = 0\nsample_rate = %g\ndtype = ''int16''\n' ...
     'hp_filtered = %s\n'], datPath, nBin, fs, extra));
writeParams(sprintf('[''%s'']', strrep(fullfile(d6, 'rec.bin'), '\', '/')), 'False');
S6 = readJsonFile(fullfile(d6, 'settings.json'));
S6.do_CAR = false;
writeJsonFile(fullfile(d6, 'settings.json'), S6);
    function X = cut(rows, s, nt0, nt, sc)
        X = double(B(rows, s - nt0 + (1:nt))).' / sc;
    end
[W, wi] = EphysDataset.readPhyWaveforms(d6, int64(spk), Filter=false);
ok = isequal(size(W), [8 3 4]) && wi.skipped == 2 && isequal(wi.samples, int64([100; 700; 1500; 2990])) ...
    && wi.nt0min == 2 && isequal(wi.binRows, binRows) && wi.units == "uV" && ~wi.car && isnan(wi.highpassHz);
for k = 1:4
    X = cut(binRows, double(wi.samples(k)), 2, 8, 2);
    ok = ok && max(abs(W(:, :, k) - (X - mean(X, 1))), [], 'all') < 1e-9;
end
[~, iMin] = min(W(:, 1, 1));
check(ok && iMin == wi.nt0min + 1, ['the templates'' window (nt from templates.npy, nt0min = floor(20*nt/61)) of ' ...
    'the channel_map rows, in uV (bin_scale), window means removed; windows that leave the file are skipped']);
check(isequal(wi.timeMs, (0:7) / fs * 1000) && endsWith(wi.dataFile, "rec.bin"), ...
    'the time axis is the templates'' and dat_path is read from params.py''s list');
W2 = EphysDataset.readPhyWaveforms(d6, spk, Filter=false, Channels=[3 1]);
check(isequal(W2, W(:, [3 1], :)), 'Channels picks sorted channels');
[Wa, ia] = EphysDataset.readPhyWaveforms(d6, spk, Filter=false, MaxSpikes=2);
[Wb, ib] = EphysDataset.readPhyWaveforms(d6, spk, Filter=false, MaxSpikes=2);
check(size(Wa, 3) == 2 && isequal(Wa, Wb) && isequal(ia.samples, ib.samples) && issorted(ia.samples) ...
    && all(ismember(ia.samples, wi.samples)), 'MaxSpikes: that many of the spikes that fit, the same ones each call');
S6 = rmfield(S6, 'do_CAR');
writeJsonFile(fullfile(d6, 'settings.json'), S6);
[W, wi] = EphysDataset.readPhyWaveforms(d6, spk, Filter=false);
X = cut(binRows, 700, 2, 8, 2); X = X - mean(X, 1); X = X - median(X, 2);
check(wi.car && max(abs(W(:, :, 2) - X), [], 'all') < 1e-9, ...
    'no do_CAR in settings.json: Kilosort4''s default, the median across the sorted channels is subtracted');
S6.do_CAR = false; S6.nt = 61;
writeJsonFile(fullfile(d6, 'settings.json'), S6);
[W, wi] = EphysDataset.readPhyWaveforms(d6, [700 1500]);
[z, p, k0] = butter(3, 300 / (fs / 2), 'high');
[sos, g] = zp2sos(z, p, k0);
F = filtfilt(sos, g, double(B(binRows, :)).' / 2);        % the whole trace filtered, as Kilosort4 does
ok = isequal(size(W), [61 3 2]) && wi.nt0min == 20 && wi.highpassHz == 300;
for k = 1:2
    ref = F(double(wi.samples(k)) - 20 + (1:61), :);
    ok = ok && max(abs(W(:, :, k) - ref), [], 'all') < 0.01 * max(abs(ref), [], 'all');
end
check(ok, 'the high-pass over the padded window matches filtering the whole trace (within 1%); nt from settings.json');
writeParams('''C:/nowhere/at/all/rec.bin''', 'False');
[~, wi] = EphysDataset.readPhyWaveforms(d6, spk, Filter=false);
check(strcmp(wi.dataFile, fullfile(d6, 'rec.bin')), 'a dat_path that is not there: the file of that name in the results folder');
writeParams('''C:/nowhere/at/all/gone.bin''', 'False');
check(strcmp(errorId(@() EphysDataset.readPhyWaveforms(d6, spk)), 'EphysDataset:readPhyWaveforms:NoDataFile'), ...
    'no such file anywhere: NoDataFile');
check(strcmp(errorId(@() EphysDataset.readPhyWaveforms(d6, spk, DataFile=fullfile(d6, 'rec.bin'), Channels=4)), ...
    'EphysDataset:readPhyWaveforms:BadChannels'), 'a channel that was not sorted: BadChannels');
check(strcmp(errorId(@() EphysDataset.readPhyWaveforms(root, spk)), 'EphysDataset:readPhyWaveforms:NoParams'), ...
    'no params.py: NoParams');
% Kilosort4's preprocessed copy: its whitened data x 200, unwhitened as the templates are.
Winv6 = [1 0.5 0; 0 1 0; 0.25 0 2];
writeNPY(fullfile(d6, 'whitening_mat_inv.npy'), single(Winv6));
Bw = round(randn(nBin, nSampB) * 300);
fid = fopen(fullfile(d6, 'temp_wh.dat'), 'w', 'ieee-le'); fwrite(fid, int16(Bw), 'int16'); fclose(fid);
writeParams('''temp_wh.dat''', 'True');
S6 = rmfield(S6, 'nt');
writeJsonFile(fullfile(d6, 'settings.json'), S6);
[W, wi] = EphysDataset.readPhyWaveforms(d6, spk);
X = double(Bw(binRows, 1500 - 2 + (1:8))).' / 200 * Winv6.' / 2;
check(wi.units == "uV" && ~wi.car && isnan(wi.highpassHz) && max(abs(W(:, :, 3) - X), [], 'all') < 1e-9, ...
    'hp_filtered (temp_wh.dat): used as it is, /200 and unwhitened with whitening_mat_inv.npy into uV');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_SortedUnits:Failures', '%d checks failed.', nFail);
end
end
