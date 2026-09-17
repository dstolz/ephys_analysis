function test_FieldTripExport()
%test_FieldTripExport  Verification suite for the FieldTrip packaging.
%   Checks the shapes FieldTripExport builds from a toMat-shaped extract, a
%   readSortedUnits struct and a spikesToMat detected struct against the
%   FieldTrip datatype conventions (raw: trial{1} [nChan x N], time = (k-1)/Fs,
%   sampleinfo, hdr; spike: label/timestamp in samples; event: 1-based sample,
%   duration in samples). No FieldTrip installation is needed; when FieldTrip
%   is already on the path, ft_datatype_raw / ft_datatype_spike are run too.
%
%   Usage:  test_FieldTripExport

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

fprintf('\n== 1. raw structure from an extract ==\n');
N = 1000; nCh = 3; Fs = 1000; origFs = 30000;
X = single(reshape(1:N*nCh, N, nCh));
S = struct();
S.Y = struct('LFP', X, 'MUA', single([]), 'SPIKE', single([]));
S.info = struct('LFP', struct('Fs', Fs, 'time', (0:N-1).'/Fs), 'labels', ["a" "b" "c"], 'origFs', origFs);
S.events = struct('din0', [0.1 0.2; 0.5 0.55], 'din1', zeros(0, 2));

data = FieldTripExport.raw(S, "LFP");
check(iscell(data.trial) && isequal(size(data.trial{1}), [nCh N]) && isa(data.trial{1}, 'double') ...
    && isequal(data.trial{1}, double(X).'), 'trial{1} is [nChan x N] double = Y.LFP transposed');
check(isequal(size(data.time{1}), [1 N]) && data.time{1}(1) == 0 && abs(data.time{1}(2) - 1/Fs) < 1e-12, ...
    'time{1} = (k-1)/Fs');
check(iscellstr(data.label) && isequal(size(data.label), [nCh 1]) && strcmp(data.label{2}, 'b'), ...
    'label is an nChan x 1 cellstr');
check(data.fsample == Fs && isequal(data.sampleinfo, [1 N]), 'fsample + sampleinfo');
h = data.hdr;
check(h.Fs == Fs && h.nChans == nCh && h.nSamples == N && h.nSamplesPre == 0 && h.nTrials == 1 ...
    && h.FirstTimeStamp == 0 && h.TimeStampPerSample == origFs / Fs, 'hdr fields');
check(isequal(h.chantype, repmat({'lfp'}, nCh, 1)) && isequal(h.chanunit, repmat({'uV'}, nCh, 1)), ...
    'hdr.chantype / chanunit');
check(data.cfg.signal == "LFP", 'cfg records the exporter and signal');
dataS = FieldTripExport.raw(S, "LFP", Class="single");
check(isa(dataS.trial{1}, 'single'), 'Class="single" keeps the data single');
errId = '';
try
    FieldTripExport.raw(S, "MUA");
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'FieldTripExport:SignalMissing'), 'a signal that is not in the extract errors');
S2 = S; S2.info = rmfield(S2.info, 'labels');
d2 = FieldTripExport.raw(S2, "LFP");
check(isequal(d2.label, {'ch1'; 'ch2'; 'ch3'}), 'labels default to ch1..chN');

fprintf('\n== 2. spike structure from sorted units ==\n');
units = struct('unitId', [0; 1], 'label', ["su000_A1_260101T1200"; "mua001_A1_260101T1200"], 'group', ["good"; "mua"], ...
    'nSpikes', [3; 1], 'samples', {{int64([300; 600; 30000]); int64(900)}}, ...
    'times', {{[300; 600; 30000] / 30000; 900 / 30000}}, 'channel', [3; 1], ...
    'templateFull', [], 'fs', 30000, 'durationSec', 1, 'resultsDir', "x");
sp = FieldTripExport.spike(units);
check(isequal(sp.label, {'su000_A1_260101T1200', 'mua001_A1_260101T1200'}) && isequal(size(sp.label), [1 2]), 'spike.label is 1 x nUnits');
check(isequal(sp.timestamp{1}, [300 600 30000]) && isequal(sp.timestamp{2}, 900) ...
    && isa(sp.timestamp{1}, 'double') && isequal(size(sp.timestamp{1}), [1 3]), ...
    'timestamp{u} are 0-based samples as double rows');
check(sp.hdr.Fs == 30000 && sp.hdr.FirstTimeStamp == 0 && sp.hdr.TimeStampPerSample == 1 ...
    && sp.hdr.nSamples == 30001, 'spike hdr on the recording sample clock');
check(~isfield(sp, 'time') && ~isfield(sp, 'trial') && ~isfield(sp, 'waveform'), ...
    'no trial-defined or waveform fields');
check(~isfield(sp.hdr.orig, 'samples') && isequal(sp.hdr.orig.channel, [3; 1]), ...
    'hdr.orig keeps the unit metadata without the spike arrays');

fprintf('\n== 3. spike structure from detected spikes ==\n');
det = struct('ts', {{[0; 2; 4] / 1000, 3 / 1000}}, 'wf', [], ...
    'info', struct('fs', 1000, 'nSamples', 5000), 'channels', [1 2], ...
    'channelNames', ["amp0" "amp1"], 'detection', struct('nRejectedArtifact', [0 0]));
spd = FieldTripExport.spikeFromDetected(det);
check(isequal(spd.label, {'amp0', 'amp1'}) && isequal(spd.timestamp{1}, [0 2 4]) && isequal(spd.timestamp{2}, 3), ...
    'detected spikes: one unit per channel, timestamps = round(t*Fs)');
check(spd.hdr.Fs == 1000 && spd.hdr.nSamples == 5000, 'detected spike hdr');

fprintf('\n== 4. events ==\n');
ev = FieldTripExport.event(S.events, Fs);
check(numel(ev) == 2 && strcmp(ev(1).type, 'din0') && ev(1).sample == 100 && ev(2).sample == 500, ...
    'one event per pulse, sample = round(t_on * Fs), 1-based');
check(ev(1).duration == 101 && ev(2).duration == 51 && ev(1).value == 1 && ev(1).offset == 0, ...
    'duration is the pulse length in samples (inclusive)');
evR = FieldTripExport.event(S.events, origFs);
check(evR(1).sample == 3000 && evR(1).duration == 3001, 'events at the recording rate');
ev0 = FieldTripExport.event(struct(), Fs);
check(isstruct(ev0) && isempty(ev0) && all(isfield(ev0, {'type', 'sample', 'value', 'offset', 'duration'})), ...
    'no lines -> empty event struct with the FieldTrip fields');
evU = FieldTripExport.event(struct('b', [0.9 1.0], 'a', [0.1 0.2]), Fs);
check(strcmp(evU(1).type, 'a') && strcmp(evU(2).type, 'b'), 'events are sorted by sample');

fprintf('\n== 5. validation ==\n');
hasFT = FieldTripExport.hasFieldTrip();
[ok, msg] = FieldTripExport.validate(data, "raw");
if hasFT
    check(ok && msg == "", 'ft_datatype_raw accepts the raw structure');
    [ok2, msg2] = FieldTripExport.validate(sp, "spike");
    check(ok2 && msg2 == "", 'ft_datatype_spike accepts the spike structure');
else
    check(ok && contains(msg, "not on the path"), 'validate is a no-op without FieldTrip');
    fprintf('  (FieldTrip not on the path; datatype checks skipped)\n');
end

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_FieldTripExport:Failures', '%d checks failed.', nFail);
end
end
