function [bad, info] = suggestReferenceExclude(obj, opts)
%suggestReferenceExclude  Channels to leave out of the common reference.
%   [BAD, INFO] = ds.suggestReferenceExclude() applies the rule of Ludwig et
%   al. (2009, J Neurophysiol 101:1679): a channel is "good" for the common
%   average when its noise floor lies between ReferenceBadLow (0.3) and
%   ReferenceBadHigh (2) times the mean noise floor across the channels.
%   Channels outside that band - dead or shorted sites below it, broken or
%   high-impedance sites (typically 3-6x) above it - are returned in BAD
%   (1-based, recording order). ExcludeChannels are already left out of the
%   reference, so they are neither suggested nor counted in the mean.
%
%   The noise floor is the robust SD (1.4826 x MAD) of the unreferenced
%   signal above the spike-band cut-off, which spikes and artifacts barely
%   move - the paper's SD after removing the threshold crossings. It is
%   measured on a sample of the recording (MaxChunks chunks spread evenly
%   over it), which is enough for a per-channel level.
%
%   Nothing is changed: set ReferenceExclude (and ReferenceExcludeSource)
%   to use the suggestion. prepareReference does that for a dataset whose
%   list was never set.
%
%   Options
%   -------
%     Low        (1,1) double  lower bound, x mean (default ArtifactConfig.ReferenceBadLow)
%     High       (1,1) double  upper bound, x mean (default ArtifactConfig.ReferenceBadHigh)
%     CutoffHz   (1,1) double  high-pass the level is measured above
%                (default ArtifactConfig.NoiseBandHz, 300 Hz when that is 0)
%     MaxChunks  (1,1) double  chunks read (default 8; Inf = the whole recording)
%     ProgressFcn function handle  ProgressFcn(i, nChunks, chunkName)
%
%   INFO: sigma [1 x nChan] noise floor (uV, NaN for ExcludeChannels),
%   ratio [1 x nChan] sigma / mean, meanSigma, low, high, cutoffHz, bad,
%   excluded (ExcludeChannels), channelNames, nChunks, summary (one line).
%
%   See also EphysDataset.applyReference, EphysDataset.noiseLevels.

arguments
    obj (1,1) EphysDataset
    opts.Low (1,1) double = NaN
    opts.High (1,1) double = NaN
    opts.CutoffHz (1,1) double = NaN
    opts.MaxChunks (1,1) double {mustBePositive} = 8
    opts.ProgressFcn = []
end

acfg = EphysDataset.normalizeArtifactConfig(obj.ArtifactConfig);
lo = opts.Low;       if isnan(lo); lo = acfg.ReferenceBadLow;  end
hi = opts.High;      if isnan(hi); hi = acfg.ReferenceBadHigh; end
cut = opts.CutoffHz; if isnan(cut); cut = acfg.NoiseBandHz;    end
if ~(cut > 0); cut = 300; end
if ~(lo >= 0 && hi > lo)
    error('EphysDataset:suggestReferenceExclude:Bounds', ...
        'The bounds must satisfy 0 <= Low < High (got %g and %g).', lo, hi);
end

nl = obj.noiseLevels(Reference=false, Filter=true, FilterType="highpass", ...
    FilterCutoff=cut, MaxChunks=opts.MaxChunks, ProgressFcn=opts.ProgressFcn);

sigma = nl.sigma;
nChan = numel(sigma);
excluded = obj.ExcludeChannels(obj.ExcludeChannels <= nChan);
counted = setdiff(1:nChan, excluded);
sigma(excluded) = NaN;
meanSigma = mean(sigma(counted));
ratio = sigma / meanSigma;
if ~(meanSigma > 0)
    ratio(counted) = 0;          % a flat recording: nothing to tell apart
    bad = double.empty(1, 0);
else
    bad = counted(ratio(counted) < lo | ratio(counted) > hi);
end

names = nl.channelNames;
if numel(names) ~= nChan; names = "ch" + string(1:nChan); end
if isempty(bad)
    summary = sprintf("no channel outside %.2g-%.2gx the mean noise (%.2f uV)", lo, hi, meanSigma);
else
    parts = compose("%s %.2fx", names(bad).', ratio(bad).');
    summary = sprintf("%d of %d outside %.2g-%.2gx the mean noise (%.2f uV): %s", ...
        numel(bad), numel(counted), lo, hi, meanSigma, strjoin(parts, ", "));
end

info = struct('sigma', sigma, 'ratio', ratio, 'meanSigma', meanSigma, ...
    'low', lo, 'high', hi, 'cutoffHz', cut, 'bad', bad, 'excluded', excluded, ...
    'channelNames', names, 'nChunks', nl.nChunks, 'summary', string(summary));
end
