function test_ChronuxDataset()
%test_ChronuxDataset  Verification suite for the Chronux dataset connector.
%   Checks the conversions ChronuxDataset performs -- params/taper construction,
%   channel and time selection, trial sample alignment, the point-process and
%   binned spike formats, digital-input onsets, the Kilosort4/phy spike
%   source (with real .npy fixtures, which also exercises READNPY), and
%   EXTRACT_TRIALS, which follows the same onset rule. Every check
%   is on values this code computes, so neither Chronux, MATLAB toolboxes beyond
%   base MATLAB, nor real Intan recordings are needed.
%
%   Usage:  test_ChronuxDataset
%
%   The fixtures live in a temp folder which is deleted on completion.
%
%   See also CHRONUXDATASET, TEST_EPHYSDATASET.

here = fileparts(mfilename('fullpath'));
addpath(here);                          % @ChronuxDataset / @EphysDataset / readNPY
addpath(fileparts(here));               % repository root helpers

root = fullfile(tempdir, sprintf('ChronuxDS_test_%s', ...
    datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>

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

%% =====================================================================
fprintf('\n== 1. params and tapers ==\n');

p = ChronuxDataset.makeParams(1000);
check(isequal(sort(string(fieldnames(p))).', sort(["tapers","pad","Fs","fpass","err","trialave"])), ...
    'makeParams returns exactly Chronux''s six fields');
check(isequal(p.tapers, [3 5]) && p.pad == 0 && p.Fs == 1000 && ...
    isequal(p.fpass, [0 500]) && isequal(p.err, 0) && p.trialave == 0, ...
    'makeParams defaults (tapers [3 5], fpass [0 Fs/2])');

p = ChronuxDataset.makeParams(2000, Fpass=[1 100], Err=[2 0.05], TrialAve=1, Pad=1);
check(isequal(p.fpass, [1 100]) && isequal(p.err, [2 0.05]) && p.trialave == 1 && p.pad == 1, ...
    'makeParams passes fpass / err / trialave / pad through');

check(threw(@() ChronuxDataset.makeParams(1000, Fpass=[0 600])), ...
    'makeParams rejects fpass above Nyquist');
check(threw(@() ChronuxDataset.makeParams(1000, Err=[1 1.5])), ...
    'makeParams rejects a confidence level outside (0 1)');
check(threw(@() ChronuxDataset.makeParams(1000, Tapers=[3 5 1 1])), ...
    'makeParams rejects a 4-element tapers');
check(threw(@() ChronuxDataset.makeParams(1000, Tapers=[3 2.5])), ...
    'makeParams rejects a non-integer taper count');

[tap, ti] = ChronuxDataset.tapersFor(2, 1);
check(isequal(tap, [2 3]) && ti.TW == 2 && ti.K == 3, ...
    'tapersFor(2 Hz, 1 s) = [TW K] = [2 3]');
check(abs(ChronuxDataset.tapersFor(4, 0.5) * [1;0] - 2) < 1e-12, ...
    'tapersFor TW = W*T');
check(threw(@() ChronuxDataset.tapersFor(0.5, 1)), ...
    'tapersFor errors when the window is too short for one taper');

S = ChronuxDataset.toPointProcess({[0.3 0.1 0.2], []});
check(numel(S) == 2 && isequal(string(fieldnames(S)), "times"), ...
    'toPointProcess makes a 1 x N struct array with only a times field');
check(isequal(S(1).times, [0.1; 0.2; 0.3]) && isempty(S(2).times), ...
    'toPointProcess sorts into column vectors and keeps empty trains');
check(threw(@() ChronuxDataset.toPointProcess({[1 NaN]})), ...
    'toPointProcess rejects non-finite spike times');

%% =====================================================================
fprintf('\n== 2. matrix source and continuous ==\n');

Fs = 1000;
n  = 1000;
X  = single((1:n).' + [0 1000 2000]);          % [1000 x 3], known values
cx = ChronuxDataset(X, Fs=Fs, ChannelLabels=["a" "b" "c"]);
check(cx.Loaded && cx.NumSamples == n && cx.NumChannels == 3 && cx.Fs == Fs, ...
    'matrix source is loaded at construction');

[d, pp, ci] = cx.continuous();
check(isequal(size(d), [n 3]) && isa(d, 'double'), ...
    'continuous returns [nSamples x nChan] double');
check(isequal(d(:, 2), double(X(:, 2))), 'continuous copies values unchanged');
check(pp.Fs == Fs && isequal(pp.fpass, [0 Fs/2]), 'continuous params.Fs is the signal rate');
check(isequal(ci.timeRange, [0 (n-1)/Fs]), 'continuous info.timeRange uses t = (row-1)/Fs');

[d, ~, ci] = cx.continuous(Channels=["c" "a"], TimeRange=[0.010 0.020]);
check(isequal(ci.channels, [3 1]) && isequal(ci.labels, ["c" "a"]), ...
    'continuous honours channel order by label');
check(isequal(ci.sampleRange, [11 21]) && size(d, 1) == 11, ...
    'continuous TimeRange [0.010 0.020] s -> samples 11..21 inclusive');
check(d(1, 2) == 11 && d(end, 2) == 21, 'continuous returns those exact samples');

d = cx.continuous(Channels=1, Detrend="constant");
check(abs(mean(d)) < 1e-9, 'Detrend="constant" removes the mean');
d = cx.continuous(Channels=1, Detrend="linear");
check(max(abs(d)) < 1e-6, 'Detrend="linear" flattens a ramp');
check(isa(cx.continuous(Class="single"), 'single'), 'Class="single" is honoured');
check(threw(@() cx.continuous(Channels=4)), 'continuous rejects an out-of-range channel');

%% =====================================================================
fprintf('\n== 3. trials: sample alignment and trial policies ==\n');

Y = zeros(n, 2);
Y(500, 1) = 7;     % the row whose dig-in time is t = row/Fs = 0.500 s
Y(501, 1) = 9;     % the sample at t = (row-1)/Fs = 0.500 s, the continuous convention
Y(:, 2)   = 1:n;
cy = ChronuxDataset(Y, Fs=Fs);

[D, ~, ~, di] = cy.trials(0.5, [0 0], Channels=1);           % OnsetRule "event"
check(isequal(size(D), [1 1]) && D == 7 && di.eventFs == Fs, ...
    'OnsetRule "event" on a matrix source (events on its own clock) maps t to row round(t*Fs), the dig-in row');
D = cy.trials(0.5, [0 0], Channels=1, OnsetRule="sample");
check(D == 9, 'OnsetRule "sample" maps t to sample round(t*Fs)+1');
[D, ~, ~, di] = cy.trials(0.5, [0 0], Channels=1, EventFs=30000);
check(D == 9 && di.eventFs == 30000 && di.onsetSamples == 501, ...
    'EventFs: recording row 15000 at 30 kHz (continuous 0.49997 s) is the 1 kHz row nearest it, 501');
check(threw(@() cy.trials(0.5, [0 0], EventFs=-1)), 'a non-positive EventFs is refused');

[D, pd, T, di] = cy.trials([0.5 0.6], [-0.002 0.003], Channels=2);
check(isequal(size(D), [6 2]), 'trials returns [nTime x nTrials] for one channel');
check(numel(T) == 6 && abs(T(1) + 0.002) < 1e-12 && abs(T(end) - 0.003) < 1e-12, ...
    'T spans round(tPre*Fs):round(tPost*Fs) samples');
check(isequal(di.sampleOffsets, [-2 3]) && isequal(di.onsetSamples, [500 600]), ...
    'info records the sample offsets and onset rows');
check(isequal(D(:, 1).', 498:503) && isequal(D(:, 2).', 598:603), ...
    'each trial holds exactly rows base+s0 .. base+s1');
check(pd.Fs == Fs && pd.trialave == 0, 'trials params.Fs is the signal rate');
[~, pd] = cy.trials([0.5 0.6], [-0.002 0.003], Channels=2, TrialAve=1);
check(pd.trialave == 1, 'TrialAve=1 sets params.trialave for the returned data');

[D, ~, ~, di] = cy.trials([0.5 0.6], [-0.002 0.003], Channels=[1 2]);
check(isequal(size(D), [6 2 2]) && di.nChan == 2, ...
    'several channels give [nTime x nTrials x nChan]');

w = warnOff('ChronuxDataset:IncompleteTrials');
[D, ~, ~, di] = cy.trials([0.0005 0.5 0.999], [-0.01 0.01], Channels=1);
check(size(D, 2) == 1 && isequal(di.keptTrials, 2) && isequal(di.droppedIncomplete, [1 3]), ...
    'trials whose window leaves the recording are dropped and reported');
[D, ~, ~, di] = cy.trials([0.0005 0.5], [-0.01 0.01], Channels=1, Incomplete="nan");
check(size(D, 2) == 2 && any(isnan(D(:, 1))) && di.nTrials == 2, ...
    'Incomplete="nan" keeps the trial and pads the missing samples');
clear w
check(threw(@() cy.trials(0.0005, [-0.01 0.01], Channels=1, Incomplete="error")), ...
    'Incomplete="error" refuses an incomplete trial');

Z = Y;  Z(600, 1) = NaN;
cz = ChronuxDataset(Z, Fs=Fs);
w = warnOff('ChronuxDataset:NonFiniteTrials');
[D, ~, ~, di] = cz.trials([0.5 0.6], [-0.01 0.01], Channels=1);
check(size(D, 2) == 1 && isequal(di.droppedNonFinite, 2), ...
    'a trial containing NaN is dropped and reported');
clear w
[D, ~, ~, di] = cz.trials([0.5 0.6], [-0.01 0.01], Channels=1, NonFinite="keep");
check(size(D, 2) == 2 && nnz(isnan(D)) == 1, 'NonFinite="keep" returns the NaN trial');

%% =====================================================================
fprintf('\n== 4. toMat .mat source and eventOnsets ==\n');

matFile = fullfile(root, 'subjA_extract.mat');
Ylfp = single((1:2000).' * [1 2]);
Y = struct('LFP', Ylfp, 'MUA', single([]), 'SPIKE', single([]));   %#ok<NASGU>
events = struct('din0', [0.5 0.52; 1.0 1.001; 1.5 1.52]);         %#ok<NASGU>
info = struct('labels', {{'A-000'; 'A-001'}}, 'origFs', 30000, ...
    'LFP', struct('Fs', 1000, 'time', (0:1999).'/1000));          %#ok<NASGU>
save(matFile, 'Y', 'events', 'info');
clear Y events info

cm = ChronuxDataset(matFile, Signal="LFP");
check(~cm.Loaded, 'a .mat source is not read until it is needed');
[d, pm] = cm.continuous();
check(isequal(size(d), [2000 2]) && pm.Fs == 1000 && cm.Fs == 1000, ...
    'the .mat source loads Y.LFP at info.LFP.Fs');
check(isequal(cm.ChannelLabels, ["A-000" "A-001"]), 'channel labels come from info.labels');
Sx = load(matFile);
cxs = ChronuxDataset(Sx, Signal="LFP");
check(cxs.SourceType == "struct" && isequal(cxs.continuous(), cm.continuous()) ...
    && isequal(cxs.Events, cm.Events) && isequal(cxs.ChannelLabels, cm.ChannelLabels), ...
    'a toMat-shaped struct source behaves exactly like the file source');
check(threw(@() ChronuxDataset(struct('Y', 1), Signal="LFP")), 'a struct without Y and info is refused');
check(threw(@() subsrefSignal(matFile, "MUA")), ...
    'asking for a signal the .mat does not hold errors');

[on, ei] = cm.eventOnsets();
check(isequal(on, [0.5; 1.0; 1.5]) && ei.name == "din0", ...
    'eventOnsets returns the onsets of the only dig-in line');
[on, ei] = cm.eventOnsets("din0", MinDurationSec=0.01);
check(isequal(on, [0.5; 1.5]) && isequal(ei.droppedDuration, 2), ...
    'MinDurationSec drops the short pulse and reports it');
check(threw(@() cm.eventOnsets("nosuchline")), 'eventOnsets rejects an unknown line');

[D, ~, ~, di] = cm.trials(cm.eventOnsets("din0"), [-0.1 0.1], Channels=1);
check(di.nTrials == 3 && di.eventFs == 30000 && isequal(di.onsetSamples, [501 1001 1501]), ...
    'dig-in onsets (rows 15000.. at origFs 30 kHz) land on the LFP sample nearest their row (501 is t = 0.500 s)');
check(isequal(D(:, 1).', 401:601), 'the epoch holds the LFP samples around the onset');
Sr = Sx;  Sr.info.origFs = 1000;                    % LFP at the recording rate
cr = ChronuxDataset(Sr, Signal="LFP");
[~, ~, ~, dr] = cr.trials([0.5 1.0 1.5], [0 0], Channels=1);
check(dr.eventFs == 1000 && isequal(dr.onsetSamples, [500 1000 1500]), ...
    'at the recording rate a dig-in onset maps back to exactly the row that produced it');

% No bias at a derived rate: 1000 onsets on random rows of a 30 kHz
% recording each land on the 1 kHz sample nearest the row's continuous time.
rng(5);
rows = randi([3000 1500000], 1000, 1);
Sb = Sx;  Sb.Y.LFP = zeros(50001, 1, 'single');  Sb.info.labels = {'A-000'};
cb = ChronuxDataset(Sb, Signal="LFP");
[~, ~, ~, db] = cb.trials(rows / 30000, [0 0]);
err = (db.onsetSamples(:) - 1) - (rows - 1) / 30;   % in LFP samples, + = late
check(max(abs(err)) <= 0.5 + 1e-9 && abs(mean(err)) < 0.05, ...
    sprintf('derived-rate onsets land on the nearest sample (error %.3f..%.3f, mean %+.4f LFP samples)', ...
    min(err), max(err), mean(err)));

%% =====================================================================
fprintf('\n== 5. spikes: point-process struct array ==\n');

cs = ChronuxDataset(zeros(3000, 1), Fs=1000);       % a 3 s "recording"
[sp, ps, t, si] = cs.spikes(Times={[0.1 0.2 2.9], 0.15}, SpikeFs=1000);
check(numel(sp) == 2 && isequal(string(fieldnames(sp)), "times"), ...
    'spikes returns a 1 x nUnits struct array with only times');
check(isequal(sp(1).times, [0.1; 0.2; 2.9]), 'spike times are passed through unchanged');
check(ps.Fs == 1000 && isequal(ps.fpass, [0 500]), 'params.Fs is SpikeFs');
check(abs(t(1)) < 1e-12 && abs(t(end) - 3) < 1e-9 && numel(t) == 3001, ...
    't spans the recording at SpikeFs (so Chronux normalizes by the real duration)');
check(isequal(si.counts, [3 1]) && abs(si.rates(1) - 1) < 1e-12, ...
    'info counts and rates are over the analysis window');
check(si.timeRangeSource == "loaded signal duration", ...
    'the window falls back to the loaded signal duration');

[sp, ~, t, si] = cs.spikes(Times={[0.1 0.2 2.9]}, TimeRange=[0 1], SpikeFs=500);
check(isequal(sp(1).times, [0.1; 0.2]) && si.nDroppedOutsideRange == 1, ...
    'TimeRange drops spikes outside it and says how many');
check(numel(t) == 501, 'the grid follows TimeRange and SpikeFs');

[sp, ~, t, si] = cs.spikes(Times={[1.1 1.2]}, TimeRange=[1 2], ...
    TimeBase="window", SpikeFs=1000);
check(max(abs(sp(1).times - [0.1; 0.2])) < 1e-9 && abs(t(1)) < 1e-12, ...
    'TimeBase="window" shifts times and the grid to start at 0 (hybrid routines)');
check(isequal(si.timeRange, [1 2]) && isequal(si.gridRange, [0 1]), ...
    'info keeps the recording-relative window and what the grid spans');

%% =====================================================================
fprintf('\n== 6. spikeTrials: the createdatamatpt convention ==\n');

train = [0.9 1.0 1.1 1.5 2.0];
[st, ~, tt, sti] = cs.spikeTrials(1.0, [-0.1 0.1], Spikes={train});
check(numel(st) == 1 && numel(st(1).times) == 2, ...
    'the window is half-open: t > E+tPre excludes the spike on the left edge');
check(max(abs(st(1).times - [0.1; 0.2])) < 1e-9, ...
    'TimeBase="window" stamps spikes from the start of the window (createdatamatpt)');
check(abs(tt(1)) < 1e-12 && abs(tt(end) - 0.2) < 1e-9, 'T spans [0, tPost-tPre]');
check(isequal(sti.counts, 2) && abs(sti.rate - 10) < 1e-9, 'info counts and rate per trial');

st = cs.spikeTrials(1.0, [-0.1 0.1], Spikes={train}, TimeBase="onset");
check(max(abs(st(1).times - [0; 0.1])) < 1e-9, 'TimeBase="onset" stamps relative to the event');
st = cs.spikeTrials(1.0, [-0.1 0.1], Spikes={train}, TimeBase="absolute");
check(max(abs(st(1).times - [1.0; 1.1])) < 1e-9, 'TimeBase="absolute" keeps recording times');

w = warnOff('ChronuxDataset:IncompleteTrials');
[st, ~, ~, sti] = cs.spikeTrials([1.0 2.95], [-0.1 0.1], Spikes={train});
check(numel(st) == 1 && isequal(sti.droppedIncomplete, 2), ...
    'a trial window past the end of the recording is dropped');
clear w
st = cs.spikeTrials([1.0 2.95], [-0.1 0.1], Spikes={train}, Incomplete="keep");
check(numel(st) == 2, 'Incomplete="keep" returns the truncated trial');

% The sorted search picks exactly what a scan of the whole train would: on a
% 1 ms grid, with repeated spike times and spikes on the window edges.
rng(9);
trainR = [round(rand(3000, 1) * 2900) / 1000; 0.9; 1.0; 1.0; 1.1; 1.1];
onR = [1.0; round(rand(200, 1) * 2600 + 200) / 1000];
st = cs.spikeTrials(onR, [-0.1 0.1], Spikes={trainR(randperm(numel(trainR)))}, ...
    TimeBase="absolute", Incomplete="keep");
same = true;
for k = 1:numel(onR)
    ref = sort(trainR(trainR > onR(k) - 0.1 & trainR <= onR(k) + 0.1));
    same = same && isequal(st(k).times, ref);
end
check(same && nnz(trainR == 1.1) >= 2 && nnz(st(1).times == 1.1) == nnz(trainR == 1.1) ...
    && ~any(st(1).times == 0.9), ...
    'spikeTrials equals the scan t > E+tPre & t <= E+tPost (ties, spikes on the edges)');
check(threw(@() cs.spikeTrials(1.0, [-0.1 0.1], Spikes={train, train})), ...
    'spikeTrials refuses to guess which unit to epoch');

%% =====================================================================
fprintf('\n== 7. binnedSpikes ==\n');

w = warnOff('ChronuxDataset:CoarseBins');
[cnt, pb, tb, bi] = cs.binnedSpikes(Times={[0.0005 0.0015 0.0016]}, ...
    BinFs=1000, TimeRange=[0 0.003]);
clear w
check(isequal(cnt, [1; 2; 0]), 'bins are half-open [left, right) counts');
check(pb.Fs == 1000 && bi.nBins == 3 && abs(bi.binWidthSec - 1e-3) < 1e-15, ...
    'params.Fs is the bin rate');
check(abs(tb(1)) < 1e-12 && abs(tb(2) - 0.001) < 1e-12, 't holds the left edge of each bin');
check(bi.maxCount == 2 && isequal(bi.counts, 3), 'info reports the busiest bin and the totals');

[cnt, ~, ~, bi] = cs.binnedSpikes(Times={[0.5 1.5 2.5]}, BinFs=2, TimeRange=[0 2]);
check(isequal(size(cnt), [4 1]) && sum(cnt) == 2 && bi.droppedOutsideRange == 1, ...
    'spikes outside the binning window are dropped and reported');
[cnt, ~, ~, bi] = cs.binnedSpikes(Times={[0.1 0.2 0.3 0.4 0.5]}, BinFs=10);
check(sum(cnt) == 5 && bi.droppedOutsideRange == 0 && bi.nBins == 6 && cnt(end) == 1 ...
    && abs(bi.timeRange(2) - 0.6) < 1e-12, ...
    'without TimeRange every supplied spike is binned, the last one in the bin it opens');
[cnt, ~, tb, bi] = cs.binnedSpikes(Times={[-0.15 0.05], 0.3}, BinFs=10);
check(isequal(cnt, [1 0; 0 0; 1 0; 0 0; 0 0; 0 1]) && abs(tb(1) + 0.2) < 1e-12 ...
    && bi.droppedOutsideRange == 0, ...
    'negative times (e.g. "onset" trial stamps) are binned too, on the grid k/BinFs');
check(threw(@() cs.binnedSpikes(Times={zeros(0, 1)}, BinFs=10)), ...
    'no spike and no TimeRange: the window is empty');

%% =====================================================================
fprintf('\n== 8. Kilosort4 / phy spike source (real .npy fixtures) ==\n');

ksDir = fullfile(root, 'kilosort4');
mkdir(ksDir);
ksFs = 30000;
spikeSamples = int64([300; 600; 900; 1500; 30000]);
spikeClusters = int32([0; 0; 1; 1; 0]);
writeNPY(fullfile(ksDir, 'spike_times.npy'), spikeSamples, '<i8');
writeNPY(fullfile(ksDir, 'spike_clusters.npy'), spikeClusters, '<i4');
fid = fopen(fullfile(ksDir, 'params.py'), 'w');
fprintf(fid, 'dat_path = "x.bin"\nn_channels_dat = 4\ndtype = "int16"\nsample_rate = %g.\n', ksFs);
fclose(fid);
fid = fopen(fullfile(ksDir, 'cluster_group.tsv'), 'w');
fprintf(fid, 'cluster_id\tgroup\n0\tgood\n1\tmua\n');
fclose(fid);

check(isequal(readNPY(fullfile(ksDir, 'spike_times.npy')), spikeSamples), ...
    'readNPY round-trips an int64 array');

ck = ChronuxDataset();
[sp, ~, ~, ki] = ck.spikes(Source="kilosort", ResultsDir=ksDir, TimeRange=[0 2]);
check(numel(sp) == 2 && isequal(ki.unitIds, [0 1]), 'one struct element per cluster');
check(max(abs(sp(1).times - double([300; 600; 30000])/ksFs)) < 1e-12, ...
    'spike times are sample/sample_rate on the recording clock');
check(ki.sampleRate == ksFs, 'the sample rate comes from params.py');
check(isequal(ki.groupLabels, ["good" "mua"]), 'phy cluster labels are read');
check(isequal(ki.labels, ["su000" "mua001"]), 'unit labels (class + id; no dataset, so no recording) stay distinct from group labels');

[sp, ~, ~, ki] = ck.spikes(Source="kilosort", ResultsDir=ksDir, TimeRange=[0 2], Groups="good");
check(numel(sp) == 1 && isequal(ki.unitIds, 0), 'Groups keeps only the matching clusters');
[sp, ~, ~, ki] = ck.spikes(Source="kilosort", ResultsDir=ksDir, TimeRange=[0 2], Units=1);
check(numel(sp) == 1 && isequal(ki.unitIds, 1) && numel(sp(1).times) == 2, ...
    'Units selects clusters by id');
check(threw(@() ck.spikes(Source="kilosort", ResultsDir=ksDir, TimeRange=[0 2], Units=7)), ...
    'an unknown unit id errors');
emptyDir = fullfile(root, 'no_sorting_here');
mkdir(emptyDir);
check(threw(@() ck.spikes(Source="kilosort", ResultsDir=emptyDir, TimeRange=[0 2])), ...
    'a folder without Kilosort output errors');

%% =====================================================================
fprintf('\n== 9. extract_trials: FieldTrip TRL, the same onset rule ==\n');

sig = (1:1000).' * [1 -1];                            % 1 kHz, value = row (and -row)
[R, Tx, trl] = extract_trials(sig, [0.3 0.6], 1000, [-0.1 0.2]);   % a row of onsets
check(isequal(trl, [200 500 -100; 500 800 -100]), ...
    'TRL is [begsample endsample offset] for every onset (a row vector of onsets too)');
check(isequal(size(R), [301 2 2]) && isequal(R(:, 1, 1), (200:500).') && isequal(R(:, 2, 2), -(500:800).') ...
    && Tx(101) == 0 && R(101, 1, 1) == 300, ...
    'R is [nTime x nChan x nTrials]; T = 0 on the onset row');
cxx = ChronuxDataset(sig, Fs=1000);
check(isequal(cxx.trials([0.3 0.6], [-0.1 0.2], Channels=1), squeeze(R(:, 1, :))), ...
    'extract_trials cuts the rows ChronuxDataset.trials cuts');
[~, Tx, trl] = extract_trials(sig, 0.3, 1000, [0.05 0.1]);
check(isequal(trl, [350 400 50]) && abs(Tx(1) - 0.05) < 1e-12 && numel(Tx) == 51, ...
    'a window after the onset (tPre > 0): TRL and T start at tPre');
[R, ~, trl] = extract_trials(sig, 0.3, 1000, [-0.1 0.2], EventFs=30000);
check(trl(1) == 201 && R(101, 1) == 301, ...
    'EventFs: row 9000 at 30 kHz (0.29997 s) falls on 1 kHz row 301 (0.300 s)');
R = extract_trials(sig, 0.05, 1000, [-0.1 0.2]);
check(all(isnan(R(1:51, 1))) && R(52, 1) == 1, 'samples before the signal are NaN');

%% =====================================================================
fprintf('\n== 10. guard rails ==\n');

check(threw(@() ChronuxDataset(zeros(10, 2))), 'a matrix source without Fs errors');
check(threw(@() ChronuxDataset("no_such_folder_xyz")), 'a nonexistent source errors');
check(threw(@() ChronuxDataset().continuous()), 'a connector with no source errors');
check(threw(@() cx.eventOnsets()), 'a matrix source has no dig-in events');
check(islogical(ChronuxDataset.hasChronux()), 'hasChronux returns a logical');

fprintf('\n=====================================\n');
fprintf('  %d passed, %d failed\n', nPass, nFail);
fprintf('=====================================\n');
if nFail > 0
    error('test_ChronuxDataset:Failures', '%d check(s) failed.', nFail);
end
end


% =========================================================================
function tf = threw(fcn)
%threw  True when calling FCN raises an error (used for guard-rail checks).
tf = false;
try
    fcn();
catch
    tf = true;
end
end


function c = warnOff(id)
%warnOff  Silence one warning id until the returned object is cleared.
old = warning('off', id);
c = onCleanup(@() warning(old));
end


function subsrefSignal(matFile, sig)
%subsrefSignal  Load a signal the .mat may not hold (for a guard-rail check).
cx = ChronuxDataset(matFile, Signal=sig);
cx.loadSignal();
end

