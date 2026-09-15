function test_ChronuxDataset()
%test_ChronuxDataset  Verification suite for the Chronux dataset connector.
%   Checks the conversions ChronuxDataset performs -- params/taper construction,
%   channel and time selection, trial sample alignment, the point-process and
%   binned spike formats, digital-input onsets, and the Kilosort4/phy spike
%   source (with real .npy fixtures, which also exercises READNPY). Every check
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
Y(500, 1) = 7;     % the sample at t = 0.500 s under the event convention
Y(501, 1) = 9;     % the sample at t = 0.500 s under the continuous convention
Y(:, 2)   = 1:n;
cy = ChronuxDataset(Y, Fs=Fs);

D = cy.trials(0.5, [0 0], Channels=1);                       % OnsetRule "event"
check(isequal(size(D), [1 1]) && D == 7, ...
    'OnsetRule "event" maps t to sample round(t*Fs) (the dig-in convention)');
D = cy.trials(0.5, [0 0], Channels=1, OnsetRule="sample");
check(D == 9, 'OnsetRule "sample" maps t to sample round(t*Fs)+1');

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
check(di.nTrials == 3 && isequal(di.onsetSamples, [500 1000 1500]), ...
    'dig-in onsets map back to their own samples at the LFP rate');
check(isequal(D(:, 1).', 400:600), 'the epoch holds the recording samples around the onset');

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
check(isequal(ki.labels, ["unit0" "unit1"]), 'unit names stay distinct from group labels');

[sp, ~, ~, ki] = ck.spikes(Source="kilosort", ResultsDir=ksDir, TimeRange=[0 2], Groups="good");
check(numel(sp) == 1 && isequal(ki.unitIds, 0), 'Groups keeps only the matching clusters');
[sp, ~, ~, ki] = ck.spikes(Source="kilosort", ResultsDir=ksDir, TimeRange=[0 2], Units=1);
check(numel(sp) == 1 && isequal(ki.unitIds, 1) && numel(sp(1).times) == 2, ...
    'Units selects clusters by id');
check(threw(@() ck.spikes(Source="kilosort", ResultsDir=ksDir, TimeRange=[0 2], Units=7)), ...
    'an unknown unit id errors');
check(threw(@() ck.spikes(Source="kilosort", ResultsDir=root, TimeRange=[0 2])), ...
    'a folder without Kilosort output errors');

%% =====================================================================
fprintf('\n== 9. guard rails ==\n');

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


function writeNPY(ffn, data, descr)
%writeNPY  Minimal little-endian .npy writer for a 1-D array (test fixture).
%   Mirrors what NumPy (and therefore Kilosort4) writes: the magic string,
%   version 1.0, a padded header dict, then C-order data.
switch descr
    case '<i8', prec = 'int64';
    case '<i4', prec = 'int32';
    case '<f8', prec = 'double';
    case '<f4', prec = 'single';
    otherwise,  error('writeNPY:dtype', 'Unsupported test dtype %s', descr);
end
h = sprintf('{''descr'': ''%s'', ''fortran_order'': False, ''shape'': (%d,), }', ...
    descr, numel(data));
total = 10 + numel(h) + 1;                  % magic(6) + version(2) + len(2) + h + \n
pad = mod(64 - mod(total, 64), 64);
h = [h repmat(' ', 1, pad) newline];

fid = fopen(ffn, 'w', 'ieee-le');
assert(fid >= 0, 'cannot open %s', ffn);
fwrite(fid, uint8([147 78 85 77 80 89]), 'uint8');   % \x93NUMPY
fwrite(fid, uint8([1 0]), 'uint8');                  % version 1.0
fwrite(fid, uint16(numel(h)), 'uint16');
fwrite(fid, h, 'char');
fwrite(fid, data, prec);
fclose(fid);
end
