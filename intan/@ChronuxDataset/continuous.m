function [data, params, info] = continuous(obj, opts)
%continuous  Continuous data as a Chronux [samples x channels] matrix.
%   [DATA, PARAMS] = cx.continuous() returns the whole loaded signal as a
%   [nSamples x nChannels] double matrix of microvolts, plus the matching
%   Chronux params struct (params.Fs is this signal's sample rate). That is the
%   input form of mtspectrumc, mtspecgramc, coherencyc, CrossSpecMatc,
%   rmlinesc, locdetrend and the rest of the continuous family. With
%   params.trialave = 1 Chronux averages over the columns, so pass one channel
%   at a time (or use trials) when you do not want channels averaged together.
%
%   [DATA, PARAMS, INFO] = cx.continuous(Name=Value) options:
%     Channels   [] (all, default), 1-based column indices in the order you
%                want them, or channel labels (matched against ChannelLabels)
%     TimeRange  [t0 t1] seconds, recording-relative, inclusive; the samples
%                kept are those with (row-1)/Fs in [t0 t1]. Default [-Inf Inf]
%     Detrend    "none" (default) | "constant" (subtract each column's mean) |
%                "linear" (MATLAB DETREND). Chronux's own locdetrend is a
%                moving-window detrend and is not applied here
%     Class      "double" (default, what Chronux's tapers are computed in) |
%                "single" | "asis"
%     Tapers, Pad, Fpass, Err, TrialAve  per-call params overrides
%
%   INFO reports exactly what was handed over: channels, labels, sampleRange
%   (1-based, inclusive), timeRange (the actual seconds those samples span),
%   fs, nSamples, nChan, signal, units, detrend, class and nonFinite (the
%   number of NaN/Inf samples in DATA, which would make Chronux return NaN).
%
%   Example
%   -------
%     cx = ChronuxDataset("D:\rec\subj1_day1", Signal="LFP");
%     cx.Tapers = ChronuxDataset.tapersFor(2, 10);          % +/-2 Hz over 10 s
%     [data, params] = cx.continuous(Channels=1, TimeRange=[0 10]);
%     [S, f] = mtspectrumc(data, params);                   % Chronux
%
%   See also ChronuxDataset.trials, ChronuxDataset.makeParams.

arguments
    obj (1,1) ChronuxDataset
    opts.Channels = []
    opts.TimeRange (1,2) double = [-Inf Inf]
    opts.Detrend (1,1) string {mustBeMember(opts.Detrend, ...
        ["none","constant","linear"])} = "none"
    opts.Class (1,1) string {mustBeMember(opts.Class, ...
        ["double","single","asis"])} = "double"
    opts.Tapers (1,:) double = double.empty(1,0)
    opts.Pad double = []
    opts.Fpass (1,:) double = double.empty(1,0)
    opts.Err (1,:) double = double.empty(1,0)
    opts.TrialAve double = []
end

obj.loadSignal();
[ch, labels] = obj.resolveChannels(opts.Channels);
[i0, i1] = obj.resolveSampleRange(opts.TimeRange);

data = obj.Data(i0:i1, ch);
data = ChronuxDataset.castTo(data, opts.Class);

switch opts.Detrend
    case "constant", data = detrend(data, 0);
    case "linear",   data = detrend(data, 1);
end

params = obj.params(Fs=obj.Fs, Tapers=opts.Tapers, Pad=opts.Pad, ...
    Fpass=opts.Fpass, Err=opts.Err, TrialAve=opts.TrialAve);

info = struct();
info.signal      = obj.Signal;
info.fs          = obj.Fs;
info.units       = "microvolts";
info.channels    = ch;
info.labels      = labels;
info.sampleRange = [i0 i1];
info.timeRange   = ([i0 i1] - 1) / obj.Fs;   % t = (row-1)/Fs
info.nSamples    = size(data, 1);
info.nChan       = size(data, 2);
info.detrend     = opts.Detrend;
info.class       = class(data);
info.nonFinite   = nnz(~isfinite(data));

if info.nonFinite > 0
    warning('ChronuxDataset:NonFinite', ...
        ['%d non-finite samples in the returned data; Chronux will return NaN ' ...
         'spectra. Select a clean TimeRange or drop the channel.'], info.nonFinite);
end
end

