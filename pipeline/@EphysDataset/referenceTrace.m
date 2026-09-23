function r = referenceTrace(obj, X)
%referenceTrace  The common reference of [nSamples x nChan] data, per sample.
%   R = ds.referenceTrace(X) returns the [nSamples x 1] reference that
%   applyReference subtracts from every channel of X (all of the recording's
%   amplifier channels, in recording order, microvolts), in X's class, as
%   ArtifactConfig.Reference says: the mean ("car") or median ("cmr") across
%   referenceChannels(). It is [] for "none" and for an empty X.
%   deriveSignals computes it once and subtracts it from the signals that
%   take it (referenceSignals) only.
%
%   See also EphysDataset.applyReference, EphysDataset.referenceChannels.

r = [];
acfg = EphysDataset.normalizeArtifactConfig(obj.ArtifactConfig);
mode = string(acfg.Reference);
if mode == "none" || isempty(X)
    return
end

ch = obj.referenceChannels();
ch = ch(ch <= size(X, 2));
if isempty(ch)
    error('EphysDataset:applyReference:NoChannels', ...
        'Every channel of %s is left out of the common reference; include at least one.', obj.Name);
end

switch mode
    case "car"
        r = mean(X(:, ch), 2);
    case "cmr"
        r = median(X(:, ch), 2);
    otherwise
        error('EphysDataset:applyReference:BadMode', ...
            'Unknown Reference "%s" (use "none", "car" or "cmr").', mode);
end
end
